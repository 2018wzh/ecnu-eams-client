import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseURL =
      'https://byyt.ecnu.edu.cn/course-selection-api/api/v1';

  String? _authorization;

  void setAuthorization(String authorization) {
    _authorization = authorization;
  }

  Future<String?> _getAuthorization() async {
    if (_authorization != null) return _authorization;

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
      response = await http.get(url, headers: headers);
    } else {
      response = await http.post(
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

  Future<List<int>> getStudentID() async {
    final data = await _requestList('GET', '/student/course-select/students');
    return List<int>.from(data);
  }

  Future<List<Map<String, dynamic>>> getOpenTurns(int studentID) async {
    final data = await _requestList(
        'GET', '/student/course-select/open-turns/$studentID');
    return List<Map<String, dynamic>>.from(
      data.map((item) => item as Map<String, dynamic>),
    );
  }

  Future<Map<String, dynamic>> getSelectDetail(
      int studentID, int turnID) async {
    return await _requestMap(
        'GET', '/student/course-select/$studentID/turn/$turnID/select');
  }

  Future<int> getSemesterID(int studentID, int turnID) async {
    final detail = await getSelectDetail(studentID, turnID);
    return (detail['semester'] as Map<String, dynamic>)['id'] as int;
  }

  Future<List<Map<String, dynamic>>> getSelectedLessons(
      int turnID, int studentID) async {
    final data = await _requestList(
        'GET', '/student/course-select/selected-lessons/$turnID/$studentID');
    return List<Map<String, dynamic>>.from(
      data.map((item) => item as Map<String, dynamic>),
    );
  }

  Future<Map<String, dynamic>> getQueryCondition(int turnID) async {
    return await _requestMap(
        'GET', '/student/course-select/query-condition/$turnID');
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
    int canSelect = 1,
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
      '_canSelect': canSelect == 1 ? '可选' : '不可选',
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
        'POST', '/student/course-select/query-lesson/$studentID/$turnID',
        body: body);
  }

  Future<List<Map<String, dynamic>>> getRepairedCourses(
      int turnID, int studentID) async {
    final data = await _requestList(
        'GET', '/student/course-select/repaired-courses/$turnID/$studentID');
    return List<Map<String, dynamic>>.from(
      data.map((item) => item as Map<String, dynamic>),
    );
  }

  Future<Map<String, dynamic>> getCountInfo(int lessonID) async {
    final url = Uri.parse(
        '$baseURL/student/course-select/count-info?lessonId=$lessonID');
    final headers = await _getHeaders();
    final response = await http.get(url, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['result'] != 0) {
      throw Exception(data['message'] ?? 'API错误');
    }

    return data['data'] as Map<String, dynamic>;
  }

  Future<String> _addDropRequest(
    String action, {
    required int studentID,
    required int turnID,
    required int lessonID,
    int virtualCost = 0,
  }) async {
    final body = {
      'studentAssoc': studentID,
      'courseSelectTurnAssoc': turnID,
      'requestMiddleDtos': [
        {
          'lessonAssoc': lessonID,
          'virtualCost': virtualCost,
        }
      ],
      'coursePackAssoc': null,
    };

    final data =
        await _request('POST', '/student/course-select/$action', body: body);
    return data.toString();
  }

  Future<Map<String, dynamic>> _getResponse(
      String type, int studentID, String requestID) async {
    return await _requestMap(
        'GET', '/student/course-select/$type-response/$studentID/$requestID');
  }

  Future<void> addCourse(
      int studentID, int turnID, int lessonID, int virtualCost) async {
    // 先验证
    final predicateID = await _addDropRequest(
      'add-predicate',
      studentID: studentID,
      turnID: turnID,
      lessonID: lessonID,
      virtualCost: virtualCost,
    );

    // 查询验证结果
    final predicateResult =
        await _getResponse('predicate', studentID, predicateID);
    if (!(predicateResult['success'] as bool)) {
      throw Exception(predicateResult['errorMessage'] ?? '验证失败');
    }

    // 提交选课请求
    final requestID = await _addDropRequest(
      'add-request',
      studentID: studentID,
      turnID: turnID,
      lessonID: lessonID,
      virtualCost: virtualCost,
    );

    // 查询选课结果
    final result = await _getResponse('add-drop', studentID, requestID);
    if (!(result['success'] as bool)) {
      throw Exception(result['errorMessage'] ?? '选课失败');
    }
  }

  Future<void> dropCourse(int studentID, int turnID, int lessonID) async {
    // 先验证
    final predicateID = await _addDropRequest(
      'drop-predicate',
      studentID: studentID,
      turnID: turnID,
      lessonID: lessonID,
    );

    // 查询验证结果
    final predicateResult =
        await _getResponse('predicate', studentID, predicateID);
    if (!(predicateResult['success'] as bool)) {
      throw Exception(predicateResult['errorMessage'] ?? '验证失败');
    }

    // 提交退课请求
    final requestID = await _addDropRequest(
      'drop-request',
      studentID: studentID,
      turnID: turnID,
      lessonID: lessonID,
    );

    // 查询退课结果
    final result = await _getResponse('add-drop', studentID, requestID);
    if (!(result['success'] as bool)) {
      throw Exception(result['errorMessage'] ?? '退课失败');
    }
  }
}
