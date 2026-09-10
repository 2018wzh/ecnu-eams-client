# desktop_webview_window (local patch)

Source: MixinNetwork/flutter-plugins, published desktop_webview_window 0.3.0.
The upstream MIT license is retained in LICENSE.

Windows patch: `launch(..., triggerOnUrlRequestEvent: false)` leaves navigation
under WebView2 control until another explicit launch changes that flag. Upstream
re-enables interception after one navigation, cancelling and replaying subsequent
redirects and form submissions as GET requests. Native navigation preserves the
school SSO redirects and POST bodies. This mode does not call the URL decision
callback; the application reads login state with origin-scoped JavaScript.

All other plugin behavior is unchanged. Do not edit the global pub cache.
