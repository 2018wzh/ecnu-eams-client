import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course_action_result.dart';
import '../models/polling_config.dart';
import 'auth_token_normalizer.dart';

typedef AuthorizationProvider = Future<String?> Function();

class ApiService {
  static const String baseURL =
      'https://byyt.ecnu.edu.cn/course-selection-api/api/v1';

  String? _authorization;
  final http.Client _client;
  final AuthorizationProvider? _authorizationProvider;

  ApiService({
    http.Client? client,
    AuthorizationProvider? authorizationProvider,
  })  : _client = client ?? http.Client(),
        _authorizationProvider = authorizationProvider;

  void setAuthorization(String authorization) {
    _authorization = AuthTokenNormalizer.normalize(authorization);
  }

  Future<String?> _getAuthorization() async {
    if (_authorization != null) return _authorization;

    if (_authorizationProvider != null) {
      return _authorizationProvider!();
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('authorization');
  }

  Future<Map<String, String>> _getHeaders() async {
    final authorization = await _getAuthorization();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      if (authorization != null) 'Authorization': authorization,
    };
  }

  Future<dynamic> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseURL$endpoint');

    http.Response response;
    if (method == 'GET') {
      response = await _client.get(url, headers: headers);
    } else {
      response = await _client.post(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    }

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['result'] != 0) {
      throw Exception(data['message'] ?? 'API错误');
    }

    return data['data'];
  }

  Future<Map<String, dynamic>> _requestMap(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final result = await _request(method, endpoint, body: body);
    return result as Map<String, dynamic>;
  }

  Future<List<dynamic>> _requestList(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final result = await _request(method, endpoint, body: body);
    return result as List<dynamic>;
  }

  Future<String> getCurrentDateTime() async {
    final data = await _request(
      'GET',
      '/student/course-select/getCurrentDateTime',
    );
    return data as String;
  }

  Future<List<Map<String, dynamic>>> getOpenTurns(int studentID) async {
    final data = await _requestList(
      'GET',
      '/student/course-select/open-turns/$studentID',
    );
    return List<Map<String, dynamic>>.from(
      data.map((item) => item as Map<String, dynamic>),
    );
  }

  Future<Map<String, dynamic>> getSelectDetail(
    int studentID,
    int turnID,
  ) async {
    return await _requestMap(
      'GET',
      '/student/course-select/$studentID/turn/$turnID/select',
    );
  }

  Future<int> getSemesterID(int studentID, int turnID) async {
    final detail = await getSelectDetail(studentID, turnID);
    return (detail['semester'] as Map<String, dynamic>)['id'] as int;
  }

  Future<List<Map<String, dynamic>>> getSelectedLessons(
    int turnID,
    int studentID,
  ) async {
    final data = await _requestList(
      'GET',
      '/student/course-select/selected-lessons/$turnID/$studentID',
    );
    return List<Map<String, dynamic>>.from(
      data.map((item) => item as Map<String, dynamic>),
    );
  }

  Future<Map<String, dynamic>> getQueryCondition(int turnID) async {
    return await _requestMap(
      'GET',
      '/student/course-select/query-condition/$turnID',
    );
  }

  Future<Map<String, dynamic>> queryLessons({
    required int studentID,
    required int turnID,
    required int semesterID,
    String courseNameOrCode = '',
    String lessonNameOrCode = '',
    String teacherNameOrCode = '',
    String week = '',
    String grade = '',
    String departmentId = '',
    String majorId = '',
    String adminclassId = '',
    String campusId = '',
    String openDepartmentId = '',
    String courseTypeId = '',
    String coursePropertyId = '',
    int? canSelect,
    String? creditGte,
    String? creditLte,
    bool? hasCount,
    List<int>? ids,
    int? substitutedCourseId,
    int? courseSubstitutePoolId,
    String sortField = 'lesson',
    String sortType = 'ASC',
    int pageNo = 1,
    int pageSize = 20,
  }) async {
    final body = {
      'turnId': turnID,
      'studentId': studentID,
      'semesterId': semesterID,
      'pageNo': pageNo,
      'pageSize': pageSize,
      'courseNameOrCode': courseNameOrCode,
      'lessonNameOrCode': lessonNameOrCode,
      'teacherNameOrCode': teacherNameOrCode,
      'week': week,
      'grade': grade,
      'departmentId': departmentId,
      'majorId': majorId,
      'adminclassId': adminclassId,
      'campusId': campusId,
      'openDepartmentId': openDepartmentId,
      'courseTypeId': courseTypeId,
      'coursePropertyId': coursePropertyId,
      'canSelect': canSelect,
      '_canSelect': canSelect == null
          ? ''
          : canSelect == 1
              ? '可选'
              : '不可选',
      'creditGte': creditGte,
      'creditLte': creditLte,
      'hasCount': hasCount,
      'ids': ids,
      'substitutedCourseId': substitutedCourseId,
      'courseSubstitutePoolId': courseSubstitutePoolId,
      'sortField': sortField,
      'sortType': sortType,
    };

    return await _requestMap(
      'POST',
      '/student/course-select/query-lesson/$studentID/$turnID',
      body: body,
    );
  }

  Future<List<Map<String, dynamic>>> getRepairedCourses(
    int turnID,
    int studentID,
  ) async {
    final data = await _requestList(
      'GET',
      '/student/course-select/repaired-courses/$turnID/$studentID',
    );
    return List<Map<String, dynamic>>.from(
      data.map((item) => item as Map<String, dynamic>),
    );
  }

  Future<Map<String, dynamic>> getCountInfo(int lessonID) async {
    final url = Uri.parse(
      '$baseURL/student/course-select/count-info?lessonId=$lessonID',
    );
    final headers = await _getHeaders();
    final response = await _client.get(url, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['result'] != 0) {
      throw Exception(data['message'] ?? 'API错误');
    }

    return data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, String>> getBatchCountInfo(List<int> lessonIDs) async {
    final data = await _requestMap(
      'POST',
      '/student/course-select/std-count',
      body: {'lessonIds': lessonIDs},
    );
    return Map<String, String>.from(data);
  }

  Future<String> _addPredicate({
    required int studentID,
    required int turnID,
    required int lessonID,
    int virtualCost = 0,
  }) async {
    late final Map<String, dynamic> body;
    body = {
      'studentAssoc': studentID,
      'courseSelectTurnAssoc': turnID,
      'requestMiddleDtos': [
        {'lessonAssoc': lessonID, 'virtualCost': virtualCost},
      ],
      'coursePackAssoc': null,
    };

    final data = await _request(
      'POST',
      '/student/course-select/add-predicate',
      body: body,
    );
    return data.toString();
  }

  Future<String> _addRequest({
    required int studentID,
    required int turnID,
    required int lessonID,
    int virtualCost = 0,
  }) async {
    late final Map<String, dynamic> body;
    body = {
      'studentAssoc': studentID,
      'courseSelectTurnAssoc': turnID,
      'requestMiddleDtos': [
        {'lessonAssoc': lessonID, 'virtualCost': virtualCost},
      ],
      'coursePackAssoc': null,
    };

    final data = await _request(
      'POST',
      '/student/course-select/add-request',
      body: body,
    );
    return data.toString();
  }

  Future<String> _dropPredicate({
    required int studentID,
    required int turnID,
    required int lessonID,
  }) async {
    late final Map<String, dynamic> body;
    body = {
      'studentAssoc': studentID,
      'courseSelectTurnAssoc': turnID,
      'lessonAssocSet': [lessonID],
    };

    final data = await _request(
      'POST',
      '/student/course-select/drop-predicate',
      body: body,
    );
    return data.toString();
  }

  Future<String> _dropRequest({
    required int studentID,
    required int turnID,
    required int lessonID,
  }) async {
    late final Map<String, dynamic> body;
    body = {
      'studentAssoc': studentID,
      'courseSelectTurnAssoc': turnID,
      'lessonAssocs': [lessonID],
      'coursePackAssoc': null,
    };

    final data = await _request(
      'POST',
      '/student/course-select/drop-request',
      body: body,
    );
    return data.toString();
  }

  Future<Map<String, dynamic>?> waitForCourseResponse(
    String type,
    int studentID,
    String requestID,
    PollingConfig polling,
  ) async {
    final config = polling.normalized();
    final started = DateTime.now();
    while (DateTime.now().difference(started) <= config.timeout) {
      final data = await _request(
        'GET',
        '/student/course-select/$type-response/$studentID/$requestID',
      );
      if (data is Map<String, dynamic>) {
        return data;
      }
      await Future.delayed(config.interval);
    }
    return null;
  }

  Future<CourseActionResult> addCourse(
    int studentID,
    int turnID,
    int lessonID,
    int virtualCost, {
    PollingConfig? polling,
  }) async {
    return _courseAction(
      predicate: () => _addPredicate(
        studentID: studentID,
        turnID: turnID,
        lessonID: lessonID,
        virtualCost: virtualCost,
      ),
      request: () => _addRequest(
        studentID: studentID,
        turnID: turnID,
        lessonID: lessonID,
        virtualCost: virtualCost,
      ),
      studentID: studentID,
      polling: polling ?? PollingConfig.defaults,
      failurePrefix: '选课失败',
    );
  }

  Future<CourseActionResult> dropCourse(
    int studentID,
    int turnID,
    int lessonID, {
    PollingConfig? polling,
  }) async {
    return _courseAction(
      predicate: () => _dropPredicate(
        studentID: studentID,
        turnID: turnID,
        lessonID: lessonID,
      ),
      request: () => _dropRequest(
        studentID: studentID,
        turnID: turnID,
        lessonID: lessonID,
      ),
      studentID: studentID,
      polling: polling ?? PollingConfig.defaults,
      failurePrefix: '退课失败',
    );
  }

  Future<CourseActionResult> _courseAction({
    required Future<String> Function() predicate,
    required Future<String> Function() request,
    required int studentID,
    required PollingConfig polling,
    required String failurePrefix,
  }) async {
    final started = DateTime.now();
    var attempts = 0;
    try {
      final predicateID = await predicate();
      final predicateResult = await _pollResponse(
        'predicate',
        studentID,
        predicateID,
        polling,
        onAttempt: () => attempts++,
      );
      if (predicateResult == null) {
        return CourseActionResult.failure(
          '$failurePrefix: 验证超时',
          requestId: predicateID,
          attempts: attempts,
          elapsedMs: DateTime.now().difference(started).inMilliseconds,
        );
      }
      if (!(predicateResult['success'] as bool? ?? false)) {
        return CourseActionResult.failure(
          (predicateResult['errorMessage'] ??
                  predicateResult['exception'] ??
                  '验证失败')
              .toString(),
          requestId: predicateID,
          attempts: attempts,
          elapsedMs: DateTime.now().difference(started).inMilliseconds,
        );
      }

      final requestID = await request();
      final result = await _pollResponse(
        'add-drop',
        studentID,
        requestID,
        polling,
        onAttempt: () => attempts++,
      );
      if (result == null) {
        return CourseActionResult.failure(
          '$failurePrefix: 请求超时',
          requestId: requestID,
          attempts: attempts,
          elapsedMs: DateTime.now().difference(started).inMilliseconds,
        );
      }
      if (!(result['success'] as bool? ?? false)) {
        return CourseActionResult.failure(
          (result['errorMessage'] ?? result['exception'] ?? failurePrefix)
              .toString(),
          requestId: requestID,
          attempts: attempts,
          elapsedMs: DateTime.now().difference(started).inMilliseconds,
        );
      }
      return CourseActionResult.success(
        requestId: requestID,
        lessonResults: Map<String, dynamic>.from(
          (result['result'] as Map?) ?? const {},
        ),
        attempts: attempts,
        elapsedMs: DateTime.now().difference(started).inMilliseconds,
      );
    } catch (e) {
      final text = e.toString();
      final authExpired = text.contains('HTTP 401');
      return CourseActionResult.failure(
        authExpired ? '登录已过期' : text.replaceFirst('Exception: ', ''),
        attempts: attempts,
        elapsedMs: DateTime.now().difference(started).inMilliseconds,
        authExpired: authExpired,
      );
    }
  }

  Future<Map<String, dynamic>?> _pollResponse(
    String type,
    int studentID,
    String requestID,
    PollingConfig polling, {
    required void Function() onAttempt,
  }) async {
    final config = polling.normalized();
    final started = DateTime.now();
    while (DateTime.now().difference(started) <= config.timeout) {
      onAttempt();
      final data = await _request(
        'GET',
        '/student/course-select/$type-response/$studentID/$requestID',
      );
      if (data is Map<String, dynamic>) {
        return data;
      }
      await Future.delayed(config.interval);
    }
    return null;
  }

  Future<List<int>> getStudentID() async {
    final data = await _requestList('GET', '/student/course-select/students');
    return List<int>.from(data);
  }
}
