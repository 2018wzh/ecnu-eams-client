import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/course_action_result.dart';
import '../models/polling_config.dart';
import '../services/api_service.dart';
import '../services/app_log_service.dart';
import '../services/notification_service.dart';

class CourseProvider with ChangeNotifier {
  static const _automationStateKey = 'automation_state';

  final ApiService _apiService;
  final AppLogService _logService;

  CourseProvider({
    ApiService? apiService,
    AppLogService? logService,
  })  : _apiService = apiService ?? ApiService(),
        _logService = logService ?? AppLogService();

  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _selectedCourses = [];
  Map<String, dynamic>? _queryCondition;
  bool _isLoading = false;
  String? _errorMessage;

  // 分页信息
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalRows = 0;

  // 筛选条件缓存
  Map<String, dynamic>? _filterConditions;
  Map<String, Map<String, dynamic>> _courseCountInfo = {}; // 课程名额信息
  PollingConfig _pollingConfig = PollingConfig.defaults;

  List<Map<String, dynamic>> get courses => _courses;
  List<Map<String, dynamic>> get selectedCourses => _selectedCourses;
  Map<String, dynamic>? get queryCondition => _queryCondition;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, Map<String, dynamic>> get courseCountInfo => _courseCountInfo;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalRows => _totalRows;
  Map<String, dynamic>? get filterConditions => _filterConditions;
  PollingConfig get pollingConfig => _pollingConfig;

  int getTotalVirtualCost() {
    return _selectedCourses.fold<int>(
      0,
      (sum, course) => sum + ((course['virtualCost'] as int?) ?? 0),
    );
  }

  // 抢课相关
  bool _isRobbing = false;
  final List<Map<String, dynamic>> _robTargets = [];
  DateTime? _scheduledStartTime;
  Duration _robInterval = const Duration(milliseconds: 500);
  int _robRunID = 0;
  final Map<int, Map<String, dynamic>> _robTargetStatuses = {}; // 监控状态

  // 监控相关
  bool _isMonitoring = false;
  final List<Map<String, dynamic>> _monitorTargets = [];
  Duration _monitorInterval = const Duration(seconds: 5);
  int _monitorRunID = 0;
  final Map<int, Map<String, dynamic>> _monitorTargetStatuses = {}; // 监控状态

  bool get isRobbing => _isRobbing;
  List<Map<String, dynamic>> get robTargets => _robTargets;
  DateTime? get scheduledStartTime => _scheduledStartTime;
  Duration get robInterval => _robInterval;
  Map<int, Map<String, dynamic>> get robTargetStatuses => _robTargetStatuses;

  bool get isMonitoring => _isMonitoring;
  List<Map<String, dynamic>> get monitorTargets => _monitorTargets;
  Duration get monitorInterval => _monitorInterval;
  Map<int, Map<String, dynamic>> get monitorTargetStatuses =>
      _monitorTargetStatuses;

  void setPollingConfig(PollingConfig config) {
    _pollingConfig = config.normalized();
    unawaitedSaveAutomationState();
    notifyListeners();
  }

  Future<void> loadAutomationState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_automationStateKey);
    if (raw == null) return;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _pollingConfig = PollingConfig.fromJson(
        data['pollingConfig'] as Map<String, dynamic>?,
      );
      _robInterval = Duration(
        milliseconds:
            _durationMs(data['robIntervalMs'], _robInterval.inMilliseconds),
      );
      _monitorInterval = Duration(
        milliseconds: _durationMs(
            data['monitorIntervalMs'], _monitorInterval.inMilliseconds),
      );
      _scheduledStartTime = data['scheduledStartTime'] == null
          ? null
          : DateTime.tryParse(data['scheduledStartTime'].toString());

      _robTargets
        ..clear()
        ..addAll(_decodeTargets(data['robTargets']));
      _monitorTargets
        ..clear()
        ..addAll(_decodeTargets(data['monitorTargets']));
      _rebuildTargetStatuses();
      notifyListeners();
    } catch (e) {
      debugPrint('加载自动化状态失败: $e');
    }
  }

  Future<void> saveAutomationState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _automationStateKey,
      jsonEncode({
        'pollingConfig': _pollingConfig.toJson(),
        'robIntervalMs': _robInterval.inMilliseconds,
        'monitorIntervalMs': _monitorInterval.inMilliseconds,
        'scheduledStartTime': _scheduledStartTime?.toIso8601String(),
        'robTargets': _robTargets,
        'monitorTargets': _monitorTargets,
      }),
    );
  }

  Future<void> clearAutomationTargets() async {
    _robTargets.clear();
    _monitorTargets.clear();
    _robTargetStatuses.clear();
    _monitorTargetStatuses.clear();
    _isRobbing = false;
    _isMonitoring = false;
    _robRunID++;
    _monitorRunID++;
    await saveAutomationState();
    notifyListeners();
  }

  Future<void> clearLogs() => _logService.clear();

  Future<String> readLogs() => _logService.readRecent();

  void unawaitedSaveAutomationState() {
    saveAutomationState().catchError((e) {
      debugPrint('保存自动化状态失败: $e');
    });
  }

  List<Map<String, dynamic>> _decodeTargets(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  void _rebuildTargetStatuses() {
    _robTargetStatuses
      ..clear()
      ..addEntries(_robTargets.map(
        (target) => MapEntry(_asInt(target['id']), _initialTargetStatus()),
      ));
    _monitorTargetStatuses
      ..clear()
      ..addEntries(_monitorTargets.map(
        (target) => MapEntry(_asInt(target['id']), _initialTargetStatus()),
      ));
  }

  int _durationMs(dynamic value, int fallback) {
    final ms = _asInt(value);
    return ms > 0 ? ms : fallback;
  }

  Future<void> loadQueryCondition(int turnID) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _queryCondition = await _apiService.getQueryCondition(turnID);
      await _loadFilterConditions();
    } catch (e) {
      _errorMessage = '加载筛选条件失败: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFilterConditions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filterJson = prefs.getString('filter_conditions');
      if (filterJson != null) {
        _filterConditions = Map<String, dynamic>.from(
          Map.castFrom<dynamic, dynamic, String, dynamic>(
            jsonDecode(filterJson) as Map,
          ),
        );
      }
    } catch (e) {
      debugPrint('加载筛选条件缓存失败: $e');
    }
  }

  Future<void> saveFilterConditions(Map<String, dynamic> conditions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('filter_conditions', jsonEncode(conditions));
      _filterConditions = Map<String, dynamic>.from(conditions);
      notifyListeners();
    } catch (e) {
      debugPrint('保存筛选条件缓存失败: $e');
    }
  }

  Future<void> clearFilterConditions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('filter_conditions');
      _filterConditions = null;
      notifyListeners();
    } catch (e) {
      debugPrint('清除筛选条件缓存失败: $e');
    }
  }

  Future<void> searchCourses({
    required int studentID,
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
    int pageSize = 20,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final result = await _apiService.queryLessons(
        studentID: studentID,
        turnID: turnID,
        semesterID: semesterID,
        courseNameOrCode: courseName ?? '',
        lessonNameOrCode: lessonName ?? '',
        teacherNameOrCode: teacherName ?? '',
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
        pageSize: pageSize,
      );

      final lessonsList = result['lessons'] as List<dynamic>;
      _courses = List<Map<String, dynamic>>.from(
        lessonsList.map((item) => item as Map<String, dynamic>),
      );
      final pageInfo = result['pageInfo'] as Map<String, dynamic>;
      _currentPage = pageInfo['currentPage'] as int;
      _totalPages = pageInfo['totalPages'] as int;
      _totalRows = pageInfo['totalRows'] as int;

      // 批量获取课程名额信息
      if (_courses.isNotEmpty) {
        final lessonIds =
            _courses.map((course) => course['id'] as int).toList();
        _courseCountInfo = await getBatchCountInfo(lessonIds);
      } else {
        _courseCountInfo = {};
      }
    } catch (e) {
      _errorMessage = '搜索课程失败: $e';
      debugPrint(_errorMessage);
      _courses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSelectedCourses(int turnID, int studentID) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _selectedCourses =
          await _apiService.getSelectedLessons(turnID, studentID);
    } catch (e) {
      _errorMessage = '加载已选课程失败: $e';
      debugPrint(_errorMessage);
      _selectedCourses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addCourse(
      int studentID, int turnID, int lessonID, int virtualCost) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final result = await _apiService.addCourse(
        studentID,
        turnID,
        lessonID,
        virtualCost,
        polling: _pollingConfig,
      );
      if (!result.success) {
        _errorMessage = result.message;
        await _logCourseAction('addCourse', result);
        return false;
      }
      await _logCourseAction('addCourse', result);

      // 刷新已选课程
      await loadSelectedCourses(turnID, studentID);

      // 更新新添加课程的virtualCost（API可能不返回此字段）
      final addedCourse = _selectedCourses.firstWhere(
        (course) => course['id'] == lessonID,
        orElse: () => <String, dynamic>{},
      );
      if (addedCourse.isNotEmpty) {
        addedCourse['virtualCost'] = virtualCost;
      }

      return true;
    } catch (e) {
      _errorMessage = '选课失败: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> dropCourse(int studentID, int turnID, int lessonID) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final result = await _apiService.dropCourse(
        studentID,
        turnID,
        lessonID,
        polling: _pollingConfig,
      );
      if (!result.success) {
        _errorMessage = result.message;
        await _logCourseAction('dropCourse', result);
        return false;
      }
      await _logCourseAction('dropCourse', result);

      // 刷新已选课程
      await loadSelectedCourses(turnID, studentID);

      return true;
    } catch (e) {
      _errorMessage = '退课失败: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getCountInfo(int lessonID) async {
    try {
      return await _apiService.getCountInfo(lessonID);
    } catch (e) {
      debugPrint('获取课程名额失败: $e');
      return null;
    }
  }

  Future<void> _logCourseAction(String event, CourseActionResult result) {
    return _logService.write(
      event,
      result.message,
      data: {
        'success': result.success,
        'requestId': result.requestId,
        'attempts': result.attempts,
        'elapsedMs': result.elapsedMs,
      },
    );
  }

  Future<Map<String, Map<String, dynamic>>> getBatchCountInfo(
      List<int> lessonIDs) async {
    try {
      final batchData = await _apiService.getBatchCountInfo(lessonIDs);
      final result = <String, Map<String, dynamic>>{};

      for (final entry in batchData.entries) {
        final lessonId = entry.key;
        final countString = entry.value;
        // 解析格式: "总选课人数-预选人数-预跨选人数-跨选人数"
        final parts = countString.split('-');
        if (parts.length >= 4) {
          final totalSelected = int.tryParse(parts[0]) ?? 0;
          final preSelected = int.tryParse(parts[1]) ?? 0;
          final preCrossSelected = int.tryParse(parts[2]) ?? 0;
          final crossSelected = int.tryParse(parts[3]) ?? 0;
          final regularSelected = totalSelected - crossSelected;

          result[lessonId] = {
            'stdCount': regularSelected, // 正选人数
            'amStdCount': crossSelected, // 跨选人数
            'preStdCount': preSelected, // 预选人数
            'preAmStdCount': preCrossSelected, // 预跨选人数
            'totalSelected': totalSelected, // 总选课人数
          };
        }
      }

      return result;
    } catch (e) {
      debugPrint('批量获取课程名额失败: $e');
      return {};
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _regularLimit(
      Map<String, dynamic> course, Map<String, dynamic> countInfo) {
    final countLimit = countInfo['limitCount'];
    return _asInt(countLimit ?? course['limitCount']);
  }

  int _acrossMajorLimit(
      Map<String, dynamic> course, Map<String, dynamic> countInfo) {
    final countLimit = countInfo['amLimitCount'] ??
        countInfo['acrossMajorLimitCount'] ??
        course['acrossMajorLimitCount'];
    return _asInt(countLimit);
  }

  int _availableSeats(
      Map<String, dynamic> course, Map<String, dynamic>? countInfo) {
    if (countInfo == null) return 0;

    final regularAvailable =
        _regularLimit(course, countInfo) - _asInt(countInfo['stdCount']);
    final acrossMajorAvailable =
        _acrossMajorLimit(course, countInfo) - _asInt(countInfo['amStdCount']);

    return (regularAvailable > 0 ? regularAvailable : 0) +
        (acrossMajorAvailable > 0 ? acrossMajorAvailable : 0);
  }

  @visibleForTesting
  int availableSeatsForTesting(
    Map<String, dynamic> course,
    Map<String, dynamic>? countInfo,
  ) =>
      _availableSeats(course, countInfo);

  Map<String, dynamic> _initialTargetStatus() => {
        'available': 0,
        'limitCount': 0,
        'stdCount': 0,
        'amStdCount': 0,
        'lastChecked': null,
        'status': '未监控',
        'attemptCount': 0,
        'lastError': null,
        'lastRequestId': null,
        'successTime': null,
      };

  Map<String, dynamic> _statusFromCountInfo(
    Map<String, dynamic> course,
    Map<String, dynamic> countInfo,
  ) {
    final regularLimit = _regularLimit(course, countInfo);
    final acrossMajorLimit = _acrossMajorLimit(course, countInfo);
    final available = _availableSeats(course, countInfo);

    return {
      'available': available,
      'limitCount': regularLimit + acrossMajorLimit,
      'stdCount': _asInt(countInfo['stdCount']),
      'amStdCount': _asInt(countInfo['amStdCount']),
      'lastChecked': DateTime.now(),
      'status': available > 0 ? '有余量' : '无余量',
    };
  }

  void addRobTarget(Map<String, dynamic> course, {int virtualCost = 0}) async {
    if (!_robTargets.any((target) => target['id'] == course['id'])) {
      _robTargets.add({
        ...course, // 保留完整的course对象
        'priority': _robTargets.length + 1,
        'virtualCost': virtualCost,
        'attemptCount': 0,
        'lastError': null,
        'lastRequestId': null,
        'successTime': null,
      });
      // 初始化监控状态
      _robTargetStatuses[course['id']] = _initialTargetStatus();
      notifyListeners();

      // 获取名额信息
      try {
        final countInfo = await getCountInfo(course['id']);
        if (countInfo != null) {
          if (!_robTargets.any((target) => target['id'] == course['id'])) {
            return;
          }
          _robTargetStatuses[course['id']] =
              _statusFromCountInfo(course, countInfo);
        }
      } catch (e) {
        debugPrint('获取抢课目标名额信息失败: $e');
      }
      unawaitedSaveAutomationState();
      notifyListeners();
    }
  }

  void removeRobTarget(int lessonID) {
    _robTargets.removeWhere((target) => target['id'] == lessonID);
    _robTargetStatuses.remove(lessonID);
    if (_robTargets.isEmpty && _isRobbing) {
      _isRobbing = false;
      _robRunID++;
    }
    unawaitedSaveAutomationState();
    notifyListeners();
  }

  // 监控相关方法
  void addMonitorTarget(Map<String, dynamic> course,
      {int virtualCost = 0}) async {
    if (!_monitorTargets.any((target) => target['id'] == course['id'])) {
      _monitorTargets.add({
        ...course, // 保留完整的course对象
        'priority': _monitorTargets.length + 1,
        'virtualCost': virtualCost,
        'attemptCount': 0,
        'lastError': null,
        'lastRequestId': null,
        'successTime': null,
      });
      // 初始化监控状态
      _monitorTargetStatuses[course['id']] = _initialTargetStatus();
      notifyListeners();

      // 获取名额信息
      try {
        final countInfo = await getCountInfo(course['id']);
        if (countInfo != null) {
          if (!_monitorTargets.any((target) => target['id'] == course['id'])) {
            return;
          }
          _monitorTargetStatuses[course['id']] =
              _statusFromCountInfo(course, countInfo);
        }
      } catch (e) {
        debugPrint('获取监控目标名额信息失败: $e');
      }
      unawaitedSaveAutomationState();
      notifyListeners();
    }
  }

  void removeMonitorTarget(int lessonID) {
    _monitorTargets.removeWhere((target) => target['id'] == lessonID);
    _monitorTargetStatuses.remove(lessonID);
    if (_monitorTargets.isEmpty && _isMonitoring) {
      _isMonitoring = false;
      _monitorRunID++;
    }
    unawaitedSaveAutomationState();
    notifyListeners();
  }

  void setMonitorInterval(Duration interval) {
    _monitorInterval = interval < const Duration(milliseconds: 200)
        ? const Duration(milliseconds: 200)
        : interval;
    unawaitedSaveAutomationState();
    notifyListeners();
  }

  Future<void> startMonitoring(int studentID, int turnID) async {
    if (_isMonitoring || _monitorTargets.isEmpty) return;

    _isMonitoring = true;
    final runID = ++_monitorRunID;
    notifyListeners();

    while (
        _isMonitoring && runID == _monitorRunID && _monitorTargets.isNotEmpty) {
      for (var target in List.from(_monitorTargets)) {
        if (!_isMonitoring || runID != _monitorRunID) return;

        final countInfo = await getCountInfo(target['id']);
        if (countInfo != null) {
          final status = _statusFromCountInfo(target, countInfo);
          final available = status['available'] as int;

          // 更新监控状态
          _monitorTargetStatuses[target['id']] = status;
          notifyListeners();

          // 如果有余量，发送通知并自动抢课
          if (available > 0) {
            await NotificationService.showCourseAvailableNotification(
              target['course']?['nameZh'] ??
                  target['course']?['nameEn'] ??
                  '未知课程',
              available,
              status['limitCount'],
            );
            final success =
                await _tryAddTargetCourse(studentID, turnID, target);
            if (success) {
              removeMonitorTarget(target['id']);
            }
          }
        } else {
          // 获取失败时更新状态
          _monitorTargetStatuses[target['id']] = {
            'available': 0,
            'limitCount': 0,
            'stdCount': 0,
            'amStdCount': 0,
            'lastChecked': DateTime.now(),
            'status': '获取失败',
          };
          notifyListeners();
        }
      }

      if (_isMonitoring &&
          runID == _monitorRunID &&
          _monitorTargets.isNotEmpty) {
        await Future.delayed(_monitorInterval);
      }
    }

    if (_isMonitoring && runID == _monitorRunID && _monitorTargets.isEmpty) {
      _isMonitoring = false;
      notifyListeners();
    }
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _monitorRunID++;
    // 停止时重置监控状态
    for (var target in _monitorTargets) {
      _monitorTargetStatuses[target['id']] = _initialTargetStatus();
    }
    notifyListeners();
  }

  void setScheduledStartTime(DateTime? time) {
    _scheduledStartTime = time;
    unawaitedSaveAutomationState();
    notifyListeners();
  }

  void setRobInterval(Duration interval) {
    _robInterval = interval < const Duration(milliseconds: 200)
        ? const Duration(milliseconds: 200)
        : interval;
    unawaitedSaveAutomationState();
    notifyListeners();
  }

  Future<void> startRob(int studentID, int turnID) async {
    if (_isRobbing || _robTargets.isEmpty) return;

    _isRobbing = true;
    final runID = ++_robRunID;
    notifyListeners();

    // 如果设置了定时开始时间，等待到指定时间
    if (_scheduledStartTime != null) {
      final now = DateTime.now();
      if (_scheduledStartTime!.isAfter(now)) {
        final delay = _scheduledStartTime!.difference(now);
        await Future.delayed(delay);
      }
    }

    if (!_isRobbing || runID != _robRunID) return;

    while (_isRobbing && runID == _robRunID && _robTargets.isNotEmpty) {
      for (var target in List.from(_robTargets)) {
        if (!_isRobbing || runID != _robRunID) return;

        final countInfo = await getCountInfo(target['id']);
        if (countInfo != null) {
          final status = _statusFromCountInfo(target, countInfo);
          _robTargetStatuses[target['id']] = status;
          notifyListeners();

          final available = status['available'] as int;
          if (available > 0) {
            final success =
                await _tryAddTargetCourse(studentID, turnID, target);
            if (success) {
              removeRobTarget(target['id']);
            }
          }
        } else {
          _robTargetStatuses[target['id']] = {
            'available': 0,
            'limitCount': 0,
            'stdCount': 0,
            'amStdCount': 0,
            'lastChecked': DateTime.now(),
            'status': '获取失败',
          };
          notifyListeners();
        }
      }

      if (_isRobbing && runID == _robRunID && _robTargets.isNotEmpty) {
        await Future.delayed(_robInterval);
      }
    }

    if (_isRobbing && runID == _robRunID && _robTargets.isEmpty) {
      _isRobbing = false;
      notifyListeners();
    }
  }

  Future<bool> _tryAddTargetCourse(
    int studentID,
    int turnID,
    Map<String, dynamic> target,
  ) async {
    target['attemptCount'] = _asInt(target['attemptCount']) + 1;
    final success = await addCourse(
      studentID,
      turnID,
      target['id'],
      _asInt(target['virtualCost']),
    );
    if (success) {
      target['successTime'] = DateTime.now().toIso8601String();
      target['lastError'] = null;
    } else {
      target['lastError'] = _errorMessage;
    }
    unawaitedSaveAutomationState();
    return success;
  }

  void stopRob() {
    _isRobbing = false;
    _robRunID++;
    notifyListeners();
  }

  @override
  void dispose() {
    _robRunID++;
    _monitorRunID++;
    super.dispose();
  }
}
