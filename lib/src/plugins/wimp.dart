/// Plugin for the Wimp/Tidal music service (Service ID 20).
///
/// Wimp was a Norwegian music streaming service that later merged with
/// Tidal. This plugin provides search and browse functionality for the
/// Wimp music service on Sonos.
///
/// Note:
///   There is an (apparent) in-consistency in the use of one data
///   type from the Wimp service. When searching for playlists, the XML
///   returned by the Wimp server indicates that the type is an 'album
///   list', and it thus suggests that this type is used for a list of
///   tracks (as expected for a playlist), and this data type is reported
///   to be playable. However, when browsing the music tree, the Wimp
///   server will return items of 'album list' type, but in this case it
///   is used for a list of albums and it is not playable. This plugin
///   maintains this (apparent) in-consistency to stick as close to the
///   reported data as possible.
///
/// Note:
///   Wimp in some cases lists tracks that are not available. In these
///   cases, while it will correctly report these tracks as not being
///   playable, the containing data structure like e.g. the album they are
///   on may report that they are playable. Trying to add one of these to
///   the queue will return a SoCoUPnPException with error code '802'.
///
/// The plugin supports dependency injection of the HTTP client for testing.
library;

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../core.dart';
import '../exceptions.dart';
import '../ms_data_structures.dart';
import '../services.dart';
import 'plugins.dart';

/// SOAP action headers for Wimp service
const _soapAction = {
  'get_metadata': '"http://www.sonos.com/Services/1.1#getMetadata"',
  'search': '"http://www.sonos.com/Services/1.1#search"',
};

/// Exception string to code mapping
const _exceptionStrToCode = {
  'unknown': 20000,
  'ItemNotFound': 20001,
};

/// Search prefix format
const _searchPrefix = '00020064{searchType}:{search}';

/// ID prefix for each item type
final _idPrefix = <Type, String?>{
  MSTrack: '00030020',
  MSAlbum: '0004002c',
  MSArtist: '10050024',
  MSAlbumList: '000d006c',
  MSPlaylist: '0006006c',
  MSArtistTracklist: '100f006c',
  MSFavorites: null, // Unknown
  MSCollection: null, // Unknown
};

/// MIME type to extension mapping
const _mimeTypeToExtension = {
  'audio/aac': 'mp4',
};

/// URI templates for each item type
final _uris = <Type, String?>{
  MSTrack: 'x-sonos-http:{item_id}.{extension}?sid={service_id}&flags=32',
  MSAlbum: 'x-rincon-cpcontainer:{extended_id}',
  MSAlbumList: 'x-rincon-cpcontainer:{extended_id}',
  MSPlaylist: 'x-rincon-cpcontainer:{extended_id}',
  MSArtistTracklist: 'x-rincon-cpcontainer:{extended_id}',
};

/// XML namespaces (kept for reference)
// const _ns = {
//   's': 'http://schemas.xmlsoap.org/soap/envelope/',
//   '': 'http://www.sonos.com/Services/1.1',
// };

/// Get the HTTP headers for a SOAP action.
Map<String, String> _getHeader(String soapAction) {
  // Get locale for Accept-Language header
  final locale = Platform.localeName;
  String language = '';
  if (locale.isNotEmpty) {
    language = '${locale.replaceAll('_', '-')}, ';
  }

  return {
    'CONNECTION': 'close',
    'ACCEPT-ENCODING': 'gzip',
    'ACCEPT-LANGUAGE': '${language}en-US;q=0.9',
    'Content-Type': 'text/xml; charset="utf-8"',
    'SOAPACTION': _soapAction[soapAction]!,
  };
}

/// Perform an HTTP POST with retries.
///
/// If [client] is provided, it will be used for the request (useful for testing).
/// Otherwise, a default HTTP client is used.
Future<http.Response> _post(
  String url,
  Map<String, String> headers,
  String body, {
  int retries = 3,
  double timeout = 3.0,
  http.Client? client,
}) async {
  http.Response? response;
  var retry = 0;
  final httpClient = client ?? http.Client();
  final shouldClose = client == null; // Only close if we created it

  try {
    while (response == null) {
      try {
        response = await httpClient
            .post(
              Uri.parse(url),
              headers: headers,
              body: body,
            )
            .timeout(Duration(milliseconds: (timeout * 1000).toInt()));
      } on Exception {
        // Handle TimeoutException, SocketException, etc.
        retry++;
        if (retry == retries) {
          rethrow;
        }
      }
    }
  } finally {
    if (shouldClose) {
      httpClient.close();
    }
  }

  return response;
}

/// A plugin for the Wimp/Tidal music service.
///
/// This class implements search and browse functionality for the Wimp
/// music service on Sonos speakers.
class WimpPlugin extends SoCoPlugin {
  /// The Wimp service URL
  final String _url = 'http://client.wimpmusic.com/sonos/services/Sonos';

  /// The serial number of the speaker
  String _serialNumber;

  /// The username for the music service
  final String _username;

  /// The service ID (always 20 for Wimp)
  final int _serviceId = 20;

  /// HTTP request settings
  final int _retries;
  final double _timeout;

  /// The session ID for authenticated requests
  String _sessionId;

  /// Whether the plugin has been initialized
  bool _initialized = false;

  /// Optional HTTP client for dependency injection (testing)
  final http.Client? _httpClient;

  /// Initialize the plugin.
  ///
  /// Parameters:
  ///   - [soco]: The SoCo instance to retrieve the session ID for the music service
  ///   - [username]: The username for the music service
  ///   - [retries]: The number of times to retry before giving up
  ///   - [timeout]: The time to wait for the post to complete, before timing out.
  ///     The Wimp server seems either slow to respond or to make the queries
  ///     internally, so the timeout should probably not be shorter than 3 seconds.
  ///   - [httpClient]: Optional HTTP client for dependency injection (testing)
  ///
  /// Note:
  ///   If you are using a phone number as the username and are
  ///   experiencing problems connecting, then try to prepend the area
  ///   code (no + or 00). I.e. if your phone number is 12345678 and you
  ///   are from Denmark, then use 4512345678. This must be set up the
  ///   same way in the Sonos device.
  WimpPlugin(
    super.soco,
    this._username, {
    int retries = 3,
    double timeout = 3.0,
    http.Client? httpClient,
  })  : _retries = retries,
        _timeout = timeout,
        _httpClient = httpClient,
        _sessionId = '',
        _serialNumber = '';

  /// Create a WimpPlugin for testing with pre-set initialization values.
  ///
  /// This constructor bypasses the network calls needed for initialization
  /// and allows testing the search and browse functionality directly.
  WimpPlugin.forTesting({
    required String username,
    required String sessionId,
    required String serialNumber,
    int retries = 3,
    double timeout = 3.0,
    http.Client? httpClient,
  })  : _username = username,
        _retries = retries,
        _timeout = timeout,
        _httpClient = httpClient,
        _sessionId = sessionId,
        _serialNumber = serialNumber,
        _initialized = true,
        super(null);

  /// Initialize the plugin by getting speaker info and session ID.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    final speakerInfo = await (soco as SoCo).getSpeakerInfo();
    _serialNumber = speakerInfo['serial_number'] ?? '';

    final musicServices = MusicServices(soco as SoCo);
    final response = await musicServices.sendCommand(
      'GetSessionId',
      args: [
        const MapEntry('ServiceId', 20),
        MapEntry('Username', _username),
      ],
    );
    _sessionId = response['SessionId'] as String;
    _initialized = true;
  }

  @override
  String get name => 'Wimp Plugin for $_username';

  /// Return the username.
  String get username => _username;

  /// Return the service ID.
  int get serviceId => _serviceId;

  /// Return the music service description for the DIDL metadata.
  String get description => 'SA_RINCON5127_$_username';

  /// Search for tracks.
  ///
  /// See [getMusicServiceInformation] for details on the arguments.
  Future<Map<String, dynamic>> getTracks(
    String search, {
    int start = 0,
    int maxItems = 100,
  }) {
    return getMusicServiceInformation('tracks', search,
        start: start, maxItems: maxItems);
  }

  /// Search for albums.
  ///
  /// See [getMusicServiceInformation] for details on the arguments.
  Future<Map<String, dynamic>> getAlbums(
    String search, {
    int start = 0,
    int maxItems = 100,
  }) {
    return getMusicServiceInformation('albums', search,
        start: start, maxItems: maxItems);
  }

  /// Search for artists.
  ///
  /// See [getMusicServiceInformation] for details on the arguments.
  Future<Map<String, dynamic>> getArtists(
    String search, {
    int start = 0,
    int maxItems = 100,
  }) {
    return getMusicServiceInformation('artists', search,
        start: start, maxItems: maxItems);
  }

  /// Search for playlists.
  ///
  /// See [getMusicServiceInformation] for details on the arguments.
  ///
  /// Note:
  ///   Un-intuitively this method returns MSAlbumList items. See
  ///   note in class doc string for details.
  Future<Map<String, dynamic>> getPlaylists(
    String search, {
    int start = 0,
    int maxItems = 100,
  }) {
    return getMusicServiceInformation('playlists', search,
        start: start, maxItems: maxItems);
  }

  /// Search for music service information items.
  ///
  /// Parameters:
  ///   - [searchType]: The type of search to perform. Possible values are:
  ///     'artists', 'albums', 'tracks' and 'playlists'
  ///   - [search]: The search string to use
  ///   - [start]: The starting index of the returned items
  ///   - [maxItems]: The maximum number of returned items
  ///
  /// Returns a map with 'index', 'count', 'total', and 'item_list' keys.
  ///
  /// Note:
  ///   Un-intuitively the playlist search returns MSAlbumList items.
  ///   See note in class doc string for details.
  Future<Map<String, dynamic>> getMusicServiceInformation(
    String searchType,
    String search, {
    int start = 0,
    int maxItems = 100,
  }) async {
    await _ensureInitialized();

    // Check input
    if (!['artists', 'albums', 'tracks', 'playlists'].contains(searchType)) {
      throw ArgumentError('The requested search $searchType is not valid');
    }

    // Transform search: tracks -> tracksearch
    final searchTypeTransformed = '${searchType}earch';
    final parentId = _searchPrefix
        .replaceFirst('{searchType}', searchTypeTransformed)
        .replaceFirst('{search}', search);

    // Perform search
    final body = _searchBody(searchTypeTransformed, search, start, maxItems);
    final headers = _getHeader('search');
    final response = await _post(
      _url,
      headers,
      body,
      retries: _retries,
      timeout: _timeout,
      client: _httpClient,
    );
    _checkForErrors(response);

    final resultDom = XmlDocument.parse(response.body);

    // Parse results
    final searchResult = resultDom.findAllElements('searchResult').first;
    final out = <String, dynamic>{'item_list': <MusicServiceItem>[]};

    for (final element in ['index', 'count', 'total']) {
      final found = searchResult.findElements(element);
      out[element] = found.isNotEmpty ? found.first.innerText : null;
    }

    final itemName =
        searchTypeTransformed == 'tracksearch' ? 'mediaMetadata' : 'mediaCollection';

    for (final element in searchResult.findElements(itemName)) {
      (out['item_list'] as List<MusicServiceItem>)
          .add(getMsItem(element, this, parentId));
    }

    return out;
  }

  /// Return the sub-elements of item or of the root if item is null.
  ///
  /// Parameters:
  ///   - [msItem]: Instance of sub-class of MusicServiceItem. This object must
  ///     have itemId, serviceId and extendedId properties.
  ///
  /// Note:
  ///   Browsing an MSTrack item will return itself.
  ///
  /// Note:
  ///   This plugin cannot yet set the parent ID of the results
  ///   correctly when browsing MSFavorites and MSCollection elements.
  Future<Map<String, dynamic>> browse([MusicServiceItem? msItem]) async {
    await _ensureInitialized();

    // Check for correct service
    if (msItem != null && msItem.content['service_id'] != _serviceId) {
      throw ArgumentError('This music service item is not for this service');
    }

    // Form HTTP body and set parent_id
    String body;
    String parentId;

    if (msItem != null) {
      body = _browseBody(msItem.itemId ?? '');
      parentId = msItem.extendedId ?? '';
    } else {
      body = _browseBody('root');
      parentId = '0';
    }

    // Get HTTP header and post
    final headers = _getHeader('get_metadata');
    final response = await _post(
      _url,
      headers,
      body,
      retries: _retries,
      timeout: _timeout,
      client: _httpClient,
    );

    // Check for errors and get XML
    _checkForErrors(response);
    final resultDom = XmlDocument.parse(response.body);

    // Find the getMetadataResult item
    final metadataResults = resultDom.findAllElements('getMetadataResult');
    if (metadataResults.length != 1) {
      throw UnknownXMLStructure(
        "The results XML has more than 1 'getMetadataResult'. This "
        'is unexpected and parsing will discontinue.',
      );
    }
    final metadataResult = metadataResults.first;

    // Browse the children of metadata result
    final out = <String, dynamic>{'item_list': <MusicServiceItem>[]};

    for (final element in ['index', 'count', 'total']) {
      final found = metadataResult.findElements(element);
      out[element] = found.isNotEmpty ? found.first.innerText : null;
    }

    for (final result in metadataResult.childElements) {
      if (result.name.local == 'mediaCollection' ||
          result.name.local == 'mediaMetadata') {
        (out['item_list'] as List<MusicServiceItem>)
            .add(getMsItem(result, this, parentId));
      }
    }

    return out;
  }

  /// Return the extended ID from an ID.
  ///
  /// Parameters:
  ///   - [itemId]: The ID of the music library item
  ///   - [itemClass]: The class of the music service item
  ///
  /// The extended ID can be something like 00030020trackid_22757082
  /// where the ID is just trackid_22757082. For classes where the prefix is
  /// not known, returns null.
  static String? idToExtendedId(String itemId, Type itemClass) {
    final prefix = _idPrefix[itemClass];
    if (prefix != null) {
      return '$prefix$itemId';
    }
    return null;
  }

  /// Form the URI for a music service element.
  ///
  /// Parameters:
  ///   - [itemContent]: The content dict of the item
  ///   - [itemClass]: The class of the item
  static String? formUri(Map<String, dynamic> itemContent, Type itemClass) {
    String? extension;
    if (itemContent.containsKey('mime_type')) {
      extension = _mimeTypeToExtension[itemContent['mime_type']];
    }

    final template = _uris[itemClass];
    if (template != null) {
      return template
          .replaceAll('{extension}', extension ?? '')
          .replaceAll('{item_id}', itemContent['item_id']?.toString() ?? '')
          .replaceAll(
              '{service_id}', itemContent['service_id']?.toString() ?? '')
          .replaceAll(
              '{extended_id}', itemContent['extended_id']?.toString() ?? '');
    }
    return null;
  }

  /// Return the search XML body.
  String _searchBody(
      String searchType, String searchTerm, int start, int maxItems) {
    final xml = _baseBody();

    // Add the Body part
    final body = XmlElement(XmlName('s:Body'));
    xml.children.add(body);

    final search = XmlElement(
      XmlName('search'),
      [XmlAttribute(XmlName('xmlns'), 'http://www.sonos.com/Services/1.1')],
    );
    body.children.add(search);

    search.children.add(XmlElement(XmlName('id'), [], [XmlText(searchType)]));
    search.children.add(XmlElement(XmlName('term'), [], [XmlText(searchTerm)]));
    search.children
        .add(XmlElement(XmlName('index'), [], [XmlText(start.toString())]));
    search.children
        .add(XmlElement(XmlName('count'), [], [XmlText(maxItems.toString())]));

    return xml.toXmlString();
  }

  /// Return the browse XML body.
  String _browseBody(String searchId) {
    final xml = _baseBody();

    // Add the Body part
    final body = XmlElement(XmlName('s:Body'));
    xml.children.add(body);

    final getMetadata = XmlElement(
      XmlName('getMetadata'),
      [XmlAttribute(XmlName('xmlns'), 'http://www.sonos.com/Services/1.1')],
    );
    body.children.add(getMetadata);

    getMetadata.children
        .add(XmlElement(XmlName('id'), [], [XmlText(searchId)]));
    getMetadata.children.add(XmlElement(XmlName('index'), [], [XmlText('0')]));
    getMetadata.children
        .add(XmlElement(XmlName('count'), [], [XmlText('100')]));

    return xml.toXmlString();
  }

  /// Return the base XML body (envelope with header).
  XmlElement _baseBody() {
    final envelope = XmlElement(
      XmlName('s:Envelope'),
      [
        XmlAttribute(
            XmlName('xmlns:s'), 'http://schemas.xmlsoap.org/soap/envelope/'),
      ],
    );

    // Add the Header part
    final header = XmlElement(XmlName('s:Header'));
    envelope.children.add(header);

    final credentials = XmlElement(
      XmlName('credentials'),
      [XmlAttribute(XmlName('xmlns'), 'http://www.sonos.com/Services/1.1')],
    );
    header.children.add(credentials);

    credentials.children
        .add(XmlElement(XmlName('sessionId'), [], [XmlText(_sessionId)]));
    credentials.children
        .add(XmlElement(XmlName('deviceId'), [], [XmlText(_serialNumber)]));
    credentials.children
        .add(XmlElement(XmlName('deviceProvider'), [], [XmlText('Sonos')]));

    return envelope;
  }

  /// Check a response for errors.
  void _checkForErrors(http.Response response) {
    if (response.statusCode != 200) {
      final xmlError = response.body;
      final errorDom = XmlDocument.parse(xmlError);

      final fault = errorDom.findAllElements('Fault').first;
      final errorDescription =
          fault.findElements('faultstring').first.innerText;
      final errorCode =
          _exceptionStrToCode[errorDescription] ?? _exceptionStrToCode['unknown']!;

      final message =
          'UPnP Error $errorCode received: $errorDescription from $_url';
      throw SoCoUPnPException(
        message: message,
        errorCode: errorCode.toString(),
        errorDescription: errorDescription,
        errorXml: xmlError,
      );
    }
  }
}
