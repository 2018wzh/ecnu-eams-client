import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show parseHttpDate;
import 'course_action_result.dart';
import 'polling_config.dart';
import 'cancellation.dart';
import 'course_page.dart';
import 'lesson_search.dart';
import 'auth_token_normalizer.dart';
import 'portal_session.dart';

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
  final Future<PortalSession?> Function()? portalSessionProvider;
  final Future<void> Function(String previous, String next)?
  onAuthorizationRenewed;
  PortalSession? _portalSession;
  bool get hasAuthorizationProvider => _authorizationProvider != null;
  final Duration requestTimeout;
  bool _actionInFlight = false;
  Completer<void>? _actionFinished;
  Future<void>? _renewalInFlight;

  ApiService({
    http.Client? client,
    AuthorizationProvider? authorizationProvider,
    this.portalSessionProvider,
    this.onAuthorizationRenewed,
    this.requestTimeout = const Duration(seconds: 10),
  })  : _client = client ?? http.Client(),
        _authorizationProvider = authorizationProvider;

  void setAuthorization(String authorization) {
    _authorization = AuthTokenNormalizer.normalize(authorization);
  }

  void clearAuthorization() => _authorization = null;
  void setPortalSession(PortalSession? session) => _portalSession = session;
  Future<PortalSession?> getPortalSession() async =>
      portalSessionProvider != null
      ? await portalSessionProvider!()
      : _portalSession;
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
    },
        );

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
          retryAfter: retryAfter,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['result'] != 0) {
      throw ApiException(
          AuthTokenNormalizer.redact((data['message'] ?? 'API错误').toString(),
        ).replaceAll(headers['Authorization']!, '[REDACTED]'),
      );
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

  Future<List<Map<String, dynamic>>> getSimplestLessons(int turnID) async {
    final rows = await _requestList(
      'GET', '/student/course-select/simplest-lessons/$turnID',
    );
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
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
    var queryIds = ids;
    if ([courseNameOrCode, lessonNameOrCode, teacherNameOrCode,
    ]
        .any((term) => term.trim().isNotEmpty)) {
      queryIds = matchLessonIds(await getSimplestLessons(turnID),
        course: courseNameOrCode, lesson: lessonNameOrCode,
        teacher: teacherNameOrCode, ids: ids,
      );
    }
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
      'ids': queryIds,
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

  Future<Map<String, dynamic>> getCountInfo(int lessonID) async =>
      CourseCounts.validateDetail(await _requestMap(
        'GET', '/student/course-select/count-info?lessonId=$lessonID',
        ),
      );

  Future<Map<String, String>> getBatchCountInfo(List<int> lessonIDs) async {
    final data = await _requestMap(
      'POST',
      '/student/course-select/std-count',
      body: {'lessonIds': lessonIDs},
    );
    return Map<String, String>.from(data);
  }

  /// Complete the same course page used by GUI and CLI with batch enrollment.
  Future<CoursePage> loadCoursePage(Map<String, dynamic> response) async {
    final raw = response['lessons'];
    if (raw is! List) throw const FormatException('课程查询缺少 lessons');
    final ids = <int>[];
    for (final lesson in raw) {
      if (lesson is! Map || lesson['id'] is! int || lesson['id'] <= 0) {
        throw const FormatException('课程条目缺少有效教学班 ID');
      }
      ids.add(lesson['id'] as int);
    }
    final counts = ids.isEmpty
        ? <String, String>{}
        : await getBatchCountInfo(ids);
    return CoursePage.parse(response, counts);
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
          polling ?? PollingConfig.defaults, cancellation,
  );

  Future<CourseActionResult> dropCourse(
    int studentID,
    int turnID,
    int lessonID, {
    PollingConfig? polling,
    CancellationToken? cancellation,
  }) =>
      _courseAction(false, studentID, turnID, lessonID, 0,
          polling ?? PollingConfig.defaults, cancellation,
  );

  Future<CourseActionResult> _courseAction(
    bool add,
    int studentID,
    int turnID,
    int lessonID,
    int virtualCost,
    PollingConfig polling,
    CancellationToken? cancellation,
  ) async {
    try {
      while (_renewalInFlight != null) {
        await _renewalInFlight;
      }
      cancellation?.throwIfCancelled();
    } on OperationCancelled {
      return CourseActionResult.failure(
        '已停止',
        outcome: ActionOutcome.cancelled,
      );
    } catch (error) {
      return CourseActionResult.failure('会话维护失败，未提交（${error.runtimeType}）');
    }
    if (_actionInFlight) {
      return CourseActionResult.failure('另一项选退课操作尚未结束');
    }
    _actionInFlight = true;
    _actionFinished = Completer<void>();
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
            {Duration? retryAfter,
    }) =>
        CourseActionResult.failure(message,
            outcome: outcome,
            requestId: requestID,
            attempts: attempts,
            elapsedMs: watch.elapsedMilliseconds,
            retryAfter: retryAfter,
    );
    Future<CourseActionResult> reconcile(
      Map<String, dynamic> results,
      String reason,
    ) async {
      try {
        final selected = await getSelectedLessons(turnID, studentID);
        final exists = selected.any((course) => course['id'] == lessonID);
        if (exists == add) {
          return CourseActionResult.success(
              requestId: requestID ?? 'unavailable',
              lessonResults: results,
              attempts: attempts,
              elapsedMs: watch.elapsedMilliseconds,
              selectedLessons: selected,
          );
        }
        // Absence does not prove that a timed-out write will never commit.
        return failure('$reason；结果尚未确认，请在官网核对后再运行', ActionOutcome.uncertain);
      } catch (e) {
        return failure(
            '$reason；核对已选课程失败: $e。请在官网确认结果', ActionOutcome.uncertain,
        );
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
                      'lessonAssocSet': [lessonID],
              },
        cancellation: cancellation,
      );
      if (predicateID is! String || predicateID.isEmpty) {
        throw const FormatException('验证请求未返回有效请求 ID');
      }
      requestID = predicateID;
      final predicate = await _pollResponse(
          'predicate', studentID, predicateID, polling,
          cancellation: cancellation, onAttempt: () => attempts++,
      );
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
                  'coursePackAssoc': null,
              },
        cancellation: cancellation,
      );
      if (id is! String || id.isEmpty) {
        throw const FormatException('选退课请求未返回有效请求 ID');
      }
      requestID = id;
      final result = await _pollResponse('add-drop', studentID, id, polling,
          onAttempt: () => attempts++,
      );
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
          retryAfter: e.retryAfter,
      );
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
      _actionFinished!.complete();
      _actionFinished = null;
    }
  }

  String _resultError(Map<String, dynamic> result) =>
      AuthTokenNormalizer.redact(
          (result['errorMessage'] ?? result['exception'] ?? '选退课验证失败')
              .toString(),
      );

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
          cancellation: cancellation, timeout: config.timeout - watch.elapsed,
      );
      if (data is Map<String, dynamic>) return data;
      if (data != null) throw const FormatException('选退课结果格式异常');
      final remaining = config.timeout - watch.elapsed;
      if (remaining <= Duration.zero) break;
      final delay = config.interval < remaining ? config.interval : remaining;
      await (cancellation?.delay(delay) ?? Future<void>.delayed(delay));
    }
    throw TimeoutException('等待选退课结果超时', config.timeout);
  }

  Future<List<int>> getStudentID({CancellationToken? cancellation}) async {
    final data = await _request(
      'GET',
      '/student/course-select/students',
      cancellation: cancellation,
    );
    return List<int>.from(data);
  }

  /// Renews using the portal session when present; otherwise checks identity.
  /// Returns true only when a replacement token was validated and saved.
  Future<bool> keepAlive(
    int studentId, {
    CancellationToken? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final session = await getPortalSession();
    if (session != null) {
      final existing = _renewalInFlight;
      if (existing != null) {
        await existing;
        cancellation?.throwIfCancelled();
        if (!(await getStudentID(
          cancellation: cancellation,
        )).contains(studentId)) {
          throw StateError('续期后的学生身份不一致，任务停止');
        }
        return true;
      }
      final renewal = _renewAuthorization(session, studentId, cancellation);
      _renewalInFlight = renewal;
      try {
        await renewal;
      } finally {
        _renewalInFlight = null;
      }
      return true;
    }
    final data = await _request(
      'GET',
      '/student/course-select/students',
      cancellation: cancellation,
    );
    cancellation?.throwIfCancelled();
    if (!List<int>.from(data as List).contains(studentId)) {
      throw StateError('保活检查发现登录学生已改变，任务停止');
    }
    return false;
  }

  Future<void> _renewAuthorization(
    PortalSession session,
    int studentId,
    CancellationToken? cancellation,
  ) async {
    if (_actionFinished != null) await _actionFinished!.future;
    cancellation?.throwIfCancelled();
    if (_authorizationProvider != null && onAuthorizationRenewed == null) {
      throw StateError('凭据提供器缺少续期保存回调');
    }
    final previous = await getAuthorization();
    cancellation?.throwIfCancelled();
    final abort = Completer<void>();
    final request =
        http.AbortableRequest(
            'POST',
            Uri.parse('https://byyt.ecnu.edu.cn/portal-service/token/renew'),
            abortTrigger: abort.future,
          )
          ..followRedirects = false
          ..headers.addAll({
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': previous,
            'Cookie': session.cookieHeader,
          })
          ..body = jsonEncode({'token': previous});
    final response = await _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(
          requestTimeout,
          onTimeout: () {
            abort.complete();
            throw TimeoutException('Token 续期超时', requestTimeout);
          },
        );
    cancellation?.throwIfCancelled();
    if (response.statusCode != 200 ||
        !(response.headers['content-type'] ?? '').contains(
          'application/json',
        )) {
      throw ApiException(
        '门户会话失效，无法续期，请重新网页登录并导出配置',
        statusCode: response.statusCode == 200 ? 401 : response.statusCode,
      );
    }
    // Never include the response body in errors: it may contain credentials.
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const FormatException('Token 续期响应不是有效 JSON');
    }
    if (decoded is! Map ||
        decoded['code'] != 0 ||
        decoded['data'] is! Map ||
        decoded['data']['token'] is! String) {
      throw const ApiException('Token 续期被拒绝，请重新网页登录', statusCode: 401);
    }
    final next = AuthTokenNormalizer.normalize(
      decoded['data']['token'] as String,
    );
    // Verify the replacement before storing it or allowing another selection.
    final verifier = ApiService(client: _client, requestTimeout: requestTimeout)
      ..setAuthorization(next);
    final ids = await verifier.getStudentID(cancellation: cancellation);
    cancellation?.throwIfCancelled();
    if (!ids.contains(studentId)) throw StateError('续期后的学生身份不一致，任务停止');
    if (await getAuthorization() != previous) {
      throw StateError('续期期间登录已改变，任务停止');
    }
    cancellation?.throwIfCancelled();
    if (onAuthorizationRenewed != null) {
      await onAuthorizationRenewed!(previous, next);
    }
    if (_authorizationProvider == null) {
      _authorization = next;
    } else {
      _authorization = null;
    }
  }
}
