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
  testWidgets('T07 new process retrieves original server record', (
    tester,
  ) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final auth = FirebaseAuth.instance;
    await auth.authStateChanges().first;
    if (auth.currentUser == null) {
      await auth.signInWithEmailAndPassword(
        email: const String.fromEnvironment('TEST_EMAIL_A'),
        password: const String.fromEnvironment('TEST_PASSWORD_A'),
      );
    }
    final c = QuizController(
      auth,
      AttemptRepository(FirebaseFirestore.instance),
    );
    await tester.pumpWidget(QuizApp(controller: c));
    await tester.pumpAndSettle();
    const id = String.fromEnvironment('RESTORE_ID');
    await c.retrieve(id);
    await tester.pumpAndSettle();
    expect(c.phase, QuizPhase.cloudVerified, reason: c.message);
    expect(c.questions, isEmpty);
    expect(c.verified!['correctCount'], 5);
    expect(
      (c.verified!['submittedAt'] as Timestamp)
          .toDate()
          .toUtc()
          .toIso8601String(),
      const String.fromEnvironment('RESTORE_TIMESTAMP'),
    );
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('T07-restarted-server-read');
    binding.reportData = {
      ...?binding.reportData,
      'records': [
        {
          'id': 'T07',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'commit': const String.fromEnvironment('APP_COMMIT'),
          'roundSuffix': id.substring(id.length - 6),
          'result': 'PASS',
          'observed': 'New Android process signed in as user A and retrieved original ID, score 5, and unchanged timestamp from Source.server without playing a round.',
        },
      ],
    };
    c.dispose();
  });
}
