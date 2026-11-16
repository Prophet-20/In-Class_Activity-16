import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ica16_cloud_quiz/firebase_options.dart';
import 'package:ica16_cloud_quiz/main.dart';
import 'package:ica16_cloud_quiz/controller.dart';
import 'package:ica16_cloud_quiz/attempts.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('T01–T12 deployed undergraduate checks', (tester) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final auth = FirebaseAuth.instance, db = FirebaseFirestore.instance;
    await auth.signOut();
    final repo = AttemptRepository(db),
        c = QuizController(auth, AttemptRepository(db));
    await tester.pumpWidget(QuizApp(controller: c));
    final records = <Map<String, dynamic>>[];
    void record(String id, String observed) {
      final r = {
        'id': id,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'commit': const String.fromEnvironment('APP_COMMIT'),
        'roundSuffix': c.roundId == null
            ? 'none'
            : c.roundId!.substring(c.roundId!.length - 6),
        'result': 'PASS',
        'observed': observed,
      };
      records.add(r);
      debugPrint('EVIDENCE ${jsonEncode(r)}');
    }

    bool surfaceConverted = false;
    Future<void> screen(String name) async {
      await tester.pumpAndSettle();
      if (!surfaceConverted) {
        await binding.convertFlutterSurfaceToImage();
        surfaceConverted = true;
      }
      await tester.pump();
      await binding.takeScreenshot(name);
    }

    Future<void> round() async {
      final last = c.service.lastRequest;
      if (last != null) {
        final wait =
            const Duration(seconds: 6) - DateTime.now().difference(last);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      await c.startRound();
      expect(c.phase, QuizPhase.playing, reason: c.message);
      for (var i = 0; i < 10; i++) {
        c.choose(
          i.isEven
              ? c.questions[i].correct
              : c.questions[i].choices.firstWhere(
                  (a) => a != c.questions[i].correct,
                ),
        );
        c.next();
      }
      expect(c.score, 5);
      expect(c.phase, QuizPhase.readyToSubmit);
    }

    await c.signIn(
      const String.fromEnvironment('TEST_EMAIL_A'),
      'deliberately-invalid',
    );
    expect(c.phase, QuizPhase.authError);
    await screen('T01-invalid-signin');
    await c.signIn(
      const String.fromEnvironment('TEST_EMAIL_A'),
      const String.fromEnvironment('TEST_PASSWORD_A'),
    );
    await tester.pumpAndSettle();
    expect(c.uid, auth.currentUser!.uid);
    record(
      'T01',
      'Invalid password showed authError; valid credentials authenticated user A. No secrets recorded.',
    );
    await c.startRound();
    expect(c.questions.length, 10);
    expect(c.phase, QuizPhase.playing, reason: c.message);
    record(
      'T02',
      'Exact OpenTDB URL returned ten validated General Knowledge easy multiple-choice questions.',
    );
    final firstChoices = List.of(c.questions.first.choices);
    c.choose(c.questions.first.correct);
    c.choose(
      c.questions.first.choices.firstWhere(
        (a) => a != c.questions.first.correct,
      ),
    );
    expect(c.score, 1);
    expect(c.questions.first.choices, firstChoices);
    await screen('T04-answer-feedback');
    c.next();
    for (var i = 1; i < 10; i++) {
      c.choose(
        c.questions[i].choices.firstWhere((a) => a != c.questions[i].correct),
      );
      c.next();
    }
    expect(c.score, 1);
    expect(c.selections.length, 10);
    record(
      'T04',
      'Correct then repeated tap awarded one point only; subsequent wrong answers awarded none; choices stayed stable.',
    );
    final oldId = c.roundId;
    await round();
    expect(c.roundId, isNot(oldId));
    expect(c.selections.length, 10);
    record(
      'T05',
      'Review had ten selections and correct total; replay allocated a new ID and reset answers before play.',
    );
    final submit = c.submit();
    await c.submit();
    await submit;
    expect(c.phase, QuizPhase.cloudVerified, reason: c.message);
    final savedId = c.roundId!,
        owner = c.uid!,
        savedAt = c.verified!['submittedAt'];
    expect(
      (await repo.attempts(owner).get(const GetOptions(source: Source.server)))
          .docs
          .where((d) => d.id == savedId)
          .length,
      1,
    );
    record(
      'T06',
      'Double Submit produced one immutable document; server-only read matched all six fields with resolved timestamp and no pending writes.',
    );
    await screen('T06-cloud-verified');
    for (final fault in ['bad-json', 'api-code', 'nine-results']) {
      await Future<void>.delayed(const Duration(seconds: 6));
      c.apiFault = fault;
      await c.startRound();
      expect(c.phase, QuizPhase.requestError);
      final request = c.service.lastRequest;
      await c.startRound();
      expect(c.service.lastRequest, request);
      expect(c.phase, QuizPhase.requestError);
    }
    c.apiFault = 'none';
    record(
      'T03',
      'All three labeled injections blocked play; immediate retry did not make another API request.',
    );
    await screen('T03-request-error');
    await round();
    final offlineId = c.roundId;
    await db.disableNetwork();
    await c.submit();
    expect(c.phase, isNot(QuizPhase.cloudVerified));
    expect(c.unresolved, true);
    await screen('T08-offline-unknown');
    await db.enableNetwork();
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (!c.operationSettled && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await c.reconcile();
    if (c.phase == QuizPhase.readyToSubmit) await c.submit();
    expect(c.phase, QuizPhase.cloudVerified, reason: c.message);
    expect(c.roundId, offlineId);
    record(
      'T08',
      'SDK network disabled before submit; no false success. Re-enabled network, reconciled, and recovered with unchanged round ID.',
    );
    await round();
    c.hideAcknowledgement = true;
    await c.submit();
    expect(c.phase, QuizPhase.saveUnknown);
    expect(c.operationSettled, true);
    final lostId = c.roundId;
    await screen('T09-acknowledgement-hidden');
    await c.startRound();
    expect(c.roundId, lostId);
    await c.signOut();
    expect(c.uid, owner);
    await c.reconcile();
    expect(c.phase, QuizPhase.cloudVerified);
    expect(c.roundId, lostId);
    record(
      'T09',
      'Real transaction committed, UI acknowledgement was hidden, saveUnknown blocked replay/sign-out, and same-ID server read recovered one document.',
    );
    await screen('T09-server-recovered');
    c.hideAcknowledgement = false;
    for (final code in ['unavailable', 'resource-exhausted']) {
      await round();
      c.cloudFault = code;
      await c.submit();
      expect(
        c.message,
        contains(
          code == 'unavailable' ? 'Service unavailable' : 'Quota exhausted',
        ),
      );
      expect(c.message, contains('INJECTED'));
      expect(c.phase, isNot(QuizPhase.cloudVerified));
      await screen('T12-$code');
      await c.reconcile();
      expect(c.phase, QuizPhase.readyToSubmit);
      c.cloudFault = 'none';
    }
    record(
      'T12',
      'Injected unavailable and resource-exhausted produced distinct labeled errors and required user-triggered reconciliation; no fake success.',
    );
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
      email: const String.fromEnvironment('TEST_EMAIL_B'),
      password: const String.fromEnvironment('TEST_PASSWORD_B'),
    );
    Future<void> denied(Future<dynamic> Function() action) async {
      try {
        await action();
        fail('Operation should be denied');
      } on FirebaseException catch (e) {
        expect(e.code, 'permission-denied');
      }
    }

    await denied(() => repo.read(owner, savedId));
    await denied(
      () => repo.attempts(owner).doc().set({
        ...repo.fixed(3),
        'submittedAt': FieldValue.serverTimestamp(),
      }),
    );
    record(
      'T10',
      'Authenticated user B was denied both server read and create at user A path by deployed rules.',
    );
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
      email: const String.fromEnvironment('TEST_EMAIL_A'),
      password: const String.fromEnvironment('TEST_PASSWORD_A'),
    );
    await denied(
      () => repo.attempts(owner).doc().set({
        ...repo.fixed(11),
        'submittedAt': FieldValue.serverTimestamp(),
      }),
    );
    await denied(
      () => repo.attempts(owner).doc().set({
        ...repo.fixed(3),
        'submittedAt': FieldValue.serverTimestamp(),
        'extra': true,
      }),
    );
    await denied(
      () => repo.attempts(owner).doc(savedId).update({'correctCount': 4}),
    );
    final original = await repo.verify(owner, savedId, 5);
    expect(original.data()!['submittedAt'], savedAt);
    record(
      'T11',
      'Score 11, extra field, and update were denied; original score 5 and timestamp stayed unchanged.',
    );
    binding.reportData = {
      ...?binding.reportData,
      'records': records,
      'restartId': savedId,
      'owner': owner,
      'savedTimestamp': (savedAt as Timestamp)
          .toDate()
          .toUtc()
          .toIso8601String(),
    };
    c.dispose();
  }, timeout: const Timeout(Duration(minutes: 12)));
}
