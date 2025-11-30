/// Tests for the config module.
library;

import 'package:test/test.dart';
import 'package:soco/src/config.dart' as config;

void main() {
  group('Config', () {
    tearDown(() {
      // Reset config after each test
      config.resetConfig();
    });

    test('default values are set correctly', () {
      config.resetConfig();
      expect(config.socoClassFactory, isNull);
      expect(config.cacheEnabled, isTrue);
      expect(config.eventAdvertiseIp, isNull);
      expect(config.eventListenerIp, isNull);
      expect(config.eventListenerPort, equals(1400));
      expect(config.requestTimeout, equals(20.0));
      expect(config.zgtEventFallback, isTrue);
    });

    test('resetConfig resets all values to defaults', () {
      // Change all values
      config.socoClassFactory = (ip) => 'mock';
      config.cacheEnabled = false;
      config.eventAdvertiseIp = '192.168.1.1';
      config.eventListenerIp = '192.168.1.2';
      config.eventListenerPort = 9999;
      config.requestTimeout = 60.0;
      config.zgtEventFallback = false;

      // Reset
      config.resetConfig();

      // Verify all are back to defaults
      expect(config.socoClassFactory, isNull);
      expect(config.cacheEnabled, isTrue);
      expect(config.eventAdvertiseIp, isNull);
      expect(config.eventListenerIp, isNull);
      expect(config.eventListenerPort, equals(1400));
      expect(config.requestTimeout, equals(20.0));
      expect(config.zgtEventFallback, isTrue);
    });

    test('getSocoInstance throws when factory not set', () {
      config.socoClassFactory = null;
      expect(
        () => config.getSocoInstance('192.168.1.1'),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('getSocoInstance uses factory when set', () {
      var factoryCalled = false;
      var receivedIp = '';
      config.socoClassFactory = (ip) {
        factoryCalled = true;
        receivedIp = ip;
        return 'mock-soco';
      };

      final result = config.getSocoInstance('192.168.1.100');

      expect(factoryCalled, isTrue);
      expect(receivedIp, equals('192.168.1.100'));
      expect(result, equals('mock-soco'));
    });

    test('cacheEnabled can be toggled', () {
      expect(config.cacheEnabled, isTrue);
      config.cacheEnabled = false;
      expect(config.cacheEnabled, isFalse);
    });

    test('requestTimeout can be changed', () {
      expect(config.requestTimeout, equals(20.0));
      config.requestTimeout = 30.0;
      expect(config.requestTimeout, equals(30.0));
      config.requestTimeout = null;
      expect(config.requestTimeout, isNull);
    });
  });
}
