import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class CourseProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

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

  int getTotalVirtualCost() {
    return _selectedCourses.fold<int>(
      0,
      (sum, course) => sum + ((course['virtualCost'] as int?) ?? 0),
    );
  }

  // 抢课相关
  bool _isRobbing = false;
  List<Map<String, dynamic>> _robTargets = [];
  DateTime? _scheduledStartTime;
  Duration _robInterval = const Duration(milliseconds: 500);
  Timer? _robTimer;
  Map<int, Map<String, dynamic>> _robTargetStatuses = {}; // 监控状态

  // 监控相关
  bool _isMonitoring = false;
  List<Map<String, dynamic>> _monitorTargets = [];
  Duration _monitorInterval = const Duration(seconds: 5);
  Timer? _monitorTimer;
  Map<int, Map<String, dynamic>> _monitorTargetStatuses = {}; // 监控状态

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
        canSelect: onlyAvailable ? 1 : 0,
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

      await _apiService.addCourse(studentID, turnID, lessonID, virtualCost);

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

      await _apiService.dropCourse(studentID, turnID, lessonID);

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

  void addRobTarget(Map<String, dynamic> course) async {
    if (!_robTargets.any((target) => target['id'] == course['id'])) {
      _robTargets.add({
        ...course, // 保留完整的course对象
        'priority': _robTargets.length + 1,
      });
      // 初始化监控状态
      _robTargetStatuses[course['id']] = {
        'available': 0,
        'limitCount': 0,
        'stdCount': 0,
        'lastChecked': null,
        'status': '未监控',
      };

      // 获取名额信息
      try {
        final countInfo = await getCountInfo(course['id']);
        if (countInfo != null) {
          _robTargetStatuses[course['id']] = {
            ..._robTargetStatuses[course['id']]!,
            'stdCount': countInfo['stdCount'] ?? 0,
            'limitCount': course['limitCount'] ?? 0,
            'available':
                (course['limitCount'] ?? 0) - (countInfo['stdCount'] ?? 0),
          };
        }
      } catch (e) {
        debugPrint('获取抢课目标名额信息失败: $e');
      }

      notifyListeners();
    }
  }

  void removeRobTarget(int lessonID) {
    _robTargets.removeWhere((target) => target['id'] == lessonID);
    _robTargetStatuses.remove(lessonID);
    notifyListeners();
  }

  // 监控相关方法
  void addMonitorTarget(Map<String, dynamic> course) async {
    if (!_monitorTargets.any((target) => target['id'] == course['id'])) {
      _monitorTargets.add({
        ...course, // 保留完整的course对象
        'priority': _monitorTargets.length + 1,
      });
      // 初始化监控状态
      _monitorTargetStatuses[course['id']] = {
        'available': 0,
        'limitCount': 0,
        'stdCount': 0,
        'lastChecked': null,
        'status': '未监控',
      };

      // 获取名额信息
      try {
        final countInfo = await getCountInfo(course['id']);
        if (countInfo != null) {
          _monitorTargetStatuses[course['id']] = {
            ..._monitorTargetStatuses[course['id']]!,
            'stdCount': countInfo['stdCount'] ?? 0,
            'limitCount': course['limitCount'] ?? 0,
            'available':
                (course['limitCount'] ?? 0) - (countInfo['stdCount'] ?? 0),
          };
        }
      } catch (e) {
        debugPrint('获取监控目标名额信息失败: $e');
      }

      notifyListeners();
    }
  }

  void removeMonitorTarget(int lessonID) {
    _monitorTargets.removeWhere((target) => target['id'] == lessonID);
    _monitorTargetStatuses.remove(lessonID);
    notifyListeners();
  }

  void setMonitorInterval(Duration interval) {
    _monitorInterval = interval;
    notifyListeners();
  }

  Future<void> startMonitoring(int studentID, int turnID) async {
    if (_monitorTargets.isEmpty) return;

    _isMonitoring = true;
    notifyListeners();

    // 使用Timer实现监控
    _monitorTimer = Timer.periodic(_monitorInterval, (timer) async {
      if (!_isMonitoring || _monitorTargets.isEmpty) {
        timer.cancel();
        return;
      }

      for (var target in List.from(_monitorTargets)) {
        final countInfo = await getCountInfo(target['id']);
        if (countInfo != null) {
          final available =
              (countInfo['limitCount'] as int) - (countInfo['stdCount'] as int);
          // 更新监控状态
          _monitorTargetStatuses[target['id']] = {
            'available': available,
            'limitCount': countInfo['limitCount'],
            'stdCount': countInfo['stdCount'],
            'lastChecked': DateTime.now(),
            'status': available > 0 ? '有余量' : '无余量',
          };
          notifyListeners();

          // 如果有余量，发送通知并自动抢课
          if (available > 0) {
            await NotificationService.showCourseAvailableNotification(
              target['course']?['nameZh'] ??
                  target['course']?['nameEn'] ??
                  '未知课程',
              available,
              countInfo['limitCount'],
            );
            final success = await addCourse(
              studentID,
              turnID,
              target['id'],
              target['virtualCost'],
            );
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
            'lastChecked': DateTime.now(),
            'status': '获取失败',
          };
          notifyListeners();
        }
      }
    });
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _monitorTimer?.cancel();
    _monitorTimer = null;
    // 停止时重置监控状态
    for (var target in _monitorTargets) {
      _monitorTargetStatuses[target['id']] = {
        'available': 0,
        'limitCount': 0,
        'stdCount': 0,
        'lastChecked': null,
        'status': '未监控',
      };
    }
    notifyListeners();
  }

  void setScheduledStartTime(DateTime? time) {
    _scheduledStartTime = time;
    notifyListeners();
  }

  void setRobInterval(Duration interval) {
    _robInterval = interval;
    notifyListeners();
  }

  Future<void> startRob(int studentID, int turnID) async {
    if (_robTargets.isEmpty) return;

    // 如果设置了定时开始时间，等待到指定时间
    if (_scheduledStartTime != null) {
      final now = DateTime.now();
      if (_scheduledStartTime!.isAfter(now)) {
        final delay = _scheduledStartTime!.difference(now);
        await Future.delayed(delay);
      }
    }

    _isRobbing = true;
    notifyListeners();

    // 使用Timer实现可控的间隔抢课
    _robTimer = Timer.periodic(_robInterval, (timer) async {
      if (!_isRobbing || _robTargets.isEmpty) {
        timer.cancel();
        return;
      }

      for (var target in List.from(_robTargets)) {
        final countInfo = await getCountInfo(target['id']);
        if (countInfo != null) {
          final available =
              (countInfo['limitCount'] as int) - (countInfo['stdCount'] as int);
          if (available > 0) {
            final success = await addCourse(
              studentID,
              turnID,
              target['id'],
              target['virtualCost'],
            );
            if (success) {
              removeRobTarget(target['id']);
            }
          }
        }
      }
    });
  }

  void stopRob() {
    _isRobbing = false;
    _robTimer?.cancel();
    _robTimer = null;
    notifyListeners();
  }
}
