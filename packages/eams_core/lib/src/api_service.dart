import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show parseHttpDate;
import 'course_action_result.dart';
import 'polling_config.dart';
import 'cancellation.dart';
import 'auth_token_normalizer.dart';

typedef AuthorizationProvider = Future<String?> Function();

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Duration? retryAfter;
  const ApiException(this.message, {this.statusCode, this.retryAfter});
  bool get authExpired => statusCode == 401 || statusCode == 403;
  bool get retryable => statusCode == 429 || (statusCode ?? 0) >= 500;
  @override
  String toString() => message;
}

class ApiService {
  static const String baseURL =
      'https://byyt.ecnu.edu.cn/course-selection-api/api/v1';

  String? _authorization;
  final http.Client _client;
  final AuthorizationProvider? _authorizationProvider;
  final Duration requestTimeout;
  bool _actionInFlight = false;

  ApiService({
    http.Client? client,
    AuthorizationProvider? authorizationProvider,
    this.requestTimeout = const Duration(seconds: 10),
  })  : _client = client ?? http.Client(),
        _authorizationProvider = authorizationProvider;

  void setAuthorization(String authorization) {
    _authorization = AuthTokenNormalizer.normalize(authorization);
  }

  void clearAuthorization() => _authorization = null;
  void close() => _client.close();

  Future<String?> _getAuthorization() async {
    if (_authorization != null) return _authorization;

    if (_authorizationProvider != null) {
      return _authorizationProvider();
    }

    return null;
  }

  Future<Map<String, String>> _getHeaders() async {
    final authorization = await getAuthorization();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': authorization,
    };
  }

  Future<String> getAuthorization() async {
    final authorization = await _getAuthorization();
    if (authorization == null || authorization.isEmpty) {
      throw const ApiException('请先登录', statusCode: 401);
    }
    return AuthTokenNormalizer.normalize(authorization);
  }

  Future<dynamic> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    CancellationToken? cancellation,
    Duration? timeout,
  }) async {
    cancellation?.throwIfCancelled();
    final headers = await _getHeaders().timeout(requestTimeout);
    final url = Uri.parse('$baseURL$endpoint');
    cancellation?.throwIfCancelled();
    final abort = Completer<void>();
    final request =
        http.AbortableRequest(method, url, abortTrigger: abort.future)
          ..headers.addAll(headers)
          ..followRedirects = false;
    if (body != null) request.body = jsonEncode(body);
    final budget =
        timeout == null || timeout > requestTimeout ? requestTimeout : timeout;
    final response = await _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(budget, onTimeout: () {
      abort.complete();
      throw TimeoutException('请求超时: $endpoint', budget);
    });

    if (response.statusCode != 200) {
      final seconds = int.tryParse(response.headers['retry-after'] ?? '');
      final retryHeader = response.headers['retry-after'];
      final retryAfter = retryHeader == null
          ? null
          : seconds != null
              ? Duration(seconds: seconds < 0 ? 0 : seconds)
              : parseHttpDate(retryHeader).difference(DateTime.now().toUtc());
      throw ApiException(
          response.statusCode == 401 || response.statusCode == 403
              ? '登录已过期或无权访问，请重新登录（HTTP ${response.statusCode}）'
              : 'HTTP ${response.statusCode}: $endpoint',
          statusCode: response.statusCode,
          retryAfter: retryAfter);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['result'] != 0) {
      throw ApiException(
          AuthTokenNormalizer.redact((data['message'] ?? 'API错误').toString())
              .replaceAll(headers['Authorization']!, '[REDACTED]'));
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

  Future<Map<String, dynamic>> getCountInfo(int lessonID) => _requestMap(
      'GET', '/student/course-select/count-info?lessonId=$lessonID');

  Future<Map<String, String>> getBatchCountInfo(List<int> lessonIDs) async {
    final data = await _requestMap(
      'POST',
      '/student/course-select/std-count',
      body: {'lessonIds': lessonIDs},
    );
    return Map<String, String>.from(data);
  }

  Future<CourseActionResult> addCourse(
    int studentID,
    int turnID,
    int lessonID,
    int virtualCost, {
    PollingConfig? polling,
    CancellationToken? cancellation,
  }) =>
      _courseAction(true, studentID, turnID, lessonID, virtualCost,
          polling ?? PollingConfig.defaults, cancellation);

  Future<CourseActionResult> dropCourse(
    int studentID,
    int turnID,
    int lessonID, {
    PollingConfig? polling,
    CancellationToken? cancellation,
  }) =>
      _courseAction(false, studentID, turnID, lessonID, 0,
          polling ?? PollingConfig.defaults, cancellation);

  Future<CourseActionResult> _courseAction(
    bool add,
    int studentID,
    int turnID,
    int lessonID,
    int virtualCost,
    PollingConfig polling,
    CancellationToken? cancellation,
  ) async {
    if (_actionInFlight) {
      return CourseActionResult.failure('另一项选退课操作尚未结束');
    }
    _actionInFlight = true;
    final watch = Stopwatch()..start();
    var attempts = 0;
    var submitted = false;
    String? requestID;
    final type = add ? 'add' : 'drop';
    final baseBody = {
      'studentAssoc': studentID,
      'courseSelectTurnAssoc': turnID,
    };
    final addBody = {
      ...baseBody,
      'requestMiddleDtos': [
        {'lessonAssoc': lessonID, 'virtualCost': virtualCost},
      ],
      'coursePackAssoc': null,
    };
    CourseActionResult failure(String message, ActionOutcome outcome,
            {Duration? retryAfter}) =>
        CourseActionResult.failure(message,
            outcome: outcome,
            requestId: requestID,
            attempts: attempts,
            elapsedMs: watch.elapsedMilliseconds,
            retryAfter: retryAfter);
    Future<CourseActionResult> reconcile(
        Map<String, dynamic> results, String reason) async {
      try {
        final selected = await getSelectedLessons(turnID, studentID);
        final exists = selected.any((course) => course['id'] == lessonID);
        if (exists == add) {
          return CourseActionResult.success(
              requestId: requestID ?? 'unavailable',
              lessonResults: results,
              attempts: attempts,
              elapsedMs: watch.elapsedMilliseconds,
              selectedLessons: selected);
        }
        // Absence does not prove that a timed-out write will never commit.
        return failure('$reason；结果尚未确认，请在官网核对后再运行', ActionOutcome.uncertain);
      } catch (e) {
        return failure(
            '$reason；核对已选课程失败: $e。请在官网确认结果', ActionOutcome.uncertain);
      }
    }

    try {
      cancellation?.throwIfCancelled();
      final predicateID =
          await _request('POST', '/student/course-select/$type-predicate',
              body: add
                  ? addBody
                  : {
                      ...baseBody,
                      'lessonAssocSet': [lessonID]
                    },
              cancellation: cancellation);
      if (predicateID is! String || predicateID.isEmpty) {
        throw const FormatException('验证请求未返回有效请求 ID');
      }
      requestID = predicateID;
      final predicate = await _pollResponse(
          'predicate', studentID, predicateID, polling,
          cancellation: cancellation, onAttempt: () => attempts++);
      if (predicate['success'] != true) {
        return failure(_resultError(predicate), ActionOutcome.rejected);
      }
      cancellation?.throwIfCancelled();
      // Once submission starts, finish read-only reconciliation even if stopped.
      submitted = true;
      requestID = null;
      final id = await _request('POST', '/student/course-select/$type-request',
          body: add
              ? addBody
              : {
                  ...baseBody,
                  'lessonAssocs': [lessonID],
                  'coursePackAssoc': null
                },
          cancellation: cancellation);
      if (id is! String || id.isEmpty) {
        throw const FormatException('选退课请求未返回有效请求 ID');
      }
      requestID = id;
      final result = await _pollResponse('add-drop', studentID, id, polling,
          onAttempt: () => attempts++);
      if (result['success'] != true) {
        return failure(_resultError(result), ActionOutcome.rejected);
      }
      final lessons = Map<String, dynamic>.from(result['result'] as Map? ?? {});
      final lessonError = lessons[lessonID.toString()];
      if (lessonError != null) {
        return failure(lessonError.toString(), ActionOutcome.rejected);
      }
      return await reconcile(lessons, '服务端已响应');
    } on OperationCancelled {
      return failure('已停止，未提交选退课请求', ActionOutcome.cancelled);
    } on ApiException catch (e) {
      if (submitted) return await reconcile({}, e.toString());
      return failure(
          e.toString(),
          e.authExpired
              ? ActionOutcome.authExpired
              : e.retryable
                  ? ActionOutcome.retryable
                  : ActionOutcome.rejected,
          retryAfter: e.retryAfter);
    } on TimeoutException catch (e) {
      if (submitted) return await reconcile({}, e.toString());
      return failure(e.toString(), ActionOutcome.retryable);
    } on http.ClientException catch (e) {
      if (submitted) return await reconcile({}, e.toString());
      return failure(e.toString(), ActionOutcome.retryable);
    } catch (e) {
      if (submitted) return await reconcile({}, e.toString());
      return failure(e.toString(), ActionOutcome.rejected);
    } finally {
      _actionInFlight = false;
    }
  }

  String _resultError(Map<String, dynamic> result) =>
      AuthTokenNormalizer.redact(
          (result['errorMessage'] ?? result['exception'] ?? '选退课验证失败')
              .toString());

  Future<Map<String, dynamic>> _pollResponse(
    String type,
    int studentID,
    String requestID,
    PollingConfig polling, {
    required void Function() onAttempt,
    CancellationToken? cancellation,
  }) async {
    final config = polling.normalized();
    final watch = Stopwatch()..start();
    while (watch.elapsed < config.timeout) {
      cancellation?.throwIfCancelled();
      onAttempt();
      final data = await _request(
          'GET', '/student/course-select/$type-response/$studentID/$requestID',
          cancellation: cancellation, timeout: config.timeout - watch.elapsed);
      if (data is Map<String, dynamic>) return data;
      if (data != null) throw const FormatException('选退课结果格式异常');
      final remaining = config.timeout - watch.elapsed;
      if (remaining <= Duration.zero) break;
      final delay = config.interval < remaining ? config.interval : remaining;
      await (cancellation?.delay(delay) ?? Future<void>.delayed(delay));
    }
    throw TimeoutException('等待选退课结果超时', config.timeout);
  }

  Future<List<int>> getStudentID() async {
    final data = await _requestList('GET', '/student/course-select/students');
    return List<int>.from(data);
  }
}
