import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';

bool runDesktopWebViewTitleBar(List<String> args) {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return false;
  }
  return runWebViewTitleBarWidget(args);
}
