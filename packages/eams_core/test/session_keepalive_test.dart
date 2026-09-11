import 'dart:async';
import 'package:eams_core/eams_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'automation_runner_test.dart' show School, config;

void main() {
  for (final waiting in [true, false]) {
    test(
      'keepalive runs during ${waiting ? 'scheduled wait' : 'monitoring'} and stops on cancellation',
      () async {
        final school = School();
        var checks = 0;
        late AutomationRunner runner;
        final api = ApiService(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/students') && ++checks == 3) {
              runner.stop();
            }
            return school.handle(request);
          }),
        )..setAuthorization('test-token');
        addTearDown(api.close);
        runner = AutomationRunner(
          api: api,
          config: config(
            start: waiting ? parseSchoolTime('2026-09-10 12:01:00') : null,
          ),
          monitorOnly: true,
          keepAliveInterval: const Duration(milliseconds: 20),
          onUpdate: (_) async {},
        );
        await runner.run().timeout(const Duration(seconds: 2));
        expect(checks, 3);
        expect(school.writes, isEmpty);
        expect(runner.states[3]!.phase, TaskPhase.cancelled);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(checks, 3);
      },
    );
  }

  for (final failure in ['expired', 'identity', 'transport']) {
    test('keepalive $failure stops before any submission', () async {
      final school = School();
      var checks = 0;
      final api = ApiService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/students') && ++checks > 1) {
            if (failure == 'expired') return http.Response('', 401);
            if (failure == 'transport') throw http.ClientException('offline');
            school.students = [99];
          }
          return school.handle(request);
        }),
      )..setAuthorization('test-token');
      addTearDown(api.close);
      final runner = AutomationRunner(
        api: api,
        config: config(start: parseSchoolTime('2026-09-10 12:01:00')),
        keepAliveInterval: const Duration(milliseconds: 20),
        onUpdate: (_) async {},
      );
      await expectLater(runner.run(), throwsA(anything));
      expect(checks, 2);
      expect(school.writes, isEmpty);
      expect(runner.states[3]!.phase, TaskPhase.failed);
      expect(runner.states[3]!.message, contains('会话保活失败'));
    });
  }

  test('check-only never starts periodic maintenance', () async {
    final school = School();
    var checks = 0;
    final api = ApiService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/students')) checks++;
        return school.handle(request);
      }),
    )..setAuthorization('test-token');
    addTearDown(api.close);
    final runner = AutomationRunner(
      api: api,
      config: config(),
      keepAliveInterval: const Duration(milliseconds: 1),
      onUpdate: (_) async {},
    );
    await runner.run(checkOnly: true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(checks, 1);
    expect(school.writes, isEmpty);
  });
}
