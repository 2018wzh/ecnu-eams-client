import 'dart:convert';
import 'dart:io';
import 'package:eams_core/eams_core.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';
import '../bin/eams.dart' show runCli;
import 'automation_runner_test.dart' show School, config;

void main() {
  test('CLI check is read-only and normal run writes a recoverable journal',
      () async {
    final dir = await Directory.systemTemp.createTemp('eams-cli-test-');
    addTearDown(() => dir.delete(recursive: true));
    final encoded = config().toBase64();
    final school = School();
    ApiService createApi() => ApiService(client: MockClient((request) {
          expect(request.headers['Authorization'], 'test-token');
          return school.handle(request);
        }));
    final check = await runCli(['--config', encoded, '--check'],
        apiFactory: createApi, stateDirectory: dir);
    expect(check, 0);
    expect(school.writes, isEmpty);
    final journal = File('${dir.path}/1-2-4.state.json');
    expect(await journal.exists(), isFalse);
    final run = await runCli(['--config', encoded],
        apiFactory: createApi, stateDirectory: dir);
    expect(run, 0);
    expect(school.writes, [3]);
    final text = await journal.readAsString();
    expect(text, isNot(contains('test-token')));
    expect(jsonDecode(text)['states'][0]['phase'], 'succeeded');
    final restart = await runCli(['--config', encoded],
        apiFactory: createApi, stateDirectory: dir);
    expect(restart, 0);
    expect(school.writes, [3]);
  });

  test('CLI restarts never repeat an uncertain submission', () async {
    final dir = await Directory.systemTemp.createTemp('eams-cli-test-');
    addTearDown(() => dir.delete(recursive: true));
    final encoded = config().toBase64();
    final school = School()..uncertain = true;
    for (var i = 0; i < 2; i++) {
      final result = await runCli(['--config', encoded],
          apiFactory: () => ApiService(client: MockClient(school.handle)),
          stateDirectory: dir);
      expect(result, 1);
    }
    expect(school.writes, [3]);
    final saved =
        jsonDecode(await File('${dir.path}/1-2-4.state.json').readAsString());
    expect(saved['states'][0]['phase'], 'uncertain');
  });
}
