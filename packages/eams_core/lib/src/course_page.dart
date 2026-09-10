import 'automation_config.dart' show positiveInt;

/// The school's std-count tuple is total, retakes, delayed releases,
/// across-major enrollment, across-business enrollment and its limit.
/// These are categories, not additive pools of available seats.
class CourseCounts {
  static Map<String, dynamic> validateDetail(Map<String, dynamic> data) {
    if (data['stdCount'] is! int || data['stdCount'] < 0) {
      throw const FormatException('count-info.stdCount 格式无效');
    }
    for (final key in [
      'limitCount',
      'preStdCount',
      'majorLimitCount',
      'majorStdCount',
      'preMajorStdCount',
      'amLimitCount',
      'amStdCount',
      'preAmStdCount',
      'abLimitCount',
      'abStdCount',
      'preAbStdCount',
      'retakeCount',
    ]) {
      final value = data[key];
      if (value != null && (value is! int || value < 0)) {
        throw FormatException('count-info.$key 应为非负整数或 null');
      }
    }
    return data;
  }

  final int total, retakes, delayed, acrossMajor;
  final int? acrossBusiness, acrossBusinessLimit;
  const CourseCounts(
    this.total,
    this.retakes,
    this.delayed,
    this.acrossMajor,
    this.acrossBusiness,
    this.acrossBusinessLimit,
  );

  factory CourseCounts.parse(String value) {
    final parts = value.split('-');
    if (parts.length != 6) {
      throw FormatException('std-count 应有 6 个字段，实际 ${parts.length} 个');
    }
    int number(int index) {
      final n = int.tryParse(parts[index]);
      if (n == null || n < 0) {
        throw FormatException('std-count 第 ${index + 1} 个字段应为非负整数');
      }
      return n;
    }

    int? optional(int index) => parts[index] == 'null' ? null : number(index);
    final result = CourseCounts(
      number(0),
      number(1),
      number(2),
      number(3),
      optional(4),
      optional(5),
    );
    if (result.retakes > result.total || result.acrossMajor > result.total) {
      throw const FormatException('std-count 分类人数超过总人数');
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
    'stdCount': total,
    'retakeCount': retakes,
    'delayReleaseCount': delayed,
    'amStdCount': acrossMajor,
    'abStdCount': acrossBusiness,
    'abLimitCount': acrossBusinessLimit,
  };
}

class CoursePage {
  final List<Map<String, dynamic>> courses;
  final Map<String, Map<String, dynamic>> counts;
  final int currentPage, totalPages, totalRows;
  const CoursePage(
    this.courses,
    this.counts,
    this.currentPage,
    this.totalPages,
    this.totalRows,
  );

  factory CoursePage.parse(
    Map<String, dynamic> response,
    Map<String, String> rawCounts,
  ) {
    final raw = response['lessons'];
    final page = response['pageInfo'];
    if (raw is! List || page is! Map) {
      throw const FormatException('课程查询缺少 lessons 或 pageInfo');
    }
    final courses = <Map<String, dynamic>>[];
    final counts = <String, Map<String, dynamic>>{};
    for (final row in raw) {
      if (row is! Map<String, dynamic>) {
        throw const FormatException('课程条目格式无效');
      }
      final id = positiveInt(row['id'], 'lesson.id');
      final value = rawCounts['$id'];
      if (value == null) throw StateError('人数接口缺少教学班 $id');
      try {
        counts['$id'] = CourseCounts.parse(value).toJson();
      } on FormatException catch (error) {
        throw FormatException('教学班 $id: ${error.message}');
      }
      courses.add(row);
    }
    int pageNumber(String key, int min) {
      final value = page[key];
      if (value is! int || value < min) {
        throw FormatException('pageInfo.$key 格式无效');
      }
      return value;
    }

    return CoursePage(
      courses,
      counts,
      pageNumber('currentPage', 1),
      pageNumber('totalPages', 0),
      pageNumber('totalRows', 0),
    );
  }

  Map<String, dynamic> toJson() => {
    'lessons': courses,
    'counts': counts,
    'pageInfo': {
      'currentPage': currentPage,
      'totalPages': totalPages,
      'totalRows': totalRows,
    },
  };
}
