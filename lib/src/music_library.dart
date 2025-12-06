/// Access to the Music Library.
///
/// The Music Library is the collection of music stored on your local network.
/// For access to third party music streaming services, see the
/// `music_service` module.
library;

import 'package:xml/xml.dart';

import 'core.dart';
import 'data_structures.dart';
import 'data_structures_entry.dart';
import 'discovery.dart';
import 'exceptions.dart';
import 'services.dart';
import 'utils.dart';

/// The Music Library.
///
/// Provides access to browse and search the local music library, including
/// artists, albums, tracks, playlists, favorites, and radio stations.
class MusicLibrary {
  /// The SoCo instance to query for music library information
  final SoCo soco;

  /// The ContentDirectory service for this instance
  late final ContentDirectory contentDirectory;

  /// Key words used when performing searches
  static const Map<String, String> searchTranslation = {
    'artists': 'A:ARTIST',
    'album_artists': 'A:ALBUMARTIST',
    'albums': 'A:ALBUM',
    'genres': 'A:GENRE',
    'composers': 'A:COMPOSER',
    'tracks': 'A:TRACKS',
    'playlists': 'A:PLAYLISTS',
    'share': 'S:',
    'sonos_playlists': 'SQ:',
    'categories': 'A:',
    'sonos_favorites': 'FV:2',
    'radio_stations': 'R:0/0',
    'radio_shows': 'R:0/1',
  };

  /// Creates a MusicLibrary instance.
  ///
  /// Parameters:
  ///   - [soco]: A SoCo instance to query for music library information.
  ///     If `null`, a random SoCo instance will be used.
  MusicLibrary(SoCo? soco)
    : soco = soco ?? (throw ArgumentError('SoCo instance required')) {
    contentDirectory = this.soco.contentDirectory;
  }

  /// Creates a MusicLibrary instance from any available speaker.
  ///
  /// This will find any available SoCo instance and use it.
  static Future<MusicLibrary> create([SoCo? soco]) async {
    final speaker = soco ?? await anySoco();
    if (speaker == null) {
      throw SoCoException('No Sonos devices found on network');
    }
    return MusicLibrary(speaker);
  }

  /// Ensure an Album Art URI is an absolute URI.
  ///
  /// Parameters:
  ///   - [url]: the album art URI
  ///
  /// Returns:
  ///   An absolute URI
  String buildAlbumArtFullUri(String url) {
    // Add on the full album art link, as the URI version
    // does not include the IP address
    if (!url.startsWith('http:') && !url.startsWith('https:')) {
      return 'http://${soco.ipAddress}:1400$url';
    }
    return url;
  }

  /// Convert a Map representation from fromDidlString to a DidlObject.
  ///
  /// This handles the incomplete fromDidlString implementation that returns
  /// Maps instead of DidlObject instances.
  /// 
  /// This is public so it can be used by SoCo.getQueue().
  DidlObject mapToDidlObject(Map<String, dynamic> itemMap) {
    final cls = itemMap['class'] as Type;
    final element = itemMap['element'] as XmlElement;
    
    // Extract common attributes
    final titleEl = element
        .findElements('title', namespace: 'http://purl.org/dc/elements/1.1/')
        .firstOrNull;
    final title = titleEl?.innerText ?? '';
    final id = element.getAttribute('id') ?? '';
    final parentId = element.getAttribute('parentID') ?? '';
    final restricted = element.getAttribute('restricted') == 'true';
    
    // Extract resources
    final resources = <DidlResource>[];
    for (final resEl in element.findElements('res')) {
      final uri = resEl.innerText;
      final protocolInfo = resEl.getAttribute('protocolInfo') ?? '';
      if (uri.isNotEmpty && protocolInfo.isNotEmpty) {
        resources.add(DidlResource(uri: uri, protocolInfo: protocolInfo));
      }
    }
    
    // Create the appropriate DidlObject instance based on class type
    if (cls == DidlPlaylistContainer) {
      return DidlPlaylistContainer(
        title: title,
        parentId: parentId,
        itemId: id,
        restricted: restricted,
        resources: resources,
      );
    } else if (cls == DidlMusicAlbum) {
      return DidlMusicAlbum(
        title: title,
        parentId: parentId,
        itemId: id,
        restricted: restricted,
        resources: resources,
      );
    } else if (cls == DidlMusicArtist) {
      return DidlMusicArtist(
        title: title,
        parentId: parentId,
        itemId: id,
        restricted: restricted,
        resources: resources,
      );
    } else if (cls == DidlAlbum) {
      return DidlAlbum(
        title: title,
        parentId: parentId,
        itemId: id,
        restricted: restricted,
        resources: resources,
      );
    } else if (cls == DidlPerson) {
      return DidlPerson(
        title: title,
        parentId: parentId,
        itemId: id,
        restricted: restricted,
        resources: resources,
      );
    } else if (cls == DidlContainer) {
      return DidlContainer(
        title: title,
        parentId: parentId,
        itemId: id,
        restricted: restricted,
        resources: resources,
      );
    } else {
      // Fallback to base DidlObject
      return DidlObject(
        title: title,
        parentId: parentId,
        itemId: id,
        restricted: restricted,
        resources: resources,
      );
    }
  }

  /// Update an item's Album Art URI to be an absolute URI.
  ///
  /// Parameters:
  ///   - [item]: The item to update the URI for
  /// Update album art URI to full URI (public for use by SoCo.getQueue).
  void updateAlbumArtToFullUri(DidlObject item) {
    // Album art URI is stored in the metadata map
    final albumArtUri = item['album_art_uri'] as String?;
    if (albumArtUri != null) {
      item['album_art_uri'] = buildAlbumArtFullUri(albumArtUri);
    }
  }

  /// Convenience method for [getMusicLibraryInformation] with
  /// `searchType='artists'`.
  Future<SearchResult> getArtists({
    int start = 0,
    int maxItems = 100,
    bool fullAlbumArtUri = false,
    String? searchTerm,
    List<String>? subcategories,
    bool completeResult = false,
  }) {
    return getMusicLibraryInformation(
      'artists',
      start: start,
      maxItems: maxItems,
      fullAlbumArtUri: fullAlbumArtUri,
      searchTerm: searchTerm,
      subcategories: subcategories,
      completeResult: completeResult,
    );
  }

  /// Convenience method for [getMusicLibraryInformation] with
  /// `searchType='album_artists'`.
  Future<SearchResult> getAlbumArtists({
    int start = 0,
    int maxItems = 100,
    bool fullAlbumArtUri = false,
    String? searchTerm,
    List<String>? subcategories,
    bool completeResult = false,
  }) {
    return getMusicLibraryInformation(
      'album_artists',
      start: start,
      maxItems: maxItems,
      fullAlbumArtUri: fullAlbumArtUri,
      searchTerm: searchTerm,
      subcategories: subcategories,
      completeResult: completeResult,
    );
  }

  /// Convenience method for [getMusicLibraryInformation] with
  /// `searchType='albums'`.
  Future<SearchResult> getAlbums({
    int start = 0,
    int maxItems = 100,
    bool fullAlbumArtUri = false,
    String? searchTerm,
    List<String>? subcategories,
    bool completeResult = false,
  }) {
    return getMusicLibraryInformation(
      'albums',
      start: start,
      maxItems: maxItems,
      fullAlbumArtUri: fullAlbumArtUri,
      searchTerm: searchTerm,
      subcategories: subcategories,
      completeResult: completeResult,
    );
  }

  /// Convenience method for [getMusicLibraryInformation] with
  /// `searchType='genres'`.
  Future<SearchResult> getGenres({
    int start = 0,
    int maxItems = 100,
    bool fullAlbumArtUri = false,
    String? searchTerm,
    List<String>? subcategories,
    bool completeResult = false,
  }) {
    return getMusicLibraryInformation(
      'genres',
      start: start,
      maxItems: maxItems,
      fullAlbumArtUri: fullAlbumArtUri,
      searchTerm: searchTerm,
      subcategories: subcategories,
      completeResult: completeResult,
    );
  }

  /// Convenience method for [getMusicLibraryInformation] with
  /// `searchType='composers'`.
  Future<SearchResult> getComposers({
    int start = 0,
    int maxItems = 100,
    bool fullAlbumArtUri = false,
    String? searchTerm,
    List<String>? subcategories,
    bool completeResult = false,
  }) {
    return getMusicLibraryInformation(
      'composers',
      start: start,
      maxItems: maxItems,
      fullAlbumArtUri: fullAlbumArtUri,
      searchTerm: searchTerm,
      subcategories: subcategories,
      completeResult: completeResult,
    );
  }

  /// Convenience method for [getMusicLibraryInformation] with
  /// `searchType='tracks'`.
  Future<SearchResult> getTracks({
    int start = 0,
    int maxItems = 100,
    bool fullAlbumArtUri = false,
    String? searchTerm,
    List<String>? subcategories,
    bool completeResult = false,
  }) {
    return getMusicLibraryInformation(
      'tracks',
      start: start,
      maxItems: maxItems,
      fullAlbumArtUri: fullAlbumArtUri,
      searchTerm: searchTerm,
      subcategories: subcategories,
      completeResult: completeResult,
    );
  }

  /// Convenience method for [getMusicLibraryInformation] with
  /// `searchType='playlists'`.
  ///
  /// Note: The playlists that are referred to here are the playlists imported
  /// from the music library, they are not the Sonos playlists.
  Future<SearchResult> getPlaylists({
    int start = 0,
    int maxItems = 100,
    bool fullAlbumArtUri = false,
    String? searchTerm,
    List<String>? subcategories,
    bool completeResult = false,
  }) {
    return getMusicLibraryInformation(
      'playlists',
      start: start,
      maxItems: maxItems,
      fullAlbumArtUri: fullAlbumArtUri,
      searchTerm: searchTerm,
      subcategories: subcategories,
      completeResult: completeResult,
    );
  }

  /// Convenience method for [getMusicLibraryInformation] with
  /// `searchType='sonos_favorites'`.
  Future<SearchResult> getSonosFavorites({
    int start = 0,
    int maxItems = 100,
    bool fullAlbumArtUri = false,
    String? searchTerm,
    List<String>? subcategories,
    bool completeResult = false,
  }) {
    return getMusicLibraryInformation(
      'sonos_favorites',
      start: start,
      maxItems: maxItems,
      fullAlbumArtUri: fullAlbumArtUri,
      searchTerm: searchTerm,
      subcategories: subcategories,
      completeResult: completeResult,
    );
  }

  /// Convenience method for [getMusicLibraryInformation] with
  /// `searchType='radio_stations'`.
  Future<SearchResult> getFavoriteRadioStations({
    int start = 0,
    int maxItems = 100,
    bool fullAlbumArtUri = false,
    String? searchTerm,
    List<String>? subcategories,
    bool completeResult = false,
  }) {
    return getMusicLibraryInformation(
      'radio_stations',
      start: start,
      maxItems: maxItems,
      fullAlbumArtUri: fullAlbumArtUri,
      searchTerm: searchTerm,
      subcategories: subcategories,
      completeResult: completeResult,
    );
  }

  /// Convenience method for [getMusicLibraryInformation] with
  /// `searchType='radio_shows'`.
  Future<SearchResult> getFavoriteRadioShows({
    int start = 0,
    int maxItems = 100,
    bool fullAlbumArtUri = false,
    String? searchTerm,
    List<String>? subcategories,
    bool completeResult = false,
  }) {
    return getMusicLibraryInformation(
      'radio_shows',
      start: start,
      maxItems: maxItems,
      fullAlbumArtUri: fullAlbumArtUri,
      searchTerm: searchTerm,
      subcategories: subcategories,
      completeResult: completeResult,
    );
  }

  /// Retrieve music information objects from the music library.
  ///
  /// This method is the main method to get music information items, like
  /// e.g. tracks, albums etc., from the music library. It can be used in
  /// a few different ways:
  ///
  /// The [searchTerm] argument performs a fuzzy search on that string in
  /// the results, so e.g calling:
  /// ```dart
  /// getMusicLibraryInformation('artists', searchTerm: 'Metallica')
  /// ```
  /// will perform a fuzzy search for the term 'Metallica' among all the
  /// artists.
  ///
  /// Using the [subcategories] argument, will jump directly into that
  /// subcategory of the search and return results from there. So. e.g
  /// knowing that among the artist is one called 'Metallica', calling:
  /// ```dart
  /// getMusicLibraryInformation('artists', subcategories: ['Metallica'])
  /// ```
  /// will jump directly into the 'Metallica' sub category and return the
  /// albums associated with Metallica and:
  /// ```dart
  /// getMusicLibraryInformation('artists',
  ///     subcategories: ['Metallica', 'Black'])
  /// ```
  /// will return the tracks of the album 'Black' by the artist 'Metallica'.
  /// The order of sub category types is: Genres->Artists->Albums->Tracks.
  /// It is also possible to combine the two, to perform a fuzzy search in a
  /// sub category.
  ///
  /// The [start], [maxItems] and [completeResult] arguments all
  /// have to do with paging of the results. By default the searches are
  /// always paged, because there is a limit to how many items we can get at
  /// a time. This paging is exposed to the user with the [start] and
  /// [maxItems] arguments. So calling:
  /// ```dart
  /// getMusicLibraryInformation('artists', start: 0, maxItems: 100)
  /// getMusicLibraryInformation('artists', start: 100, maxItems: 100)
  /// ```
  /// will get the first and next 100 items, respectively. It is also
  /// possible to ask for all the elements at once:
  /// ```dart
  /// getMusicLibraryInformation('artists', completeResult: true)
  /// ```
  /// This will perform the paging internally and simply return all the
  /// items.
  ///
  /// Parameters:
  ///   - [searchType]: The kind of information to retrieve. Can be one of:
  ///     'artists', 'album_artists', 'albums', 'genres', 'composers',
  ///     'tracks', 'share', 'sonos_playlists', 'sonos_favorites',
  ///     'radio_stations', 'radio_shows', or 'playlists', where playlists
  ///     are the imported playlists from the music library.
  ///   - [start]: starting number of returned matches (zero based). Default 0.
  ///   - [maxItems]: Maximum number of returned matches. Default 100.
  ///   - [fullAlbumArtUri]: whether the album art URI should be absolute
  ///     (i.e. including the IP address). Default `false`.
  ///   - [searchTerm]: a string that will be used to perform a fuzzy search
  ///     among the search results. If used in combination with subcategories,
  ///     the fuzzy search will be performed in the subcategory.
  ///   - [subcategories]: A list of strings that indicate one or more
  ///     subcategories to dive into.
  ///   - [completeResult]: if `true`, will disable paging (ignore [start]
  ///     and [maxItems]) and return all results for the search.
  ///
  /// Returns:
  ///   An instance of [SearchResult].
  ///
  /// Warning:
  ///   Getting e.g. all the tracks in a large collection might take some time.
  ///
  /// Note:
  ///   - The maximum number of results may be restricted by the unit,
  ///     presumably due to transfer size consideration, so check the
  ///     returned number against that requested.
  ///   - The playlists that are returned with the 'playlists' search,
  ///     are the playlists imported from the music library, they
  ///     are not the Sonos playlists.
  Future<SearchResult> getMusicLibraryInformation(
    String searchType, {
    int start = 0,
    int maxItems = 100,
    bool fullAlbumArtUri = false,
    String? searchTerm,
    List<String>? subcategories,
    bool completeResult = false,
  }) async {
    final searchPrefix = searchTranslation[searchType];
    if (searchPrefix == null) {
      throw ArgumentError('Unknown search type: $searchType');
    }
    var search = searchPrefix;

    // Add sub categories
    // sub categories are not allowed when searching shares
    if (subcategories != null && searchType != 'share') {
      for (final category in subcategories) {
        search = '$search/${urlEscapePath(category)}';
      }
    }

    // Add fuzzy search
    if (searchTerm != null) {
      if (searchType == 'share') {
        // Don't insert ":" and don't escape "/" (use Uri.encodeComponent)
        search = '$search${Uri.encodeComponent(searchTerm)}';
      } else {
        search = '$search:${urlEscapePath(searchTerm)}';
      }
    }

    final itemList = <DidlObject>[];
    var totalMatches = 100000;
    var numberReturned = 0;
    int? updateId;

    while (itemList.length < totalMatches) {
      // Change start and max for complete searches
      var currentStart = start;
      var currentMax = maxItems;
      if (completeResult) {
        currentStart = itemList.length;
        currentMax = 100000;
      }

      // Try and get this batch of results
      Map<String, dynamic> response;
      Map<String, int> metadata;
      try {
        final result = await _musicLibSearch(search, currentStart, currentMax);
        response = result.$1;
        metadata = result.$2;
        numberReturned = metadata['number_returned']!;
        totalMatches = metadata['total_matches']!;
        updateId = metadata['update_id'];
      } on SoCoUPnPException catch (exception) {
        // 'No such object' UPnP errors
        if (exception.errorCode == '701') {
          return SearchResult([], searchType, 0, 0, null);
        } else {
          rethrow;
        }
      }

      // Parse the results
      final items = fromDidlString(response['Result'] as String);
      for (final item in items) {
        // Check if the album art URI should be fully qualified
        if (fullAlbumArtUri) {
          updateAlbumArtToFullUri(item);
        }
        // Append the item to the list
        itemList.add(item);
      }

      // If we are not after the complete results, then stop after 1 iteration
      if (!completeResult) {
        break;
      }
    }

    if (completeResult) {
      numberReturned = itemList.length;
    }

    return SearchResult(
      itemList,
      searchType,
      numberReturned,
      totalMatches,
      updateId,
    );
  }

  /// Browse (get sub-elements from) a music library item.
  ///
  /// Parameters:
  ///   - [mlItem]: the item to browse, if left out or `null`, items at the
  ///     root level will be searched.
  ///   - [start]: the starting index of the results.
  ///   - [maxItems]: the maximum number of items to return.
  ///   - [fullAlbumArtUri]: whether the album art URI should be fully
  ///     qualified with the relevant IP address.
  ///   - [searchTerm]: A string that will be used to perform a fuzzy search
  ///     among the search results. If used in combination with subcategories,
  ///     the fuzzy search will be performed on the subcategory.
  ///     Note: Searching will not work if [mlItem] is `null`.
  ///   - [subcategories]: A list of strings that indicate one or more
  ///     subcategories to descend into. Note: Providing sub categories
  ///     will not work if [mlItem] is `null`.
  ///
  /// Returns:
  ///   A [SearchResult] instance.
  Future<SearchResult> browse({
    DidlObject? mlItem,
    int start = 0,
    int maxItems = 100,
    bool fullAlbumArtUri = false,
    String? searchTerm,
    List<String>? subcategories,
  }) async {
    var search = mlItem == null ? 'A:' : mlItem.itemId;

    // Add sub categories
    if (subcategories != null) {
      for (final category in subcategories) {
        search += '/${urlEscapePath(category)}';
      }
    }

    // Add fuzzy search
    if (searchTerm != null) {
      search += ':${urlEscapePath(searchTerm)}';
    }

    Map<String, dynamic> response;
    Map<String, int> metadata;
    try {
      final result = await _musicLibSearch(search, start, maxItems);
      response = result.$1;
      metadata = result.$2;
    } on SoCoUPnPException catch (exception) {
      // 'No such object' UPnP errors
      if (exception.errorCode == '701') {
        return SearchResult([], 'browse', 0, 0, null);
      } else {
        rethrow;
      }
    }

    // Parse the results
    final containers = fromDidlString(response['Result'] as String);
    final itemList = <DidlObject>[];
    for (final container in containers) {
      // Check if the album art URI should be fully qualified
      if (fullAlbumArtUri) {
        updateAlbumArtToFullUri(container);
      }
      itemList.add(container);
    }

    return SearchResult(
      itemList,
      'browse',
      metadata['number_returned']!,
      metadata['total_matches']!,
      metadata['update_id'],
    );
  }

  /// Browse (get sub-elements from) a given music library item, specified by
  /// a string.
  ///
  /// Parameters:
  ///   - [searchType]: The kind of information to retrieve. Can be one of:
  ///     'artists', 'album_artists', 'albums', 'genres', 'composers',
  ///     'tracks', 'share', 'sonos_playlists', and 'playlists', where
  ///     playlists are the imported file based playlists from the music
  ///     library.
  ///   - [idstring]: a term to search for.
  ///   - [start]: starting number of returned matches. Default 0.
  ///   - [maxItems]: Maximum number of returned matches. Default 100.
  ///   - [fullAlbumArtUri]: whether the album art URI should be absolute
  ///     (i.e. including the IP address). Default `false`.
  ///
  /// Returns:
  ///   A [SearchResult] instance.
  ///
  /// Note:
  ///   The maximum number of results may be restricted by the unit,
  ///   presumably due to transfer size consideration, so check the
  ///   returned number against that requested.
  Future<SearchResult> browseByIdstring(
    String searchType,
    String idstring, {
    int start = 0,
    int maxItems = 100,
    bool fullAlbumArtUri = false,
  }) async {
    var search = searchTranslation[searchType];
    if (search == null) {
      throw ArgumentError('Unknown search type: $searchType');
    }

    // Check if the string ID already has the type, if so we do not want to
    // add one also Imported playlist have a full path to them, so they do
    // not require the A:PLAYLISTS part first
    if (idstring.startsWith(search) || searchType == 'playlists') {
      search = '';
    }

    final searchItemId = search + idstring;
    final searchUri = '#$searchItemId';
    // Not sure about the res protocol. But this seems to work
    final res = [
      DidlResource(uri: searchUri, protocolInfo: 'x-rincon-playlist:*:*:*'),
    ];
    final searchItem = DidlObject(
      resources: res,
      title: '',
      parentId: '',
      itemId: searchItemId,
    );

    // Call the base version
    return browse(
      mlItem: searchItem,
      start: start,
      maxItems: maxItems,
      fullAlbumArtUri: fullAlbumArtUri,
    );
  }

  /// Perform a music library search and extract search numbers.
  ///
  /// You can get an overview of all the relevant search prefixes (like 'A:')
  /// and their meaning with the request:
  /// ```dart
  /// final response = await device.contentDirectory.sendCommand('Browse',
  ///   args: [
  ///     MapEntry('ObjectID', '0'),
  ///     MapEntry('BrowseFlag', 'BrowseDirectChildren'),
  ///     MapEntry('Filter', '*'),
  ///     MapEntry('StartingIndex', 0),
  ///     MapEntry('RequestedCount', 100),
  ///     MapEntry('SortCriteria', ''),
  ///   ]
  /// );
  /// ```
  ///
  /// Parameters:
  ///   - [search]: The ID to search.
  ///   - [start]: The index of the first item to return.
  ///   - [maxItems]: The maximum number of items to return.
  ///
  /// Returns:
  ///   A tuple (response, metadata) where response is the returned metadata
  ///   and metadata is a dict with the 'number_returned', 'total_matches'
  ///   and 'update_id' integers.
  Future<(Map<String, dynamic>, Map<String, int>)> _musicLibSearch(
    String search,
    int start,
    int maxItems,
  ) async {
    final response = await contentDirectory.sendCommand(
      'Browse',
      args: [
        MapEntry('ObjectID', search),
        MapEntry('BrowseFlag', 'BrowseDirectChildren'),
        MapEntry('Filter', '*'),
        MapEntry('StartingIndex', start),
        MapEntry('RequestedCount', maxItems),
        MapEntry('SortCriteria', ''),
      ],
    );

    // Get result information
    final metadata = <String, int>{};
    for (final tag in ['NumberReturned', 'TotalMatches', 'UpdateID']) {
      metadata[camelToUnderscore(tag)] = int.parse(response[tag] ?? '0');
    }

    return (response, metadata);
  }
}
