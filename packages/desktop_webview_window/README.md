# desktop_webview_window (local patch)

Source: MixinNetwork/flutter-plugins, published desktop_webview_window 0.3.0.
The upstream MIT license is retained in LICENSE.

Windows patch: `launch(..., triggerOnUrlRequestEvent: false)` leaves navigation
under WebView2 control until another explicit launch changes that flag. Upstream
re-enables interception after one navigation, cancelling and replaying subsequent
redirects and form submissions as GET requests. Native navigation preserves the
school SSO redirects and POST bodies. This mode does not call the URL decision
callback; the application reads login state with origin-scoped JavaScript.

The Dart `close()` method returns a Future so the application can wait for the
native close result and the `onClose` event before finishing login.
The Windows programmatic-close handler explicitly sends `onWindowClose` after
destroying the native window, matching the notification from a user close.
Title-bar sizing uses the actual window DPI, including after moving between
monitors with different scale factors.

Custom Flutter title bars can send actions to a window's Dart handler through
the existing isolate message channel. Pending state and an optional error message
are returned to the title bar. ECNU uses this for its manual login-completion
button; credentials never pass through the title-bar channel.

On Windows, `getAllCookies(url: ...)` delegates URL matching to WebView2's
CookieManager. Session cookies have no expiry date. Native cookie-property read
failures are returned explicitly instead of silently dropping entries.
Cookie strings reuse the existing length-aware UTF-8 converter, avoiding the
terminating NUL that the old cookie-specific converter appended to every field.

All other plugin behavior is unchanged. Do not edit the global pub cache.
