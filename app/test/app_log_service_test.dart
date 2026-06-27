import 'dart:io';

import 'package:ecnu_eams_client/services/app_log_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writes local logs without leaking authorization values', () async {
    final dir = await Directory.systemTemp.createTemp('ecnu-log-test-');
    final logs = AppLogService(directory: dir, maxBytes: 2000);

    await logs.write(
      'login',
      'Authorization: Bearer secret.token.value',
      data: {'authorization': 'secret-token', 'ok': true},
    );

    final text = await logs.readRecent();
    expect(text, contains('login'));
    expect(text, contains('[REDACTED]'));
    expect(text, isNot(contains('secret.token.value')));
    expect(text, isNot(contains('secret-token')));
  });
}
