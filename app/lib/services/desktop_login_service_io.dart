import 'dart:async';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';

import 'package:eams_core/eams_core.dart';

class DesktopLoginResult {
  final String? authorization;
  final String? errorMessage;

  const DesktopLoginResult({this.authorization, this.errorMessage});

  bool get success => authorization != null && authorization!.isNotEmpty;
}

class DesktopLoginService {
  static const _loginUrl = 'https://byyt.ecnu.edu.cn/';

  Future<DesktopLoginResult> login() async {
    if (!Platform.isWindows) {
      return const DesktopLoginResult(errorMessage: '内置自动登录仅支持 Windows');
    }
    final available = await WebviewWindow.isWebviewAvailable();
    if (!available) {
      return const DesktopLoginResult(
        errorMessage: '未检测到 WebView2 Runtime，请安装后重试或手动输入 Token',
      );
    }

    final completer = Completer<DesktopLoginResult>();
    Timer? timer;
    Webview? webview;
    try {
      webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          windowWidth: 1100,
          windowHeight: 760,
          title: 'ECNU 统一认证登录',
          userDataFolderWindows:
              '${Directory.systemTemp.path}${Platform.pathSeparator}ecnu_eams_webview2',
        ),
      );

      Future<void> tryExtract() async {
        final currentWebview = webview;
        if (completer.isCompleted || currentWebview == null) return;
        try {
          final value = await currentWebview.evaluateJavaScript(r'''
(() => {
  if (window.location.origin !== 'https://byyt.ecnu.edu.cn') return '';
  const keys = ['authorization', 'Authorization', 'token', 'access_token'];
  for (const store of [window.localStorage, window.sessionStorage]) {
    for (const key of keys) {
      const value = store.getItem(key);
      if (value) return value;
    }
  }
  return '';
})()
''');
          final token = value?.trim() ?? '';
          if (completer.isCompleted) return;
          if (token.isNotEmpty && token != 'null' && token != 'undefined') {
            completer.complete(
              DesktopLoginResult(
                authorization: AuthTokenNormalizer.normalize(token),
              ),
            );
            currentWebview.close();
          }
        } catch (_) {
          // 页面跨阶段加载时 JS 可能短暂失败，下一轮继续。
        }
      }

      webview
        ..launch(_loginUrl)
        ..setOnUrlRequestCallback((url) {
          if (url.contains('byyt.ecnu.edu.cn') && !url.contains('login')) {
            Future<void>.delayed(const Duration(milliseconds: 500), tryExtract);
          }
          return true;
        });

      timer = Timer.periodic(const Duration(seconds: 1), (_) => tryExtract());
      webview.onClose.whenComplete(() {
        timer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(
            const DesktopLoginResult(errorMessage: '登录窗口已关闭，未获取到 Token'),
          );
        }
      });
      return await completer.future;
    } catch (e) {
      timer?.cancel();
      webview?.close();
      return DesktopLoginResult(errorMessage: '内置登录失败: $e');
    }
  }
}
