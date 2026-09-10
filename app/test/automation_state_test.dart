import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'package:http/testing.dart';
import 'package:eams_core/eams_core.dart';
import 'package:ecnu_eams_client/providers/course_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(
    () => FlutterSecureStorage.setMockInitialValues({
      'authorization': 'test-token',
    }),
  );
  test('stop during token loading prevents automation startup', () async {
    SharedPreferences.setMockInitialValues({});
    final token = Completer<String?>();
    final api = ApiService(
      authorizationProvider: () => token.future,
      client: MockClient(
        (_) async => throw StateError('Stopped startup must not send requests'),
      ),
    );
    final provider = CourseProvider(apiService: api);
    await provider.bindContext(1, 2, 3);
    provider.addRobTarget({
      'id': 10,
      'course': {'nameZh': 'A'},
    }, virtualCost: 0);
    final running = provider.startRob(1, 2);
    expect(provider.isRobbing, isTrue);
    final stopped = provider.stopAllAndWait();
    token.complete('test-token');
    await stopped.timeout(const Duration(seconds: 2));
    await running;
    expect(provider.isRobbing, isFalse);
    expect(provider.automationError, isNull);
    await provider.saveAutomationState();
    provider.dispose();
    api.close();
  });
  test(
    'persists automation targets and config without starting loops',
    () async {
      SharedPreferences.setMockInitialValues({'authorization': 'test-token'});
      final provider = CourseProvider();
      await provider.bindContext(1, 2, 3);

      provider.setPollingConfig(
        const PollingConfig(
          timeout: Duration(seconds: 12),
          interval: Duration(milliseconds: 700),
        ),
      );
      provider.setRobInterval(const Duration(milliseconds: 250));
      provider.setMonitorInterval(const Duration(seconds: 3));
      provider.addRobTarget({
        'id': 10,
        'limitCount': 20,
        'course': {'nameZh': 'A'},
      }, virtualCost: 7);
      provider.addMonitorTarget({
        'id': 11,
        'limitCount': 20,
        'course': {'nameZh': 'B'},
      }, virtualCost: 5);
      await provider.saveAutomationState();

      final restored = CourseProvider();
      await restored.bindContext(1, 2, 3);

      expect(restored.pollingConfig.timeout, const Duration(seconds: 12));
      expect(
        restored.pollingConfig.interval,
        const Duration(milliseconds: 700),
      );
      expect(restored.robInterval, const Duration(milliseconds: 250));
      expect(restored.monitorInterval, const Duration(seconds: 3));
      expect(restored.robTargets.single['virtualCost'], 7);
      expect(restored.monitorTargets.single['virtualCost'], 5);
      expect(restored.isRobbing, isFalse);
      expect(restored.isMonitoring, isFalse);
      final exported = AutomationConfig.fromJson(
        (await restored.buildRobConfig()).toJson(),
      );
      expect(exported.studentId, 1);
      expect(exported.turnId, 2);
      expect(exported.semesterId, 3);
      expect(exported.targets.single.lessonId, 10);
      await restored.bindContext(1, 99, 3);
      expect(restored.robTargets, isEmpty);
      await restored.bindContext(1, 2, 3);
      expect(restored.robTargets.single['id'], 10);
      await restored.clearSession();
      expect(restored.robTargets, isEmpty);
      expect(restored.selectedCourses, isEmpty);
      provider.dispose();
      restored.dispose();
    },
  );
}
