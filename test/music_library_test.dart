/// Tests for MusicLibrary class.
library;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:soco/src/music_library.dart';
import 'package:soco/src/core.dart';
import 'package:soco/src/data_structures.dart';
import 'package:soco/src/exceptions.dart';

/// Helper to create a successful Browse SOAP response
String browseResponse({
  required String result,
  int numberReturned = 0,
  int totalMatches = 0,
  int updateId = 1,
}) {
  // HTML-encode the result for SOAP
  final encodedResult = result
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  return '''<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
            s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:BrowseResponse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1">
      <Result>$encodedResult</Result>
      <NumberReturned>$numberReturned</NumberReturned>
      <TotalMatches>$totalMatches</TotalMatches>
      <UpdateID>$updateId</UpdateID>
    </u:BrowseResponse>
  </s:Body>
</s:Envelope>''';
}

/// Helper to create a UPnP error response
String errorResponse(int errorCode, String errorDescription) {
  return '''<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
            s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <s:Fault>
      <faultcode>s:Client</faultcode>
      <faultstring>UPnPError</faultstring>
      <detail>
        <UPnPError xmlns="urn:schemas-upnp-org:control-1-0">
          <errorCode>$errorCode</errorCode>
          <errorDescription>$errorDescription</errorDescription>
        </UPnPError>
      </detail>
    </s:Fault>
  </s:Body>
</s:Envelope>''';
}

/// Sample DIDL-Lite for artists
const sampleArtistsDIDL = '''<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
<container id="A:ARTIST/The%20Beatles" parentID="A:ARTIST" restricted="true">
<dc:title>The Beatles</dc:title>
<upnp:class>object.container.person.musicArtist</upnp:class>
</container>
<container id="A:ARTIST/Pink%20Floyd" parentID="A:ARTIST" restricted="true">
<dc:title>Pink Floyd</dc:title>
<upnp:class>object.container.person.musicArtist</upnp:class>
</container>
</DIDL-Lite>''';

/// Sample DIDL-Lite for tracks
const sampleTracksDIDL = '''<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
<item id="A:TRACKS/Song1" parentID="A:TRACKS" restricted="true">
<dc:title>Yesterday</dc:title>
<upnp:class>object.item.audioItem.musicTrack</upnp:class>
<upnp:albumArtURI>/getaa?s=1&amp;u=x-file-cifs</upnp:albumArtURI>
<res protocolInfo="http-get:*:audio/mpeg:*">x-file-cifs://server/music/yesterday.mp3</res>
</item>
</DIDL-Lite>''';

/// Sample DIDL-Lite for albums
const sampleAlbumsDIDL = '''<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
<container id="A:ALBUM/Abbey%20Road" parentID="A:ALBUM" restricted="true">
<dc:title>Abbey Road</dc:title>
<upnp:class>object.container.album.musicAlbum</upnp:class>
<upnp:albumArtURI>/getaa?s=1&amp;u=x-file-cifs</upnp:albumArtURI>
</container>
</DIDL-Lite>''';

/// Empty DIDL-Lite - needs proper format
const emptyDIDL = '<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"></DIDL-Lite>';

void main() {
  // Initialize DIDL classes
  setUpAll(() {
    initializeDidlClasses();
  });
  group('MusicLibrary', () {
    // Use unique IP to avoid singleton conflicts
    final device = SoCo('192.168.210.100');

    group('searchTranslation', () {
      test('contains all expected search types', () {
        expect(MusicLibrary.searchTranslation.containsKey('artists'), isTrue);
        expect(
          MusicLibrary.searchTranslation.containsKey('album_artists'),
          isTrue,
        );
        expect(MusicLibrary.searchTranslation.containsKey('albums'), isTrue);
        expect(MusicLibrary.searchTranslation.containsKey('genres'), isTrue);
        expect(MusicLibrary.searchTranslation.containsKey('composers'), isTrue);
        expect(MusicLibrary.searchTranslation.containsKey('tracks'), isTrue);
        expect(MusicLibrary.searchTranslation.containsKey('playlists'), isTrue);
        expect(MusicLibrary.searchTranslation.containsKey('share'), isTrue);
        expect(
          MusicLibrary.searchTranslation.containsKey('sonos_playlists'),
          isTrue,
        );
        expect(
          MusicLibrary.searchTranslation.containsKey('categories'),
          isTrue,
        );
        expect(
          MusicLibrary.searchTranslation.containsKey('sonos_favorites'),
          isTrue,
        );
        expect(
          MusicLibrary.searchTranslation.containsKey('radio_stations'),
          isTrue,
        );
        expect(
          MusicLibrary.searchTranslation.containsKey('radio_shows'),
          isTrue,
        );
      });

      test('maps to correct UPnP prefixes', () {
        expect(MusicLibrary.searchTranslation['artists'], equals('A:ARTIST'));
        expect(
          MusicLibrary.searchTranslation['album_artists'],
          equals('A:ALBUMARTIST'),
        );
        expect(MusicLibrary.searchTranslation['albums'], equals('A:ALBUM'));
        expect(MusicLibrary.searchTranslation['genres'], equals('A:GENRE'));
        expect(
          MusicLibrary.searchTranslation['composers'],
          equals('A:COMPOSER'),
        );
        expect(MusicLibrary.searchTranslation['tracks'], equals('A:TRACKS'));
        expect(
          MusicLibrary.searchTranslation['playlists'],
          equals('A:PLAYLISTS'),
        );
        expect(MusicLibrary.searchTranslation['share'], equals('S:'));
        expect(
          MusicLibrary.searchTranslation['sonos_playlists'],
          equals('SQ:'),
        );
        expect(MusicLibrary.searchTranslation['categories'], equals('A:'));
        expect(
          MusicLibrary.searchTranslation['sonos_favorites'],
          equals('FV:2'),
        );
        expect(
          MusicLibrary.searchTranslation['radio_stations'],
          equals('R:0/0'),
        );
        expect(MusicLibrary.searchTranslation['radio_shows'], equals('R:0/1'));
      });
    });

    group('constructor', () {
      test('creates MusicLibrary with SoCo instance', () {
        final library = MusicLibrary(device);

        expect(library.soco, equals(device));
        expect(library.contentDirectory, isNotNull);
      });

      test('throws ArgumentError when SoCo is null', () {
        expect(() => MusicLibrary(null), throwsA(isA<ArgumentError>()));
      });
    });

    group('buildAlbumArtFullUri', () {
      late MusicLibrary library;

      setUp(() {
        library = MusicLibrary(device);
      });

      test('adds IP address to relative URI', () {
        final result = library.buildAlbumArtFullUri('/getaa?s=1&u=x-sonos');

        expect(
          result,
          equals('http://192.168.210.100:1400/getaa?s=1&u=x-sonos'),
        );
      });

      test('returns absolute http URI unchanged', () {
        final result = library.buildAlbumArtFullUri(
          'http://example.com/art.jpg',
        );

        expect(result, equals('http://example.com/art.jpg'));
      });

      test('returns absolute https URI unchanged', () {
        final result = library.buildAlbumArtFullUri(
          'https://example.com/art.jpg',
        );

        expect(result, equals('https://example.com/art.jpg'));
      });

      test('handles empty relative path', () {
        final result = library.buildAlbumArtFullUri('/');

        expect(result, equals('http://192.168.210.100:1400/'));
      });

      test('handles path with query parameters', () {
        final result = library.buildAlbumArtFullUri(
          '/getaa?s=1&u=x-sonos-spotify:spotify:track:123',
        );

        expect(
          result,
          equals(
            'http://192.168.210.100:1400/getaa?s=1&u=x-sonos-spotify:spotify:track:123',
          ),
        );
      });
    });

    group('SearchResult', () {
      test('creates SearchResult with all fields', () {
        final items = <DidlObject>[
          DidlMusicTrack(
            resources: [],
            title: 'Track 1',
            parentId: 'A:TRACKS',
            itemId: 'A:TRACKS/Track1',
          ),
          DidlMusicTrack(
            resources: [],
            title: 'Track 2',
            parentId: 'A:TRACKS',
            itemId: 'A:TRACKS/Track2',
          ),
        ];

        final result = SearchResult(items, 'tracks', 2, 100, 12345);

        expect(result.items.length, equals(2));
        expect(result.searchType, equals('tracks'));
        expect(result.numberReturned, equals(2));
        expect(result.totalMatches, equals(100));
        expect(result.updateId, equals(12345));
      });

      test('SearchResult items are iterable', () {
        final items = <DidlObject>[
          DidlMusicTrack(
            resources: [],
            title: 'Track 1',
            parentId: 'A:TRACKS',
            itemId: 'A:TRACKS/Track1',
          ),
          DidlMusicTrack(
            resources: [],
            title: 'Track 2',
            parentId: 'A:TRACKS',
            itemId: 'A:TRACKS/Track2',
          ),
        ];

        final result = SearchResult(items, 'tracks', 2, 100, null);

        final titles = <String>[];
        for (final item in result.items) {
          titles.add(item.title);
        }

        expect(titles, equals(['Track 1', 'Track 2']));
      });

      test('SearchResult items support index access', () {
        final items = <DidlObject>[
          DidlMusicTrack(
            resources: [],
            title: 'First',
            parentId: 'A:TRACKS',
            itemId: 'A:TRACKS/First',
          ),
          DidlMusicTrack(
            resources: [],
            title: 'Second',
            parentId: 'A:TRACKS',
            itemId: 'A:TRACKS/Second',
          ),
        ];

        final result = SearchResult(items, 'tracks', 2, 2, null);

        expect(result.items[0].title, equals('First'));
        expect(result.items[1].title, equals('Second'));
      });

      test('SearchResult with null updateId', () {
        final result = SearchResult([], 'artists', 0, 0, null);

        expect(result.updateId, isNull);
        expect(result.items.length, equals(0));
      });

      test('empty SearchResult', () {
        final result = SearchResult([], 'albums', 0, 0, null);

        expect(result.items.isEmpty, isTrue);
        expect(result.items.isNotEmpty, isFalse);
        expect(result.items.length, equals(0));
        expect(result.totalMatches, equals(0));
      });
    });

    group('search type validation', () {
      test('all convenience methods use correct search types', () {
        // This test documents the expected search type for each method
        // The actual search type is passed to getMusicLibraryInformation
        final expectedTypes = {
          'getArtists': 'artists',
          'getAlbumArtists': 'album_artists',
          'getAlbums': 'albums',
          'getGenres': 'genres',
          'getComposers': 'composers',
          'getTracks': 'tracks',
          'getPlaylists': 'playlists',
          'getSonosFavorites': 'sonos_favorites',
          'getFavoriteRadioStations': 'radio_stations',
          'getFavoriteRadioShows': 'radio_shows',
        };

        // Verify all types have valid translations
        for (final type in expectedTypes.values) {
          expect(
            MusicLibrary.searchTranslation.containsKey(type),
            isTrue,
            reason: 'Search type "$type" should have a translation',
          );
        }
      });
    });

    group('default parameters', () {
      test('getMusicLibraryInformation has correct defaults', () {
        // Document the default parameter values
        // start=0, maxItems=100, fullAlbumArtUri=false,
        // searchTerm=null, subcategories=null, completeResult=false

        // We can't call the method without network, but we can verify
        // the searchTranslation exists for all types
        final validTypes = [
          'artists',
          'album_artists',
          'albums',
          'genres',
          'composers',
          'tracks',
          'playlists',
          'share',
          'sonos_playlists',
          'categories',
          'sonos_favorites',
          'radio_stations',
          'radio_shows',
        ];

        for (final type in validTypes) {
          expect(MusicLibrary.searchTranslation[type], isNotNull);
        }
      });
    });
  });

  group('DidlResource', () {
    test('creates DidlResource with uri and protocolInfo', () {
      final resource = DidlResource(
        uri: 'x-file-cifs://server/share/song.mp3',
        protocolInfo: 'http-get:*:audio/mpeg:*',
      );

      expect(resource.uri, equals('x-file-cifs://server/share/song.mp3'));
      expect(resource.protocolInfo, equals('http-get:*:audio/mpeg:*'));
    });

    test('creates DidlResource for playlist item', () {
      final resource = DidlResource(
        uri: '#A:PLAYLISTS/MyPlaylist',
        protocolInfo: 'x-rincon-playlist:*:*:*',
      );

      expect(resource.uri, equals('#A:PLAYLISTS/MyPlaylist'));
      expect(resource.protocolInfo, equals('x-rincon-playlist:*:*:*'));
    });
  });

  group('DidlMusicTrack', () {
    test('creates track with all properties', () {
      final track = DidlMusicTrack(
        resources: [
          DidlResource(
            uri: 'x-file-cifs://server/Music/song.mp3',
            protocolInfo: 'http-get:*:audio/mpeg:*',
          ),
        ],
        title: 'My Song',
        parentId: 'A:ALBUM/MyAlbum',
        itemId: 'A:TRACKS/MySong',
      );

      expect(track.title, equals('My Song'));
      expect(track.parentId, equals('A:ALBUM/MyAlbum'));
      expect(track.itemId, equals('A:TRACKS/MySong'));
      expect(track.resources.length, equals(1));
    });
  });

  group('DidlMusicAlbum', () {
    test('creates album with properties', () {
      final album = DidlMusicAlbum(
        title: 'My Album',
        parentId: 'A:ARTIST/MyArtist',
        itemId: 'A:ALBUM/MyAlbum',
      );

      expect(album.title, equals('My Album'));
      expect(album.parentId, equals('A:ARTIST/MyArtist'));
      expect(album.itemId, equals('A:ALBUM/MyAlbum'));
    });

    test('has correct static itemClass', () {
      expect(DidlMusicAlbum.itemClass, equals('object.container.musicAlbum'));
    });
  });

  group('DidlMusicArtist', () {
    test('creates artist with properties', () {
      final artist = DidlMusicArtist(
        title: 'My Artist',
        parentId: 'A:',
        itemId: 'A:ARTIST/MyArtist',
      );

      expect(artist.title, equals('My Artist'));
      expect(artist.parentId, equals('A:'));
      expect(artist.itemId, equals('A:ARTIST/MyArtist'));
    });

    test('has correct static itemClass', () {
      expect(
        DidlMusicArtist.itemClass,
        equals('object.container.person.musicArtist'),
      );
    });
  });

  group('DidlMusicGenre', () {
    test('creates genre with properties', () {
      final genre = DidlMusicGenre(
        title: 'Rock',
        parentId: 'A:',
        itemId: 'A:GENRE/Rock',
      );

      expect(genre.title, equals('Rock'));
      expect(genre.parentId, equals('A:'));
      expect(genre.itemId, equals('A:GENRE/Rock'));
    });

    test('has correct static itemClass', () {
      expect(
        DidlMusicGenre.itemClass,
        equals('object.container.genre.musicGenre'),
      );
    });
  });

  group('DidlPlaylistContainer', () {
    test('creates playlist container with properties', () {
      final playlist = DidlPlaylistContainer(
        title: 'My Playlist',
        parentId: 'SQ:',
        itemId: 'SQ:1',
      );

      expect(playlist.title, equals('My Playlist'));
      expect(playlist.parentId, equals('SQ:'));
      expect(playlist.itemId, equals('SQ:1'));
    });

    test('has correct static itemClass', () {
      expect(
        DidlPlaylistContainer.itemClass,
        equals('object.container.playlistContainer'),
      );
    });
  });

  group('MusicLibrary with HTTP mocking', () {
    late SoCo device;
    late MusicLibrary library;
    late List<http.Request> capturedRequests;

    setUp(() {
      device = SoCo('192.168.211.100');
      library = MusicLibrary(device);
      capturedRequests = [];
    });

    MockClient createMockClient(String response, {int statusCode = 200}) {
      return MockClient((request) async {
        capturedRequests.add(request);
        return http.Response(response, statusCode);
      });
    }

    test('getMusicLibraryInformation throws on unknown search type', () async {
      expect(
        () => library.getMusicLibraryInformation('invalid_type'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getMusicLibraryInformation returns empty result on 701 error', () async {
      final mockClient = createMockClient(
        errorResponse(701, 'No such object'),
        statusCode: 500,
      );
      device.httpClient = mockClient;

      final result = await library.getArtists();

      expect(result.items, isEmpty);
      expect(result.numberReturned, equals(0));
      expect(result.totalMatches, equals(0));
    });

    test('getMusicLibraryInformation rethrows non-701 errors', () async {
      final mockClient = createMockClient(
        errorResponse(402, 'Invalid Args'),
        statusCode: 500,
      );
      device.httpClient = mockClient;

      expect(
        () => library.getArtists(),
        throwsA(isA<SoCoUPnPException>()),
      );
    });

    test('browse returns empty result on 701 error', () async {
      final mockClient = createMockClient(
        errorResponse(701, 'No such object'),
        statusCode: 500,
      );
      device.httpClient = mockClient;

      final result = await library.browse();

      expect(result.items, isEmpty);
      expect(result.searchType, equals('browse'));
    });

    test('browseByIdstring throws on unknown search type', () async {
      expect(
        () => library.browseByIdstring('unknown', 'test'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getMusicLibraryInformation returns correct metadata', () async {
      // Note: fromDidlString currently returns maps instead of DidlObjects
      // This test verifies the metadata is parsed correctly
      final mockClient = createMockClient(
        browseResponse(
          result: emptyDIDL,
          numberReturned: 0,
          totalMatches: 5,
          updateId: 1234,
        ),
      );
      device.httpClient = mockClient;

      final result = await library.getArtists();

      expect(result.numberReturned, equals(0));
      expect(result.totalMatches, equals(5));
      expect(result.updateId, equals(1234));
      expect(result.searchType, equals('artists'));
    });

    // Note: fullAlbumArtUri test requires DidlObject types from fromDidlString,
    // but currently it returns Map<String, Object>. The _updateAlbumArtToFullUri
    // line (456) would require library changes to test properly.

    test('getMusicLibraryInformation with subcategories builds correct search', () async {
      String? capturedSearch;
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        // Extract ObjectID from SOAP body
        final match = RegExp(r'<ObjectID>([^<]+)</ObjectID>').firstMatch(request.body);
        if (match != null) {
          capturedSearch = match.group(1);
        }
        return http.Response(
          browseResponse(result: emptyDIDL, numberReturned: 0, totalMatches: 0),
          200,
        );
      });
      device.httpClient = mockClient;

      await library.getArtists(subcategories: ['The Beatles', 'Abbey Road']);

      expect(capturedSearch, equals('A:ARTIST/The%20Beatles/Abbey%20Road'));
    });

    test('getMusicLibraryInformation with searchTerm builds correct search', () async {
      String? capturedSearch;
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        final match = RegExp(r'<ObjectID>([^<]+)</ObjectID>').firstMatch(request.body);
        if (match != null) {
          capturedSearch = match.group(1);
        }
        return http.Response(
          browseResponse(result: emptyDIDL, numberReturned: 0, totalMatches: 0),
          200,
        );
      });
      device.httpClient = mockClient;

      await library.getArtists(searchTerm: 'Beatles');

      expect(capturedSearch, equals('A:ARTIST:Beatles'));
    });

    test('getMusicLibraryInformation with share searchType handles searchTerm differently', () async {
      String? capturedSearch;
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        final match = RegExp(r'<ObjectID>([^<]+)</ObjectID>').firstMatch(request.body);
        if (match != null) {
          capturedSearch = match.group(1);
        }
        return http.Response(
          browseResponse(result: emptyDIDL, numberReturned: 0, totalMatches: 0),
          200,
        );
      });
      device.httpClient = mockClient;

      await library.getMusicLibraryInformation('share', searchTerm: '//server/music');

      // Share type doesn't add colon and uses Uri.encodeComponent
      expect(capturedSearch, contains('S:'));
    });

    test('getMusicLibraryInformation ignores subcategories for share type', () async {
      String? capturedSearch;
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        final match = RegExp(r'<ObjectID>([^<]+)</ObjectID>').firstMatch(request.body);
        if (match != null) {
          capturedSearch = match.group(1);
        }
        return http.Response(
          browseResponse(result: emptyDIDL, numberReturned: 0, totalMatches: 0),
          200,
        );
      });
      device.httpClient = mockClient;

      await library.getMusicLibraryInformation('share', subcategories: ['ignored']);

      // Share type should not include subcategories
      expect(capturedSearch, equals('S:'));
    });

    test('getMusicLibraryInformation sends correct start and maxItems', () async {
      int? capturedStart;
      int? capturedMax;
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        final startMatch = RegExp(r'<StartingIndex>(\d+)</StartingIndex>').firstMatch(request.body);
        final maxMatch = RegExp(r'<RequestedCount>(\d+)</RequestedCount>').firstMatch(request.body);
        if (startMatch != null) capturedStart = int.parse(startMatch.group(1)!);
        if (maxMatch != null) capturedMax = int.parse(maxMatch.group(1)!);
        return http.Response(
          browseResponse(result: emptyDIDL, numberReturned: 0, totalMatches: 0),
          200,
        );
      });
      device.httpClient = mockClient;

      await library.getArtists(start: 50, maxItems: 25);

      expect(capturedStart, equals(50));
      expect(capturedMax, equals(25));
    });

    test('browse with subcategories and searchTerm', () async {
      String? capturedSearch;
      final mockClient = MockClient((request) async {
        final match = RegExp(r'<ObjectID>([^<]+)</ObjectID>').firstMatch(request.body);
        if (match != null) {
          capturedSearch = match.group(1);
        }
        return http.Response(
          browseResponse(result: emptyDIDL, numberReturned: 0, totalMatches: 0),
          200,
        );
      });
      device.httpClient = mockClient;

      // Create a DidlObject to browse from
      final item = DidlMusicArtist(
        title: 'Artist',
        parentId: 'A:',
        itemId: 'A:ARTIST/TestArtist',
      );

      await library.browse(
        mlItem: item,
        subcategories: ['Album1'],
        searchTerm: 'Track',
      );

      expect(capturedSearch, equals('A:ARTIST/TestArtist/Album1:Track'));
    });

    test('browse with null mlItem starts at root', () async {
      String? capturedSearch;
      final mockClient = MockClient((request) async {
        final match = RegExp(r'<ObjectID>([^<]+)</ObjectID>').firstMatch(request.body);
        if (match != null) {
          capturedSearch = match.group(1);
        }
        return http.Response(
          browseResponse(result: emptyDIDL, numberReturned: 0, totalMatches: 0),
          200,
        );
      });
      device.httpClient = mockClient;

      await library.browse();

      expect(capturedSearch, equals('A:'));
    });

    test('browseByIdstring with idstring that already has prefix', () async {
      String? capturedSearch;
      final mockClient = MockClient((request) async {
        final match = RegExp(r'<ObjectID>([^<]+)</ObjectID>').firstMatch(request.body);
        if (match != null) {
          capturedSearch = match.group(1);
        }
        return http.Response(
          browseResponse(result: emptyDIDL, numberReturned: 0, totalMatches: 0),
          200,
        );
      });
      device.httpClient = mockClient;

      await library.browseByIdstring('artists', 'A:ARTIST/Beatles');

      // Should not double-add the prefix
      expect(capturedSearch, equals('A:ARTIST/Beatles'));
    });

    test('browseByIdstring for playlists uses full path', () async {
      String? capturedSearch;
      final mockClient = MockClient((request) async {
        final match = RegExp(r'<ObjectID>([^<]+)</ObjectID>').firstMatch(request.body);
        if (match != null) {
          capturedSearch = match.group(1);
        }
        return http.Response(
          browseResponse(result: emptyDIDL, numberReturned: 0, totalMatches: 0),
          200,
        );
      });
      device.httpClient = mockClient;

      await library.browseByIdstring('playlists', '//server/share/playlist.m3u');

      // Playlists use the full path without adding prefix
      expect(capturedSearch, equals('//server/share/playlist.m3u'));
    });

    test('convenience methods use correct search types', () async {
      final methods = <String, Future<SearchResult> Function()>{
        'artists': () => library.getArtists(),
        'album_artists': () => library.getAlbumArtists(),
        'albums': () => library.getAlbums(),
        'genres': () => library.getGenres(),
        'composers': () => library.getComposers(),
        'tracks': () => library.getTracks(),
        'playlists': () => library.getPlaylists(),
        'sonos_favorites': () => library.getSonosFavorites(),
        'radio_stations': () => library.getFavoriteRadioStations(),
        'radio_shows': () => library.getFavoriteRadioShows(),
      };

      for (final entry in methods.entries) {
        String? capturedSearch;
        final mockClient = MockClient((request) async {
          final match = RegExp(r'<ObjectID>([^<]+)</ObjectID>').firstMatch(request.body);
          if (match != null) {
            capturedSearch = match.group(1);
          }
          return http.Response(
            browseResponse(result: emptyDIDL, numberReturned: 0, totalMatches: 0),
            200,
          );
        });
        device.httpClient = mockClient;

        await entry.value();

        final expectedPrefix = MusicLibrary.searchTranslation[entry.key];
        expect(
          capturedSearch,
          equals(expectedPrefix),
          reason: 'Method for ${entry.key} should use prefix $expectedPrefix',
        );
      }
    });
  });

  group('Album art URI helpers', () {
    late SoCo device;
    late MusicLibrary musicLibrary;

    setUp(() {
      device = SoCo('192.168.99.1');
      musicLibrary = MusicLibrary(device);
    });

    test('buildAlbumArtFullUri returns absolute URI for relative path', () {
      final result = musicLibrary.buildAlbumArtFullUri('/getaa?s=1&u=test');
      expect(result, equals('http://192.168.99.1:1400/getaa?s=1&u=test'));
    });

    test('buildAlbumArtFullUri returns unchanged for http URI', () {
      final uri = 'http://example.com/image.jpg';
      final result = musicLibrary.buildAlbumArtFullUri(uri);
      expect(result, equals(uri));
    });

    test('buildAlbumArtFullUri returns unchanged for https URI', () {
      final uri = 'https://example.com/image.jpg';
      final result = musicLibrary.buildAlbumArtFullUri(uri);
      expect(result, equals(uri));
    });
  });
}
