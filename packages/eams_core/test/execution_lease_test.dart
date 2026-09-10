import 'dart:convert';
import 'dart:io';
import 'package:eams_core/eams_core.dart';
import 'package:test/test.dart';

void main() {
  test('GUI and CLI processes cannot hold the same student lock', () async {
    final id = 100000000 + pid;
    final child = await Process.start(Platform.resolvedExecutable,
        ['run', 'test/support/lease_holder.dart', '$id']);
    final errors = child.stderr.transform(utf8.decoder).join();
    addTearDown(() async {
      child.kill();
      await child.exitCode;
    });
    final line = await child.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first
        .timeout(const Duration(seconds: 30));
    expect(line, 'acquired');
    await expectLater(ExecutionLease.acquire(id), throwsStateError);
    child.stdin.writeln('release');
    await child.stdin.close();
    expect(await child.exitCode, 0, reason: await errors);
    final next = await ExecutionLease.acquire(id);
    await next.release();
    await File(
            '${Directory.systemTemp.path}${Platform.pathSeparator}ecnu-eams-$id.lock')
        .delete();
  });
}
