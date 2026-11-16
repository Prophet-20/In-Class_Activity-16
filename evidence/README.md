# Evidence index

`test-results.json` contains all twelve timestamped records with redacted round suffixes. Tests ran on the real Android emulator and Firebase project ica16-a-cantave-1116. The restart check ran in a new app process and signed in again after test installation cleared local Auth state.

- `screenshots/T01-invalid-signin.png`: visible authentication error.
- `screenshots/T03-request-error.png`: blocked malformed/incomplete request and rate limit.
- `screenshots/T04-answer-feedback.png`: readable one-answer feedback.
- `screenshots/T06-cloud-verified.png`: online transaction verified.
- `screenshots/T07-restarted-server-read.png`: original payload retrieved in a new process.
- `screenshots/T08-offline-unknown.png`: no false success offline.
- `screenshots/T09-acknowledgement-hidden.png` and `T09-server-recovered.png`: real commit, injected acknowledgement loss, same-ID recovery.
- `screenshots/T12-unavailable.png` and `T12-resource-exhausted.png`: distinct injected errors.
- `screenshots/firestore-console-redacted.png`: cropped Safari console field view for the T06/T07 record ending tFHVBO, timestamp 2026-11-16T23:16:16.323Z.
- `state-diagram.png`: implemented states and key guards.

T10 and T11 are assertion-backed SDK tests against the deployed rules; their observed results are in the JSON log. The corresponding original record remained at score 5 with an unchanged timestamp. Screenshots are captured from the running app. Test builds can redact path prefixes using REDACT_EVIDENCE; no credentials are displayed. The console capture is cropped to exclude identifiers without changing field values.

To reproduce, use the README commands with private test input. Find the full saved ID in the authorized console by suffix and enter it in the app's existing-attempt retrieval control. Do not publish test passwords or test binaries that embed private inputs.
