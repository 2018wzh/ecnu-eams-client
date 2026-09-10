/// The official UI resolves text filters against simplest-lessons first.
/// query-lesson applies the resulting ids; text fields alone are ignored.
List<int> matchLessonIds(
  List<Map<String, dynamic>> index, {
  String course = '',
  String lesson = '',
  String teacher = '',
  List<int>? ids,
}) {
  final terms = [course.trim(), lesson.trim(), teacher.trim()];
  final allowed = ids?.toSet();
  final matches = <int>[];
  for (final row in index) {
    final id = row['id'];
    if (id is! int || id <= 0) throw const FormatException('课程索引的教学班 ID 无效');
    if (allowed != null && !allowed.contains(id)) continue;
    bool contains(String key, String term) {
      final value = row[key];
      if (value == null) return false;
      if (value is! String) throw FormatException('课程索引 $key 应为字符串');
      return value.contains(term);
    }

    if (terms[0].isNotEmpty &&
        !contains('courseName', terms[0]) &&
        !contains('courseCode', terms[0]))
      continue;
    if (terms[1].isNotEmpty &&
        !contains('lessonName', terms[1]) &&
        !contains('lessonCode', terms[1]))
      continue;
    if (terms[2].isNotEmpty && !contains('teacherName', terms[2])) continue;
    matches.add(id);
  }
  return matches;
}
