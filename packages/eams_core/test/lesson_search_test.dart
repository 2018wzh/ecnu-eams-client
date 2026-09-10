import 'dart:convert';
import 'package:eams_core/eams_core.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'api_service_test.dart' show reply;

void main() {
  final index = [
    {
      'id': 1,
      'courseName': '高等数学',
      'courseCode': 'M01',
      'lessonName': '数学A班',
      'lessonCode': 'L01',
      'teacherName': '王老师',
    },
    {
      'id': 2,
      'courseName': '高等数学',
      'courseCode': 'M01',
      'lessonName': '数学B班',
      'lessonCode': 'L02',
      'teacherName': '李老师',
    },
    {
      'id': 3,
      'courseName': '大学英语',
      'courseCode': 'E01',
      'lessonName': '英语A班',
      'lessonCode': 'L03',
      'teacherName': null,
    },
  ];
  test('name/code/teacher filters combine and intersect explicit targets', () {
    expect(matchLessonIds(index, course: ' 数学 ', teacher: '王'), [1]);
    expect(matchLessonIds(index, course: 'M01', lesson: 'L02'), [2]);
    expect(matchLessonIds(index, course: '数学', ids: [2, 3]), [2]);
    expect(matchLessonIds(index, course: '不存在'), isEmpty);
    expect(matchLessonIds(index, teacher: '王', ids: [3]), isEmpty);
  });
  test('API resolves text into IDs before sending the server query', () async {
    final paths = <String>[];
    final api = ApiService(
      client: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.contains('/simplest-lessons/'))
          return reply(index);
        final body = jsonDecode(request.body);
        expect(body['ids'], [2]);
        return reply({'lessons': []});
      }),
    )..setAuthorization('test-token');
    addTearDown(api.close);
    await api.queryLessons(
      studentID: 1,
      turnID: 2,
      semesterID: 3,
      courseNameOrCode: '数学',
      teacherNameOrCode: '李',
    );
    expect(paths.first, endsWith('/simplest-lessons/2'));
    expect(paths.last, endsWith('/query-lesson/1/2'));
  });
}
