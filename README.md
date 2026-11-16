# ICA16 Class A Cloud Quiz

This is Blake Cantave's undergraduate ICA16 project. It's an Android quiz built with Flutter that loads ten easy General Knowledge questions from OpenTDB. After signing in with Firebase Email/Password, you can play a round, review your answers, and save your score to Cloud Firestore.

The app checks the saved record directly with the server before showing **Cloud verified**. If a save's acknowledgement gets lost, it keeps the same round ID and checks what happened before letting you retry.

## Run the app

The project was built with Flutter 3.47.3 and Dart 3.13.3. You'll also need the Android SDK and an Android device or emulator.

The Android package is `edu.gsu.blake.ica16_cloud_quiz`. It connects to the separate Firebase project `ica16-a-cantave-1116`, which uses the Spark plan without billing. Its Firestore database is Standard edition, Native mode, in `nam5`.

```sh
flutter pub get
flutter run
flutter build apk --release
```

The release APK is written to `build/app/outputs/flutter-apk/app-release.apk`. This is a release-mode build signed with Flutter's local development key for the class installation test.

## Set up your own Firebase project

Start with a Firebase project on the Spark plan. In the console, initialize Authentication, enable Email/Password, and create two test accounts. Then create the default Firestore database in production mode, choosing Standard edition and Native mode. Register the Android package and run:

```sh
flutterfire configure --project=YOUR_PROJECT --platforms=android
firebase deploy --only firestore:rules --project=YOUR_PROJECT
```

The app initializes Firebase with the generated `DefaultFirebaseOptions.currentPlatform`. The main Android manifest already includes the INTERNET permission. If you change the native configuration, do a full rebuild.

Firebase's client configuration identifies the project. The deployed rules control who can read and write its data, so keep those rules in place when setting up another project.

Enter your credentials through the app's sign-in screen. Keep test passwords, Auth tokens, service-account files, and signing keys out of the repository and evidence. An authorized grader can get test access through an instructor-approved private channel.

To check an existing attempt, find its full document ID in the console using the six-character suffix in the evidence. Enter that ID under **Retrieve an existing attempt** and choose **Read from server**. The app always uses the signed-in user's UID.

## How saving and recovery work

A new round gets one ID from `attempts.doc().id`. Your first answer tap is final, and a completed round freezes the five fixed payload fields plus a server timestamp sentinel. The transaction reads the document before writing: it creates a missing record, reuses a matching one, and reports a collision if the existing values differ. The rules deny updates and deletes, so completed attempts stay unchanged.

After the transaction, the app uses `Source.server` to read that exact document. It checks the schema values, waits for a resolved timestamp, and requires a response with no cached data or pending writes before showing success.

A ten-second UI timeout does not cancel the transaction. If the outcome is unclear, `saveUnknown` blocks replay and sign-out while the app checks the server. A retry is allowed only when the earlier operation has settled and the document is absent. The retry keeps the same ID and score. Each response is also checked against the initiating UID, round ID, and epoch so an old response cannot change a newer session.

The SDK transaction is limited to three attempts and 20 seconds. OpenTDB requests time out after ten seconds, with at least five seconds between attempts. Application retries happen only when the user asks; there is no automatic retry loop.

## Run the checks

All twelve required checks passed on the Android emulator, including the tests that need a deployed Firebase backend. Start with static analysis and the local tests, then run the device checks:

```sh
flutter analyze
flutter test
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/cloud_flow_test.dart -d emulator-5554 \
  --dart-define=DEV_TOOLS=true --dart-define=REDACT_EVIDENCE=true \
  --dart-define=APP_COMMIT=YOUR_COMMIT \
  --dart-define-from-file=/PRIVATE/PATH/test-input.json
```

The private input file needs `TEST_EMAIL_A`, `TEST_PASSWORD_A`, `TEST_EMAIL_B`, and `TEST_PASSWORD_B`. Keep it outside this repository. Those values are embedded in the integration-test binary, so don't distribute that binary. Build the final release again without the test defines.

The separate `restart_test.dart` starts in a new process and signs in again if installation cleared the saved credentials. It reads the existing `RESTORE_ID` and checks its `RESTORE_TIMESTAMP`. Supply those two values and user A's credentials through another private input file. This check does not load new questions or recreate the saved document.

The failure checks cover different situations:

- **T08:** Turn off Firestore SDK networking, try to save, then reconnect and recover.
- **T09:** Complete a real cloud transaction, hide only its acknowledgement, and recover through a server read.
- **T10 and T11:** Send authenticated client requests that the deployed ownership and schema rules should reject.
- **T12:** Inject service and quota errors in the repository without using up quota.

The local unit tests also check malformed responses, duplicate answers after HTML decoding, and retry timing. The observed results and redacted screenshots are in [`evidence/`](evidence/).

## Where to find things

- [`lib/quiz.dart`](lib/quiz.dart) fetches and validates questions, decodes HTML entities, and shuffles each answer list once.
- [`lib/controller.dart`](lib/controller.dart) manages quiz state, scoring, save recovery, and checks for stale responses.
- [`lib/attempts.dart`](lib/attempts.dart) handles the create-once transaction and server-only verification.
- [`lib/main.dart`](lib/main.dart) contains the sign-in, quiz, review, feedback, and retrieval screens.
- [`firestore.rules`](firestore.rules) enforces ownership, the exact six-field schema, and immutable attempts.
- [`evidence/`](evidence/) contains the test records, screenshots, and state diagram.

The accompanying Word document includes the state diagram, four development checkpoints, all twelve test records, and six explanations. The source and evidence package is recorded at commit `6b80c0f395176997c16fa72b29a97195ef8c05fa`; the app revision used for the cloud run is `ecfafa09586eacf6659dbc773163b81af60b739f`. Later wording updates do not change the app or its test results.

The repository is published. Nothing has been submitted to the course portal.
