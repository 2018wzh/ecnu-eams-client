import 'dart:convert';
import 'package:eams_core/eams_core.dart';
import 'package:test/test.dart';
import 'automation_runner_test.dart' show config;

void main() {
  test('Base64 preserves token, Unicode names and scheduling fields', () {
    final original = config(start: DateTime.utc(2026, 9, 10));
    final decoded = AutomationConfig.fromBase64(original.toBase64());
    expect(decoded.toJson(), original.toJson());
    expect(decoded.token, 'test-token');
    expect(decoded.targets.single.name, '课程3');
  });
  test('malformed Base64, UTF-8 and JSON fail without echoing input', () {
    for (final text in [
      'secret!bad',
      base64Encode([255]),
      base64Encode(utf8.encode('secret-invalid-json')),
      base64Encode(utf8.encode('[]'))
    ]) {
      try {
        AutomationConfig.fromBase64(text);
        fail('Invalid configuration was accepted');
      } on FormatException catch (e) {
        expect(e.toString(), isNot(contains(text)));
        expect(e.toString(), isNot(contains('secret')));
      }
    }
  });
  test(
      'configuration rejects duplicate lessons, missing scope and missing tokens',
      () {
    final valid = config().toJson();
    for (final invalid in [
      {
        ...valid,
        'targets': [valid['targets'][0], valid['targets'][0]]
      },
      {...valid, 'studentId': null},
      {...valid, 'token': null},
      {...valid, 'token': '  '},
      {...valid, 'intervalMs': 0},
      {...valid, 'version': 99},
      {...valid, 'startAt': '2026-09-10T10:00:00'},
    ]) {
      expect(() => AutomationConfig.fromJson(invalid), throwsFormatException);
    }
  });
  test('school wall clock is interpreted as UTC+8', () {
    expect(parseSchoolTime('2026-09-10 12:00:00'),
        DateTime.parse('2026-09-10T04:00:00Z'));
  });
}
