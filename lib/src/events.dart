/// Classes to handle Sonos UPnP Events and Subscriptions.
///
/// Example:
/// ```dart
/// import 'package:soco/soco.dart';
///
/// // Discover a device and get the group coordinator
/// final devices = await discover();
/// if (devices != null && devices.isNotEmpty) {
///   final device = devices.first;
///   final coordinator = await device.group?.coordinator ?? device;
///
///   print('Subscribing to ${await coordinator.playerName}');
///
///   // Subscribe to rendering control events (volume, mute, etc.)
///   final sub = await coordinator.renderingControl.subscribe();
///
///   // Subscribe to transport events (playback state, track info, etc.)
///   final sub2 = await coordinator.avTransport.subscribe();
///
///   // Listen to events
///   sub.events.listen((event) {
///     print('Rendering Control event: ${event.variables}');
///   });
///
///   sub2.events.listen((event) {
///     print('AV Transport event: ${event.variables}');
///   });
///
///   // Keep the program running
///   await Future.delayed(Duration(seconds: 60));
///
///   // Clean up
///   await sub.unsubscribe();
///   await sub2.unsubscribe();
///   await eventListener.stop();
/// }
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'config.dart' as config;
import 'core.dart';
import 'events_base.dart';
import 'exceptions.dart';

/// Export Event class for convenience
export 'events_base.dart' show Event;
export 'exceptions.dart' show EventParseException, SoCoFault;

final _log = Logger('soco.events');

// Private module-level instances
final _globalEventListener = EventListener();
final _globalSubscriptionsMap = SubscriptionsMap();

/// The global event listener instance
EventListener get eventListener => _globalEventListener;

/// The global subscriptions map instance
SubscriptionsMap get subscriptionsMap => _globalSubscriptionsMap;

/// Handles HTTP NOTIFY verbs sent to the listener server.
class EventNotifyHandler extends EventNotifyHandlerBase {
  @override
  SubscriptionsMap get subscriptionsMap => _globalSubscriptionsMap;

  @override
  void logEvent(String seq, String serviceId, double timestamp) {
    _log.fine('Event $seq received for $serviceId service at $timestamp');
  }

  /// Handle an incoming HTTP request.
  ///
  /// Parameters:
  ///   - [request]: The HTTP request to handle
  Future<void> handleRequest(HttpRequest request) async {
    if (request.method == 'NOTIFY') {
      // Read the request body
      final bytes = await request.toList();
      final content = utf8.decode(bytes.expand((x) => x).toList());

      // Convert headers to map (case-insensitive)
      final headers = <String, String>{};
      request.headers.forEach((name, values) {
        headers[name.toLowerCase()] = values.first;
      });

      // Handle the notification
      handleNotification(headers, content);

      // Send response
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
    } else {
      // Unsupported method
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
    }
  }
}

/// The Event Listener.
///
/// Runs an HTTP server which is an endpoint for NOTIFY requests from Sonos
/// devices.
class EventListener extends EventListenerBase {
  HttpServer? _server;
  final EventNotifyHandler _handler = EventNotifyHandler();

  @override
  Future<void> start(dynamic anyZone) async {
    if (isRunning) {
      return;
    }

    // Find our local network IP address which is accessible to the Sonos net
    final sonoIpAddress = anyZone is SoCo
        ? anyZone.ipAddress
        : anyZone.toString();

    // Use configured IP address if there is one, else detect automatically
    var ipAddress = config.eventListenerIp;
    if (ipAddress == null) {
      // Try to find the local IP by connecting to the Sonos device
      try {
        final socket = await Socket.connect(
          sonoIpAddress,
          1400,
          timeout: const Duration(seconds: 5),
        );
        ipAddress = socket.address.address;
        await socket.close();
      } catch (e) {
        _log.warning('Could not determine local IP address: $e');
        // Fall back to any interface
        ipAddress = InternetAddress.anyIPv4.address;
      }
    }

    final port = await listen(ipAddress);
    if (port == null) {
      _log.severe('Could not start Event Listener');
      return;
    }

    address = (ip: ipAddress, port: port);
    isRunning = true;
    _log.info('Event Listener started on $ipAddress:$port');
  }

  @override
  Future<int?> listen(String ipAddress) async {
    // Try to bind to the requested port, or find an available one
    for (
      var portNumber = requestedPortNumber;
      portNumber < requestedPortNumber + 100;
      portNumber++
    ) {
      try {
        _server = await HttpServer.bind(ipAddress, portNumber);

        // Handle incoming requests
        _server!.listen((request) async {
          try {
            await _handler.handleRequest(request);
          } catch (e, stackTrace) {
            _log.warning('Error handling request: $e\n$stackTrace');
            request.response.statusCode = HttpStatus.internalServerError;
            await request.response.close();
          }
        });

        _log.fine('Event listener listening on $ipAddress:$portNumber');
        return portNumber;
      } on SocketException catch (e) {
        if (e.osError?.errorCode == 48 || // Address already in use (macOS)
            e.osError?.errorCode == 98) {
          // Address already in use (Linux)
          _log.fine('Port $portNumber already in use, trying next port');
          continue;
        }
        _log.warning('Failed to bind to $ipAddress:$portNumber: $e');
        return null;
      }
    }

    _log.severe(
      'Could not find an available port in range '
      '$requestedPortNumber-${requestedPortNumber + 100}',
    );
    return null;
  }

  @override
  Future<void> stop() async {
    if (!isRunning) {
      return;
    }

    await stopListening();
    isRunning = false;
    address = null;
    _log.info('Event Listener stopped');
  }

  @override
  Future<void> stopListening() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
    }
  }
}

/// A Subscription to a Sonos UPnP service.
///
/// Represents a subscription to events from a Sonos service. Events are
/// delivered via a Dart Stream.
class Subscription extends SubscriptionBase {
  @override
  EventListenerBase get eventListener => _globalEventListener;

  @override
  SubscriptionsMap get subscriptionsMap => _globalSubscriptionsMap;

  /// Creates a Subscription.
  ///
  /// Parameters:
  ///   - [service]: The SoCo Service to which the subscription should be made
  ///   - [broadcast]: If true, the events stream will be a broadcast stream
  ///     (allowing multiple listeners). Default is true.
  Subscription(super.service, {super.broadcast = true});

  @override
  Future<void> subscribe({
    int? requestedTimeout,
    bool autoRenew = false,
  }) async {
    this.requestedTimeout = requestedTimeout;

    if (isSubscribed) {
      throw SoCoException(
        'Cannot subscribe Subscription instance more than once. Use renew instead',
      );
    }

    if (hasBeenUnsubscribed) {
      throw SoCoException(
        'Cannot resubscribe Subscription instance once unsubscribed',
      );
    }

    // The Event Listener must be running, so start it if not
    if (!eventListener.isRunning) {
      await eventListener.start(service.soco);
    }

    // An event subscription looks like this:
    // SUBSCRIBE publisher path HTTP/1.1
    // HOST: publisher host:publisher port
    // CALLBACK: <delivery URL>
    // NT: upnp:event
    // TIMEOUT: Second-requested subscription duration (optional)

    final addr = eventListener.address!;
    var ipAddress = addr.ip;
    final port = addr.port;

    if (config.eventAdvertiseIp != null) {
      ipAddress = config.eventAdvertiseIp!;
    }

    final headers = <String, String>{
      'CALLBACK': '<http://$ipAddress:$port>',
      'NT': 'upnp:event',
    };

    if (requestedTimeout != null) {
      headers['TIMEOUT'] = 'Second-$requestedTimeout';
    }

    await _request(
      'SUBSCRIBE',
      service.baseUrl + service.eventSubscriptionUrl,
      headers,
      _onSubscribeSuccess,
      autoRenew: autoRenew,
    );
  }

  void _onSubscribeSuccess(
    Map<String, String> headers, {
    bool autoRenew = false,
  }) {
    sid = headers['sid'];
    final timeoutStr = headers['timeout'] ?? '';

    // According to the spec, timeout can be "infinite" or "second-123"
    // where 123 is a number of seconds. Sonos uses "Second-123"
    // (with a capital letter)
    if (timeoutStr.toLowerCase() == 'infinite') {
      timeout = null;
    } else {
      final match = RegExp(
        r'second-(\d+)',
        caseSensitive: false,
      ).firstMatch(timeoutStr);
      if (match != null) {
        timeout = int.parse(match.group(1)!);
      }
    }

    timestamp = DateTime.now().millisecondsSinceEpoch / 1000.0;
    isSubscribed = true;

    _log.fine(
      'Subscribed to ${service.baseUrl}${service.eventSubscriptionUrl}, sid: $sid',
    );

    // Register the subscription so it can be looked up by sid
    subscriptionsMap.register(this);

    // Set up auto_renew
    if (autoRenew && timeout != null) {
      // Auto renew just before expiry, say at 85% of timeout seconds
      final interval = timeout! * 0.85;
      autoRenewStart(interval);
    }
  }

  @override
  Future<void> renew({int? requestedTimeout, bool isAutorenew = false}) async {
    final logMsg = isAutorenew
        ? 'Autorenewing subscription $sid'
        : 'Renewing subscription $sid';
    _log.fine(logMsg);

    if (hasBeenUnsubscribed) {
      throw SoCoException('Cannot renew subscription once unsubscribed');
    }

    if (!isSubscribed) {
      throw SoCoException('Cannot renew subscription before subscribing');
    }

    if (timeLeft == 0) {
      throw SoCoException('Cannot renew subscription after expiry');
    }

    // SUBSCRIBE publisher path HTTP/1.1
    // HOST: publisher host:publisher port
    // SID: uuid:subscription UUID
    // TIMEOUT: Second-requested subscription duration (optional)
    final headers = <String, String>{'SID': sid!};

    requestedTimeout ??= this.requestedTimeout;
    if (requestedTimeout != null) {
      headers['TIMEOUT'] = 'Second-$requestedTimeout';
    }

    await _request(
      'SUBSCRIBE',
      service.baseUrl + service.eventSubscriptionUrl,
      headers,
      _onRenewSuccess,
    );
  }

  void _onRenewSuccess(Map<String, String> headers) {
    final timeoutStr = headers['timeout'] ?? '';

    // According to the spec, timeout can be "infinite" or "second-123"
    // where 123 is a number of seconds. Sonos uses "Second-123"
    // (with a capital letter)
    if (timeoutStr.toLowerCase() == 'infinite') {
      timeout = null;
    } else {
      final match = RegExp(
        r'second-(\d+)',
        caseSensitive: false,
      ).firstMatch(timeoutStr);
      if (match != null) {
        timeout = int.parse(match.group(1)!);
      }
    }

    timestamp = DateTime.now().millisecondsSinceEpoch / 1000.0;
    isSubscribed = true;

    _log.fine(
      'Renewed subscription to ${service.baseUrl}${service.eventSubscriptionUrl}, sid: $sid',
    );
  }

  @override
  Future<void> unsubscribe() async {
    // Trying to unsubscribe if already unsubscribed, or not yet
    // subscribed, fails silently
    if (hasBeenUnsubscribed || !isSubscribed) {
      return;
    }

    // If the subscription has timed out, an attempt to
    // unsubscribe from it will fail silently
    if (timeLeft == 0) {
      return;
    }

    // Send an unsubscribe request like this:
    // UNSUBSCRIBE publisher path HTTP/1.1
    // HOST: publisher host:publisher port
    // SID: uuid:subscription UUID
    final headers = <String, String>{'SID': sid!};

    try {
      await _request(
        'UNSUBSCRIBE',
        service.baseUrl + service.eventSubscriptionUrl,
        headers,
        _onUnsubscribeSuccess,
      );
    } finally {
      await cancelSubscription(msg: 'Unsubscribed from $sid');
    }
  }

  void _onUnsubscribeSuccess(Map<String, String> headers) {
    _log.fine(
      'Unsubscribed from ${service.baseUrl}${service.eventSubscriptionUrl}, sid: $sid',
    );
  }

  /// Send an HTTP request for subscription operations.
  ///
  /// Parameters:
  ///   - [method]: 'SUBSCRIBE' or 'UNSUBSCRIBE'
  ///   - [url]: The full endpoint to which the request is being sent
  ///   - [headers]: A map of headers
  ///   - [onSuccess]: A function to be called if the request succeeds
  ///   - [autoRenew]: Whether to enable auto-renewal (only for SUBSCRIBE)
  Future<void> _request(
    String method,
    String url,
    Map<String, String> headers,
    void Function(Map<String, String>) onSuccess, {
    bool autoRenew = false,
  }) async {
    final request = http.Request(method, Uri.parse(url));
    request.headers.addAll(headers);

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Convert response headers to case-insensitive map
        final responseHeaders = <String, String>{};
        response.headers.forEach((key, value) {
          responseHeaders[key.toLowerCase()] = value;
        });

        if (method == 'SUBSCRIBE' && autoRenew) {
          _onSubscribeSuccess(responseHeaders, autoRenew: true);
        } else {
          onSuccess(responseHeaders);
        }
      } else {
        _log.warning(
          '$method request failed with status ${response.statusCode}: ${response.body}',
        );
        throw SoCoException(
          '$method request failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      _log.warning('Error during $method request: $e');
      rethrow;
    }
  }
}
