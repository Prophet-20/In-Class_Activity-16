# ICA16 Class A Cloud Quiz

Undergraduate submission for Blake Cantave. Flutter Android quiz using ten easy General Knowledge questions from OpenTDB, Firebase Email/Password sign-in, and immutable Cloud Firestore attempts.

## Run

Flutter 3.47.3 / Dart 3.13.3; Android SDK installed. The app is registered as `edu.gsu.blake.ica16_cloud_quiz` in the separate no-billing project `ica16-a-cantave-1116`. Firestore is Standard edition, Native mode, region `nam5`.

```sh
flutter pub get
flutter run
flutter build apk --release
```

The release APK is `build/app/outputs/flutter-apk/app-release.apk`. It is a release-mode build using Flutter's local development signing key, suitable for this install-tested class delivery, not Play Store distribution. The delivered release contains no test passwords and no development fault controls.

## Configure a separate backend

Create a Firebase project on the Spark plan; initialize Authentication in the console, enable Email/Password, and create two test accounts. Create the default Standard/Native Firestore database in production mode. Register the Android package and run:

```sh
flutterfire configure --project=YOUR_PROJECT --platforms=android
firebase deploy --only firestore:rules --project=YOUR_PROJECT
```

Initialize using generated `DefaultFirebaseOptions.currentPlatform`. The main Android manifest includes INTERNET permission. Rebuild after native configuration changes. Firebase client configuration identifies the project; authorization comes from the deployed rules, not secrecy of that configuration.

Never publish test passwords, Auth tokens, service-account files, or signing keys. Supply credentials in the sign-in UI. An authorized grader can obtain test access through an instructor-approved private channel and locate the saved attempt by its six-character suffix in the evidence. The application accepts the full document ID in **Retrieve an existing attempt** and always uses the currently authenticated UID.

## Save and recovery

Each new round allocates one `attempts.doc().id`. Selections are final after the first tap. A completed round freezes five fixed fields plus a server timestamp sentinel. A transaction reads before creating, reuses matching data, and rejects collisions. Updates and deletes are denied by rules.

After commit, `Source.server` verification requires exact schema values, a resolved timestamp, and no cache/pending writes. A 10-second UI timeout does not cancel the transaction. `saveUnknown` disables replay/sign-out; server reconciliation may re-enable retry only after the operation settles and the document is absent. Requests retain initiating UID, round ID, and epoch guards so stale responses cannot affect another session.

The SDK transaction is bounded to three attempts and 20 seconds; UI retries are user-triggered. OpenTDB requests have a 10-second timeout and at least five seconds between attempts. No automatic application retry loop is used.

## Verification

```sh
flutter analyze
flutter test
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/cloud_flow_test.dart -d emulator-5554 \
  --dart-define=DEV_TOOLS=true --dart-define=REDACT_EVIDENCE=true \
  --dart-define=APP_COMMIT=YOUR_COMMIT \
  --dart-define-from-file=/PRIVATE/PATH/test-input.json
```

Private test input contains `TEST_EMAIL_A`, `TEST_PASSWORD_A`, `TEST_EMAIL_B`, and `TEST_PASSWORD_B`; never place it inside this repository. Integration test binaries embed that private input and must not be distributed. The final release is rebuilt without these defines.

`restart_test.dart` runs in a new process, signs in again when the installation cleared credentials, and reads `RESTORE_ID` with its expected `RESTORE_TIMESTAMP`; provide those keys and user A credentials through another private input file. It does not fetch quiz questions or recreate the document.

T08 disables the Firestore SDK network, then reconnects. T09 hides only the acknowledgement after a real cloud transaction. T10 and T11 exercise the deployed rules with authenticated client requests. T12 injects repository errors without consuming quota. The standalone unit tests cover malformed data, duplicate decoded choices, and rate limiting.

## Source map

- `lib/quiz.dart`: HTTP fetch, response/schema validation, entity decoding, stable shuffled choices.
- `lib/controller.dart`: state, scoring, save/reconcile guards, and stale-response isolation.
- `lib/attempts.dart`: create-once transaction and server-only verification.
- `lib/main.dart`: accessible feedback, review, sign-in and retrieval UI.
- `firestore.rules`: ownership, exact six-field create schema, immutable attempts.
- `evidence/`: observed test records and redacted screenshots.

The state diagram and six explanations are in the accompanying Word evidence document. Repository publication and course submission are held for the owner's approval.
