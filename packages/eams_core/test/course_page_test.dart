import 'package:eams_core/eams_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'school six-field tuple preserves categories and nullable business quota',
    () {
      final counts = CourseCounts.parse('59-2-3-4-null-null').toJson();
      expect(counts, {
        'stdCount': 59,
        'retakeCount': 2,
        'delayReleaseCount': 3,
        'amStdCount': 4,
        'abStdCount': null,
        'abLimitCount': null,
      });
      expect(CourseCounts.parse('59-2-3-4-5-12').acrossBusinessLimit, 12);
    },
  );
  test('invalid counts fail without fabricating empty seats', () {
    for (final value in [
      '1-2',
      '59-2-0-2',
      'x-0-0-0-null-null',
      '1-0-0-2-null-null',
      '1-2-0-0-null-null',
      '1-0-0-0-null-x',
    ]) {
      expect(() => CourseCounts.parse(value), throwsFormatException);
    }
  });
  test('every returned lesson must have a validated count and pagination', () {
    final result = {
      'lessons': [
        {'id': 8},
      ],
      'pageInfo': {'currentPage': 1, 'totalPages': 2, 'totalRows': 30},
    };
    final page = CoursePage.parse(result, {'8': '12-0-0-0-null-null'});
    expect(page.counts['8']!['stdCount'], 12);
    expect(page.totalRows, 30);
    expect(() => CoursePage.parse(result, {}), throwsStateError);
    expect(
      () => CoursePage.parse({'lessons': [], 'pageInfo': {}}, {}),
      throwsFormatException,
    );
  });
}
