import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eams_core/eams_core.dart';
import '../services/credentials.dart';
import '../services/app_log_service.dart';
import '../services/notification_service.dart';

class CourseProvider with ChangeNotifier {
  final ApiService _apiService;
  final AppLogService _logService;
  CourseProvider({ApiService? apiService, AppLogService? logService})
      : _apiService = apiService ?? createApiService(),
        _logService = logService ?? AppLogService();

  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _selectedCourses = [];
  Map<String, dynamic>? _queryCondition;
  Map<String, dynamic>? _filterConditions;
  Map<String, Map<String, dynamic>> _courseCountInfo = {};
  String? _errorMessage;
  String? _selectedError;
  String? _automationError;
  String? _notificationWarning;
  bool _isLoading = false;
  bool _isActing = false;
  bool _disposed = false;
  int _currentPage = 1, _totalPages = 1, _totalRows = 0;
  int? _studentId, _turnId, _semesterId;
  int _contextVersion = 0, _searchVersion = 0;
  PollingConfig _pollingConfig = PollingConfig.defaults;
  Duration _robInterval = const Duration(milliseconds: 500);
  Duration _monitorInterval = const Duration(seconds: 5);
  DateTime? _scheduledStartTime;
  final List<Map<String, dynamic>> _robTargets = [];
  final List<Map<String, dynamic>> _monitorTargets = [];
  final Map<int, TaskUpdate> _robStates = {};
  final Map<int, TaskUpdate> _monitorStates = {};
  AutomationRunner? _robRunner, _monitorRunner;
  Future<void>? _robFuture, _monitorFuture, _actionFuture;
  CancellationToken? _manualCancellation;
  Future<void> _writeTail = Future.value();

  List<Map<String, dynamic>> get courses => _courses;
  List<Map<String, dynamic>> get selectedCourses => _selectedCourses;
  Map<String, dynamic>? get queryCondition => _queryCondition;
  Map<String, dynamic>? get filterConditions => _filterConditions;
  Map<String, Map<String, dynamic>> get courseCountInfo => _courseCountInfo;
  bool get isLoading => _isLoading;
  bool get isActing => _isActing;
  CancellationToken? _robStartup, _monitorStartup;
  bool get isRobbing => _robStartup != null || _robRunner != null;
  bool get isMonitoring => _monitorStartup != null || _monitorRunner != null;
  String? get errorMessage => _errorMessage;
  String? get selectedError => _selectedError;
  String? get automationError => _automationError;
  String? get notificationWarning => _notificationWarning;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalRows => _totalRows;
  PollingConfig get pollingConfig => _pollingConfig;
  Duration get robInterval => _robInterval;
  Duration get monitorInterval => _monitorInterval;
  DateTime? get scheduledStartTime => _scheduledStartTime;
  String? get contextKey => _stateKey;
  List<Map<String, dynamic>> get robTargets => List.unmodifiable(_robTargets);
  List<Map<String, dynamic>> get monitorTargets =>
      List.unmodifiable(_monitorTargets);
  Map<int, Map<String, dynamic>> get robTargetStatuses =>
      _statusMaps(_robStates);
  Map<int, Map<String, dynamic>> get monitorTargetStatuses =>
      _statusMaps(_monitorStates);
  bool get hasUncertainActions => _robStates.values.any(
      (s) => s.phase == TaskPhase.uncertain || s.phase == TaskPhase.submitting);

  Map<int, Map<String, dynamic>> _statusMaps(Map<int, TaskUpdate> states) => {
        for (final entry in states.entries)
          entry.key: {
            'status': entry.value.message,
            'phase': entry.value.phase.name,
            'lastChecked': entry.value.timestamp,
            'attemptCount': entry.value.attempts,
            'lastRequestId': entry.value.requestId,
          },
      };

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  String? get _stateKey => _studentId == null
      ? null
      : 'automation_v2_${_studentId}_${_turnId}_$_semesterId';

  Future<void> bindContext(int studentId, int turnId, int semesterId) async {
    if (_studentId == studentId &&
        _turnId == turnId &&
        _semesterId == semesterId) {
      return;
    }
    await stopAllAndWait();
    await _writeTail;
    _contextVersion++;
    _studentId = studentId;
    _turnId = turnId;
    _semesterId = semesterId;
    _clearView();
    await loadAutomationState();
    _changed();
  }

  Future<void> clearSession() async {
    await stopAllAndWait();
    await _writeTail;
    _contextVersion++;
    _studentId = null;
    _turnId = null;
    _semesterId = null;
    _clearView();
    _changed();
  }

  void _clearView() {
    _courses = [];
    _selectedCourses = [];
    _queryCondition = null;
    _courseCountInfo = {};
    _filterConditions = null;
    _robTargets.clear();
    _monitorTargets.clear();
    _robStates.clear();
    _monitorStates.clear();
    _scheduledStartTime = null;
    _errorMessage = null;
    _selectedError = null;
    _automationError = null;
    _isLoading = false;
    _currentPage = 1;
    _totalPages = 1;
    _totalRows = 0;
  }

  Future<void> loadAutomationState() async {
    final key = _stateKey;
    if (key == null) return;
    final epoch = _contextVersion;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || epoch != _contextVersion) return;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _pollingConfig =
        PollingConfig.fromJson(data['pollingConfig'] as Map<String, dynamic>?);
    _robInterval = Duration(
        milliseconds: boundedInt(data['robIntervalMs'], '抢课间隔', 200, 60000));
    _monitorInterval = Duration(
        milliseconds:
            boundedInt(data['monitorIntervalMs'], '监控间隔', 200, 60000));
    _scheduledStartTime = data['scheduledStartTime'] == null
        ? null
        : DateTime.parse(data['scheduledStartTime'] as String);
    _robTargets.addAll((data['robTargets'] as List)
        .map((v) => Map<String, dynamic>.from(v as Map)));
    _monitorTargets.addAll((data['monitorTargets'] as List)
        .map((v) => Map<String, dynamic>.from(v as Map)));
    for (final raw in data['robStates'] as List) {
      final state = TaskUpdate.fromJson(Map<String, dynamic>.from(raw as Map));
      _robStates[state.lessonId] = state;
    }
    _filterConditions = data['filters'] == null
        ? null
        : Map<String, dynamic>.from(data['filters'] as Map);
    _changed();
  }

  Future<void> saveAutomationState() {
    final key = _stateKey;
    if (key == null) return Future.value();
    final raw = jsonEncode({
      'pollingConfig': _pollingConfig.toJson(),
      'robIntervalMs': _robInterval.inMilliseconds,
      'monitorIntervalMs': _monitorInterval.inMilliseconds,
      'scheduledStartTime': _scheduledStartTime?.toUtc().toIso8601String(),
      'robTargets': _robTargets,
      'monitorTargets': _monitorTargets,
      'robStates': _robStates.values.map((v) => v.toJson()).toList(),
      'filters': _filterConditions,
    });
    final write = _writeTail.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, raw)) throw StateError('保存任务状态失败');
    });
    _writeTail = write.catchError((Object e) {
      _automationError = '保存失败，已停止任务: $e';
      stopRob();
      stopMonitoring();
      _changed();
    });
    return write;
  }

  void _save() {
    unawaited(saveAutomationState().catchError((Object e) {
      _automationError = '保存任务失败: $e';
      _changed();
    }));
  }

  Future<void> clearAutomationTargets() async {
    await stopAllAndWait();
    if (hasUncertainActions) throw StateError('存在未确认提交，请先核对结果');
    _robTargets.clear();
    _monitorTargets.clear();
    _robStates.clear();
    _monitorStates.clear();
    await saveAutomationState();
    _changed();
  }

  Future<void> reconcileActions() async {
    if (_studentId == null || _turnId == null) return;
    await stopAllAndWait();
    final selected =
        await _apiService.getSelectedLessons(_turnId!, _studentId!);
    for (final entry in Map<int, TaskUpdate>.from(_robStates).entries) {
      if (entry.value.phase != TaskPhase.submitting &&
          entry.value.phase != TaskPhase.uncertain) {
        continue;
      }
      if (selected.any((v) => v['id'] == entry.key) ==
          (entry.value.action == 'add')) {
        _robStates[entry.key] = TaskUpdate(
            entry.key, TaskPhase.succeeded, '已核对操作成功',
            action: entry.value.action);
      }
    }
    _selectedCourses = selected;
    await saveAutomationState();
    _changed();
  }

  Future<void> acknowledgeUncertainActions() async {
    await stopAllAndWait();
    for (final entry in Map<int, TaskUpdate>.from(_robStates).entries) {
      if (entry.value.phase == TaskPhase.submitting ||
          entry.value.phase == TaskPhase.uncertain) {
        _robStates[entry.key] = TaskUpdate(
            entry.key, TaskPhase.cancelled, '用户已在官网核对，允许重新操作',
            action: entry.value.action);
      }
    }
    _automationError = null;
    await saveAutomationState();
    _changed();
  }

  Future<void> clearLogs() => _logService.clear();
  Future<String> readLogs() => _logService.readRecent();
  int getTotalVirtualCost() => _selectedCourses.fold(
      0, (sum, c) => sum + ((c['virtualCost'] as num?)?.toInt() ?? 0));

  Future<void> loadQueryCondition(int turnID) async {
    final epoch = _contextVersion;
    try {
      final result = await _apiService.getQueryCondition(turnID);
      if (epoch != _contextVersion) return;
      _queryCondition = result;
      _changed();
    } catch (e) {
      if (epoch == _contextVersion) {
        _errorMessage = '加载筛选条件失败: $e';
        _changed();
      }
      rethrow;
    }
  }

  Future<void> saveFilterConditions(Map<String, dynamic> conditions) async {
    _filterConditions = Map.from(conditions);
    await saveAutomationState();
    _changed();
  }

  Future<void> clearFilterConditions() async {
    _filterConditions = null;
    await saveAutomationState();
    _changed();
  }

  Future<void> searchCourses(
      {required int studentID,
      required int turnID,
      required int semesterID,
      String? courseName,
      String? teacherName,
      String? lessonName,
      String? campusId,
      String? courseTypeId,
      String? coursePropertyId,
      String? departmentId,
      String? majorId,
      String? grade,
      String? week,
      String? creditGte,
      String? creditLte,
      bool onlyAvailable = false,
      bool onlyWithCount = false,
      String sortField = 'lesson',
      String sortType = 'ASC',
      int pageNo = 1,
      int pageSize = 20}) async {
    final epoch = _contextVersion, search = ++_searchVersion;
    _isLoading = true;
    _errorMessage = null;
    _changed();
    try {
      final result = await _apiService.queryLessons(
          studentID: studentID,
          turnID: turnID,
          semesterID: semesterID,
          courseNameOrCode: courseName ?? '',
          teacherNameOrCode: teacherName ?? '',
          lessonNameOrCode: lessonName ?? '',
          campusId: campusId ?? '',
          courseTypeId: courseTypeId ?? '',
          coursePropertyId: coursePropertyId ?? '',
          departmentId: departmentId ?? '',
          majorId: majorId ?? '',
          grade: grade ?? '',
          week: week ?? '',
          creditGte: creditGte,
          creditLte: creditLte,
          canSelect: onlyAvailable ? 1 : null,
          hasCount: onlyWithCount ? true : null,
          sortField: sortField,
          sortType: sortType,
          pageNo: pageNo,
          pageSize: pageSize);
      final courses = (result['lessons'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      final counts = courses.isEmpty
          ? <String, Map<String, dynamic>>{}
          : await getBatchCountInfo(
              courses.map((v) => v['id'] as int).toList());
      if (epoch != _contextVersion || search != _searchVersion) return;
      _courses = courses;
      _courseCountInfo = counts;
      final page = result['pageInfo'] as Map;
      _currentPage = page['currentPage'] as int;
      _totalPages = page['totalPages'] as int;
      _totalRows = page['totalRows'] as int;
    } catch (e) {
      if (epoch == _contextVersion && search == _searchVersion) {
        _errorMessage = '搜索失败: $e';
      }
    } finally {
      if (epoch == _contextVersion && search == _searchVersion) {
        _isLoading = false;
        _changed();
      }
    }
  }

  Future<void> loadSelectedCourses(int turnID, int studentID) async {
    final epoch = _contextVersion;
    _selectedError = null;
    try {
      final result = await _apiService.getSelectedLessons(turnID, studentID);
      if (epoch != _contextVersion) return;
      _selectedCourses = result;
    } catch (e) {
      if (epoch == _contextVersion) _selectedError = '加载已选课程失败: $e';
      rethrow;
    } finally {
      if (epoch == _contextVersion) _changed();
    }
  }

  Future<bool> addCourse(
          int studentID, int turnID, int lessonID, int virtualCost) =>
      _manualAction(true, studentID, turnID, lessonID, virtualCost);
  Future<bool> dropCourse(int studentID, int turnID, int lessonID) =>
      _manualAction(false, studentID, turnID, lessonID, 0);

  Future<bool> _manualAction(
      bool add, int student, int turn, int lesson, int cost) async {
    if (_isActing || isRobbing || hasUncertainActions) {
      _errorMessage = '请先停止抢课并核对未完成的操作';
      _changed();
      return false;
    }
    if (student != _studentId || turn != _turnId) {
      _errorMessage = '当前学生或轮次已改变，请重新打开课程';
      _changed();
      return false;
    }
    final done = Completer<void>();
    _actionFuture = done.future;
    _isActing = true;
    _errorMessage = null;
    final token = _manualCancellation = CancellationToken();
    ExecutionLease? lease;
    CourseActionResult? outcome;
    _changed();
    try {
      lease = await ExecutionLease.acquire(student);
      _robStates[lesson] = TaskUpdate(
          lesson, TaskPhase.submitting, add ? '手动选课处理中' : '手动退课处理中',
          action: add ? 'add' : 'drop');
      await saveAutomationState();
      final result = add
          ? await _apiService.addCourse(student, turn, lesson, cost,
              polling: _pollingConfig, cancellation: token)
          : await _apiService.dropCourse(student, turn, lesson,
              polling: _pollingConfig, cancellation: token);
      outcome = result;
      _robStates[lesson] = TaskUpdate(
          lesson,
          result.success
              ? TaskPhase.succeeded
              : result.outcome == ActionOutcome.uncertain
                  ? TaskPhase.uncertain
                  : TaskPhase.failed,
          result.message,
          attempts: result.attempts,
          requestId: result.requestId,
          action: add ? 'add' : 'drop');
      await saveAutomationState();
      await _logService
          .write(add ? 'addCourse' : 'dropCourse', result.message, data: {
        'lessonId': lesson,
        'outcome': result.outcome.name,
        'requestId': result.requestId,
        'attempts': result.attempts
      });
      if (!result.success) {
        _errorMessage = result.message;
        return false;
      }
      _selectedCourses = result.selectedLessons;
      _selectedError = null;
      return true;
    } catch (e) {
      if (outcome?.success == true) {
        _automationError = '选退课已成功，但本地记录失败: $e';
        _changed();
        return true;
      }
      _errorMessage = e.toString();
      return false;
    } finally {
      try {
        await lease?.release();
      } catch (e) {
        _automationError = '释放运行锁失败: $e';
      }
      _isActing = false;
      _manualCancellation = null;
      _actionFuture = null;
      done.complete();
      _changed();
    }
  }

  Future<Map<String, dynamic>> getCountInfo(int lessonID) =>
      _apiService.getCountInfo(lessonID);
  Future<Map<String, Map<String, dynamic>>> getBatchCountInfo(
      List<int> ids) async {
    final raw = await _apiService.getBatchCountInfo(ids);
    return {
      for (final entry in raw.entries) entry.key: parseCountInfo(entry.value)
    };
  }

  @visibleForTesting
  static Map<String, dynamic> parseCountInfo(String value) {
    final parts = value.split('-');
    if (parts.length != 4) throw const FormatException('课程人数格式异常');
    final n = parts.map(int.parse).toList();
    if (n.any((v) => v < 0) || n[0] < n[3]) {
      throw const FormatException('课程人数不一致');
    }
    return {
      'stdCount': n[0] - n[3],
      'amStdCount': n[3],
      'preStdCount': n[1],
      'preAmStdCount': n[2],
      'totalSelected': n[0]
    };
  }

  void setPollingConfig(PollingConfig config) {
    _pollingConfig = config.normalized();
    _save();
    _changed();
  }

  void setRobInterval(Duration value) {
    _robInterval = _interval(value);
    _save();
    _changed();
  }

  void setMonitorInterval(Duration value) {
    _monitorInterval = _interval(value);
    _save();
    _changed();
  }

  Duration _interval(Duration value) =>
      Duration(milliseconds: value.inMilliseconds.clamp(200, 60000));
  void setScheduledStartTime(DateTime? time) {
    _scheduledStartTime = time;
    _save();
    _changed();
  }

  void addRobTarget(Map<String, dynamic> course, {int virtualCost = 0}) =>
      _addTarget(_robTargets, course, virtualCost);
  void addMonitorTarget(Map<String, dynamic> course, {int virtualCost = 0}) =>
      _addTarget(_monitorTargets, course, virtualCost);
  void _addTarget(List<Map<String, dynamic>> targets,
      Map<String, dynamic> course, int cost) {
    if (_stateKey == null) throw StateError('请先选择轮次');
    if (targets.length >= 100) throw StateError('最多支持 100 门目标课程');
    if (isRobbing || isMonitoring) throw StateError('请先停止自动任务再添加目标');
    if (targets.any((v) => v['id'] == course['id'])) return;
    targets
        .add({...course, 'virtualCost': cost, 'priority': targets.length + 1});
    _save();
    _changed();
  }

  void removeRobTarget(int id) {
    final phase = _robStates[id]?.phase;
    if (phase == TaskPhase.submitting || phase == TaskPhase.uncertain) {
      _automationError = '此课程存在未确认操作，请先停止并核对';
      _changed();
      return;
    }
    _robRunner?.removeTarget(id);
    _robTargets.removeWhere((t) => t['id'] == id);
    _robStates.remove(id);
    _save();
    _changed();
  }

  void removeMonitorTarget(int id) {
    _monitorRunner?.removeTarget(id);
    _monitorTargets.removeWhere((t) => t['id'] == id);
    _monitorStates.remove(id);
    _save();
    _changed();
  }

  void moveRobTarget(int index, int delta) {
    if (isRobbing || index + delta < 0 || index + delta >= _robTargets.length) {
      return;
    }
    final target = _robTargets.removeAt(index);
    _robTargets.insert(index + delta, target);
    for (var i = 0; i < _robTargets.length; i++) {
      _robTargets[i]['priority'] = i + 1;
    }
    _save();
    _changed();
  }

  Future<AutomationConfig> buildRobConfig() =>
      _config(_robTargets, _robInterval, _scheduledStartTime);
  Future<AutomationConfig> _config(List<Map<String, dynamic>> targets,
      Duration interval, DateTime? start) async {
    final epoch = _contextVersion;
    final token = await _apiService.getAuthorization();
    if (epoch != _contextVersion) throw StateError('学生或轮次已改变');
    if (_studentId == null || _turnId == null || _semesterId == null) {
      throw StateError('请先选择轮次');
    }
    final config = AutomationConfig(
        token: token,
        studentId: _studentId!,
        turnId: _turnId!,
        semesterId: _semesterId!,
        interval: interval,
        polling: _pollingConfig,
        startAt: start,
        targets: targets
            .map((t) => AutomationTarget(
                lessonId: t['id'] as int,
                name: (t['course']?['nameZh'] ??
                        t['course']?['nameEn'] ??
                        t['code'])
                    .toString(),
                virtualCost: t['virtualCost'] as int))
            .toList());
    config.validate();
    return config;
  }

  Future<void> startRob(int studentID, int turnID) async {
    if (isRobbing || _isActing) return;
    final run = _run(false, studentID, turnID);
    _robFuture = run;
    await run;
  }

  Future<void> startMonitoring(int studentID, int turnID) async {
    if (isMonitoring) return;
    final run = _run(true, studentID, turnID);
    _monitorFuture = run;
    await run;
  }

  Future<void> _run(bool monitor, int student, int turn) async {
    final startup = CancellationToken();
    if (monitor) {
      _monitorStartup = startup;
    } else {
      _robStartup = startup;
    }
    ExecutionLease? lease;
    AutomationRunner? runner;
    final epoch = _contextVersion;
    try {
      if (student != _studentId || turn != _turnId) {
        throw StateError('学生或轮次已改变');
      }
      if (!monitor && hasUncertainActions) throw StateError('存在未确认提交，请先核对结果');
      final config = monitor
          ? await _config(_monitorTargets, _monitorInterval, null)
          : await buildRobConfig();
      if (startup.isCancelled) return;
      final states = monitor ? _monitorStates : _robStates;
      _automationError = null;
      runner = AutomationRunner(
          api: _apiService,
          config: config,
          initialStates: states,
          monitorOnly: monitor,
          onUpdate: (update) async {
            if (_disposed || epoch != _contextVersion) return;
            final previous = states[update.lessonId];
            states[update.lessonId] = update;
            if (update.selectedLessons != null) {
              _selectedCourses = update.selectedLessons!;
              _selectedError = null;
            }
            _changed();
            if (!monitor &&
                (previous?.phase != update.phase ||
                    previous?.attempts != update.attempts ||
                    previous?.requestId != update.requestId)) {
              await saveAutomationState();
            }
            if (update.phase == TaskPhase.submitting ||
                update.phase == TaskPhase.failed ||
                update.phase == TaskPhase.uncertain ||
                update.phase == TaskPhase.succeeded) {
              await _logService.write('automation', update.message,
                  data: update.toJson());
            }
            if (update.phase == TaskPhase.succeeded ||
                update.phase == TaskPhase.available) {
              final name = config.targets
                  .firstWhere((t) => t.lessonId == update.lessonId)
                  .name;
              try {
                await NotificationService.showNotification(
                    title:
                        update.phase == TaskPhase.succeeded ? '选课成功' : '课程余量提醒',
                    body: '$name：${update.message}',
                    id: update.lessonId);
              } catch (e) {
                _notificationWarning = '系统通知不可用: $e';
                _changed();
              }
            }
          });
      if (monitor) {
        _monitorRunner = runner;
      } else {
        _robRunner = runner;
      }
      _changed();
      try {
        await NotificationService.requestPermission();
      } catch (e) {
        _notificationWarning = e.toString();
        _changed();
      }
      if (!monitor) lease = await ExecutionLease.acquire(student);
      await runner.run();
    } catch (e) {
      if (!_disposed && epoch == _contextVersion) {
        _automationError = '任务已停止: $e';
      }
    } finally {
      try {
        await lease?.release();
      } catch (e) {
        _automationError = '释放运行锁失败: $e';
      }
      if (monitor) {
        _monitorStartup = null;
        _monitorRunner = null;
      } else {
        _robStartup = null;
        _robRunner = null;
      }
      _changed();
    }
  }

  void stopRob() {
    _robStartup?.cancel();
    _robRunner?.stop();
    _changed();
  }

  void stopMonitoring() {
    _monitorStartup?.cancel();
    _monitorRunner?.stop();
    _changed();
  }

  Future<void> stopAllAndWait() async {
    stopRob();
    stopMonitoring();
    _manualCancellation?.cancel();
    await Future.wait([
      if (_robFuture != null) _robFuture!,
      if (_monitorFuture != null) _monitorFuture!,
      if (_actionFuture != null) _actionFuture!
    ]);
  }

  @override
  void dispose() {
    _disposed = true;
    _robStartup?.cancel();
    _monitorStartup?.cancel();
    _robRunner?.stop();
    _monitorRunner?.stop();
    _manualCancellation?.cancel();
    super.dispose();
  }
}
