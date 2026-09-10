import 'dart:convert';
import 'dart:io';
import 'package:eams_core/eams_core.dart';

Future<void> main(List<String> args) async {
  final lease = await ExecutionLease.acquire(int.parse(args.single));
  stdout.writeln('acquired');
  await stdin.transform(utf8.decoder).first;
  await lease.release();
}
