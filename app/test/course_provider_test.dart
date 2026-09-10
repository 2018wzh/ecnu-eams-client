import 'package:ecnu_eams_client/providers/course_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('batch count separates regular and across-major enrollment', () {
    final count = CourseProvider.parseCountInfo('59-2-0-2');
    expect(count['stdCount'], 57);
    expect(count['amStdCount'], 2);
    expect(count['totalSelected'], 59);
  });
  test('malformed counts fail instead of claiming empty seats', () {
    for (final value in ['abc-0-0-0', '1-2', '1-0-0-2']) {
      expect(() => CourseProvider.parseCountInfo(value), throwsFormatException);
    }
  });
}
