/// Base classes used by the events system.
///
/// This module provides the foundational classes for handling Sonos UPnP
/// events and subscriptions.
library;

import 'dart:async';
import 'dart:collection';

import 'package:logging/logging.dart';
import 'package:xml/xml.dart';

import 'config.dart' as config;
import 'data_structures.dart';
import 'data_structures_entry.dart';
import 'exceptions.dart';
import 'services.dart';
import 'utils.dart';

final _log = Logger('soco.events_base');

/// Cache for parsed event XML (LRU cache with max 128 entries)
final _eventXmlCache = LinkedHashMap<String, Map<String, dynamic>>();
const _maxCacheSize = 128;

/// Parse the body of a UPnP event.
///
/// Parameters:
///   - [xmlEvent]: String containing the body of the event
///
/// Returns:
///   A map with keys representing the evented variables. The relevant value
///   will usually be a string representation of the variable's value, but may
///   on occasion be:
///   - a Map (eg when the volume changes, the value will itself be a map
///     containing the volume for each channel:
///     `{'Volume': {'LF': '100', 'RF': '100', 'Master': '36'}}`)
///   - an instance of a [DidlObject] subclass (eg if it represents track
///     metadata)
///   - a [SoCoFault] (if a variable contains illegal metadata)
Map<String, dynamic> parseEventXml(String xmlEvent) {
  // Check cache first
  if (_eventXmlCache.containsKey(xmlEvent)) {
    // Move to end (LRU)
    final cached = _eventXmlCache.remove(xmlEvent)!;
    _eventXmlCache[xmlEvent] = cached;
    return Map.from(cached); // Return copy to prevent mutation
  }

  final result = <String, dynamic>{};
  final tree = XmlDocument.parse(xmlEvent);

  // Property values are just under the propertyset, which uses this namespace
  final properties = tree.rootElement.findElements(
    'property',
    namespace: 'urn:schemas-upnp-org:event-1-0',
  );

  for (final prop in properties) {
    for (final variable in prop.children.whereType<XmlElement>()) {
      // Special handling for a LastChange event. For details on
      // LastChange events, see
      // http://upnp.org/specs/av/UPnP-av-RenderingControl-v1-Service.pdf
      // and http://upnp.org/specs/av/UPnP-av-AVTransport-v1-Service.pdf
      if (variable.name.local == 'LastChange') {
        final lastChangeText = variable.innerText;
        if (lastChangeText.isEmpty) continue;

        final lastChangeTree = XmlDocument.parse(lastChangeText);

        // We assume there is only one InstanceID tag. This is true for
        // Sonos, as far as we know.
        // InstanceID can be in one of two namespaces, depending on
        // whether we are looking at an avTransport event, a
        // renderingControl event, or a Queue event
        // (there, it is named QueueID)
        XmlElement? instance = lastChangeTree.rootElement.findElements(
          'InstanceID',
          namespace: 'urn:schemas-upnp-org:metadata-1-0/AVT/',
        ).firstOrNull;

        instance ??= lastChangeTree.rootElement.findElements(
          'InstanceID',
          namespace: 'urn:schemas-upnp-org:metadata-1-0/RCS/',
        ).firstOrNull;

        instance ??= lastChangeTree.rootElement.findElements(
          'QueueID',
          namespace: 'urn:schemas-sonos-com:metadata-1-0/Queue/',
        ).firstOrNull;

        if (instance == null) continue;

        // Look at each variable within the LastChange event
        for (final lastChangeVar in instance.children.whereType<XmlElement>()) {
          var tag = lastChangeVar.name.local;

          // Un-camel case it
          tag = camelToUnderscore(tag);

          // Now extract the relevant value for the variable.
          // The UPnP specs suggest that the value of any variable
          // evented via a LastChange Event will be in the 'val'
          // attribute, but audio related variables may also have a
          // 'channel' attribute. In addition, it seems that Sonos
          // sometimes uses a text value instead: see
          // http://forums.sonos.com/showthread.php?t=34663
          var value = lastChangeVar.getAttribute('val') ?? lastChangeVar.innerText;

          if (value.isEmpty) continue;

          // If DIDL metadata is returned, convert it to a music
          // library data structure
          if (value.startsWith('<DIDL-Lite')) {
            // Wrap any parsing exception in a SoCoFault, so the
            // user can handle it
            try {
              value = fromDidlString(value)[0];
            } on SoCoException catch (originalException) {
              _log.fine(
                'Event contains illegal metadata for \'$tag\'.\n'
                'Error message: \'$originalException\'\n'
                'The result will be a SoCoFault.',
              );
              final eventParseException = EventParseException(
                tag: tag,
                metadata: value,
                cause: originalException,
              );
              value = SoCoFault(eventParseException) as dynamic;
            }
          }

          final channel = lastChangeVar.getAttribute('channel');
          if (channel != null) {
            result[tag] ??= <String, dynamic>{};
            (result[tag] as Map<String, dynamic>)[channel] = value;
          } else {
            result[tag] = value;
          }
        }
      } else {
        result[camelToUnderscore(variable.name.local)] = variable.innerText;
      }
    }
  }

  // Add to cache (LRU eviction)
  _eventXmlCache[xmlEvent] = result;
  if (_eventXmlCache.length > _maxCacheSize) {
    _eventXmlCache.remove(_eventXmlCache.keys.first);
  }

  return result;
}

/// A read-only object representing a received event.
///
/// The values of the evented variables can be accessed via the [variables]
/// map, or as properties on the instance itself using the [] operator.
///
/// Example:
/// ```dart
/// print(event.variables['transport_state']);  // 'STOPPED'
/// print(event['transport_state']);  // 'STOPPED'
/// ```
class Event {
  /// The subscription ID
  final String sid;

  /// The event sequence number for that subscription
  final String seq;

  /// The time that the event was received (Unix timestamp in seconds)
  final double timestamp;

  /// The service which is subscribed to the event
  final Service service;

  /// Contains the {names: values} of the evented variables
  final Map<String, dynamic> variables;

  /// Creates an Event.
  ///
  /// Parameters:
  ///   - [sid]: the subscription id
  ///   - [seq]: the event sequence number for that subscription
  ///   - [timestamp]: the time that the event was received
  ///   - [service]: the service which is subscribed to the event
  ///   - [variables]: contains the {names: values} of the evented variables
  Event(
    this.sid,
    this.seq,
    this.service,
    this.timestamp, {
    Map<String, dynamic>? variables,
  }) : variables = variables ?? {};

  /// Access event variables by name.
  ///
  /// Not all attributes are returned with each event. Returns null if the
  /// variable was not returned in the event.
  dynamic operator [](String name) => variables[name];

  @override
  String toString() => 'Event(sid: $sid, seq: $seq, service: ${service.serviceId})';
}

/// Base class for handling NOTIFY requests from Sonos devices.
abstract class EventNotifyHandlerBase {
  /// The subscriptions map for looking up subscriptions by sid
  SubscriptionsMap get subscriptionsMap;

  /// Handle a NOTIFY request by building an [Event] object and
  /// sending it to the relevant Subscription object.
  ///
  /// A NOTIFY request will be sent by a Sonos device when a state
  /// variable changes. See the UPnP Spec §4.3 for details.
  ///
  /// Parameters:
  ///   - [headers]: A map of received headers
  ///   - [content]: A string of received content
  void handleNotification(Map<String, String> headers, String content) {
    final timestamp = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final seq = headers['seq'] ?? headers['SEQ'] ?? '';
    final sid = headers['sid'] ?? headers['SID'] ?? '';

    // Find the relevant service from the sid
    final subscription = subscriptionsMap.getSubscription(sid);

    // It might have been removed by another isolate/thread
    if (subscription != null) {
      final service = subscription.service;
      logEvent(seq, service.serviceId, timestamp);
      _log.fine('Event content: $content');
      final variables = parseEventXml(content);

      // Build the Event object
      final event = Event(sid, seq, service, timestamp, variables: variables);

      // Pass the event details on to the service so it can update its cache
      service.updateCacheOnEvent(event);

      // Pass the event on for handling
      subscription.sendEvent(event);
    } else {
      _log.info('No service registered for $sid');
    }
  }

  /// Log an event reception.
  ///
  /// This method should be overridden in subclasses to provide specific
  /// logging behavior.
  void logEvent(String seq, String serviceId, double timestamp);
}

/// Base class for the Event Listener.
///
/// The Event Listener runs an HTTP server which is an endpoint for NOTIFY
/// requests from Sonos devices.
abstract class EventListenerBase {
  /// Indicates whether the server is currently running
  bool isRunning = false;

  /// The address (ip, port) on which the server is configured to listen
  ({String ip, int port})? address;

  /// Port on which to listen
  int requestedPortNumber = config.eventListenerPort;

  /// Start the event listener listening on the local machine.
  ///
  /// Parameters:
  ///   - [anyZone]: Any Sonos device on the network. It does not matter which
  ///     device. It is used only to find a local IP address reachable by the
  ///     Sonos net.
  Future<void> start(dynamic anyZone);

  /// Stop the Event Listener.
  Future<void> stop();

  /// Start listening on the given IP address.
  ///
  /// This method should be overridden in subclasses.
  ///
  /// Parameters:
  ///   - [ipAddress]: The local network interface on which the server should
  ///     start listening
  ///
  /// Returns:
  ///   The port on which the server is listening
  Future<int?> listen(String ipAddress);

  /// Stop listening.
  ///
  /// This method should be overridden in subclasses.
  Future<void> stopListening();
}

/// Base class for Subscription objects.
///
/// A Subscription represents a subscription to events from a Sonos service.
abstract class SubscriptionBase {
  /// The SoCo Service to which the subscription is made
  final Service service;

  /// A unique ID for this subscription
  String? sid;

  /// The amount of time in seconds until the subscription expires
  int? timeout;

  /// An indication of whether the subscription is subscribed
  bool isSubscribed = false;

  /// The StreamController for events
  final StreamController<Event> _eventsController;

  /// The stream of events
  late final Stream<Event> events;

  /// The period (seconds) for which the subscription is requested
  int? requestedTimeout;

  /// An optional function to be called if an exception occurs upon autorenewal
  void Function(Object)? autoRenewFail;

  /// A flag to make sure that an unsubscribed instance is not resubscribed
  bool hasBeenUnsubscribed = false;

  /// The time when the subscription was made (Unix timestamp in seconds)
  double? timestamp;

  /// Timer for auto-renewal
  Timer? _autoRenewTimer;

  /// Event listener reference
  EventListenerBase get eventListener;

  /// Subscriptions map reference
  SubscriptionsMap get subscriptionsMap;

  /// Creates a Subscription.
  ///
  /// Parameters:
  ///   - [service]: The SoCo Service to which the subscription should be made
  ///   - [broadcast]: If true, the events stream will be a broadcast stream
  SubscriptionBase(this.service, {bool broadcast = true})
      : _eventsController = broadcast
            ? StreamController<Event>.broadcast()
            : StreamController<Event>() {
    events = _eventsController.stream;
  }

  /// Subscribe to the service.
  ///
  /// If [requestedTimeout] is provided, a subscription valid for that number
  /// of seconds will be requested, but not guaranteed. Check [timeout] on
  /// return to find out what period of validity is actually allocated.
  ///
  /// Note:
  ///   SoCo will try to unsubscribe any subscriptions which are still
  ///   subscribed on program termination, but it is good practice for you to
  ///   clean up by making sure that you call [unsubscribe] yourself.
  ///
  /// Parameters:
  ///   - [requestedTimeout]: The timeout to be requested
  ///   - [autoRenew]: If true, renew the subscription automatically shortly
  ///     before timeout. Default false.
  Future<void> subscribe({int? requestedTimeout, bool autoRenew = false});

  /// Renew the event subscription.
  ///
  /// You should not try to renew a subscription which has been unsubscribed,
  /// or once it has expired.
  ///
  /// Parameters:
  ///   - [requestedTimeout]: The period for which a renewal request should be
  ///     made. If null (the default), use the timeout requested on subscription.
  ///   - [isAutorenew]: Whether this is an autorenewal
  Future<void> renew({int? requestedTimeout, bool isAutorenew = false});

  /// Unsubscribe from the service's events.
  ///
  /// Once unsubscribed, a Subscription instance should not be reused.
  Future<void> unsubscribe();

  /// Send an Event to the events stream.
  ///
  /// Parameters:
  ///   - [event]: The Event to send to the stream
  void sendEvent(Event event) {
    if (!_eventsController.isClosed) {
      _eventsController.add(event);
    }
  }

  /// The amount of time left until the subscription expires (seconds).
  ///
  /// If the subscription is unsubscribed (or not yet subscribed), timeLeft is 0.
  int get timeLeft {
    if (timestamp == null || timeout == null) {
      return 0;
    }
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final left = timeout! - (now - timestamp!);
    return left > 0 ? left.round() : 0;
  }

  /// Start auto-renewal.
  ///
  /// Parameters:
  ///   - [interval]: The interval (in seconds) before renewal
  void autoRenewStart(double interval) {
    _autoRenewTimer?.cancel();
    _autoRenewTimer = Timer(Duration(seconds: interval.round()), () async {
      try {
        await renew(isAutorenew: true);
      } catch (e) {
        _log.warning('Auto-renewal failed: $e');
        if (autoRenewFail != null) {
          autoRenewFail!(e);
        }
      }
    });
  }

  /// Cancel auto-renewal.
  void autoRenewCancel() {
    _autoRenewTimer?.cancel();
    _autoRenewTimer = null;
  }

  /// Cancel the subscription and clean up resources.
  Future<void> cancelSubscription({String? msg}) async {
    // Unregister subscription
    subscriptionsMap.unregister(this);

    // Stop the event listener, if there are no other subscriptions
    if (subscriptionsMap.count == 0) {
      await eventListener.stop();
    }

    // No need to do any more if this flag has been set to true
    if (hasBeenUnsubscribed) {
      return;
    }

    isSubscribed = false;
    hasBeenUnsubscribed = true;
    timestamp = null;

    // Cancel any auto renew
    autoRenewCancel();

    // Close the events stream
    await _eventsController.close();

    if (msg != null) {
      _log.fine(msg);
    }
  }

  /// Dispose of this subscription and clean up resources.
  Future<void> dispose() async {
    await unsubscribe();
  }
}

/// Maintains a mapping of sids to Subscription instances with thread safety.
class SubscriptionsMap {
  /// Thread safe mapping. Used to store a mapping of sid to subscription
  final Map<String, SubscriptionBase> _subscriptions = {};

  /// Register a subscription by updating local mapping of sid to subscription.
  ///
  /// Parameters:
  ///   - [subscription]: the subscription to be registered
  void register(SubscriptionBase subscription) {
    if (subscription.sid != null) {
      _subscriptions[subscription.sid!] = subscription;
    }
  }

  /// Unregister a subscription by updating local mapping of sid to subscription.
  ///
  /// Parameters:
  ///   - [subscription]: the subscription to be unregistered
  void unregister(SubscriptionBase subscription) {
    if (subscription.sid != null) {
      _subscriptions.remove(subscription.sid);
    }
  }

  /// Look up a subscription from a sid.
  ///
  /// Parameters:
  ///   - [sid]: The sid from which to look up the subscription
  ///
  /// Returns:
  ///   The subscription relating to that sid, or null if not found
  SubscriptionBase? getSubscription(String sid) {
    return _subscriptions[sid];
  }

  /// The number of active subscriptions.
  int get count => _subscriptions.length;
}

/// Find the listen IP address.
///
/// Parameters:
///   - [ipAddress]: The IP address of a Sonos device
///
/// Returns:
///   The local IP address to use for the event listener
String? getListenIp(String ipAddress) {
  if (config.eventListenerIp != null) {
    return config.eventListenerIp;
  }

  // In Dart, we don't have a direct equivalent to Python's socket.connect()
  // trick to find the local IP. We'll need to use platform-specific code
  // or just return the configured IP.
  // For now, return null to indicate auto-detection is needed at a higher level
  return null;
}
