import 'dart:async';
import 'dart:io';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:eams_core/eams_core.dart';
import 'package:flutter/services.dart';
import 'app_log_service.dart';

class DesktopLoginResult {
  final String? authorization;
  final PortalSession? portalSession;
  final String? errorMessage;
  const DesktopLoginResult({
    this.authorization,
    this.errorMessage,
    this.portalSession,
  });
  bool get success => authorization != null && authorization!.isNotEmpty;
}

class DesktopLoginService {
  static const _loginUrl = 'https://byyt.ecnu.edu.cn/';

  Future<DesktopLoginResult> login() async {
    final log = AppLogService();
    await log.write('browser_login', 'opening');
    if (!Platform.isWindows) {
      return const DesktopLoginResult(errorMessage: '内置登录仅支持 Windows');
    }
    if (!await WebviewWindow.isWebviewAvailable()) {
      return const DesktopLoginResult(
        errorMessage: '未检测到 WebView2 Runtime，请安装后重试或手动输入 Token',
      );
    }
    final completer = Completer<DesktopLoginResult>();
    Webview? webview;
    var closed = false;
    var extracting = false;
    try {
      final window = webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          windowWidth: 1100,
          windowHeight: 760,
          titleBarHeight: 64,
          title: '登录并进入选课后，点击“已登录，获取凭据并关闭”',
          userDataFolderWindows:
              '${Directory.systemTemp.path}${Platform.pathSeparator}ecnu_eams_webview2',
        ),
      );
      window.onClose.then((_) {
        closed = true;
        if (!completer.isCompleted) {
          completer.complete(const DesktopLoginResult(errorMessage: '已取消网页登录'));
        }
      });
      window.setTitleBarActionHandler((action) async {
        if (action != 'complete-login') return '不支持的登录操作';
        if (closed || completer.isCompleted) return '登录窗口已结束';
        if (extracting) return '正在读取登录凭据，请稍候';
        extracting = true;
        try {
          await log.write('browser_login', 'manual_complete_requested');
          final value = await window
              .evaluateJavaScript(browserLoginScript)
              .timeout(const Duration(seconds: 10));
          final snapshot = BrowserLoginSnapshot.parse(value);
          if (snapshot == null || snapshot.token == null) {
            return '尚未获取到选课 Token，请完成登录并进入“选课”服务后再次点击';
          }
          await log.write(
            'browser_login',
            'page_state',
            data: {'origin': snapshot.origin, 'ready': snapshot.ready},
          );
          final cookies = await window
              .getAllCookies(
                url: 'https://byyt.ecnu.edu.cn/portal-service/token/renew',
              )
              .timeout(const Duration(seconds: 10));
          final values = <String, String>{};
          await log.write(
            'browser_login',
            'portal_cookie_metadata',
            data: {
              'count': cookies.length,
              'cookies': cookies
                  .where(
                    (cookie) =>
                        cookie.name == 'SESSION' || cookie.name == 'cookie',
                  )
                  .map(
                    (cookie) => {
                      'name': cookie.name,
                      'domain': cookie.domain,
                      'path': cookie.path,
                      'secure': cookie.secure,
                      'httpOnly': cookie.httpOnly,
                      'sessionOnly': cookie.sessionOnly,
                      'valueLength': cookie.value.length,
                    },
                  )
                  .toList(),
            },
          );
          // Let WebView2 apply cookie domain/path/session rules for the exact
          // renewal URL. Secure/HttpOnly are attributes, not login validity tests.
          for (final cookie in cookies) {
            if (cookie.name == 'SESSION' || cookie.name == 'cookie') {
              if (values.containsKey(cookie.name)) {
                throw StateError('门户 Cookie 重复');
              }
              values[cookie.name] = cookie.value;
            }
          }
          final session = PortalSession.fromJson(values);
          if (closed || completer.isCompleted) return '登录窗口已结束';
          await log.write('browser_login', 'credentials_received');
          if (!completer.isCompleted) {
            completer.complete(
              DesktopLoginResult(
                authorization: snapshot.token,
                portalSession: session,
              ),
            );
          }
          return null;
        } catch (error) {
          await log.write(
            'browser_login',
            'manual_complete_failed',
            data: {
              'type': error.runtimeType.toString(),
              if (error is PlatformException) 'platformCode': error.code,
              if (error is PlatformException &&
                  error.code == 'cookie_read_failed')
                'propertyError': error.message,
            },
          );
          return error is FormatException
              ? error.message
              : '读取登录凭据失败（${error.runtimeType}），请重试或查看应用日志';
        } finally {
          extracting = false;
        }
      });
      // Only the title-bar button reads credentials. Preserve native SSO navigation.
      window.launch(_loginUrl, triggerOnUrlRequestEvent: false);
      final result = await completer.future;
      if (!closed) {
        await log.write('browser_login', 'closing');
        await window.close().timeout(const Duration(seconds: 10));
        await log.write('browser_login', 'close_acknowledged');
        await window.onClose.timeout(const Duration(seconds: 10));
      }
      await log.write('browser_login', 'closed');
      return result;
    } catch (error) {
      await log.write(
        'browser_login',
        'failed',
        data: {'type': error.runtimeType.toString()},
      );
      return DesktopLoginResult(
        errorMessage: '内置登录失败（${error.runtimeType}），请关闭登录窗口后重试',
      );
    } finally {
      webview?.setTitleBarActionHandler(null);
      if (webview != null && !closed) {
        try {
          await webview.close().timeout(const Duration(seconds: 10));
        } catch (error) {
          await log.write(
            'browser_login',
            'close_failed',
            data: {'type': error.runtimeType.toString()},
          );
        }
      }
    }
  }
}
