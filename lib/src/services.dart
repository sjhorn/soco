/// Classes representing Sonos UPnP services.
///
/// Example:
/// ```dart
/// import 'package:soco/soco.dart';
///
/// final device = SoCo('192.168.1.102');
/// final rc = RenderingControl(device);
/// print(await rc.getMute([
///   MapEntry('InstanceID', 0),
///   MapEntry('Channel', 'Master')
/// ]));
/// // Output: {'CurrentMute': '0'}
/// ```
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:xml/xml.dart' as xml;

import 'cache.dart';
import 'config.dart' as config;
import 'exceptions.dart';
import 'utils.dart';
import 'xml.dart' as soco_xml;

final _log = Logger('soco.services');

/// A UPnP Action and its arguments.
class Action {
  /// The name of the action
  final String name;

  /// Input arguments
  final List<Argument> inArgs;

  /// Output arguments
  final List<Argument> outArgs;

  /// Creates an action.
  const Action({
    required this.name,
    required this.inArgs,
    required this.outArgs,
  });

  @override
  String toString() {
    final args = inArgs.map((arg) => arg.toString()).join(', ');
    final returns = outArgs.map((arg) => arg.toString()).join(', ');
    return '$name($args) -> {$returns}';
  }
}

/// A UPnP Argument and its type.
class Argument {
  /// The name of the argument
  final String name;

  /// The variable type
  final Vartype vartype;

  /// Creates an argument.
  const Argument({required this.name, required this.vartype});

  @override
  String toString() {
    var argument = name;
    if (vartype.defaultValue != null) {
      argument = '$name=${vartype.defaultValue}';
    }
    return '$argument: ${vartype.toString()}';
  }
}

/// An argument type with default value and range.
class Vartype {
  /// The data type
  final String datatype;

  /// Default value
  final String? defaultValue;

  /// List of allowed values
  final List<String>? allowedValues;

  /// Range of allowed values [min, max]
  final List<int>? range;

  /// Creates a variable type.
  const Vartype({
    required this.datatype,
    this.defaultValue,
    this.allowedValues,
    this.range,
  });

  @override
  String toString() {
    if (allowedValues != null) {
      return '[${allowedValues!.join(', ')}]';
    }
    if (range != null) {
      return '[${range![0]}..${range![1]}]';
    }
    return datatype;
  }
}

/// A class representing a UPnP service.
///
/// This is the base class for all Sonos Service classes. This class has a
/// dynamic method dispatcher. Calls to methods which are not explicitly
/// defined here are dispatched automatically to the service action with the
/// same name.
class Service {
  /// SOAP body template
  static const soapBodyTemplate =
      '<?xml version="1.0"?>'
      '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"'
      ' s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
      '<s:Body>'
      '<u:{action} xmlns:u="urn:schemas-upnp-org:service:{serviceType}:{version}">'
      '{arguments}'
      '</u:{action}>'
      '</s:Body>'
      '</s:Envelope>';

  /// The SoCo instance to which UPnP Actions are sent
  final dynamic soco;

  /// The UPnP service type (can be overridden by subclasses)
  late String serviceType;

  /// The UPnP service version (can be overridden by subclasses)
  late int version;

  /// The service ID (can be overridden by subclasses)
  late String serviceId;

  /// The base URL for sending UPnP Actions
  late final String baseUrl;

  /// The UPnP Control URL (can be overridden by subclasses)
  late String controlUrl;

  /// The service control protocol description URL (can be overridden by subclasses)
  late String scpdUrl;

  /// The service eventing subscription URL (can be overridden by subclasses)
  late String eventSubscriptionUrl;

  /// A cache for storing the result of network calls
  late final BaseCache cache;

  /// Optional HTTP client for testing. If null, uses http.post directly.
  http.Client? httpClient;

  /// Caching variable for actions
  List<Action>? _actions;

  /// Caching variable for event vars
  Map<String, dynamic>? _eventVars;

  /// UPnP error codes
  final Map<int, String> upnpErrors = {
    400: 'Bad Request',
    401: 'Invalid Action',
    402: 'Invalid Args',
    404: 'Invalid Var',
    412: 'Precondition Failed',
    501: 'Action Failed',
    600: 'Argument Value Invalid',
    601: 'Argument Value Out of Range',
    602: 'Optional Action Not Implemented',
    603: 'Out Of Memory',
    604: 'Human Intervention Required',
    605: 'String Argument Too Long',
    606: 'Action Not Authorized',
    607: 'Signature Failure',
    608: 'Signature Missing',
    609: 'Not Encrypted',
    610: 'Invalid Sequence',
    611: 'Invalid Control URL',
    612: 'No Such Session',
  };

  /// Default arguments
  Map<String, dynamic> defaultArgs = {};

  /// Additional headers
  Map<String, String> additionalHeaders = {};

  /// Creates a service.
  ///
  /// Parameters:
  ///   - [soco]: A SoCo instance to which the UPnP Actions will be sent
  Service(this.soco) {
    serviceType = runtimeType.toString();
    version = 1;
    serviceId = serviceType;
    baseUrl = 'http://${soco.ipAddress}:1400';
    controlUrl = '/$serviceType/Control';
    scpdUrl = '/xml/$serviceType$version.xml';
    eventSubscriptionUrl = '/$serviceType/Event';
    cache = Cache.create(defaultTimeout: Duration.zero);
  }

  /// Wrap a list of entries in XML ready to pass into a SOAP request.
  ///
  /// Parameters:
  ///   - [args]: a list of (name, value) entries specifying the name of each
  ///     argument and its value. The value can be a string or something with
  ///     a string representation. The arguments are escaped and wrapped in
  ///     `<name>` and `<value>` tags.
  ///
  /// Returns:
  ///   XML string with wrapped arguments
  ///
  /// Example:
  /// ```dart
  /// final s = Service(device);
  /// print(s.wrapArguments([
  ///   MapEntry('InstanceID', 0),
  ///   MapEntry('Speed', 1)
  /// ]));
  /// // Output: '&lt;InstanceID&gt;0&lt;/InstanceID&gt;&lt;Speed&gt;1&lt;/Speed&gt;'
  /// ```
  static String wrapArguments(List<MapEntry<String, dynamic>> args) {
    final tags = <String>[];
    for (final arg in args) {
      final name = arg.key;
      final value = arg.value.toString();
      // Escape XML special characters
      final escapedValue = _escapeXml(value);
      tags.add('<$name>$escapedValue</$name>');
    }
    return tags.join();
  }

  /// Extract arguments and their values from a SOAP response.
  ///
  /// Parameters:
  ///   - [xmlResponse]: SOAP/XML response text
  ///
  /// Returns:
  ///   A map of {argument_name: value} items
  static Map<String, String> unwrapArguments(String xmlResponse) {
    xml.XmlDocument tree;
    try {
      tree = xml.XmlDocument.parse(xmlResponse);
    } on xml.XmlParserException {
      // Try to filter illegal xml chars, in case that is the reason for
      // the parse error
      final filtered = soco_xml.filterIllegalXmlChars(xmlResponse);
      tree = xml.XmlDocument.parse(filtered);
    }

    // Get the first child of the <Body> tag which will be
    // <{actionNameResponse}>. Turn the children of this into a
    // {tagname, content} dict. XML unescaping is carried out for us by xml package.
    final body = tree
        .findAllElements(
          'Body',
          namespace: 'http://schemas.xmlsoap.org/soap/envelope/',
        )
        .first;
    final actionResponse = body.children.whereType<xml.XmlElement>().first;

    return {
      for (final element in actionResponse.children.whereType<xml.XmlElement>())
        element.name.local: element.innerText,
    };
  }

  /// Compose the argument list from an argument dictionary, with respect
  /// for default values.
  ///
  /// Parameters:
  ///   - [actionName]: The name of the action to be performed
  ///   - [inArgdict]: Arguments as a map, e.g.
  ///     `{'InstanceID': 0, 'Speed': 1}`. The values can be a string or
  ///     something with a string representation.
  ///
  /// Returns:
  ///   A list of (name, value) entries
  ///
  /// Throws:
  ///   - [ArgumentError] if this service does not support the action
  ///   - [ArgumentError] if the argument lists do not match the action signature
  Future<List<MapEntry<String, dynamic>>> composeArgs(
    String actionName,
    Map<String, dynamic> inArgdict,
  ) async {
    // Find the action
    final actionsList = await actions;
    final action = actionsList.where((a) => a.name == actionName).firstOrNull;

    if (action == null) {
      throw ArgumentError('Unknown Action: $actionName');
    }

    // Check for given argument names which do not occur in the expected
    // argument list
    final expectedArgNames = {for (final arg in action.inArgs) arg.name};
    final unexpectedArgs = inArgdict.keys.toSet().difference(expectedArgNames);

    if (unexpectedArgs.isNotEmpty) {
      throw ArgumentError(
        "Unexpected argument '${unexpectedArgs.first}'. "
        'Method signature: ${action.toString()}',
      );
    }

    // List the (name, value) entries for each argument in the argument list
    final composed = <MapEntry<String, dynamic>>[];
    for (final argument in action.inArgs) {
      final name = argument.name;

      if (inArgdict.containsKey(name)) {
        composed.add(MapEntry(name, inArgdict[name]));
        continue;
      }

      if (defaultArgs.containsKey(name)) {
        composed.add(MapEntry(name, defaultArgs[name]));
        continue;
      }

      if (argument.vartype.defaultValue != null) {
        composed.add(MapEntry(name, argument.vartype.defaultValue));
        continue;
      }

      throw ArgumentError(
        "Missing argument '$name'. Method signature: ${action.toString()}",
      );
    }

    return composed;
  }

  /// Build a SOAP command.
  ///
  /// Parameters:
  ///   - [action]: The name of the action to be performed
  ///   - [args]: Arguments as a list of (name, value) entries
  ///
  /// Returns:
  ///   A tuple of (headers, body) ready for sending
  (Map<String, String>, String) buildCommand(
    String action, [
    List<MapEntry<String, dynamic>> args = const [],
  ]) {
    // Get the arguments wrapped in XML tags
    final arguments = wrapArguments(args);

    // Build the SOAP body
    final body = soapBodyTemplate
        .replaceAll('{action}', action)
        .replaceAll('{serviceType}', serviceType)
        .replaceAll('{version}', version.toString())
        .replaceAll('{arguments}', arguments);

    // Build the headers
    final headers = <String, String>{
      'Content-Type': 'text/xml; charset="utf-8"',
      'SOAPACTION':
          '"urn:schemas-upnp-org:service:$serviceType:$version#$action"',
    };

    // Add any additional headers
    headers.addAll(additionalHeaders);

    return (headers, body);
  }

  /// Send a command to the Sonos device.
  ///
  /// Parameters:
  ///   - [action]: The name of the action to be sent
  ///   - [args]: Arguments as a list of (name, value) entries (optional)
  ///   - [useCache]: Whether to use the cache. Default uses class cache settings.
  ///   - [cacheTimeout]: Timeout for cache entry (optional)
  ///
  /// Returns:
  ///   A map of return values
  Future<Map<String, String>> sendCommand(
    String action, {
    List<MapEntry<String, dynamic>> args = const [],
    bool? useCache,
    Duration? cacheTimeout,
  }) async {
    final shouldCache = useCache ?? cache.enabled;

    // Check cache
    if (shouldCache) {
      final cached = cache.get(
        [action],
        {for (final a in args) a.key: a.value},
      );
      if (cached != null) {
        return cached as Map<String, String>;
      }
    }

    final (headers, body) = buildCommand(action, args);

    // Log if debug level
    if (_log.level <= Level.FINE) {
      _log.fine('Sending command: $action with args: $args');
      _log.fine('Body: ${prettify(body)}');
    }

    final timeout = config.requestTimeout != null
        ? Duration(seconds: config.requestTimeout!.toInt())
        : const Duration(seconds: 20);

    try {
      // Use injected client if available, otherwise use http.post directly
      final http.Response response;
      final uri = Uri.parse('$baseUrl$controlUrl');
      final bodyBytes = utf8.encode(body);
      if (httpClient != null) {
        response = await httpClient!
            .post(uri, headers: headers, body: bodyBytes)
            .timeout(timeout);
      } else {
        response = await http
            .post(uri, headers: headers, body: bodyBytes)
            .timeout(timeout);
      }

      _log.fine('Received: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final result = unwrapArguments(response.body);

        // Cache the result
        if (shouldCache && cache is TimedCache) {
          (cache as TimedCache).put(
            result,
            [action],
            {for (final a in args) a.key: a.value},
            timeout: cacheTimeout,
          );
        } else if (shouldCache) {
          cache.put(result, [action], {for (final a in args) a.key: a.value});
        }

        return result;
      } else if (response.statusCode == 500) {
        // UPnP error
        handleUpnpError(response.body);
        // handleUpnpError always throws, but Dart doesn't know that
        throw SoCoException('UPnP error occurred');
      } else {
        throw http.ClientException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          Uri.parse('$baseUrl$controlUrl'),
        );
      }
    } catch (e) {
      _log.warning('Error sending command $action: $e');
      rethrow;
    }
  }

  /// Handle a UPnP error by parsing the error XML and raising an exception.
  ///
  /// Parameters:
  ///   - [xmlError]: The XML error response
  ///
  /// Throws:
  ///   - [SoCoUPnPException] with error details
  ///   - [UnknownSoCoException] if error cannot be parsed
  void handleUpnpError(String xmlError) {
    try {
      final tree = xml.XmlDocument.parse(xmlError);
      final fault = tree
          .findAllElements(
            'Fault',
            namespace: 'http://schemas.xmlsoap.org/soap/envelope/',
          )
          .first;

      final detail = fault.findElements('detail').first;
      final upnpError = detail.findElements('UPnPError').first;

      final errorCode = upnpError.findElements('errorCode').first.innerText;
      final errorDescription = upnpError
          .findElements('errorDescription')
          .first
          .innerText;

      final errorCodeInt = int.tryParse(errorCode) ?? 0;
      final errorMessage = upnpErrors[errorCodeInt] ?? errorDescription;

      throw SoCoUPnPException(
        message: errorMessage,
        errorCode: errorCode,
        errorXml: xmlError,
        errorDescription: errorDescription,
      );
    } catch (e) {
      if (e is SoCoUPnPException) {
        rethrow;
      }
      // If we can't parse the error, raise a generic exception
      throw UnknownSoCoException(xmlError);
    }
  }

  /// Get the list of available actions for this service.
  ///
  /// Returns:
  ///   A list of Action objects
  Future<List<Action>> get actions async {
    if (_actions != null) {
      return _actions!;
    }

    // This would need to fetch and parse the service description XML
    // For now, return an empty list as this requires more infrastructure
    // TODO: Implement SCPD parsing
    _actions = [];
    return _actions!;
  }

  /// Iterate over available actions.
  Stream<Action> iterActions() async* {
    final actionsList = await actions;
    for (final action in actionsList) {
      yield action;
    }
  }

  /// Get the event variables for this service.
  ///
  /// Returns:
  ///   A map of event variable names to their properties
  Future<Map<String, dynamic>> get eventVars async {
    if (_eventVars != null) {
      return _eventVars!;
    }

    // This would need to fetch and parse the service description XML
    // For now, return an empty map
    // TODO: Implement SCPD parsing
    _eventVars = {};
    return _eventVars!;
  }

  /// Subscribe to events from this service.
  ///
  /// Parameters:
  ///   - [requestedTimeout]: The timeout (in seconds) to be requested for the
  ///     subscription. If null, the Sonos default will be used.
  ///   - [autoRenew]: If true, renew the subscription automatically shortly
  ///     before timeout. Default is false.
  ///   - [broadcast]: If true, the events stream will be a broadcast stream
  ///     (allowing multiple listeners). Default is true.
  ///
  /// Returns:
  ///   A Subscription object through which events can be received
  ///
  /// Example:
  /// ```dart
  /// final sub = await device.avTransport.subscribe(autoRenew: true);
  /// sub.events.listen((event) {
  ///   print('Transport state: ${event['transport_state']}');
  /// });
  /// ```
  Future<dynamic> subscribe({
    int? requestedTimeout,
    bool autoRenew = false,
    bool broadcast = true,
  }) async {
    // Avoid circular dependency by using dynamic import
    // The actual import happens at runtime in the events module
    throw UnimplementedError(
      'subscribe() requires importing events module. '
      'Use: import \'package:soco/soco.dart\' and call device.service.subscribe()',
    );
  }

  /// Update the cache based on an event.
  ///
  /// This method is called internally by the events system when an event is
  /// received. It updates the service's cache with the new values from the
  /// event.
  ///
  /// Parameters:
  ///   - [event]: The Event object containing updated values
  void updateCacheOnEvent(dynamic event) {
    // Update cache entries based on event variables
    final variables = event.variables as Map<String, dynamic>;

    for (final entry in variables.entries) {
      final key = entry.key;
      final value = entry.value;

      // Cache the value - the cache implementation will use its default timeout
      // Events represent authoritative state changes from the device
      cache.put(value, [], {key: value});
    }
  }
}

// Service subclasses

/// Sonos alarm service.
class AlarmClock extends Service {
  AlarmClock(super.soco) {
    serviceType = 'AlarmClock';
    version = 1;
  }
}

/// Sonos music services.
class MusicServices extends Service {
  MusicServices(super.soco) {
    serviceType = 'MusicServices';
  }
}

/// Sonos audio input service.
class AudioIn extends Service {
  AudioIn(super.soco) {
    serviceType = 'AudioIn';
  }
}

/// Sonos device properties service.
class DeviceProperties extends Service {
  DeviceProperties(super.soco) {
    serviceType = 'DeviceProperties';
  }
}

/// Sonos system properties service.
class SystemProperties extends Service {
  SystemProperties(super.soco) {
    serviceType = 'SystemProperties';
  }
}

/// Sonos zone group topology service.
class ZoneGroupTopology extends Service {
  ZoneGroupTopology(super.soco) {
    serviceType = 'ZoneGroupTopology';
  }
}

/// Sonos group management service.
class GroupManagement extends Service {
  GroupManagement(super.soco) {
    serviceType = 'GroupManagement';
  }
}

/// Sonos QPlay service.
class QPlay extends Service {
  QPlay(super.soco) {
    serviceType = 'QPlay';
  }
}

/// Sonos content directory service.
class ContentDirectory extends Service {
  ContentDirectory(super.soco) {
    serviceType = 'ContentDirectory';
  }
}

/// Sonos connection manager service.
class MSConnectionManager extends Service {
  MSConnectionManager(super.soco) {
    serviceType = 'ConnectionManager';
  }
}

/// Sonos rendering control service.
class RenderingControl extends Service {
  RenderingControl(super.soco) {
    serviceType = 'RenderingControl';
  }
}

/// Sonos connection manager service.
class MRConnectionManager extends Service {
  MRConnectionManager(super.soco) {
    serviceType = 'ConnectionManager';
  }
}

/// Sonos AV transport service.
class AVTransport extends Service {
  AVTransport(super.soco) {
    serviceType = 'AVTransport';
  }
}

/// Sonos queue service.
class Queue extends Service {
  Queue(super.soco) {
    serviceType = 'Queue';
  }
}

/// Sonos group rendering control service.
class GroupRenderingControl extends Service {
  GroupRenderingControl(super.soco) {
    serviceType = 'GroupRenderingControl';
  }
}

/// Escape XML special characters.
String _escapeXml(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
