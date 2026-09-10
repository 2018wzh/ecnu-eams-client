import 'dart:async';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'automation_config.dart';
import 'cancellation.dart';
import 'course_action_result.dart';

enum TaskPhase {
  waiting,
  submitting,
  succeeded,
  failed,
  uncertain,
  cancelled,
  available
}

class TaskUpdate {
  final int lessonId;
  final TaskPhase phase;
  final String message;
  final int attempts;
  final String? requestId;
  final String action;
  final List<Map<String, dynamic>>? selectedLessons;
  final DateTime timestamp;
  TaskUpdate(
    this.lessonId,
    this.phase,
    this.message, {
    this.attempts = 0,
    this.requestId,
    this.action = 'add',
    this.selectedLessons,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'lessonId': lessonId,
        'phase': phase.name,
        'message': message,
        'attempts': attempts,
        'requestId': requestId,
        'action': action,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };
  factory TaskUpdate.fromJson(Map<String, dynamic> json) => TaskUpdate(
      json['lessonId'] as int,
      TaskPhase.values.byName(json['phase'] as String),
      json['message'] as String,
      attempts: json['attempts'] as int,
      requestId: json['requestId'] as String?,
      action: json['action'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String));
}

typedef TaskObserver = Future<void> Function(TaskUpdate update);

/// Shared sequential scheduler. Server-side canSelect/hasCount filtering is the
/// source of eligibility; ordinary and across-major seats are not added together.
class AutomationRunner {
  final ApiService api;
  final AutomationConfig config;
  final TaskObserver onUpdate;
  final CancellationToken cancellation = CancellationToken();
  final Map<int, TaskUpdate> states;
  final bool monitorOnly;
  final Set<int> _removed = {};
  CancellationToken? _activeAction;
  int? _activeLesson;
  bool _running = false;

  AutomationRunner(
      {required this.api,
      required this.config,
      required this.onUpdate,
      this.monitorOnly = false,
      Map<int, TaskUpdate>? initialStates})
      : states = {...?initialStates};

  void stop() {
    cancellation.cancel();
    _activeAction?.cancel();
  }

  void removeTarget(int lessonId) {
    _removed.add(lessonId);
    if (_activeLesson == lessonId) _activeAction?.cancel();
    if (config.targets.every((t) => _removed.contains(t.lessonId))) stop();
  }

  Future<void> _emit(int id, TaskPhase phase, String message,
      {int? attempts,
      String? requestId,
      List<Map<String, dynamic>>? selectedLessons}) async {
    final update = TaskUpdate(id, phase, message,
        attempts: attempts ?? states[id]?.attempts ?? 0,
        requestId: requestId,
        selectedLessons: selectedLessons);
    states[id] = update;
    // Persistence is part of submission: a failed checkpoint stops the runner.
    await onUpdate(update);
  }

  Future<void> run({bool checkOnly = false, bool once = false}) async {
    if (_running) throw StateError('任务已在运行');
    config.validate();
    _running = true;
    try {
      final ids = await api.getStudentID();
      cancellation.throwIfCancelled();
      if (!ids.contains(config.studentId)) {
        throw StateError('登录学生与配置不一致');
      }
      final turns = await api.getOpenTurns(config.studentId);
      final matching = turns.where((t) => t['id'] == config.turnId).toList();
      if (matching.length != 1) throw StateError('配置轮次已关闭或不可访问');
      final turn = matching.single;
      if (turn['allowEnter'] != true) {
        throw StateError('不允许进入该轮次: ${turn['disallowReasons']}');
      }
      final detail = await api.getSelectDetail(config.studentId, config.turnId);
      if ((detail['semester'] as Map)['id'] != config.semesterId) {
        throw StateError('配置学期与轮次不一致');
      }
      final timeText = await api.getCurrentDateTime();
      final serverTime = parseSchoolTime(timeText);
      final clock = Stopwatch()..start();
      final range = turn['selectDateTimeRange'] as Map;
      final start = parseSchoolTime(range['startDateTime'] as String);
      final end = parseSchoolTime(range['endDateTime'] as String);
      if (!end.isAfter(start)) throw StateError('选课时间范围无效');
      final requested = config.startAt;
      final effectiveStart =
          requested != null && requested.isAfter(start) ? requested : start;
      if (!effectiveStart.isBefore(end) || !serverTime.isBefore(end)) {
        throw StateError('已超过选课截止时间');
      }
      final selected =
          await api.getSelectedLessons(config.turnId, config.studentId);
      final selectedIds = selected.map((v) => v['id']).toSet();
      final all = await api.queryLessons(
          studentID: config.studentId,
          turnID: config.turnId,
          semesterID: config.semesterId,
          ids: config.targets.map((t) => t.lessonId).toList(),
          pageSize: 100);
      final lessons = (all['lessons'] as List).cast<Map>();
      final visibleIds = lessons.map((v) => v['id']).toSet();
      cancellation.throwIfCancelled();
      final pending = <AutomationTarget>[];
      for (final target in config.targets) {
        final id = target.lessonId;
        if (_removed.contains(id)) continue;
        if (selectedIds.contains(id)) {
          await _emit(id, TaskPhase.succeeded, '已在已选课程中',
              selectedLessons: selected);
          continue;
        }
        final previous = states[id]?.phase;
        if (previous == TaskPhase.submitting ||
            previous == TaskPhase.uncertain) {
          await _emit(id, TaskPhase.uncertain, '上次提交结果不确定，请先在官网核对');
          throw StateError('存在未确认的提交，已停止，避免重复提交');
        }
        if (!visibleIds.contains(id)) {
          throw StateError('目标课程 $id 不属于当前可查询轮次');
        }
        pending.add(target);
        await _emit(id, TaskPhase.waiting, checkOnly ? '配置及身份检查通过' : '等待选课');
      }
      if (checkOnly || pending.isEmpty) return;
      await cancellation
          .delay(effectiveStart.difference(serverTime.add(clock.elapsed)));
      var consecutiveFailures = 0;
      final transientFailures = <int, int>{};
      final notified = <int>{};
      while (pending.isNotEmpty) {
        cancellation.throwIfCancelled();
        pending.removeWhere((t) => _removed.contains(t.lessonId));
        if (pending.isEmpty) break;
        if (!serverTime.add(clock.elapsed).isBefore(end)) {
          throw StateError('选课轮次已截止，任务停止');
        }
        try {
          final available = await api.queryLessons(
              studentID: config.studentId,
              turnID: config.turnId,
              semesterID: config.semesterId,
              ids: pending.map((t) => t.lessonId).toList(),
              canSelect: 1,
              hasCount: true,
              pageSize: 100);
          cancellation.throwIfCancelled();
          final eligible = (available['lessons'] as List)
              .cast<Map>()
              .map((v) => v['id'])
              .toSet();
          consecutiveFailures = 0;
          for (final target in List<AutomationTarget>.from(pending)) {
            cancellation.throwIfCancelled();
            final id = target.lessonId;
            if (_removed.contains(id)) continue;
            if (!eligible.contains(id)) {
              notified.remove(id);
              await _emit(id, TaskPhase.waiting, '暂无可选余量');
              continue;
            }
            if (monitorOnly) {
              if (notified.add(id))
                await _emit(id, TaskPhase.available, '发现可选余量');
              continue;
            }
            if (!serverTime.add(clock.elapsed).isBefore(end)) {
              throw StateError('选课轮次已截止，任务停止');
            }
            final attempts = (states[id]?.attempts ?? 0) + 1;
            _activeLesson = id;
            final action = _activeAction = CancellationToken();
            await _emit(id, TaskPhase.submitting, '正在验证并提交',
                attempts: attempts);
            if (cancellation.isCancelled || _removed.contains(id))
              action.cancel();
            final result = await api.addCourse(
                config.studentId, config.turnId, id, target.virtualCost,
                polling: config.polling, cancellation: action);
            _activeAction = null;
            _activeLesson = null;
            var phase = switch (result.outcome) {
              ActionOutcome.success => TaskPhase.succeeded,
              ActionOutcome.uncertain => TaskPhase.uncertain,
              ActionOutcome.cancelled => TaskPhase.cancelled,
              ActionOutcome.retryable => TaskPhase.waiting,
              _ => TaskPhase.failed,
            };
            if (result.outcome == ActionOutcome.retryable) {
              final failures = (transientFailures[id] ?? 0) + 1;
              transientFailures[id] = failures;
              if (failures >= 5) phase = TaskPhase.failed;
            }
            await _emit(id, phase, result.message,
                attempts: attempts,
                requestId: result.requestId,
                selectedLessons:
                    result.success ? result.selectedLessons : null);
            if (result.authExpired ||
                result.outcome == ActionOutcome.uncertain) {
              throw StateError(result.message);
            }
            if (phase == TaskPhase.succeeded ||
                phase == TaskPhase.failed ||
                phase == TaskPhase.cancelled) pending.remove(target);
            if (result.outcome == ActionOutcome.retryable &&
                phase != TaskPhase.failed) {
              final minimum = const Duration(seconds: 5);
              await cancellation.delay(
                  result.retryAfter != null && result.retryAfter! > minimum
                      ? result.retryAfter!
                      : minimum);
            }
          }
        } on ApiException catch (e) {
          if (!e.retryable) rethrow;
          consecutiveFailures++;
          if (consecutiveFailures >= 5) rethrow;
          final backoff = Duration(seconds: 1 << consecutiveFailures);
          final delay = e.retryAfter != null && e.retryAfter! > backoff
              ? e.retryAfter!
              : backoff;
          for (final target in pending) {
            await _emit(target.lessonId, TaskPhase.waiting,
                '$e；${delay.inSeconds} 秒后重试');
          }
          await cancellation.delay(delay);
        } on TimeoutException catch (e) {
          consecutiveFailures++;
          if (consecutiveFailures >= 5) rethrow;
          for (final target in pending) {
            await _emit(target.lessonId, TaskPhase.waiting, e.toString());
          }
          await cancellation.delay(Duration(seconds: 1 << consecutiveFailures));
        } on http.ClientException catch (e) {
          consecutiveFailures++;
          if (consecutiveFailures >= 5) rethrow;
          for (final target in pending) {
            await _emit(target.lessonId, TaskPhase.waiting, e.toString());
          }
          await cancellation.delay(Duration(seconds: 1 << consecutiveFailures));
        }
        if (once || pending.isEmpty) break;
        await cancellation.delay(config.interval);
      }
    } on OperationCancelled {
      // Keep committed/uncertain results visible; only unsubmitted work stops.
      for (final target in config.targets) {
        final phase = states[target.lessonId]?.phase;
        if (phase == TaskPhase.waiting || phase == TaskPhase.available) {
          await _emit(target.lessonId, TaskPhase.cancelled, '已停止');
        }
      }
    } finally {
      _activeAction = null;
      _activeLesson = null;
      _running = false;
    }
  }
}
