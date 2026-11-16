import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'attempts.dart';
import 'quiz.dart';

enum QuizPhase {
  signedOut,
  authError,
  loading,
  requestError,
  playing,
  readyToSubmit,
  submitting,
  verifying,
  cloudVerified,
  saveUnknown,
  permissionDenied,
  verificationUnavailable,
}

const developmentTools = bool.fromEnvironment('DEV_TOOLS');

class QuizController extends ChangeNotifier {
  final FirebaseAuth auth;
  final AttemptRepository repository;
  final QuestionService service;
  late final StreamSubscription<User?> _authSub;
  QuizPhase phase = QuizPhase.signedOut;
  String message = 'Sign in to start your cloud quiz.';
  String? uid, roundId;
  List<Question> questions = [];
  List<String?> selections = [];
  int index = 0, score = 0, _epoch = 0;
  bool busy = false, unresolved = false, operationSettled = true;
  Map<String, dynamic>? frozen, verified;
  String apiFault = 'none', cloudFault = 'none';
  bool hideAcknowledgement = false;
  QuizController(this.auth, this.repository, {QuestionService? service})
    : service = service ?? QuestionService() {
    uid = auth.currentUser?.uid;
    if (uid != null)
      message = 'Signed in. Start a round or retrieve a saved ID.';
    _authSub = auth.authStateChanges().listen((user) {
      if (user?.uid != uid) {
        _epoch++;
        uid = user?.uid;
        roundId = null;
        questions = [];
        selections = [];
        index = 0;
        score = 0;
        busy = false;
        unresolved = false;
        operationSettled = true;
        frozen = null;
        verified = null;
        phase = QuizPhase.signedOut;
        message = uid == null
            ? 'Sign in to start your cloud quiz.'
            : 'Signed in. Start a round or retrieve a saved ID.';
        notifyListeners();
      }
    });
  }
  bool get locked => busy || unresolved;
  bool current(int epoch, String owner, String? id) =>
      _epoch == epoch && uid == owner && roundId == id;
  void setPhase(QuizPhase next, String text) {
    phase = next;
    message = text;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      setPhase(
        QuizPhase.authError,
        'Sign-in failed (${e.code}). Check your credentials.',
      );
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (!locked) await auth.signOut();
  }

  Future<void> startRound() async {
    if (locked || uid == null) return;
    final owner = uid!, epoch = ++_epoch;
    roundId = repository.attempts(owner).doc().id;
    final id = roundId;
    questions = [];
    selections = [];
    score = 0;
    index = 0;
    frozen = null;
    verified = null;
    busy = true;
    setPhase(
      QuizPhase.loading,
      'Loading ten easy General Knowledge questions…',
    );
    try {
      final loaded = await service.load(
        injected: developmentTools ? apiFault : 'none',
      );
      if (!current(epoch, owner, id)) return;
      questions = loaded;
      selections = List.filled(10, null);
      setPhase(
        QuizPhase.playing,
        'Choose one answer. Your first selection is final.',
      );
    } catch (e) {
      if (current(epoch, owner, id))
        setPhase(QuizPhase.requestError, 'Question request: $e');
    } finally {
      if (current(epoch, owner, id)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void choose(String answer) {
    if (phase != QuizPhase.playing ||
        selections[index] != null ||
        !questions[index].choices.contains(answer))
      return;
    selections[index] = answer;
    if (answer == questions[index].correct) score++;
    message = answer == questions[index].correct
        ? 'Correct! One point added.'
        : 'Incorrect. Correct answer: ${questions[index].correct}';
    notifyListeners();
  }

  void next() {
    if (phase != QuizPhase.playing || selections[index] == null) return;
    if (index == 9) {
      frozen = Map.unmodifiable({
        ...repository.fixed(score),
        'submittedAt': FieldValue.serverTimestamp(),
      });
      setPhase(
        QuizPhase.readyToSubmit,
        'Round complete. Review your answers, then save to the cloud.',
      );
    } else {
      index++;
      message = 'Choose one answer. Your first selection is final.';
      notifyListeners();
    }
  }

  String errorText(Object e) {
    if (e is FirebaseException) {
      return switch (e.code) {
        'permission-denied' =>
          'Permission denied. This account cannot perform that operation.',
        'unauthenticated' => 'Authentication expired. Resolve this attempt after signing in again.',
        'unavailable' =>
          'Service unavailable. Reconnect, then check the same round ID.',
        'resource-exhausted' =>
          'Quota exhausted. Wait for capacity; no automatic retry.',
        _ =>
          'Cloud error (${e.code}). Check the same round ID before retrying.',
      };
    }
    return e.toString();
  }

  Future<void> submit() async {
    if (locked ||
        phase != QuizPhase.readyToSubmit ||
        frozen == null ||
        uid == null)
      return;
    final owner = uid!, id = roundId!, epoch = _epoch, payload = frozen!;
    busy = true;
    unresolved = true;
    operationSettled = false;
    setPhase(QuizPhase.submitting, 'Saving this round once…');
    final operation = () async {
      try {
        if (developmentTools && cloudFault != 'none') {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: cloudFault,
            message: 'Injected repository fault',
          );
        }
        await repository.commit(owner, id, payload);
      } finally {
        if (current(epoch, owner, id)) {
          operationSettled = true;
          notifyListeners();
        }
      }
    }();
    try {
      await operation.timeout(const Duration(seconds: 10));
      if (!current(epoch, owner, id)) return;
      if (developmentTools && hideAcknowledgement) {
        setPhase(
          QuizPhase.saveUnknown,
          'INJECTED: committed acknowledgement hidden. Check the same round ID.',
        );
      } else {
        await _verify(owner, id, epoch, score);
      }
    } on TimeoutException {
      if (current(epoch, owner, id))
        setPhase(
          QuizPhase.saveUnknown,
          'Save outcome unknown. A timeout does not cancel the write. Check the server.',
        );
    } catch (e) {
      if (current(epoch, owner, id)) {
        setPhase(
          e is FirebaseException && e.code == 'permission-denied'
              ? QuizPhase.permissionDenied
              : QuizPhase.saveUnknown,
          '${developmentTools && cloudFault != 'none' ? 'INJECTED: ' : ''}${errorText(e)}',
        );
      }
    } finally {
      if (current(epoch, owner, id)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> _verify(
    String owner,
    String id,
    int epoch,
    int? expected,
  ) async {
    setPhase(
      QuizPhase.verifying,
      'Reading this exact attempt from the server…',
    );
    try {
      final snap = await repository
          .verify(owner, id, expected)
          .timeout(const Duration(seconds: 10));
      if (!current(epoch, owner, id)) return;
      if (snap.exists) {
        verified = snap.data();
        unresolved = false;
        setPhase(
          QuizPhase.cloudVerified,
          'Cloud verified • server timestamp resolved • no pending writes',
        );
      } else if (!operationSettled) {
        setPhase(
          QuizPhase.saveUnknown,
          'Not found yet; the original operation is still running. Check again when it settles.',
        );
      } else {
        unresolved = false;
        setPhase(
          frozen == null ? QuizPhase.signedOut : QuizPhase.readyToSubmit,
          'No server document exists. ${frozen == null ? 'Check the ID.' : 'You can retry with this same ID.'}',
        );
      }
    } catch (e) {
      if (current(epoch, owner, id)) {
        setPhase(
          e is FirebaseException && e.code == 'permission-denied'
              ? QuizPhase.permissionDenied
              : QuizPhase.verificationUnavailable,
          'Verification unavailable. ${errorText(e)}',
        );
      }
    }
  }

  Future<void> reconcile() async {
    if (busy || uid == null || roundId == null) return;
    busy = true;
    final owner = uid!, id = roundId!, epoch = _epoch;
    await _verify(owner, id, epoch, frozen == null ? null : score);
    if (current(epoch, owner, id)) {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> retrieve(String id) async {
    if (locked ||
        uid == null ||
        !RegExp(r'^[A-Za-z0-9_-]{1,150}$').hasMatch(id))
      return;
    _epoch++;
    roundId = id;
    questions = [];
    selections = [];
    frozen = null;
    verified = null;
    operationSettled = true;
    await reconcile();
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}
