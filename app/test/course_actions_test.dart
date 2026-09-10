import 'dart:async';
import 'dart:io';
import 'package:ecnu_eams_client/providers/course_provider.dart';
import 'package:ecnu_eams_client/services/app_log_service.dart';
import 'package:eams_core/eams_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingApi extends ApiService {
  final entered = Completer<void>();
  final result = Completer<CourseActionResult>();
  CancellationToken? token;
  @override
  Future<CourseActionResult> addCourse(
      int studentID, int turnID, int lessonID, int virtualCost,
      {PollingConfig? polling, CancellationToken? cancellation}) {
    token = cancellation;
    entered.complete();
    return result.future;
  }
}

void main() {
  test('switching scope waits for an in-flight action and cancels further work',
      () async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('eams-action-test-');
    final api = PendingApi();
    final courses = CourseProvider(
        apiService: api, logService: AppLogService(directory: dir));
    await courses.bindContext(1, 2, 3);
    final action = courses.addCourse(1, 2, 4, 0);
    await api.entered.future;
    var switched = false;
    final change = courses.bindContext(1, 9, 3).then((_) => switched = true);
    await Future<void>.delayed(Duration.zero);
    expect(switched, isFalse);
    expect(api.token!.isCancelled, isTrue);
    api.result.complete(CourseActionResult.success(
        requestId: 'r',
        lessonResults: {},
        attempts: 1,
        elapsedMs: 1,
        selectedLessons: [
          {'id': 4}
        ]));
    expect(await action, isTrue);
    await change;
    expect(courses.selectedCourses, isEmpty);
    expect(courses.hasUncertainActions, isFalse);
    courses.dispose();
    api.close();
    await dir.delete(recursive: true);
  });

  test('selected list uses the already reconciled server snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('eams-action-test-');
    final api = PendingApi();
    final courses = CourseProvider(
        apiService: api, logService: AppLogService(directory: dir));
    await courses.bindContext(1, 2, 3);
    api.result.complete(CourseActionResult.success(
        requestId: 'r',
        lessonResults: {},
        attempts: 1,
        elapsedMs: 1,
        selectedLessons: [
          {
            'id': 4,
            'course': {'nameZh': '课程'}
          }
        ]));
    expect(await courses.addCourse(1, 2, 4, 0), isTrue);
    expect(courses.selectedCourses.single['id'], 4);
    courses.dispose();
    api.close();
    await dir.delete(recursive: true);
  });
}
