import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:eams_core/eams_core.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runCli(arguments);
}

Future<int> runCli(
  List<String> arguments, {
  ApiService Function()? apiFactory,
  Directory? stateDirectory,
}) async {
  var resultCode = 0;
  final parser = ArgParser()
    ..addOption('config', abbr: 'c', help: 'GUI 导出的 Base64 配置字符串（含 Token）')
    ..addFlag('check', negatable: false, help: '只验证配置、身份和轮次，不提交选课')
    ..addFlag('once', negatable: false, help: '只执行一轮检查与选课')
    ..addFlag('acknowledge-uncertain',
        negatable: false, help: '已在官网人工核对所有未确认操作且无待处理请求，允许重新运行')
    ..addFlag('version', negatable: false, help: '显示 CLI 版本')
    ..addFlag('help', abbr: 'h', negatable: false);
  ApiService? api;
  ExecutionLease? lease;
  StreamSubscription<ProcessSignal>? interrupt;
  StreamSubscription<ProcessSignal>? terminate;
  try {
    late ArgResults args;
    try {
      args = parser.parse(arguments);
    } on FormatException {
      throw const FormatException('命令行参数无效，请运行 --help 查看用法');
    }
    if (args['version'] as bool) {
      stdout.writeln(const String.fromEnvironment('EAMS_VERSION',
          defaultValue: 'development'));
      return 0;
    }
    if (args['help'] as bool) {
      stdout.writeln('ECNU 选课 CLI\n${parser.usage}');
      return 0;
    }
    if (args.rest.isNotEmpty || args['config'] == null) {
      throw FormatException('请指定 --config\n${parser.usage}');
    }
    final config = AutomationConfig.fromBase64(args['config'] as String);
    lease = await ExecutionLease.acquire(config.studentId);
    api = (apiFactory ?? ApiService.new)()..setAuthorization(config.token);
    final directory = stateDirectory ?? defaultStateDirectory();
    final stateFile = File(
        '${directory.path}/${config.studentId}-${config.turnId}-${config.semesterId}.state.json');
    final states = <int, TaskUpdate>{};
    if (await stateFile.exists()) {
      final saved =
          jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>;
      if (saved['studentId'] != config.studentId ||
          saved['turnId'] != config.turnId ||
          saved['semesterId'] != config.semesterId) {
        throw StateError('运行状态文件与配置身份或轮次不一致');
      }
      for (final raw in saved['states'] as List) {
        final state =
            TaskUpdate.fromJson(Map<String, dynamic>.from(raw as Map));
        states[state.lessonId] = state;
      }
      if (args['acknowledge-uncertain'] as bool) {
        for (final entry in Map<int, TaskUpdate>.from(states).entries) {
          if (entry.value.phase == TaskPhase.submitting ||
              entry.value.phase == TaskPhase.uncertain) {
            states[entry.key] =
                TaskUpdate(entry.key, TaskPhase.cancelled, '用户已人工核对');
          }
        }
      }
      final removedUncertain = states.values.any((s) =>
          (s.phase == TaskPhase.uncertain || s.phase == TaskPhase.submitting) &&
          !config.targets.any((t) => t.lessonId == s.lessonId));
      if (removedUncertain) throw StateError('状态文件仍有未确认提交，请先在官网核对');
    }
    final checkOnly = args['check'] as bool;
    final names = {for (final t in config.targets) t.lessonId: t.name};
    final lastPrinted = <int, String>{};
    Future<void> record(TaskUpdate update) async {
      final previous = states[update.lessonId];
      states[update.lessonId] = update;
      // Persist changes and every submission before it can reach the server.
      if (!checkOnly &&
          (previous?.phase != update.phase ||
              previous?.attempts != update.attempts ||
              previous?.requestId != update.requestId)) {
        final text = const JsonEncoder.withIndent('  ').convert({
          'studentId': config.studentId,
          'turnId': config.turnId,
          'semesterId': config.semesterId,
          'states': states.values.map((s) => s.toJson()).toList(),
        });
        await directory.create(recursive: true);
        final temp = File('${stateFile.path}.tmp');
        await temp.writeAsString(text, flush: true);
        await temp.rename(stateFile.path);
      }
      final line = '${update.phase.name}: ${update.message}';
      if (lastPrinted[update.lessonId] != line) {
        stdout.writeln('${update.timestamp.toIso8601String()} '
            '[${names[update.lessonId]}] $line '
            '(尝试 ${update.attempts}${update.requestId == null ? '' : ', 请求 ${update.requestId}'})');
        lastPrinted[update.lessonId] = line;
      }
    }

    final runner = AutomationRunner(
        api: api, config: config, initialStates: states, onUpdate: record);
    void stop(ProcessSignal _) {
      stderr.writeln('正在停止；已发出的请求将完成结果核对。');
      runner.stop();
    }

    interrupt = ProcessSignal.sigint.watch().listen(stop);
    if (!Platform.isWindows)
      terminate = ProcessSignal.sigterm.watch().listen(stop);
    stdout.writeln(checkOnly ? '只读检查中…' : '开始运行；按 Ctrl+C 停止。');
    await runner.run(checkOnly: checkOnly, once: args['once'] as bool);
    if (runner.cancellation.isCancelled) {
      resultCode = 130;
    } else if (states.values.any(
        (s) => s.phase == TaskPhase.failed || s.phase == TaskPhase.uncertain)) {
      resultCode = 1;
    } else if (!checkOnly &&
        config.targets
            .any((t) => states[t.lessonId]?.phase != TaskPhase.succeeded)) {
      resultCode = 3;
    }
    stdout.writeln(checkOnly ? '检查完成，未提交选课。' : '运行结束（退出码 $resultCode）。');
  } catch (e) {
    stderr.writeln(AuthTokenNormalizer.redact(
        e is FormatException ? e.message.toString() : e.toString()));
    resultCode = 1;
  } finally {
    await interrupt?.cancel();
    await terminate?.cancel();
    api?.close();
    await lease?.release();
  }
  return resultCode;
}

Directory defaultStateDirectory() {
  final env = Platform.environment;
  if (Platform.isWindows) {
    final local = env['LOCALAPPDATA'];
    if (local == null || local.isEmpty)
      throw StateError('缺少 LOCALAPPDATA，无法保存运行状态');
    return Directory('$local/ecnu-eams');
  }
  final home = env['HOME'];
  if (home == null || home.isEmpty) throw StateError('缺少 HOME，无法保存运行状态');
  if (Platform.isMacOS)
    return Directory('$home/Library/Application Support/ecnu-eams');
  final xdg = env['XDG_STATE_HOME'];
  return Directory(
      '${xdg != null && xdg.isNotEmpty ? xdg : '$home/.local/state'}/ecnu-eams');
}
