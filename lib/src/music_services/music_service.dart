/// Sonos Music Services interface.
///
/// This module provides the MusicService class and related functionality.
///
/// Known problems:
///
/// 1. Not all music services follow the pattern layout for the
///    authentication information completely. This means that it might be
///    necessary to tweak the code for individual services. This is an
///    unfortunate result of Sonos not enforcing data hygiene of its
///    services. The implication for SoCo is that getting all services
///    to work will require more effort and the kind of broader testing we
///    will only get by putting the code out there. Hence, if you are an
///    early adopter of the music service code (added in version 0.26)
///    consider yourselves guinea pigs.
/// 2. There currently is no way to reset an authentication, at least when
///    authentication has been performed for TIDAL (which uses device link
///    authentication), after it has been done once for a particular
///    household ID, it fails on subsequent attempts. What this might mean
///    is that if you lose the authentication tokens for such a service,
///    it may not be possible to generate new ones. Obviously, some method
///    must exist to reset this, but it is not presently implemented.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:xml/xml.dart';

import '../discovery.dart';
import '../exceptions.dart';
import '../soap.dart';
import '../data_structures.dart' show SearchResult;
import 'data_structures.dart';
import 'token_store.dart';

final _log = Logger('soco.music_services.music_service');

/// Convert an XML element to a Map structure, similar to Python's xmltodict.parse().
///
/// This function converts XML elements to nested Maps, handling:
/// - Element names as keys (with namespace prefixes stripped if matching the provided namespace)
/// - Text content as values
/// - Child elements as nested maps
/// - Multiple elements with the same name as lists
///
/// Parameters:
///   - [element]: The XML element to convert
///   - [namespace]: The namespace URI to strip from element names (optional)
///
/// Returns:
///   A Map representation of the XML structure
Map<String, dynamic> _xmlElementToMap(XmlElement element, String? namespace) {
  // Get the local name (without namespace prefix)
  String localName = element.name.local;

  // If namespace is provided and matches, we've already got the local name
  // Otherwise, we might need to handle namespace prefixes
  final elementNamespace = element.name.namespaceUri;
  if (namespace != null &&
      elementNamespace == namespace &&
      (element.name.prefix?.isNotEmpty ?? false)) {
    // Already using local name, which is correct
  }

  // Process child elements
  final children = element.childElements;
  final textContent = element.innerText.trim();

  if (children.isEmpty) {
    // Leaf element - return text content or empty string
    return {localName: textContent.isEmpty ? null : textContent};
  }

  // Process child elements
  final childMap = <String, dynamic>{};
  final childCounts = <String, int>{};

  for (final child in children) {
    final childLocalName = child.name.local;
    childCounts[childLocalName] = (childCounts[childLocalName] ?? 0) + 1;
  }

  for (final child in children) {
    final childLocalName = child.name.local;
    final childValue = _xmlElementToMap(child, namespace);

    // If there are multiple children with the same name, make it a list
    if (childCounts[childLocalName]! > 1) {
      if (!childMap.containsKey(childLocalName)) {
        childMap[childLocalName] = <dynamic>[];
      }
      // Extract the value from the child map (which has the element name as key)
      final childData = childValue[childLocalName];
      (childMap[childLocalName] as List).add(childData);
    } else {
      // Single child - extract the value from the child map
      childMap[childLocalName] = childValue[childLocalName];
    }
  }

  // If there's text content along with children, include it
  if (textContent.isNotEmpty && childMap.isNotEmpty) {
    childMap['#text'] = textContent;
  } else if (textContent.isNotEmpty) {
    // Only text content, no children
    return {localName: textContent};
  }

  // Return map with element name as key
  return {localName: childMap.isEmpty ? null : childMap};
}

/// A SOAP client for accessing Music Services.
///
/// This class handles all the necessary authentication for accessing
/// third party music services. You are unlikely to need to use it
/// yourself.
class MusicServiceSoapClient {
  /// The SOAP endpoint URL
  final String endpoint;

  /// Timeout in seconds
  final int timeout;

  /// The MusicService object to which this client belongs
  final MusicService musicService;

  /// Token store instance
  final TokenStoreBase tokenStore;

  /// The SOAP namespace
  final String namespace = 'http://www.sonos.com/Services/1.1';

  /// Cached SOAP header
  String? _cachedSoapHeader;

  /// HTTP headers for requests
  final Map<String, String> httpHeaders = {
    'Accept-Encoding': 'gzip, deflate',
    'User-Agent':
        'Linux UPnP/1.0 Sonos/29.3-87071 (ICRU_iPhone7,1); iOS/Version 8.2 (Build 12D508)',
  };

  /// Device for communication
  late final dynamic _device;

  /// Device ID
  late final String _deviceId;

  /// Household ID
  late final String _householdId;

  /// Initialize the SOAP client
  ///
  /// Parameters:
  ///   - [endpoint]: The SOAP endpoint URL
  ///   - [timeout]: Timeout in seconds
  ///   - [musicService]: The MusicService object
  ///   - [tokenStore]: A token store instance
  ///   - [device]: Optional device for communication
  MusicServiceSoapClient({
    required this.endpoint,
    required this.timeout,
    required this.musicService,
    required this.tokenStore,
    dynamic device,
  }) {
    _initDevice(device);
  }

  /// Initialize device and related IDs
  Future<void> _initDevice(dynamic device) async {
    _device = device ?? await anySoco();
    if (_device == null) {
      throw Exception('No Sonos device found');
    }

    final deviceIdResult = await _device.systemProperties.getString([
      MapEntry('VariableName', 'R_TrialZPSerial'),
    ]);
    _deviceId = deviceIdResult['StringValue'] as String;

    final householdResult = await _device.deviceProperties.getHouseholdId();
    _householdId = householdResult['CurrentHouseholdID'] as String;
  }

  /// Generate the SOAP authentication header for the related service.
  ///
  /// This header contains all the necessary authentication details.
  ///
  /// Returns:
  ///   A string representation of the XML content of the SOAP header.
  Future<String> getSoapHeader() async {
    // Return cached header if available
    if (_cachedSoapHeader != null) {
      return _cachedSoapHeader!;
    }

    // Check for token first (before building XML)
    List<String>? tokenPair;
    if (musicService.authType == 'DeviceLink' ||
        musicService.authType == 'AppLink') {
      final hasToken = await tokenStore.hasToken(
        musicService.serviceId,
        _device.householdId as String,
      );
      if (hasToken) {
        tokenPair = await tokenStore.loadTokenPair(
          musicService.serviceId,
          _device.householdId as String,
        );
      }
    }

    final builder = XmlBuilder();
    builder.element(
      'credentials',
      nest: () {
        builder.attribute('xmlns', namespace);
        builder.element('deviceId', nest: _deviceId);
        builder.element('deviceProvider', nest: 'Sonos');

        if (musicService.authType == 'DeviceLink' ||
            musicService.authType == 'AppLink') {
          // Add context
          builder.element('context');

          // If we have a token, add login token elements
          if (tokenPair != null) {
            builder.element(
              'loginToken',
              nest: () {
                builder.element('token', nest: tokenPair![0]);
                builder.element('key', nest: tokenPair[1]);
                builder.element('householdId', nest: _householdId);
              },
            );
          }
        }
      },
    );

    _cachedSoapHeader = builder.buildDocument().toXmlString();
    return _cachedSoapHeader!;
  }

  /// Call a method on the server.
  ///
  /// Parameters:
  ///   - [method]: The name of the method to call
  ///   - [args]: List of (parameter, value) pairs
  ///
  /// Returns:
  ///   A Map representing the response
  ///
  /// Throws:
  ///   MusicServiceException on error
  Future<Map<String, dynamic>> call(
    String method, [
    List<MapEntry<String, dynamic>>? args,
  ]) async {
    final soapHeader = await getSoapHeader();
    final message = SoapMessage(
      endpoint: endpoint,
      method: method,
      parameters: args ?? [],
      httpHeaders: httpHeaders,
      soapAction: 'http://www.sonos.com/Services/1.1#$method',
      soapHeader: soapHeader,
      namespace: namespace,
      timeout: Duration(seconds: timeout),
    );

    try {
      final resultElt = await message.call();

      // Convert XML element to Map
      final resultMap = _xmlElementToMap(resultElt, namespace);

      // The top key in the map will be the methodResult. Its value may be null
      // if no results were returned. Extract the first value from the map.
      if (resultMap.isEmpty) {
        return {};
      }

      // Get the first value from the result map (similar to Python's .values()[0])
      final firstValue = resultMap.values.first;
      return firstValue is Map<String, dynamic> ? firstValue : {};
    } on SoapFault catch (exc) {
      if (exc.faultcode.contains('Client.AuthTokenExpired')) {
        throw MusicServiceAuthException(
          'Authorization for ${musicService.serviceName} expired, is invalid or has not yet been '
          'completed: [${exc.faultcode} / ${exc.faultstring} / ${exc.detail}]',
        );
      }

      if (exc.faultcode.contains('Client.TokenRefreshRequired')) {
        _log.fine(
          'Auth token for ${musicService.serviceName} expired, attempting to refresh',
        );

        if (musicService.authType != 'DeviceLink' &&
            musicService.authType != 'AppLink') {
          throw MusicServiceAuthException(
            'Token-refresh not supported for music service auth type: ${musicService.authType}',
          );
        }

        // Remove cached SOAP header
        _cachedSoapHeader = null;

        // Extract new token and key from error detail
        String? authToken;
        String? privateKey;

        final detailXml = exc.detail;
        if (detailXml != null) {
          authToken = detailXml
              .findElements('authToken')
              .firstOrNull
              ?.innerText;
          privateKey = detailXml
              .findElements('privateKey')
              .firstOrNull
              ?.innerText;

          // Try without namespace if not found
          authToken ??= detailXml
              .findElements('authToken')
              .firstOrNull
              ?.innerText;
          privateKey ??= detailXml
              .findElements('privateKey')
              .firstOrNull
              ?.innerText;

          if (authToken == null || privateKey == null) {
            throw MusicServiceAuthException(
              'Got a TokenRefreshRequired but no new token was found in the reply: ${exc.detail}',
            );
          }

          // Save new token pair
          await tokenStore.saveTokenPair(
            musicService.serviceId,
            _device.householdId as String,
            [authToken, privateKey],
          );

          // Retry with new token
          return call(method, args);
        }
      }

      _log.severe(
        'Unhandled SOAP Fault. Code: ${exc.faultcode}. Detail: ${exc.detail}. String: ${exc.faultstring}',
      );
      throw MusicServiceException(exc.faultstring);
    } on XmlException {
      throw MusicServiceAuthException(
        'Got empty response to request, likely because the service is not authenticated',
      );
    }
  }

  /// Perform the first part of a Device or App Link authentication session
  ///
  /// Returns:
  ///   A tuple of (regUrl, linkCode, linkDeviceId)
  Future<(String, String, String?)> beginAuthentication() async {
    String? linkDeviceId;

    if (musicService.authType == 'DeviceLink') {
      _log.fine('Beginning DeviceLink authentication');
      final result = await call('getDeviceLinkCode', [
        MapEntry('householdId', _householdId),
      ]);
      final linkCodeResult = result['getDeviceLinkCodeResult'] as Map;
      if (linkCodeResult.containsKey('linkDeviceId')) {
        linkDeviceId = linkCodeResult['linkDeviceId'] as String;
      }
      return (
        linkCodeResult['regUrl'] as String,
        linkCodeResult['linkCode'] as String,
        linkDeviceId,
      );
    } else if (musicService.authType == 'AppLink') {
      _log.fine('Beginning AppLink authentication');
      final result = await call('getAppLink', [
        MapEntry('householdId', _householdId),
      ]);
      final appLinkResult = result['getAppLinkResult'] as Map;
      final authParts =
          (appLinkResult['authorizeAccount'] as Map)['deviceLink'] as Map;
      if (authParts.containsKey('linkDeviceId')) {
        linkDeviceId = authParts['linkDeviceId'] as String;
      }
      return (
        authParts['regUrl'] as String,
        authParts['linkCode'] as String,
        linkDeviceId,
      );
    }

    throw MusicServiceAuthException(
      'begin_authentication() is not implemented for auth type ${musicService.authType}',
    );
  }

  /// Completes a previously initiated authentication session
  ///
  /// Parameters:
  ///   - [linkCode]: The link code from beginAuthentication
  ///   - [linkDeviceId]: Optional link device ID
  Future<void> completeAuthentication(
    String linkCode, [
    String? linkDeviceId,
  ]) async {
    _log.fine('Attempting to complete DeviceLink or AppLink authentication');
    final result = await call('getDeviceAuthToken', [
      MapEntry('householdId', _householdId),
      MapEntry('linkCode', linkCode),
      MapEntry('linkDeviceId', linkDeviceId ?? _deviceId),
    ]);

    final authResult = result['getDeviceAuthTokenResult'] as Map;
    final tokenPair = [
      authResult['authToken'] as String,
      authResult['privateKey'] as String,
    ];

    await tokenStore.saveTokenPair(
      musicService.serviceId,
      _device.householdId as String,
      tokenPair,
    );

    // Delete the cached SOAP header
    _cachedSoapHeader = null;
  }
}

/// The MusicService class provides access to third party music services.
///
/// Example:
///
///     List all the services Sonos knows about:
///
///     ```dart
///     final services = await MusicService.getAllMusicServicesNames();
///     print(services);
///     // ['Spotify', 'TuneIn', 'Deezer', ...]
///     ```
///
///     Interact with TuneIn:
///
///     ```dart
///     final tunein = await MusicService.create('TuneIn');
///     print(tunein);
///     // <MusicService 'TuneIn'>
///
///     // Browse the root item
///     final result = await tunein.getMetadata();
///     print(result);
///     // SearchResult with MediaCollection items
///     ```
///
/// Note:
///     Some of this code is still unstable, and in particular the data
///     structures returned by methods such as `getMetadata` may change in
///     future.
class MusicService {
  /// Cached music services data
  static Map<String, Map<String, dynamic>>? _musicServicesData;

  /// The name of the music service
  final String serviceName;

  /// Token store instance
  final TokenStoreBase tokenStore;

  /// Service URI
  late final String uri;

  /// Secure service URI
  late final String secureUri;

  /// Service capabilities
  late final String capabilities;

  /// Service version
  late final String version;

  /// Container type
  late final String containerType;

  /// Service ID
  late final String serviceId;

  /// Authentication type
  late final String authType;

  /// Presentation map URI
  late final String? presentationMapUri;

  /// Manifest URI
  late final String? manifestUri;

  /// Manifest data
  Map<String, dynamic>? manifestData;

  /// Search prefix map cache
  Map<String, String>? _searchPrefixMap;

  /// Service type
  late final String serviceType;

  /// Cached link code from authentication
  String? linkCode;

  /// Cached link device ID from authentication
  String? linkDeviceId;

  /// SOAP client
  late final MusicServiceSoapClient soapClient;

  /// Private constructor
  MusicService._({
    required this.serviceName,
    required this.tokenStore,
    required Map<String, dynamic> data,
    dynamic device,
  }) {
    // Initialize fields from data
    uri = data['Uri'] as String;
    secureUri = data['SecureUri'] as String;
    capabilities = data['Capabilities'] as String;
    version = data['Version'] as String;
    containerType = data['ContainerType'] as String;
    serviceId = data['Id'] as String;
    authType = data['Auth'] as String;
    presentationMapUri = data['PresentationMapUri'] as String?;
    manifestUri = data['ManifestUri'] as String?;
    serviceType = data['ServiceType'] as String;

    // Create SOAP client
    soapClient = MusicServiceSoapClient(
      endpoint: secureUri,
      timeout: 9,
      musicService: this,
      tokenStore: tokenStore,
      device: device,
    );
  }

  /// Create a MusicService instance
  ///
  /// Parameters:
  ///   - [serviceName]: The name of the music service
  ///   - [tokenStore]: Optional token store instance
  ///   - [device]: Optional device for communication
  ///
  /// Returns:
  ///   A MusicService instance
  static Future<MusicService> create(
    String serviceName, {
    TokenStoreBase? tokenStore,
    dynamic device,
  }) async {
    final store = tokenStore ?? await JsonFileTokenStore.fromConfigFile();
    final data = await getDataForName(serviceName);

    return MusicService._(
      serviceName: serviceName,
      tokenStore: store,
      data: data,
      device: device,
    );
  }

  @override
  String toString() {
    return '<MusicService \'$serviceName\'>';
  }

  /// Fetch the music services data xml from a Sonos device.
  ///
  /// Parameters:
  ///   - [soco]: Optional SoCo instance to query
  ///
  /// Returns:
  ///   A string containing the music services data XML
  static Future<String> _getMusicServicesDataXml([dynamic soco]) async {
    final device = soco ?? await anySoco();
    if (device == null) {
      throw Exception('No Sonos device found');
    }

    _log.fine('Fetching music services data from $device');
    final availableServices = await device.musicServices
        .listAvailableServices();
    final descriptorListXml =
        availableServices['AvailableServiceDescriptorList'] as String;
    _log.fine('Services descriptor list: $descriptorListXml');
    return descriptorListXml;
  }

  /// Parse raw account data XML into a useful data structure.
  ///
  /// Returns:
  ///   A map where each key is a service_type and each value is a map
  ///   containing relevant data.
  static Future<Map<String, Map<String, dynamic>>>
  _getMusicServicesData() async {
    // Return from cache if available
    if (_musicServicesData != null) {
      return _musicServicesData!;
    }

    final result = <String, Map<String, dynamic>>{};
    final xmlString = await _getMusicServicesDataXml();
    final root = XmlDocument.parse(xmlString).rootElement;

    final services = root.findElements('Service');
    for (final service in services) {
      final resultValue = <String, dynamic>{};
      for (final attr in service.attributes) {
        resultValue[attr.name.local] = attr.value;
      }

      final name = service.getAttribute('Name')!;
      resultValue['Name'] = name;

      final authElement = service.findElements('Policy').firstOrNull;
      if (authElement != null) {
        for (final attr in authElement.attributes) {
          resultValue[attr.name.local] = attr.value;
        }
      }

      // Get presentation map
      final presentationElement = service
          .findAllElements('PresentationMap')
          .firstOrNull;
      if (presentationElement != null) {
        resultValue['PresentationMapUri'] = presentationElement.getAttribute(
          'Uri',
        );
        resultValue['StringsUri'] = presentationElement.getAttribute('Uri');
      }

      // Get manifest information if available
      final manifestElement = service.findElements('Manifest').firstOrNull;
      if (manifestElement != null) {
        resultValue['ManifestUri'] = manifestElement.getAttribute('Uri');
      }

      resultValue['ServiceID'] = service.getAttribute('Id');

      // ServiceType is (ID * 256) + 7
      final serviceId = int.parse(service.getAttribute('Id')!);
      final serviceType = (serviceId * 256 + 7).toString();
      resultValue['ServiceType'] = serviceType;
      result[serviceType] = resultValue;
    }

    // Cache the result
    _musicServicesData = result;
    return result;
  }

  /// Get a list of the names of all available music services.
  ///
  /// These services have not necessarily been subscribed to.
  ///
  /// Returns:
  ///   A list of service names
  static Future<List<String>> getAllMusicServicesNames() async {
    final data = await _getMusicServicesData();
    return data.values.map((s) => s['Name'] as String).toList();
  }

  /// Get the data relating to a named music service.
  ///
  /// Parameters:
  ///   - [serviceName]: The name of the music service
  ///
  /// Returns:
  ///   Data relating to the music service
  ///
  /// Throws:
  ///   MusicServiceException if the music service cannot be found
  static Future<Map<String, dynamic>> getDataForName(String serviceName) async {
    final data = await _getMusicServicesData();
    for (final service in data.values) {
      if (service['Name'] == serviceName) {
        return service;
      }
    }
    throw MusicServiceException('Unknown music service: \'$serviceName\'');
  }

  /// Fetch and parse the service search category mapping.
  ///
  /// Standard Sonos search categories are 'all', 'artists', 'albums',
  /// 'tracks', 'playlists', 'genres', 'stations', 'tags'. Not all are
  /// available for each music service.
  Future<Map<String, String>> _getSearchPrefixMap() async {
    // Return cached if available
    if (_searchPrefixMap != null) {
      return _searchPrefixMap!;
    }

    _searchPrefixMap = {};

    // TuneIn is a special case
    if (serviceName == 'TuneIn') {
      _searchPrefixMap = {
        'stations': 'search:station',
        'shows': 'search:show',
        'hosts': 'search:host',
      };
      return _searchPrefixMap!;
    }

    // Get presentation map from manifest if needed
    if (presentationMapUri == null &&
        manifestUri != null &&
        manifestData == null) {
      final response = await http.get(Uri.parse(manifestUri!));
      manifestData = json.decode(response.body) as Map<String, dynamic>;
      final pmapElement = manifestData!['presentationMap'] as Map?;
      if (pmapElement != null) {
        presentationMapUri = pmapElement['uri'] as String?;
      }
    }

    if (presentationMapUri == null) {
      return _searchPrefixMap!;
    }

    _log.fine('Fetching presentation map from $presentationMapUri');
    final pmap = await http.get(Uri.parse(presentationMapUri!));
    final pmapRoot = XmlDocument.parse(pmap.body).rootElement;

    final categories = pmapRoot.findAllElements('Category');
    for (final category in categories) {
      if (category.parentElement?.name.local == 'SearchCategories') {
        final id = category.getAttribute('id');
        final mappedId = category.getAttribute('mappedId') ?? id;
        if (id != null) {
          _searchPrefixMap![id] = mappedId!;
        }
      }
    }

    final customCategories = pmapRoot.findAllElements('CustomCategory');
    for (final category in customCategories) {
      if (category.parentElement?.name.local == 'SearchCategories') {
        final stringId = category.getAttribute('stringId');
        final mappedId = category.getAttribute('mappedId');
        if (stringId != null && mappedId != null) {
          _searchPrefixMap![stringId] = mappedId;
        }
      }
    }

    return _searchPrefixMap!;
  }

  /// The list of search categories supported by this service.
  ///
  /// May include 'artists', 'albums', 'tracks', 'playlists', 'genres',
  /// 'stations', 'tags', or others depending on the service.
  Future<List<String>> get availableSearchCategories async {
    final map = await _getSearchPrefixMap();
    return map.keys.toList();
  }

  /// Get a URI which can be sent for playing.
  ///
  /// Parameters:
  ///   - [itemId]: The unique id of a playable item
  ///
  /// Returns:
  ///   A URI that encodes the item_id and account information
  String sonosUriFromId(String itemId) {
    final encodedId = Uri.encodeComponent(itemId);
    // Serial number is assumed to be 0 (accounts no longer accessible)
    return 'soco://$encodedId?sid=$serviceId&sn=0';
  }

  /// The Sonos descriptor to use for this service.
  ///
  /// The Sonos descriptor is used as the content of the `<desc>` tag in
  /// DIDL metadata, to indicate the relevant music service id.
  String get desc {
    if (authType == 'DeviceLink') {
      return 'SA_RINCON${serviceType}_X_#Svc$serviceType-0-Token';
    } else {
      return 'SA_RINCON${serviceType}_';
    }
  }

  /// Perform the first part of a Device or App Link authentication session
  ///
  /// Returns the registration URL that the user needs to visit.
  ///
  /// Note:
  ///   The beginAuthentication and completeAuthentication methods must be
  ///   completed on the same MusicService instance unless the linkCode
  ///   and linkDeviceId values are passed to completeAuthentication.
  Future<String> beginAuthentication() async {
    _log.fine('Begin authentication on music service $this');
    final (regUrl, code, deviceId) = await soapClient.beginAuthentication();
    linkCode = code;
    linkDeviceId = deviceId;
    return regUrl;
  }

  /// Completes a previously initiated device or app link authentication session
  ///
  /// Parameters:
  ///   - [code]: Optional link code (uses cached if not provided)
  ///   - [deviceId]: Optional link device ID (uses cached if not provided)
  Future<void> completeAuthentication({String? code, String? deviceId}) async {
    _log.fine('Complete authentication on music service $this');
    final linkCodeToUse = code ?? linkCode;
    if (linkCodeToUse == null) {
      throw MusicServiceAuthException('link_code not provided or cached');
    }
    final linkDeviceIdToUse = deviceId ?? linkDeviceId;
    await soapClient.completeAuthentication(linkCodeToUse, linkDeviceIdToUse);
    linkCode = null;
    linkDeviceId = null;
  }

  ////////////////////////////////////////////////////////////////////////
  //                                                                    //
  //                           SOAP METHODS                             //
  //                                                                    //
  ////////////////////////////////////////////////////////////////////////

  /// Get metadata for a container or item.
  ///
  /// Parameters:
  ///   - [item]: The container or item to browse (default: 'root')
  ///   - [index]: The starting index (default: 0)
  ///   - [count]: Maximum number of items to return (default: 100)
  ///   - [recursive]: Whether to recurse into sub-items (default: false)
  ///
  /// Returns:
  ///   A SearchResult containing the metadata
  Future<SearchResult> getMetadata({
    dynamic item = 'root',
    int index = 0,
    int count = 100,
    bool recursive = false,
  }) async {
    String itemId;
    if (item is MusicServiceItem) {
      itemId = item.itemId;
    } else {
      itemId = item as String;
    }

    final response = await soapClient.call('getMetadata', [
      MapEntry('id', itemId),
      MapEntry('index', index),
      MapEntry('count', count),
      MapEntry('recursive', recursive ? 1 : 0),
    ]);

    return parseResponse(this, response, 'browse');
  }

  /// Search for an item in a category.
  ///
  /// Parameters:
  ///   - [category]: The search category to use
  ///   - [term]: The term to search for (default: '')
  ///   - [index]: The starting index (default: 0)
  ///   - [count]: Maximum number of items to return (default: 100)
  ///
  /// Returns:
  ///   A SearchResult containing the search results
  Future<SearchResult> search({
    required String category,
    String term = '',
    int index = 0,
    int count = 100,
  }) async {
    final searchPrefixMap = await _getSearchPrefixMap();
    final searchCategory = searchPrefixMap[category];

    if (searchCategory == null) {
      throw MusicServiceException(
        '$serviceName does not support the \'$category\' search category',
      );
    }

    final response = await soapClient.call('search', [
      MapEntry('id', searchCategory),
      MapEntry('term', term),
      MapEntry('index', index),
      MapEntry('count', count),
    ]);

    return parseResponse(this, response, category);
  }

  /// Get metadata for a media item.
  ///
  /// Parameters:
  ///   - [itemId]: The item for which metadata is required
  ///
  /// Returns:
  ///   The item's metadata
  Future<Map<String, dynamic>?> getMediaMetadata(String itemId) async {
    final response = await soapClient.call('getMediaMetadata', [
      MapEntry('id', itemId),
    ]);
    return response['getMediaMetadataResult'] as Map<String, dynamic>?;
  }

  /// Get a streaming URI for an item.
  ///
  /// Note:
  ///   You should not need to use this directly. It is used by the Sonos
  ///   players to obtain the URI of the media stream.
  ///
  /// Parameters:
  ///   - [itemId]: The item for which the URI is required
  ///
  /// Returns:
  ///   The item's streaming URI
  Future<String?> getMediaUri(String itemId) async {
    final response = await soapClient.call('getMediaURI', [
      MapEntry('id', itemId),
    ]);
    return response['getMediaURIResult'] as String?;
  }

  /// Get last_update details for this music service.
  ///
  /// Returns:
  ///   A map with keys 'catalog' and 'favorites'. The value of each is
  ///   a string which changes each time the catalog or favorites change.
  Future<Map<String, dynamic>?> getLastUpdate() async {
    final response = await soapClient.call('getLastUpdate');
    return response['getLastUpdateResult'] as Map<String, dynamic>?;
  }

  /// Get extended metadata for a media item, such as related items.
  ///
  /// Parameters:
  ///   - [itemId]: The item for which metadata is required
  ///
  /// Returns:
  ///   The item's extended metadata
  Future<Map<String, dynamic>?> getExtendedMetadata(String itemId) async {
    final response = await soapClient.call('getExtendedMetadata', [
      MapEntry('id', itemId),
    ]);
    return response['getExtendedMetadataResult'] as Map<String, dynamic>?;
  }

  /// Get extended metadata text for a media item.
  ///
  /// Parameters:
  ///   - [itemId]: The item for which metadata is required
  ///   - [metadataType]: The type of text to return (e.g., 'ARTIST_BIO')
  ///
  /// Returns:
  ///   The item's extended metadata text
  Future<String?> getExtendedMetadataText(
    String itemId,
    String metadataType,
  ) async {
    final response = await soapClient.call('getExtendedMetadataText', [
      MapEntry('id', itemId),
      MapEntry('type', metadataType),
    ]);
    return response['getExtendedMetadataTextResult'] as String?;
  }
}
