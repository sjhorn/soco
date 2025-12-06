/// Tests for the cache module.
library;

import 'package:test/test.dart';
import 'package:soco/src/cache.dart';
import 'package:soco/src/config.dart' as config;

void main() {
  group('Cache', () {
    test('instance creation returns TimedCache when enabled', () {
      config.cacheEnabled = true;
      final cache = Cache.create();
      expect(cache, isA<TimedCache>());
    });

    test('instance creation returns NullCache when disabled', () {
      config.cacheEnabled = false;
      final cache = Cache.create();
      expect(cache, isA<NullCache>());
      // Restore default
      config.cacheEnabled = true;
    });

    test('put and get items with keyword arguments', () async {
      final cache = Cache.create();
      cache.put(
        'item',
        ['some'],
        {'kw': 'args'},
        timeout: const Duration(seconds: 3),
      );

      // Different args should not match
      expect(
        cache.get(['some'], {'otherargs': 'value'}),
        isNot(equals('item')),
      );

      // Same args should match
      expect(cache.get(['some'], {'kw': 'args'}), equals('item'));

      // Wait 2 seconds, should still be there
      await Future.delayed(const Duration(seconds: 2));
      expect(cache.get(['some'], {'kw': 'args'}), equals('item'));

      // Wait another 2 seconds (total 4s), should be expired (timeout was 3s)
      await Future.delayed(const Duration(seconds: 2));
      expect(cache.get(['some'], {'kw': 'args'}), isNot(equals('item')));
    }, timeout: Timeout(Duration(seconds: 5)));

    test('put and get items with positional and keyword arguments', () {
      final cache = Cache.create();
      cache.put(
        'item',
        ['some', 'args'],
        {'and_a': 'keyword'},
        timeout: const Duration(seconds: 3),
      );

      expect(cache.get(['some', 'args'], {'and_a': 'keyword'}), equals('item'));
      expect(
        cache.get(['some', 'otherargs'], {'and_a': 'keyword'}),
        isNot(equals('item')),
      );
    }, timeout: Timeout(Duration(seconds: 5)));

    test('delete removes items from cache', () {
      final cache = Cache.create();
      cache.put(
        'item',
        ['some'],
        {'kw': 'args'},
        timeout: const Duration(seconds: 2),
      );

      // Check it's there
      expect(cache.get(['some'], {'kw': 'args'}), equals('item'));

      // Delete it
      cache.delete(['some'], {'kw': 'args'});
      expect(cache.get(['some'], {'kw': 'args'}), isNot(equals('item')));
    });

    test('clear removes all items from cache', () {
      final cache = Cache.create();
      cache.put(
        'item',
        ['some'],
        {'kw': 'args'},
        timeout: const Duration(seconds: 3),
      );

      // Check it's there
      expect(cache.get(['some'], {'kw': 'args'}), equals('item'));

      // Clear the cache
      cache.clear();
      expect(cache.get(['some'], {'kw': 'args'}), isNot(equals('item')));
    });

    test('works with typical UPnP service arguments', () {
      final cache = Cache.create();
      // Use simple key-value pairs instead of MapEntry since they can't be JSON encoded
      cache.put(
        'result',
        [
          'SetAVTransportURI',
          {
            'InstanceID': 1,
            'CurrentURI': 'URI2',
            'CurrentURIMetaData': 'abcd',
            'Unicode': 'μИⅠℂ☺ΔЄ💋',
          },
        ],
        {},
        timeout: const Duration(seconds: 3),
      );

      expect(
        cache.get([
          'SetAVTransportURI',
          {
            'InstanceID': 1,
            'CurrentURI': 'URI2',
            'CurrentURIMetaData': 'abcd',
            'Unicode': 'μИⅠℂ☺ΔЄ💋',
          },
        ], {}),
        equals('result'),
      );
    });

    test('cache can be disabled at runtime', () {
      final cache = Cache.create();
      expect(cache.enabled, isTrue);

      cache.enabled = false;
      cache.put('item', ['args'], {}, timeout: const Duration(seconds: 3));

      // Should not be cached when disabled
      expect(cache.get(['args'], {}), isNull);
      expect(cache.get(['some'], {'kw': 'args'}), isNull);

      // Re-enable for other tests
      cache.enabled = true;
    });
  });

  group('NullCache', () {
    test('put does nothing', () {
      final cache = NullCache();
      // Should not throw
      cache.put('item', ['arg1'], {'key': 'value'});
      expect(cache.get(['arg1'], {'key': 'value'}), isNull);
    });

    test('get always returns null', () {
      final cache = NullCache();
      expect(cache.get([], {}), isNull);
      expect(cache.get(['arg'], {'k': 'v'}), isNull);
    });

    test('delete does nothing', () {
      final cache = NullCache();
      // Should not throw
      cache.delete(['arg1'], {'key': 'value'});
    });

    test('clear does nothing', () {
      final cache = NullCache();
      // Should not throw
      cache.clear();
    });
  });
}
