import 'dart:async';
import 'dart:convert';
import 'package:eams_core/eams_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'api_service_test.dart' show reply;

class School {
  final selected = <int>{};
  final writes = <int>[];
  List<int> students = [1];
  Future<void> Function()? onEligibleQuery;
  bool reject = false;
  bool uncertain = false;
  int? eligibleLesson;
  late final api = ApiService(client: MockClient(handle))
    ..setAuthorization('token');
  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/students')) return reply(students);
    if (path.contains('/open-turns/'))
      return reply([
        {
          'id': 2,
          'allowEnter': true,
          'selectDateTimeRange': {
            'startDateTime': '2026-01-01 00:00:00',
            'endDateTime': '2027-01-01 00:00:00'
          },
        }
      ]);
    if (path.endsWith('/select'))
      return reply({
        'semester': {'id': 4}
      });
    if (path.endsWith('/getCurrentDateTime'))
      return reply('2026-09-10 12:00:00');
    if (path.contains('/selected-lessons/'))
      return reply(selected.map((id) => {'id': id}).toList());
    if (path.contains('/query-lesson/')) {
      final body = jsonDecode(request.body) as Map;
      if (body['canSelect'] == 1) {
        expect(body['hasCount'], isTrue);
        await onEligibleQuery?.call();
      }
      return reply({
        'lessons': (body['ids'] as List)
            .where((id) =>
                body['canSelect'] != 1 ||
                eligibleLesson == null ||
                eligibleLesson == id)
            .map((id) => {'id': id})
            .toList()
      });
    }
    if (path.endsWith('/add-predicate')) return reply('p');
    if (path.contains('/predicate-response/'))
      return reply(reject
          ? {'success': false, 'errorMessage': '时间冲突'}
          : {'success': true});
    if (path.endsWith('/add-request')) {
      final body = jsonDecode(request.body) as Map;
      final id = body['requestMiddleDtos'][0]['lessonAssoc'] as int;
      writes.add(id);
      if (uncertain) throw http.ClientException('connection lost');
      selected.add(id);
      return reply('r');
    }
    if (path.contains('/add-drop-response/')) return reply({'success': true});
    throw StateError('Unexpected endpoint: $path');
  }
}

AutomationConfig config(
        {List<int> targets = const [3], int semester = 4, DateTime? start}) =>
    AutomationConfig(
        token: 'test-token',
        studentId: 1,
        turnId: 2,
        semesterId: semester,
        startAt: start,
        targets: targets
            .map((id) => AutomationTarget(lessonId: id, name: '课程$id'))
            .toList());

void main() {
  test('repeated pre-submit transport failures stop after five attempts',
      () async {
    final school = School();
    final api = ApiService(
        client: MockClient((request) async =>
            request.url.path.endsWith('/add-predicate')
                ? http.Response('', 503)
                : school.handle(request)))
      ..setAuthorization('token');
    final runner =
        AutomationRunner(api: api, config: config(), onUpdate: (_) async {});
    await runner.run();
    expect(runner.states[3]!.phase, TaskPhase.failed);
    expect(runner.states[3]!.attempts, 5);
    expect(school.writes, isEmpty);
    api.close();
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('GUI JSON roundtrip can be used by runner; writes follow target order',
      () async {
    final school = School();
    final exported = config(targets: [5, 3]).encode();
    final updates = <TaskUpdate>[];
    final runner = AutomationRunner(
        api: school.api,
        config: AutomationConfig.fromJson(jsonDecode(exported)),
        onUpdate: (v) async => updates.add(v));
    await runner.run();
    expect(school.writes, [5, 3]);
    expect(updates.where((u) => u.phase == TaskPhase.succeeded).length, 2);
    school.api.close();
  });

  test('identity mismatch blocks every write', () async {
    final school = School()..students = [99];
    final runner = AutomationRunner(
        api: school.api, config: config(), onUpdate: (_) async {});
    await expectLater(runner.run(), throwsStateError);
    expect(school.writes, isEmpty);
    school.api.close();
  });

  test('semester mismatch blocks every write', () async {
    final school = School();
    final runner = AutomationRunner(
        api: school.api, config: config(semester: 9), onUpdate: (_) async {});
    await expectLater(runner.run(), throwsStateError);
    expect(school.writes, isEmpty);
    school.api.close();
  });

  test('stop during eligibility query prevents subsequent submission',
      () async {
    final school = School();
    late AutomationRunner runner;
    school.onEligibleQuery = () async => runner.stop();
    runner = AutomationRunner(
        api: school.api, config: config(), onUpdate: (_) async {});
    await runner.run();
    expect(school.writes, isEmpty);
    expect(runner.states[3]!.phase, TaskPhase.cancelled);
    school.api.close();
  });

  test('removal during eligibility query prevents that target submission',
      () async {
    final school = School();
    late AutomationRunner runner;
    school.onEligibleQuery = () async => runner.removeTarget(3);
    runner = AutomationRunner(
        api: school.api,
        config: config(targets: [3, 5]),
        onUpdate: (_) async {});
    await runner.run();
    expect(school.writes, [5]);
    school.api.close();
  });

  test('check and monitor modes are read-only', () async {
    for (final monitor in [false, true]) {
      final school = School();
      final runner = AutomationRunner(
          api: school.api,
          config: config(),
          monitorOnly: monitor,
          onUpdate: (_) async {});
      await runner.run(checkOnly: !monitor, once: true);
      expect(school.writes, isEmpty);
      school.api.close();
    }
  });

  test('already selected targets do not get resubmitted', () async {
    final school = School()..selected.add(3);
    final runner = AutomationRunner(
        api: school.api, config: config(), onUpdate: (_) async {});
    await runner.run();
    expect(school.writes, isEmpty);
    expect(runner.states[3]!.phase, TaskPhase.succeeded);
    school.api.close();
  });

  test('crash checkpoint with unconfirmed write never silently retries',
      () async {
    final school = School();
    final checkpoint = TaskUpdate(3, TaskPhase.submitting, '提交中').toJson();
    final runner = AutomationRunner(
        api: school.api,
        config: config(),
        initialStates: {3: TaskUpdate.fromJson(checkpoint)},
        onUpdate: (_) async {});
    await expectLater(runner.run(), throwsStateError);
    expect(school.writes, isEmpty);
    school.api.close();
  });

  test('uncertain write stops before the next target', () async {
    final school = School()..uncertain = true;
    final runner = AutomationRunner(
        api: school.api,
        config: config(targets: [3, 5]),
        onUpdate: (_) async {});
    await expectLater(runner.run(), throwsStateError);
    expect(school.writes, [3]);
    expect(runner.states[3]!.phase, TaskPhase.uncertain);
    school.api.close();
  });

  test('checkpoint failure prevents submission', () async {
    final school = School();
    final runner = AutomationRunner(
        api: school.api,
        config: config(),
        onUpdate: (u) async {
          if (u.phase == TaskPhase.submitting) throw StateError('disk full');
        });
    await expectLater(runner.run(), throwsStateError);
    expect(school.writes, isEmpty);
    school.api.close();
  });

  test('business rejection is shown and is not retried indefinitely', () async {
    final school = School()..reject = true;
    final runner = AutomationRunner(
        api: school.api, config: config(), onUpdate: (_) async {});
    await runner.run();
    expect(school.writes, isEmpty);
    expect(runner.states[3]!.phase, TaskPhase.failed);
    expect(runner.states[3]!.attempts, 1);
    school.api.close();
  });

  test('server eligibility filter excludes targets even if other seats exist',
      () async {
    final school = School()..eligibleLesson = 5;
    final runner = AutomationRunner(
        api: school.api,
        config: config(targets: [3, 5]),
        onUpdate: (_) async {});
    await runner.run(once: true);
    expect(school.writes, [5]);
    school.api.close();
  });

  test('scheduled wait stops promptly', () async {
    final school = School();
    final waiting = Completer<void>();
    final runner = AutomationRunner(
        api: school.api,
        config: config(start: DateTime.parse('2026-09-11T00:00:00Z')),
        onUpdate: (u) async {
          if (!waiting.isCompleted) waiting.complete();
        });
    final run = runner.run();
    await waiting.future;
    runner.stop();
    await run.timeout(const Duration(seconds: 1));
    expect(school.writes, isEmpty);
    school.api.close();
  });
}
