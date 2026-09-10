import 'dart:async';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';

import 'app_log_service.dart';
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
    final log = AppLogService();
    await log.write('browser_login', 'opening');
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
    var extracting = false;
    var consecutiveErrors = 0;
    String? lastPageState;
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
        if (completer.isCompleted || currentWebview == null || extracting) {
          return;
        }
        extracting = true;
        try {
          final value = await currentWebview
              .evaluateJavaScript(browserLoginScript)
              .timeout(const Duration(seconds: 10));
          if (completer.isCompleted) return;
          final snapshot = BrowserLoginSnapshot.parse(value);
          if (snapshot == null) return; // A document is being replaced.
          consecutiveErrors = 0;
          final pageState = '${snapshot.origin} ${snapshot.ready}';
          if (pageState != lastPageState) {
            await log.write(
              'browser_login',
              'page_state',
              data: {'origin': snapshot.origin, 'ready': snapshot.ready},
            );
            lastPageState = pageState;
          }
          if (completer.isCompleted) return;
          if (snapshot.token != null) {
            await log.write('browser_login', 'token_received');
            if (completer.isCompleted) return;
            completer.complete(
              DesktopLoginResult(authorization: snapshot.token),
            );
            currentWebview.close();
          }
        } catch (error) {
          if (completer.isCompleted) return;
          consecutiveErrors++;
          await log.write(
            'browser_login',
            'extraction_failed',
            data: {
              'type': error.runtimeType.toString(),
              'consecutiveErrors': consecutiveErrors,
            },
          );
          if (consecutiveErrors >= 3 && !completer.isCompleted) {
            completer.complete(
              const DesktopLoginResult(
                errorMessage: '无法读取浏览器登录状态，请关闭后重试；详细原因见应用日志',
              ),
            );
            currentWebview.close();
          }
        } finally {
          extracting = false;
        }
      }

      // Keep native redirects and POST bodies intact (see the local plugin patch).
      webview.launch(_loginUrl, triggerOnUrlRequestEvent: false);

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
