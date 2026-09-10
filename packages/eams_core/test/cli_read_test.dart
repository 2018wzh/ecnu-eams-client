import 'dart:convert';
import 'dart:io';
import 'package:eams_core/eams_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import '../bin/eams.dart' show runCli;
import 'api_service_test.dart' show reply;

class QuerySchool {
  String counts = '12-1-2-3-null-null';
  int semester = 4;
  final requests = <http.Request>[];
  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    expect(request.headers['Authorization'], 'test-token');
    final path = request.url.path;
    if (path.endsWith('/students')) return reply([41001]);
    if (path.contains('/open-turns/'))
      return reply([
        {'id': 2, 'allowEnter': true},
      ]);
    if (path.endsWith('/select'))
      return reply({
        'semester': {'id': semester},
      });
    if (path.contains('/simplest-lessons/'))
      return reply([
        {
          'id': 3,
          'courseName': '测试课程',
          'courseCode': 'T1',
          'lessonName': '测试班级',
          'lessonCode': 'L1',
          'teacherName': '教师',
        },
        {
          'id': 8,
          'courseName': '其他课程',
          'courseCode': 'T2',
          'lessonName': '其他班级',
          'lessonCode': 'L2',
          'teacherName': '其他',
        },
      ]);
    if (path.contains('/query-lesson/'))
      return reply({
        'lessons': [
          {
            'id': 3,
            'course': {'nameZh': '测试课程'},
          },
        ],
        'pageInfo': {'currentPage': 1, 'totalPages': 1, 'totalRows': 1},
      });
    if (path.endsWith('/std-count')) return reply({'3': counts});
    if (path.contains('/query-condition/')) return reply({});
    if (path.contains('/selected-lessons/'))
      return reply([
        {'id': 3},
      ]);
    if (path.endsWith('/count-info'))
      return reply({'stdCount': 12, 'limitCount': 20});
    throw StateError('Unexpected request: ${request.method} $path');
  }

  ApiService api() => ApiService(client: MockClient(handle));
}

void main() {
  final encoded = const ClientConfig(
    token: 'test-token',
    studentId: 41001,
  ).toBase64();
  test(
    'all read commands use shared services and never create a writer journal',
    () async {
      final dir = await Directory.systemTemp.createTemp('eams-read-test');
      addTearDown(() => dir.delete(recursive: true));
      final school = QuerySchool();
      final outputs = <Map<String, dynamic>>[];
      final lease = await ExecutionLease.acquire(41001);
      addTearDown(lease.release);
      for (final action in [
        'account',
        'courses',
        'selected',
        'count',
        'verify',
      ]) {
        final code = await runCli(
          [
            '--config',
            encoded,
            '--action',
            action,
            if (action == 'count') ...['--lesson', '3'],
          ],
          apiFactory: school.api,
          stateDirectory: dir,
          readOutput: outputs.add,
        );
        expect(code, 0, reason: action);
      }
      expect(outputs.last['ok'], isTrue);
      expect(outputs[1]['counts']['3']['stdCount'], 12);
      expect(outputs[1]['counts']['3']['retakeCount'], 1);
      expect(jsonEncode(outputs), isNot(contains('test-token')));
      expect(await dir.list().isEmpty, isTrue);
      expect(
        school.requests
            .where((r) => r.method == 'POST')
            .every(
              (r) =>
                  r.url.path.contains('/query-lesson/') ||
                  r.url.path.endsWith('/std-count'),
            ),
        isTrue,
      );
    },
  );
  test(
    'course filters and pagination use the same API contract as GUI',
    () async {
      final school = QuerySchool();
      expect(
        await runCli(
          [
            '--config',
            encoded,
            '--action',
            'courses',
            '--course',
            '测试',
            '--teacher',
            '教师',
            '--page',
            '2',
            '--page-size',
            '10',
            '--available',
            '--with-seats',
          ],
          apiFactory: school.api,
          readOutput: (_) {},
        ),
        0,
      );
      final body = jsonDecode(
        school.requests
            .singleWhere((r) => r.url.path.contains('/query-lesson/'))
            .body,
      );
      expect(body['courseNameOrCode'], '测试');
      expect(body['teacherNameOrCode'], '教师');
      expect(body['pageNo'], 2);
      expect(body['pageSize'], 10);
      expect(body['canSelect'], 1);
      expect(body['hasCount'], true);
      expect(body['ids'], [3]);
    },
  );
  test(
    'verify fails on the same malformed count that blocks the GUI',
    () async {
      final school = QuerySchool()..counts = '12-0-0-0';
      final output = <Map<String, dynamic>>[];
      expect(
        await runCli(
          ['--config', encoded, '--action', 'verify'],
          apiFactory: school.api,
          readOutput: output.add,
        ),
        1,
      );
      expect(output, isEmpty);
    },
  );
  test('scope mismatches and ambiguous command modes fail', () async {
    final school = QuerySchool();
    final stale = const ClientConfig(
      token: 'test-token',
      studentId: 41001,
      turnId: 2,
      semesterId: 9,
    ).toBase64();
    expect(
      await runCli(
        ['--config', stale, '--action', 'verify'],
        apiFactory: school.api,
        readOutput: (_) {},
      ),
      1,
    );
    expect(
      await runCli([
        '--config',
        encoded,
        '--action',
        'verify',
        '--once',
      ], apiFactory: school.api),
      1,
    );
    expect(
      await runCli([
        '--config',
        encoded,
        '--course',
        'test',
      ], apiFactory: school.api),
      1,
    );
    expect(await runCli(['--config', encoded], apiFactory: school.api), 1);
  });
}
