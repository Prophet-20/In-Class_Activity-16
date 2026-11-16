# Build checkpoints

All times America/New_York on November 16, 2026.

1. 18:04 — Flutter Android scaffold and dependencies ready; separate Firebase project created. Authentication initialized in the console and two disposable test users created using its Auth API. Firestore service setup required a REST fallback after the CLI repeatedly reported a disabled API.
2. 18:09 — Implementation checkpoint ae2796c: parser, quiz, immutable transaction, recovery controller, and UI. The obsolete scaffold widget test initially failed analysis and was replaced with parser/retry tests.
3. 18:13 — Failed-first device run reached authentication and live questions, then failed repeated surface conversion. Commit 705532b converts the Android screenshot surface once. ecfafa0 retains screenshots when adding test report metadata.
4. 18:16–18:24 — Full deployed run passed eleven checks; T07 passed at 18:18:58 in a new process after the harness allowed reauthentication following reinstall. Final release built, installed, and launched. Static analysis and three unit checks passed. Word evidence was rendered and checked.

The application sources tested by the final cloud run are in ecfafa09586eacf6659dbc773163b81af60b739f. Subsequent commits add the restart-harness correction, documentation, and evidence; the app runtime implementation is unchanged.
