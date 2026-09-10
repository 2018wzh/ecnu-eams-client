import 'dart:convert';
import 'package:ecnu_eams_client/providers/course_provider.dart';
import 'package:eams_core/eams_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'GUI course loading uses the shared page and six-field count parser',
    () async {
      var counts = '59-2-3-4-null-null';
      final api = ApiService(
        client: MockClient((request) async {
          Object data;
          if (request.url.path.contains('/query-lesson/')) {
            data = {
              'lessons': [
                {'id': 3},
              ],
              'pageInfo': {'currentPage': 1, 'totalPages': 1, 'totalRows': 1},
            };
          } else if (request.url.path.endsWith('/std-count')) {
            data = {'3': counts};
          } else {
            throw StateError('Unexpected endpoint');
          }
          return http.Response(jsonEncode({'result': 0, 'data': data}), 200);
        }),
      )..setAuthorization('test-token');
      final provider = CourseProvider(apiService: api);
      addTearDown(provider.dispose);
      await provider.searchCourses(studentID: 1, turnID: 2, semesterID: 4);
      expect(provider.errorMessage, isNull);
      expect(provider.courses.single['id'], 3);
      expect(provider.courseCountInfo['3']!['stdCount'], 59);
      expect(provider.courseCountInfo['3']!['retakeCount'], 2);
      counts = 'broken';
      await provider.searchCourses(studentID: 1, turnID: 2, semesterID: 4);
      expect(provider.errorMessage, contains('std-count'));
    },
  );
}
