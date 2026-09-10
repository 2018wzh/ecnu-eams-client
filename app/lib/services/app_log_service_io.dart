import 'dart:convert';
import 'dart:io';

import 'package:eams_core/eams_core.dart';

class AppLogService {
  final Directory directory;
  final int maxBytes;

  AppLogService({Directory? directory, this.maxBytes = 256 * 1024})
      : directory = directory ?? Directory(_defaultLogPath());

  File get _file => File('${directory.path}/app.log');

  Future<void> write(
    String event,
    String message, {
    Map<String, dynamic>? data,
  }) async {
    await directory.create(recursive: true);
    await _rotateIfNeeded();
    final payload = {
      'time': DateTime.now().toIso8601String(),
      'event': event,
      'message': message,
      if (data != null) 'data': data,
    };
    final line = AuthTokenNormalizer.redact(jsonEncode(payload));
    await _file.writeAsString('$line\n', mode: FileMode.append, flush: true);
  }

  Future<String> readRecent() async {
    if (!await _file.exists()) return '';
    return AuthTokenNormalizer.redact(await _file.readAsString());
  }

  Future<void> clear() async {
    if (await _file.exists()) {
      await _file.delete();
    }
  }

  Future<void> _rotateIfNeeded() async {
    if (!await _file.exists()) return;
    final length = await _file.length();
    if (length < maxBytes) return;
    final backup = File('${directory.path}/app.log.1');
    if (await backup.exists()) {
      await backup.delete();
    }
    await _file.rename(backup.path);
  }

  static String _defaultLogPath() {
    final base = Platform.environment['APPDATA'] ??
        Platform.environment['HOME'] ??
        Directory.systemTemp.path;
    return '$base${Platform.pathSeparator}ecnu_eams_client${Platform.pathSeparator}logs';
  }
}
