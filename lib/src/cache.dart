/// This module contains the classes underlying SoCo's caching system.
library;

import 'dart:convert';

import 'config.dart' as config;

/// An abstract base class for the cache.
abstract class BaseCache {
  /// The internal cache storage
  final Map<String, dynamic> _cache = {};

  /// Whether the cache is enabled
  bool enabled = true;

  /// Put an item into the cache.
  void put(dynamic item, List<dynamic> args, Map<String, dynamic> kwargs);

  /// Get an item from the cache.
  dynamic get(List<dynamic> args, Map<String, dynamic> kwargs);

  /// Delete an item from the cache.
  void delete(List<dynamic> args, Map<String, dynamic> kwargs);

  /// Empty the whole cache.
  void clear();
}

/// A cache which does nothing.
///
/// Useful for debugging.
class NullCache extends BaseCache {
  /// Put an item into the cache (does nothing).
  @override
  void put(dynamic item, List<dynamic> args, Map<String, dynamic> kwargs) {
    // Do nothing
  }

  /// Get an item from the cache (always returns null).
  @override
  dynamic get(List<dynamic> args, Map<String, dynamic> kwargs) {
    return null;
  }

  /// Delete an item from the cache (does nothing).
  @override
  void delete(List<dynamic> args, Map<String, dynamic> kwargs) {
    // Do nothing
  }

  /// Empty the whole cache (does nothing).
  @override
  void clear() {
    // Do nothing
  }
}

/// A simple thread-safe cache for caching method return values.
///
/// The cache key is generated from the given [args] and [kwargs].
/// Items are expired from the cache after a given period of time.
///
/// Example:
/// ```dart
/// final cache = TimedCache();
/// cache.put("item", ['some'], {'kw': 'args'}, timeout: Duration(seconds: 3));
/// // Fetch the item again, by providing the same args and kwargs.
/// assert(cache.get(['some'], {'kw': 'args'}) == "item");
/// // Providing different args or kwargs will not return the item.
/// assert(cache.get(['some', 'otherargs'], {}) != "item");
/// // Waiting for less than the provided timeout does not cause the item to expire.
/// await Future.delayed(Duration(seconds: 2));
/// assert(cache.get(['some'], {'kw': 'args'}) == "item");
/// // But waiting for longer does.
/// await Future.delayed(Duration(seconds: 2));
/// assert(cache.get(['some'], {'kw': 'args'}) != "item");
/// ```
///
/// Warning:
///   At present, the cache can theoretically grow and grow, since entries
///   are not automatically purged, though in practice this is unlikely
///   since there are not that many different combinations of arguments in
///   the places where it is used in SoCo, so not that many different
///   cache entries will be created. If this becomes a problem,
///   use a timer to purge the cache, or rewrite this to use
///   LRU logic!
class TimedCache extends BaseCache {
  /// The default caching expiry interval.
  final Duration defaultTimeout;

  /// Creates a timed cache.
  ///
  /// Parameters:
  ///   - [defaultTimeout]: The default duration after which items will be expired.
  TimedCache({this.defaultTimeout = Duration.zero});

  /// Get an item from the cache for this combination of args and kwargs.
  ///
  /// Parameters:
  ///   - [args]: any arguments
  ///   - [kwargs]: any keyword arguments
  ///
  /// Returns:
  ///   The object which has been found in the cache, or `null` if
  ///   no unexpired item is found. This means that there is no point
  ///   storing an item in the cache if it is `null`.
  @override
  dynamic get(List<dynamic> args, Map<String, dynamic> kwargs) {
    if (!enabled) {
      return null;
    }

    // Look in the cache to see if there is an unexpired item. If there is
    // we can just return the cached result.
    final cacheKey = makeKey(args, kwargs);

    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey] as _CacheEntry;

      if (cached.expiryTime.isAfter(DateTime.now())) {
        return cached.item;
      } else {
        // An expired item is present - delete it
        _cache.remove(cacheKey);
      }
    }

    // Nothing found
    return null;
  }

  /// Put an item into the cache, for this combination of args and kwargs.
  ///
  /// Parameters:
  ///   - [item]: The item to cache
  ///   - [args]: any arguments
  ///   - [kwargs]: any keyword arguments. If `timeout` is specified as one
  ///     of the keyword arguments, the item will remain available
  ///     for retrieval for that duration. If `timeout` is
  ///     `null` or not specified, the [defaultTimeout] for this
  ///     cache will be used. Specify a `timeout` of Duration.zero (or ensure that
  ///     the [defaultTimeout] for this cache is Duration.zero) if this item is
  ///     not to be cached.
  @override
  void put(
    dynamic item,
    List<dynamic> args,
    Map<String, dynamic> kwargs, {
    Duration? timeout,
  }) {
    if (!enabled) {
      return;
    }

    // Use the provided timeout or fall back to default
    final effectiveTimeout = timeout ?? defaultTimeout;
    final cacheKey = makeKey(args, kwargs);

    // Store the item, along with the time at which it will expire
    _cache[cacheKey] = _CacheEntry(
      item: item,
      expiryTime: DateTime.now().add(effectiveTimeout),
    );
  }

  /// Delete an item from the cache for this combination of args and kwargs.
  @override
  void delete(List<dynamic> args, Map<String, dynamic> kwargs) {
    final cacheKey = makeKey(args, kwargs);
    _cache.remove(cacheKey);
  }

  /// Empty the whole cache.
  @override
  void clear() {
    _cache.clear();
  }

  /// Generate a unique, hashable, representation of the args and kwargs.
  ///
  /// Parameters:
  ///   - [args]: any arguments
  ///   - [kwargs]: any keyword arguments
  ///
  /// Returns:
  ///   The cache key as a string
  static String makeKey(List<dynamic> args, Map<String, dynamic> kwargs) {
    // Create a stable JSON representation
    // Sort the kwargs keys to ensure consistent ordering
    final sortedKwargs = Map.fromEntries(
      kwargs.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    final combined = {'args': args, 'kwargs': sortedKwargs};

    return jsonEncode(combined);
  }
}

/// Internal class to store cached items with their expiry time.
class _CacheEntry {
  final dynamic item;
  final DateTime expiryTime;

  _CacheEntry({required this.item, required this.expiryTime});
}

/// A factory class which returns an instance of a cache subclass.
///
/// A [TimedCache] is returned, unless [config.cacheEnabled] is `false`,
/// in which case a [NullCache] will be returned.
class Cache {
  /// Create a new cache instance based on configuration.
  ///
  /// Parameters:
  ///   - [defaultTimeout]: The default timeout for cached items
  ///
  /// Returns:
  ///   A [TimedCache] if caching is enabled, otherwise a [NullCache]
  static BaseCache create({Duration defaultTimeout = Duration.zero}) {
    if (config.cacheEnabled) {
      return TimedCache(defaultTimeout: defaultTimeout);
    } else {
      return NullCache();
    }
  }
}
