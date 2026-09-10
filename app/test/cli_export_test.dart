import 'package:ecnu_eams_client/widgets/cli_export_dialog.dart';
import 'package:eams_core/eams_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GUI exports a CLI-readable configuration with credentials',
      (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    const config = AutomationConfig(
        token: 'test-token',
        studentId: 1,
        turnId: 2,
        semesterId: 3,
        targets: [AutomationTarget(lessonId: 4, name: '测试课程')]);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: CliExportDialog(config: config))));
    await tester.tap(find.text('复制配置'));
    await tester.pump();
    final cli = AutomationConfig.fromBase64(clipboard!);
    expect(cli.targets.single.lessonId, 4);
    expect(cli.studentId, 1);
    expect(cli.token, 'test-token');
    await tester.tap(find.text('复制启动命令'));
    await tester.pump();
    expect(clipboard, 'eams --config "${config.toBase64()}"');
    await tester.tap(find.text('复制检查命令'));
    await tester.pump();
    expect(clipboard, 'eams --config "${config.toBase64()}" --check');
    expect(tester.takeException(), isNull);
  });
}
