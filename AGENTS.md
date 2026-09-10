# ECNU EAMS Client

## Architecture

- `app/` is the Flutter GUI. Keep widgets, platform login, preferences and notifications here.
- `packages/eams_core/` is a pure Dart package shared by GUI and CLI. API requests, selection transactions, configuration validation and the automation scheduler belong here. Do not add Flutter dependencies to this package.
- `packages/eams_core/bin/eams.dart` is the CLI entry point. GUI exports versioned UTF-8 JSON including the current `token`, encoded as standard Base64. CLI accepts the string directly through `--config`; no configuration file or separate token input. Keep the per-student/turn/semester execution journal in the OS user state directory, without credentials.
- Bind persisted GUI targets to student, turn and semester. Never import the old unscoped automation cache.
- Only the shared scheduler performs automated selection. Monitoring is read-only. Use server `canSelect`/`hasCount` filtering rather than summing different categories of seats.
- A cancellation must prevent any subsequent mutation. A request already sent is reconciled through read-only requests; its outcome can remain uncertain. Never automatically resubmit an uncertain transaction.
- Checkpoint before submission. Keep the same student's GUI/CLI writer mutually exclusive on one machine. This is a local lock, not a distributed lock.
- Keep tokens and personal configurations out of source, sample data and logs. API base URL is fixed to the school endpoint.
- GUI credentials use flutter_secure_storage; never restore the removed SharedPreferences token path. Existing plaintext tokens are discarded and require a fresh login. Base64 CLI export intentionally includes the current token.
- Release CI uses Flutter 3.44.1 and committed lockfiles. Tags must match GUI/core versions; all platforms must build before publishing. Android always requires the fixed release signing key. Windows distribution is a portable ZIP; no MSIX dependency is added during CI. See docs/releasing.md.

## Development

Use a feature branch for broad refactors. Keep existing worktrees and unrelated changes intact. Prefer small, relevant tests; do not submit real course selections to test code.

```sh
cd packages/eams_core
dart pub get
dart analyze
dart test test/api_service_test.dart test/automation_runner_test.dart
cd ../../app
flutter pub get
flutter analyze
flutter test test/automation_state_test.dart test/auth_provider_test.dart
```

Wait for an existing Flutter/build lock rather than killing its owner. Keep commands and documentation portable. Update this file and the README when runtime boundaries or the configuration contract change.
