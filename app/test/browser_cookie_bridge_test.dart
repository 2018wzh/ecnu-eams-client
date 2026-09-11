import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('programmatic close notification completes onClose', () async {
    const channel = MethodChannel('webview_window');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var closes = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'create') return 9002;
      expect(call.method, 'close');
      closes++;
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onWindowClose', {'id': 9002}),
        ),
        (_) {},
      );
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final webview = await WebviewWindow.create();
    await webview.close();
    await webview.onClose.timeout(const Duration(seconds: 1));
    await webview.close();
    expect(closes, 1);
  });
  test(
    'cookie lookup passes renewal URL and respects session semantics',
    () async {
      const channel = MethodChannel('webview_window');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'create') return 9001;
        expect(call.method, 'getAllCookies');
        expect(
          call.arguments['url'],
          'https://byyt.ecnu.edu.cn/portal-service/token/renew',
        );
        return [
          {
            'name': 'SESSION',
            'value': 'test-session',
            'domain': '.ecnu.edu.cn',
            'path': '/',
            'secure': false,
            'httpOnly': true,
            'sessionOnly': true,
            'expires': 0,
          },
        ];
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final webview = await WebviewWindow.create();
      final cookies = await webview.getAllCookies(
        url: 'https://byyt.ecnu.edu.cn/portal-service/token/renew',
      );
      expect(cookies.single.expires, isNull);
      expect(cookies.single.domain, '.ecnu.edu.cn');
      expect(cookies.single.secure, isFalse);
    },
  );
}
