import 'package:ecnu_eams_client/widgets/desktop_login_title_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('instructions stay inline without clipped hover overlays', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 64));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: DesktopLoginTitleBar(
            busy: false,
            onComplete: () {},
            onBack: () {},
            onReload: () {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(Tooltip), findsNothing);
    final back = tester.getCenter(find.byIcon(Icons.arrow_back));
    final instructions = tester.getCenter(find.textContaining('进入“选课”后'));
    final complete = tester.getCenter(find.byType(FilledButton));
    expect(instructions.dy, back.dy);
    expect(complete.dy, back.dy);
    expect(instructions.dx, greaterThan(back.dx));
    expect(instructions.dx, lessThan(complete.dx));
  });
  testWidgets(
    'login completion requires a click and busy state blocks repeats',
    (tester) async {
      var completions = 0;
      Widget bar({bool busy = false, String? message}) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 64,
            child: DesktopLoginTitleBar(
              busy: busy,
              message: message,
              onComplete: () => completions++,
              onBack: () {},
              onReload: () {},
            ),
          ),
        ),
      );
      await tester.pumpWidget(bar());
      await tester.pump(const Duration(seconds: 2));
      expect(completions, 0);
      await tester.tap(find.text('已登录，获取凭据并关闭'));
      expect(completions, 1);
      await tester.pumpWidget(bar(busy: true));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.text('正在读取凭据…'), findsOneWidget);
      await tester.pumpWidget(bar(message: '请先进入选课服务'));
      expect(find.text('请先进入选课服务'), findsOneWidget);
      await tester.tap(find.text('已登录，获取凭据并关闭'));
      expect(completions, 2);
    },
  );
}
