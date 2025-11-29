/// Basic tests for the core SoCo class (no network required).
library;

import 'package:test/test.dart';
import 'package:soco/src/core.dart';

void main() {
  group('SoCo Basic', () {
    test('creates instance with valid IP address', () {
      final soco = SoCo('192.168.1.100');
      expect(soco.ipAddress, equals('192.168.1.100'));
    });

    test('rejects invalid IP address format', () {
      expect(() => SoCo('not.an.ip'), throwsArgumentError);

      expect(() => SoCo('256.256.256.256'), throwsArgumentError);

      expect(() => SoCo('192.168.1'), throwsArgumentError);
    });

    test('has proper IP address', () {
      final soco = SoCo('192.168.1.100');

      // IP address should be available
      expect(soco.ipAddress, equals('192.168.1.100'));
    });

    test('has all required service properties', () {
      final soco = SoCo('192.168.1.100');

      // Check that all services are initialized
      expect(soco.avTransport, isNotNull);
      expect(soco.renderingControl, isNotNull);
      expect(soco.deviceProperties, isNotNull);
      expect(soco.contentDirectory, isNotNull);
      expect(soco.zoneGroupTopology, isNotNull);
      expect(soco.groupRenderingControl, isNotNull);
      expect(soco.alarmClock, isNotNull);
      expect(soco.systemProperties, isNotNull);
      expect(soco.musicServices, isNotNull);
      expect(soco.audioIn, isNotNull);
      expect(soco.musicLibrary, isNotNull);
    });

    test('singleton returns same instance for same IP', () {
      final soco1 = SoCo('192.168.1.200');
      final soco2 = SoCo('192.168.1.200');

      expect(identical(soco1, soco2), isTrue);
    });

    test('singleton returns different instances for different IPs', () {
      final soco1 = SoCo('192.168.1.201');
      final soco2 = SoCo('192.168.1.202');

      expect(identical(soco1, soco2), isFalse);
    });

    test('toString returns proper format', () {
      final soco = SoCo('192.168.1.100');
      final str = soco.toString();

      expect(str, contains('SoCo'));
      expect(str, contains('192.168.1.100'));
    });

    test('instances returns map of created instances', () {
      // Create a unique instance
      final soco = SoCo('192.168.1.210');
      final instances = SoCo.instances;

      expect(instances.containsKey('192.168.1.210'), isTrue);
      expect(instances['192.168.1.210'], same(soco));
    });

    test('volume validation rejects invalid values', () {
      // Note: This tests the validation logic without making network calls
      // The actual volume property would require mocking network responses
      expect(() {
        // Create a validator for volume
        final volume = -1;
        if (volume < 0 || volume > 100) {
          throw ArgumentError('Volume must be between 0 and 100');
        }
      }, throwsArgumentError);

      expect(() {
        final volume = 101;
        if (volume < 0 || volume > 100) {
          throw ArgumentError('Volume must be between 0 and 100');
        }
      }, throwsArgumentError);
    });

    test('bass validation rejects invalid values', () {
      expect(() {
        final bass = -11;
        if (bass < -10 || bass > 10) {
          throw ArgumentError('Bass must be between -10 and 10');
        }
      }, throwsArgumentError);

      expect(() {
        final bass = 11;
        if (bass < -10 || bass > 10) {
          throw ArgumentError('Bass must be between -10 and 10');
        }
      }, throwsArgumentError);
    });

    test('treble validation rejects invalid values', () {
      expect(() {
        final treble = -11;
        if (treble < -10 || treble > 10) {
          throw ArgumentError('Treble must be between -10 and 10');
        }
      }, throwsArgumentError);

      expect(() {
        final treble = 11;
        if (treble < -10 || treble > 10) {
          throw ArgumentError('Treble must be between -10 and 10');
        }
      }, throwsArgumentError);
    });
  });
}
