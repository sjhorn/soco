/// Data structures for music service items.
///
/// The basis for this implementation is this page in the Sonos API
/// documentation: http://musicpartners.sonos.com/node/83
///
/// A note about naming. The Sonos API uses camel case with starting lower
/// case. These names have been adapted to match general Dart naming conventions.
///
/// MediaMetadata:
///   - Track
///   - Stream
///   - Show
///   - Other
///
/// MediaCollection:
///   - Artist
///   - Album
///   - Genre
///   - Playlist
///   - Search
///   - Program
///   - Favorites
///   - Favorite
///   - Collection
///   - Container
///   - AlbumList
///   - TrackList
///   - StreamList
///   - ArtistTrackList
///   - Other
///
/// NOTE: "Other" is allowed under both.
library;

import 'package:logging/logging.dart';

import '../data_structures.dart';
import '../utils.dart';

final _log = Logger('soco.music_services.data_structures');

/// Form and return a music service item uri
///
/// Parameters:
///   - [itemId]: The item id
///   - [service]: The music service that the item originates from
///   - [isTrack]: Whether the itemId is from a track or not
///
/// Returns:
///   The music service item uri
String formUri(String itemId, dynamic service, bool isTrack) {
  if (isTrack) {
    return service.sonosUriFromId(itemId);
  } else {
    return 'x-rincon-cpcontainer:$itemId';
  }
}

/// Returns a boolean from a string input of 'true' or 'false'
bool boolStr(String string) {
  if (string != 'true' && string != 'false') {
    throw ArgumentError('Invalid boolean string: "$string"');
  }
  return string == 'true';
}

/// Parse the response to a music service query and return a SearchResult
///
/// Parameters:
///   - [service]: The music service that produced the response
///   - [response]: The response from the soap client call
///   - [searchType]: A string that indicates the search type
///
/// Returns:
///   A SearchResult object
SearchResult parseResponse(
  dynamic service,
  Map<String, dynamic> response,
  String searchType,
) {
  _log.fine('Parse response from service $service of type $searchType');

  final items = <DidlObject>[];

  // The result to be parsed is in either searchResult or getMetadataResult
  Map<String, dynamic> result;
  if (response.containsKey('searchResult')) {
    result = response['searchResult'] as Map<String, dynamic>;
  } else if (response.containsKey('getMetadataResult')) {
    result = response['getMetadataResult'] as Map<String, dynamic>;
  } else {
    throw ArgumentError(
      'response should contain either the key "searchResult" or "getMetadataResult"',
    );
  }

  // Form the search metadata
  final numberReturned = result['count'] as int?;
  const totalMatches = null;
  const updateId = null;

  for (final resultType in ['mediaCollection', 'mediaMetadata']) {
    var rawItems = result[resultType];

    // If there is only 1 result, it is not put in an array
    if (rawItems != null && rawItems is! List) {
      rawItems = [rawItems];
    }

    if (rawItems != null) {
      for (final rawItem in rawItems as List) {
        final itemMap = rawItem as Map<String, dynamic>;

        final item = resultType == 'mediaMetadata'
            ? MediaMetadata.fromMusicService(service, itemMap)
            : MediaCollection.fromMusicService(service, itemMap);
        items.add(item);
      }
    }
  }

  return SearchResult(
    items,
    searchType,
    numberReturned ?? 0,
    totalMatches ?? 0,
    updateId,
  );
}

/// Class used to parse metadata from kwargs
abstract class MetadataDictBase {
  /// Valid fields for this class
  Set<String> get validFields;

  /// Field type conversions
  Map<String, Function> get types;

  /// The metadata dictionary
  late final Map<String, dynamic> metadata;

  /// Initialize from metadata dictionary
  MetadataDictBase(Map<String, dynamic> metadataDict) {
    _log.fine('MetadataDictBase.__init__ with: $metadataDict');

    // Check for invalid fields
    for (final key in metadataDict.keys) {
      if (!validFields.contains(key)) {
        _log.fine(
          'instantiated with invalid field "$key" and value: "${metadataDict[key]}"',
        );
      }
    }

    // Convert names and create metadata dict
    metadata = {};
    for (final entry in metadataDict.entries) {
      var value = entry.value;
      if (types.containsKey(entry.key)) {
        final conversionCallable = types[entry.key]!;
        value = conversionCallable(value);
      }
      metadata[camelToUnderscore(entry.key)] = value;
    }
  }

  /// Access metadata fields dynamically
  dynamic operator [](String key) {
    if (!metadata.containsKey(key)) {
      throw ArgumentError('Class $runtimeType has no attribute "$key"');
    }
    return metadata[key];
  }
}

/// Track metadata class
class TrackMetadata extends MetadataDictBase {
  TrackMetadata(super.metadataDict);

  @override
  Set<String> get validFields => {
    'artistId',
    'artist',
    'composerId',
    'composer',
    'albumId',
    'album',
    'albumArtURI',
    'albumArtistId',
    'albumArtist',
    'genreId',
    'genre',
    'duration',
    'canPlay',
    'canSkip',
    'canAddToFavorites',
    'rating',
    'trackNumber',
    'isFavorite',
  };

  @override
  Map<String, Function> get types => {
    'duration': (v) => int.parse(v.toString()),
    'canPlay': boolStr,
    'canSkip': boolStr,
    'canAddToFavorites': boolStr,
    'rating': (v) => int.parse(v.toString()),
    'trackNumber': (v) => int.parse(v.toString()),
    'isFavorite': boolStr,
  };
}

/// Stream metadata class
class StreamMetadata extends MetadataDictBase {
  StreamMetadata(super.metadataDict);

  @override
  Set<String> get validFields => {
    'currentHost',
    'currentShowId',
    'currentShow',
    'secondsRemaining',
    'secondsToNextShow',
    'bitrate',
    'logo',
    'hasOutOfBandMetadata',
    'description',
    'isEphemeral',
  };

  @override
  Map<String, Function> get types => {
    'secondsRemaining': (v) => int.parse(v.toString()),
    'secondsToNextShow': (v) => int.parse(v.toString()),
    'bitrate': (v) => int.parse(v.toString()),
    'hasOutOfBandMetadata': boolStr,
    'isEphemeral': boolStr,
  };
}

/// A base class for all music service items
abstract class MusicServiceItem extends DidlItem {
  /// The MusicService instance the item originates from
  final dynamic musicService;

  /// The metadata from the music service
  final Map<String, dynamic> serviceMetadata;

  MusicServiceItem({
    required super.itemId,
    required super.parentId,
    required super.title,
    required super.desc,
    required super.resources,
    required this.serviceMetadata,
    this.musicService,
  });
}

/// Base class for all media metadata items
class MediaMetadata extends MusicServiceItem {
  MediaMetadata({
    required super.itemId,
    required super.parentId,
    required super.title,
    required super.desc,
    required super.resources,
    required super.serviceMetadata,
    super.musicService,
  });

  /// Create from music service response
  static MediaMetadata fromMusicService(
    dynamic musicService,
    Map<String, dynamic> contentDict,
  ) {
    // Form the item_id
    final id = contentDict['id'] as String? ?? '';
    final quotedId = Uri.encodeComponent(id);
    // The hex prefix remains a mystery for now
    final itemId = '0fffffff$quotedId';

    // Form the uri
    const isTrack = true; // Simplified - should check class type
    final uri = formUri(itemId, musicService, isTrack);

    // Form resources and get desc
    final resources = [DidlResource(uri: uri, protocolInfo: 'DUMMY')];
    final desc = musicService.desc as String;
    final title = contentDict['title'] as String? ?? '';

    return MediaMetadata(
      itemId: itemId,
      parentId: 'DUMMY',
      title: title,
      desc: desc,
      resources: resources,
      serviceMetadata: contentDict,
      musicService: musicService,
    );
  }
}

/// Base class for all mediaCollection items
class MediaCollection extends MusicServiceItem {
  MediaCollection({
    required super.itemId,
    required super.parentId,
    required super.title,
    required super.desc,
    required super.resources,
    required super.serviceMetadata,
    super.musicService,
  });

  /// Create from music service response
  static MediaCollection fromMusicService(
    dynamic musicService,
    Map<String, dynamic> contentDict,
  ) {
    // Form the item_id
    final id = contentDict['id'] as String? ?? '';
    final quotedId = Uri.encodeComponent(id);
    final itemId = '0fffffff$quotedId';

    // Form the uri
    const isTrack = false;
    final uri = formUri(itemId, musicService, isTrack);

    // Form resources and get desc
    final resources = [DidlResource(uri: uri, protocolInfo: 'DUMMY')];
    final desc = musicService.desc as String;
    final title = contentDict['title'] as String? ?? '';

    return MediaCollection(
      itemId: itemId,
      parentId: 'DUMMY',
      title: title,
      desc: desc,
      resources: resources,
      serviceMetadata: contentDict,
      musicService: musicService,
    );
  }
}
