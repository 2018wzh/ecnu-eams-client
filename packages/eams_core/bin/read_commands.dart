import 'package:args/args.dart';
import 'package:eams_core/eams_core.dart';

Future<void> runReadCommand(
  ArgResults args,
  ApiService api,
  void Function(Map<String, dynamic>) output,
) async {
  final config = ClientConfig.fromBase64(args['config'] as String);
  final action = args['action'] as String;
  final session = ClientSession(api);
  var stage = 'account';
  try {
    final account = await session.loadAccount(studentId: config.studentId);
    if (action == 'account') {
      output(account.toJson());
      return;
    }
    int positiveOption(String name, {int? fallback}) {
      final text = args[name] as String?;
      final value = text == null ? fallback : int.tryParse(text);
      if (value == null || value <= 0) {
        throw FormatException('--$name 必须为正整数');
      }
      return value;
    }

    final specifiedTurn = args['turn'] == null
        ? config.turnId
        : positiveOption('turn');
    if (specifiedTurn != null &&
        config.turnId != null &&
        specifiedTurn != config.turnId) {
      throw StateError('--turn 与配置的轮次不一致；请使用对应轮次或无轮次的查询配置');
    }
    final turnIds = specifiedTurn != null
        ? [specifiedTurn]
        : account.turns.map((t) => t['id'] as int).toList();
    if (turnIds.isEmpty) throw StateError('当前账号没有开放轮次');
    if (action != 'verify' && turnIds.length != 1) {
      throw StateError('存在多个开放轮次，请通过 --turn 指定');
    }
    final pageNo = positiveOption('page', fallback: 1);
    final pageSize = positiveOption('page-size', fallback: 20);
    if (pageSize > 100) throw const FormatException('--page-size 不能超过 100');
    final verified = <Map<String, dynamic>>[];
    for (final turnId in turnIds) {
      stage = 'open-turn';
      final scope = await session.openTurn(
        account,
        turnId,
        semesterId: config.semesterId,
      );
      if (action == 'selected') {
        stage = 'selected-lessons';
        output({
          ...scope.toJson(),
          'lessons': await api.getSelectedLessons(turnId, account.studentId),
        });
        return;
      }
      if (action == 'count') {
        stage = 'count-info';
        final lesson = positiveOption('lesson');
        output({'lessonId': lesson, 'counts': await api.getCountInfo(lesson)});
        return;
      }
      stage = 'course-query-and-counts';
      final page = await api.loadCoursePage(
        await api.queryLessons(
          studentID: account.studentId,
          turnID: turnId,
          semesterID: scope.semesterId,
          courseNameOrCode: args['course'] as String,
          teacherNameOrCode: args['teacher'] as String,
          lessonNameOrCode: args['lesson-name'] as String,
          campusId: args['campus'] as String,
          courseTypeId: args['course-type'] as String,
          coursePropertyId: args['course-property'] as String,
          departmentId: args['department'] as String,
          majorId: args['major'] as String,
          grade: args['grade'] as String,
          week: args['week'] as String,
          creditGte: args['credit-min'] as String?,
          creditLte: args['credit-max'] as String?,
          canSelect: args['available'] as bool ? 1 : null,
          hasCount: args['with-seats'] as bool ? true : null,
          pageNo: pageNo,
          pageSize: pageSize,
        ),
      );
      if (action == 'courses') {
        output({...scope.toJson(), ...page.toJson()});
        return;
      }
      stage = 'query-condition';
      await api.getQueryCondition(turnId);
      stage = 'selected-lessons';
      final selected = await api.getSelectedLessons(turnId, account.studentId);
      stage = 'eligible-course-query';
      final eligible = await api.loadCoursePage(
        await api.queryLessons(
          studentID: account.studentId,
          turnID: turnId,
          semesterID: scope.semesterId,
          canSelect: 1,
          hasCount: true,
          pageSize: pageSize,
        ),
      );
      stage = 'count-info';
      if (page.courses.isNotEmpty) {
        await api.getCountInfo(page.courses.first['id'] as int);
      }
      stage = 'text-search';
      var textSearchChecked = false;
      if (page.courses.isNotEmpty) {
        final course = page.courses.first['course'];
        if (course is! Map ||
            course['nameZh'] is! String ||
            (course['nameZh'] as String).trim().isEmpty) {
          throw const FormatException('课程缺少用于搜索验证的名称');
        }
        final name = course['nameZh'] as String;
        final filtered = await api.loadCoursePage(
          await api.queryLessons(
            studentID: account.studentId,
            turnID: turnId,
            semesterID: scope.semesterId,
            courseNameOrCode: name,
            pageSize: pageSize,
          ),
        );
        if (filtered.courses.isEmpty ||
            !filtered.courses.every((row) {
              final info = row['course'];
              return info is Map &&
                  ((info['nameZh'] is String &&
                          (info['nameZh'] as String).contains(name)) ||
                      (info['code'] is String &&
                          (info['code'] as String).contains(name)));
            }))
          throw StateError('课程名称搜索结果与筛选条件不一致');
        textSearchChecked = true;
      }
      stage = 'pagination';
      var paginationChecked = false;
      if (page.totalPages > 1) {
        final nextPage = page.currentPage == 1 ? 2 : 1;
        final next = await api.loadCoursePage(
          await api.queryLessons(
            studentID: account.studentId,
            turnID: turnId,
            semesterID: scope.semesterId,
            pageNo: nextPage,
            pageSize: pageSize,
          ),
        );
        if (next.currentPage != nextPage) throw StateError('课程翻页未生效');
        paginationChecked = true;
      }
      verified.add({
        ...scope.toJson(),
        'page': page.currentPage,
        'coursesChecked': page.courses.length,
        'totalCourses': page.totalRows,
        'eligibleCoursesChecked': eligible.courses.length,
        'selectedCoursesChecked': selected.length,
        'countDetailChecked': page.courses.isNotEmpty,
        'textSearchChecked': textSearchChecked,
        'paginationChecked': paginationChecked,
      });
    }
    output({'ok': true, 'readOnly': true, 'turns': verified});
  } catch (error) {
    // Server messages may contain credentials; the caller also redacts errors.
    final message = error is FormatException ? error.message : error.toString();
    throw StateError('$stage: $message');
  }
}
