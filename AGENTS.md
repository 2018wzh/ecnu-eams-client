# ECNU EAMS Client

## Architecture

- `app/` is the Flutter GUI. Keep widgets, platform login, preferences and notifications here.
- `packages/eams_core/` is a pure Dart package shared by GUI and CLI. API requests, selection transactions, configuration validation and the automation scheduler belong here. Do not add Flutter dependencies to this package.
- GUI and CLI share `ClientSession`, `ApiService.loadCoursePage`, `CourseCounts` and browser token decoding. Validate ordinary data flows with CLI `--action verify` before using Computer Use for window/navigation checks. Read-only actions never acquire the writer lease or read/write automation journals. Query configuration may contain only version/token; automatic selection still requires the complete scoped target configuration.
- The school std-count response has six fields: total enrollment, retakes, delayed releases, across-major enrollment, across-business enrollment and its limit (last two may be null). Do not subtract across-major enrollment from the total or relabel retakes as preselection. Use the same parser in GUI and CLI.
- Resolve course/lesson/teacher text filters against the school's `simplest-lessons` index and send matching lesson IDs to `query-lesson`; the server ignores text fields alone. Keep this resolution in the shared API so CLI verification exercises GUI search behavior.
- `packages/eams_core/bin/eams.dart` is the CLI entry point. GUI exports versioned UTF-8 JSON including the current `token`, encoded as standard Base64. CLI accepts the string directly through `--config`; no configuration file or separate token input. Keep the per-student/turn/semester execution journal in the OS user state directory, without credentials.
- Bind persisted GUI targets to student, turn and semester. Never import the old unscoped automation cache.
- Only the shared scheduler performs automated selection. Monitoring is read-only. Use server `canSelect`/`hasCount` filtering rather than summing different categories of seats.
- A cancellation must prevent any subsequent mutation. A request already sent is reconciled through read-only requests; its outcome can remain uncertain. Never automatically resubmit an uncertain transaction.
- Checkpoint before submission. Keep the same student's GUI/CLI writer mutually exclusive on one machine. This is a local lock, not a distributed lock.
- Keep tokens and personal configurations out of source, sample data and logs. API base URL is fixed to the school endpoint.
- GUI credentials use flutter_secure_storage; never restore the removed SharedPreferences token path. Existing plaintext tokens are discarded and require a fresh login. Base64 CLI export intentionally includes the current token.
- Windows browser login asks WebView2 for cookies applicable to the exact school renewal URL, then saves `SESSION` and `cookie` in secure storage. Do not reimplement domain/path matching or reject valid cookies based on Secure/HttpOnly attributes; session cookies have no persistent expiry. Full automation exports optionally include them as `portalSession`; token-only/manual login supports authenticated heartbeat checks but cannot renew. Never log or journal cookie values, and send them only to the fixed school portal renewal endpoint. Read-only exports omit the portal session.
- Shared automated tasks renew at startup and every five minutes, including scheduled/retry waits. POST `/portal-service/token/renew` requires the portal session and returns `code: 0` with `data.token`; verify the replacement student's identity before storing it. Serialize renewal against selection transactions, stop on renewal failure, and do not renew in `--check` or read-only actions. Cancellation prevents new renewal requests and later course mutations; it cannot revoke requests already sent.
- Windows browser login uses the vendored `packages/desktop_webview_window` patch with native navigation enabled for the whole login session. Never cancel and replay SSO redirects or POST submissions. Decode WebView2 JSON results and accept credentials only from the exact school HTTPS origin. Browser diagnostics record origin, document state and error types, never URLs containing tickets or tokens.
- Browser login completion is manual: the Flutter title-bar button sends a local action to the main isolate, which reads credentials once and closes on success. Never reintroduce automatic extraction timers. A failed extraction keeps the browser open and displays a retryable message; closing the native window cancels login. Title-bar messages must never carry credentials.
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
