import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ecnu_eams_client/providers/auth_provider.dart';
import 'package:ecnu_eams_client/providers/course_provider.dart';
import 'package:ecnu_eams_client/screens/rob_screen.dart';
import 'package:eams_core/eams_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(
    () => FlutterSecureStorage.setMockInitialValues({
      'authorization': 'test-token',
    }),
  );
  testWidgets('reorders GUI targets and exports the same order for CLI', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'authorization': 'test-token'});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthProvider();
    final courses = CourseProvider();
    await courses.bindContext(1, 2, 3);
    for (final id in [4, 5]) {
      courses.addRobTarget({
        'id': id,
        'course': {'nameZh': '课程$id'},
      }, virtualCost: 0);
    }
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: courses),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('选课')),
            body: const RobScreen(),
            bottomNavigationBar: NavigationBar(
              destinations: const [
                NavigationDestination(icon: Icon(Icons.search), label: '搜索'),
                NavigationDestination(icon: Icon(Icons.flash_on), label: '抢课'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('降低优先级').first);
    await tester.pumpAndSettle();
    expect(courses.robTargets.first['id'], 5);
    await tester.tap(find.text('停止并导出 CLI 配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制配置'));
    await tester.pumpAndSettle();
    final config = AutomationConfig.fromBase64(copied!);
    expect(config.targets.map((t) => t.lessonId), [5, 4]);
    expect(tester.takeException(), isNull);
    await courses.saveAutomationState();
    await tester.pumpWidget(const SizedBox());
    courses.dispose();
    auth.dispose();
  });
}
