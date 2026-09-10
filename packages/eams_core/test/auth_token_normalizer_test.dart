import 'package:eams_core/eams_core.dart';
import 'package:test/test.dart';

void main() {
  group('AuthTokenNormalizer', () {
    test('normalizes bare and bearer tokens to the raw authorization value',
        () {
      expect(AuthTokenNormalizer.normalize('abc.def'), 'abc.def');
      expect(AuthTokenNormalizer.normalize('Bearer abc.def'), 'abc.def');
      expect(AuthTokenNormalizer.normalize('bearer abc.def'), 'abc.def');
    });

    test('trims quotes and whitespace', () {
      expect(AuthTokenNormalizer.normalize('  "Bearer abc.def"  '), 'abc.def');
      expect(AuthTokenNormalizer.normalize("'abc.def'"), 'abc.def');
    });

    test('rejects empty tokens', () {
      expect(() => AuthTokenNormalizer.normalize('  '), throwsFormatException);
    });

    test('redacts authorization-shaped values', () {
      expect(
        AuthTokenNormalizer.redact('Authorization: Bearer abc.def.ghi'),
        'Authorization: [REDACTED]',
      );
    });
  });
}
