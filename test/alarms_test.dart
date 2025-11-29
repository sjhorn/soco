/// Tests for the alarms module.
library;

import 'package:test/test.dart';
import 'package:soco/src/alarms.dart';

void main() {
  group('Alarms', () {
    test('isValidRecurrence accepts standard recurrence patterns', () {
      for (final recur in ['DAILY', 'WEEKDAYS', 'WEEKENDS', 'ONCE']) {
        expect(
          isValidRecurrence(recur),
          isTrue,
          reason: 'Should accept standard pattern: $recur',
        );
      }
    });

    test('isValidRecurrence accepts ON_* patterns with valid day numbers', () {
      expect(isValidRecurrence('ON_1'), isTrue);
      expect(isValidRecurrence('ON_132'), isTrue); // Mon, Tue, Wed
      expect(isValidRecurrence('ON_123456'), isTrue); // Mon-Sat
      expect(
        isValidRecurrence('ON_666'),
        isTrue,
      ); // Sat, Sat, Sat (valid but redundant)
      expect(isValidRecurrence('ON_0123456'), isTrue); // All days (Sun-Sat)
    });

    test('isValidRecurrence rejects lowercase ON_ patterns', () {
      expect(isValidRecurrence('on_1'), isFalse);
    });

    test('isValidRecurrence rejects ON_ patterns with too many digits', () {
      expect(isValidRecurrence('ON_123456789'), isFalse);
    });

    test('isValidRecurrence rejects ON_ without digits', () {
      expect(isValidRecurrence('ON_'), isFalse);
    });

    test('isValidRecurrence rejects patterns with leading spaces', () {
      expect(isValidRecurrence(' ON_1'), isFalse);
    });

    test('isValidRecurrence rejects invalid patterns', () {
      expect(isValidRecurrence('INVALID'), isFalse);
      expect(isValidRecurrence('daily'), isFalse);
      expect(isValidRecurrence(''), isFalse);
    });
  });
}
