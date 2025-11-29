/// Tests for the singleton pattern in SoCo class.
library;

import 'package:test/test.dart';
import 'package:soco/src/core.dart';

void main() {
  group('SoCo Singleton', () {
    test('returns same instance for same IP address', () {
      // Use a unique IP for this test to avoid conflicts
      final soco1 = SoCo('192.168.100.1');
      final soco2 = SoCo('192.168.100.1');

      expect(
        identical(soco1, soco2),
        isTrue,
        reason: 'Same IP should return identical instance',
      );
    });

    test('returns different instances for different IP addresses', () {
      // Use unique IPs for this test
      final soco1 = SoCo('192.168.100.10');
      final soco2 = SoCo('192.168.100.11');

      expect(
        identical(soco1, soco2),
        isFalse,
        reason: 'Different IPs should return different instances',
      );
    });

    test('maintains singleton across multiple calls', () {
      final soco1 = SoCo('192.168.100.20');
      final soco2 = SoCo('192.168.100.20');
      final soco3 = SoCo('192.168.100.20');

      expect(identical(soco1, soco2), isTrue);
      expect(identical(soco2, soco3), isTrue);
      expect(identical(soco1, soco3), isTrue);
    });

    test('validates IPv4 address format', () {
      expect(
        () => SoCo('not.an.ip.address'),
        throwsArgumentError,
        reason: 'Invalid IP should throw ArgumentError',
      );

      expect(
        () => SoCo('256.256.256.256'),
        throwsArgumentError,
        reason: 'Out of range IP should throw ArgumentError',
      );

      expect(
        () => SoCo('192.168.1'),
        throwsArgumentError,
        reason: 'Incomplete IP should throw ArgumentError',
      );
    });

    test('instances property contains created instances', () {
      // Create a unique instance
      final soco = SoCo('192.168.100.30');
      final instances = SoCo.instances;

      expect(instances.containsKey('192.168.100.30'), isTrue);
      expect(instances['192.168.100.30'], same(soco));
    });

    test('instances property returns unmodifiable map', () {
      final instances = SoCo.instances;

      // Try to modify the map directly (should fail)
      expect(
        () => instances['192.168.100.200'] = SoCo('192.168.100.40'),
        throwsUnsupportedError,
        reason: 'Instances map should be unmodifiable',
      );
    });
  });
}
