import 'package:ecnu_eams_client/providers/course_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CourseProvider available seats', () {
    late CourseProvider provider;

    setUp(() {
      provider = CourseProvider();
    });

    test('uses regular seats', () {
      expect(
        provider.availableSeatsForTesting(
          {'limitCount': 10, 'acrossMajorLimitCount': 0},
          {'stdCount': 8, 'amStdCount': 0},
        ),
        2,
      );
    });

    test('uses across-major seats when regular seats are full', () {
      expect(
        provider.availableSeatsForTesting(
          {'limitCount': 10, 'acrossMajorLimitCount': 3},
          {'stdCount': 10, 'amStdCount': 1},
        ),
        2,
      );
    });

    test('returns zero when all seats are full', () {
      expect(
        provider.availableSeatsForTesting(
          {'limitCount': 10, 'acrossMajorLimitCount': 3},
          {'stdCount': 10, 'amStdCount': 3},
        ),
        0,
      );
    });

    test('treats null, missing, and non-int values as zero', () {
      expect(provider.availableSeatsForTesting({}, null), 0);
      expect(provider.availableSeatsForTesting({}, {}), 0);
      expect(
        provider.availableSeatsForTesting(
          {'limitCount': 'bad', 'acrossMajorLimitCount': 'bad'},
          {'stdCount': 'bad', 'amStdCount': 'bad'},
        ),
        0,
      );
    });
  });
}
