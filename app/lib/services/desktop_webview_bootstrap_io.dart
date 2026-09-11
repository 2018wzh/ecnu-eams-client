import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import '../widgets/desktop_login_title_bar.dart';

bool runDesktopWebViewTitleBar(List<String> args) {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return false;
  }
  return runWebViewTitleBarWidget(
    args,
    builder: (context) {
      final state = TitleBarWebViewState.of(context);
      final controller = TitleBarWebViewController.of(context);
      return DesktopLoginTitleBar(
        busy: state.actionPending,
        message: state.actionMessage,
        onComplete: () => controller.performAction('complete-login'),
        onBack: controller.back,
        onReload: controller.reload,
      );
    },
  );
}
