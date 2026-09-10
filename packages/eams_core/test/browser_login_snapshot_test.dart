import 'dart:convert';
import 'package:test/test.dart';
import 'package:eams_core/eams_core.dart';

void main() {
  String state(String origin, Object? token) =>
      jsonEncode({'origin': origin, 'ready': 'complete', 'token': token});

  test('empty browser results are waiting states, not credentials', () {
    expect(BrowserLoginSnapshot.parse(null), isNull);
    expect(BrowserLoginSnapshot.parse('null'), isNull);
    for (final token in [null, '', ' ', 'null', 'undefined']) {
      expect(
        BrowserLoginSnapshot.parse(
          state('https://byyt.ecnu.edu.cn', token),
        )!.token,
        isNull,
      );
    }
  });

  test('only exact school HTTPS origin can supply credentials', () {
    for (final origin in [
      'http://byyt.ecnu.edu.cn',
      'https://byyt.ecnu.edu.cn.example.com',
      'https://sso.ecnu.edu.cn',
    ]) {
      expect(
        BrowserLoginSnapshot.parse(state(origin, 'test-token'))!.token,
        isNull,
      );
    }
    expect(
      BrowserLoginSnapshot.parse(
        state('https://byyt.ecnu.edu.cn', 'Bearer test-token'),
      )!.token,
      'test-token',
    );
  });

  test('malformed script responses fail without exposing their contents', () {
    expect(() => BrowserLoginSnapshot.parse('""'), throwsFormatException);
    expect(
      () => BrowserLoginSnapshot.parse(state('https://byyt.ecnu.edu.cn', 123)),
      throwsFormatException,
    );
  });
}
