import 'package:ecnu_eams_client/models/polling_config.dart';
import 'package:ecnu_eams_client/providers/course_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists automation targets and config without starting loops',
      () async {
    SharedPreferences.setMockInitialValues({});
    final provider = CourseProvider();

    provider.setPollingConfig(const PollingConfig(
      timeout: Duration(seconds: 12),
      interval: Duration(milliseconds: 700),
    ));
    provider.setRobInterval(const Duration(milliseconds: 250));
    provider.setMonitorInterval(const Duration(seconds: 3));
    provider.addRobTarget({
      'id': 10,
      'limitCount': 20,
      'course': {'nameZh': 'A'}
    }, virtualCost: 7);
    provider.addMonitorTarget({
      'id': 11,
      'limitCount': 20,
      'course': {'nameZh': 'B'}
    }, virtualCost: 5);
    await provider.saveAutomationState();

    final restored = CourseProvider();
    await restored.loadAutomationState();

    expect(restored.pollingConfig.timeout, const Duration(seconds: 12));
    expect(restored.pollingConfig.interval, const Duration(milliseconds: 700));
    expect(restored.robInterval, const Duration(milliseconds: 250));
    expect(restored.monitorInterval, const Duration(seconds: 3));
    expect(restored.robTargets.single['virtualCost'], 7);
    expect(restored.monitorTargets.single['virtualCost'], 5);
    expect(restored.isRobbing, isFalse);
    expect(restored.isMonitoring, isFalse);
  });
}
