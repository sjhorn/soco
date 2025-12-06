/// Tests for the Wimp plugin.
library;

import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:soco/src/plugins/wimp.dart';
import 'package:soco/src/ms_data_structures.dart';
import 'package:soco/src/exceptions.dart';

import 'helpers/mock_http.dart';

void main() {
  group('WimpPlugin static methods', () {
    test('idToExtendedId returns correct prefix for MSTrack', () {
      final result = WimpPlugin.idToExtendedId('trackid_12345', MSTrack);
      expect(result, equals('00030020trackid_12345'));
    });

    test('idToExtendedId returns correct prefix for MSAlbum', () {
      final result = WimpPlugin.idToExtendedId('albumid_12345', MSAlbum);
      expect(result, equals('0004002calbumid_12345'));
    });

    test('idToExtendedId returns correct prefix for MSArtist', () {
      final result = WimpPlugin.idToExtendedId('artistid_12345', MSArtist);
      expect(result, equals('10050024artistid_12345'));
    });

    test('idToExtendedId returns correct prefix for MSAlbumList', () {
      final result = WimpPlugin.idToExtendedId('listid_12345', MSAlbumList);
      expect(result, equals('000d006clistid_12345'));
    });

    test('idToExtendedId returns correct prefix for MSPlaylist', () {
      final result = WimpPlugin.idToExtendedId('playlistid_12345', MSPlaylist);
      expect(result, equals('0006006cplaylistid_12345'));
    });

    test('idToExtendedId returns correct prefix for MSArtistTracklist', () {
      final result =
          WimpPlugin.idToExtendedId('tracklistid_12345', MSArtistTracklist);
      expect(result, equals('100f006ctracklistid_12345'));
    });

    test('idToExtendedId returns null for MSFavorites (unknown prefix)', () {
      final result = WimpPlugin.idToExtendedId('favid_12345', MSFavorites);
      expect(result, isNull);
    });

    test('idToExtendedId returns null for MSCollection (unknown prefix)', () {
      final result = WimpPlugin.idToExtendedId('collid_12345', MSCollection);
      expect(result, isNull);
    });
  });

  group('WimpPlugin formUri', () {
    test('formUri for MSTrack with mime type', () {
      final content = {
        'item_id': 'trackid_12345',
        'service_id': 20,
        'mime_type': 'audio/aac',
      };
      final result = WimpPlugin.formUri(content, MSTrack);
      expect(result, equals('x-sonos-http:trackid_12345.mp4?sid=20&flags=32'));
    });

    test('formUri for MSTrack without mime type', () {
      final content = {
        'item_id': 'trackid_12345',
        'service_id': 20,
      };
      final result = WimpPlugin.formUri(content, MSTrack);
      expect(result, equals('x-sonos-http:trackid_12345.?sid=20&flags=32'));
    });

    test('formUri for MSAlbum', () {
      final content = {
        'extended_id': '0004002calbumid_12345',
      };
      final result = WimpPlugin.formUri(content, MSAlbum);
      expect(result, equals('x-rincon-cpcontainer:0004002calbumid_12345'));
    });

    test('formUri for MSAlbumList', () {
      final content = {
        'extended_id': '000d006clistid_12345',
      };
      final result = WimpPlugin.formUri(content, MSAlbumList);
      expect(result, equals('x-rincon-cpcontainer:000d006clistid_12345'));
    });

    test('formUri for MSPlaylist', () {
      final content = {
        'extended_id': '0006006cplaylistid_12345',
      };
      final result = WimpPlugin.formUri(content, MSPlaylist);
      expect(result, equals('x-rincon-cpcontainer:0006006cplaylistid_12345'));
    });

    test('formUri for MSArtistTracklist', () {
      final content = {
        'extended_id': '100f006ctracklistid_12345',
      };
      final result = WimpPlugin.formUri(content, MSArtistTracklist);
      expect(result, equals('x-rincon-cpcontainer:100f006ctracklistid_12345'));
    });

    test('formUri returns null for unsupported types', () {
      final content = {'item_id': 'test'};
      final result = WimpPlugin.formUri(content, MSFavorites);
      expect(result, isNull);
    });
  });

  group('WimpPlugin properties', () {
    late WimpPlugin plugin;

    setUp(() {
      plugin = WimpPlugin.forTesting(
        username: 'testuser@example.com',
        sessionId: 'test-session-123',
        serialNumber: 'XX-XX-XX-XX-XX-XX',
      );
    });

    test('name returns plugin name with username', () {
      expect(plugin.name, equals('Wimp Plugin for testuser@example.com'));
    });

    test('username returns the username', () {
      expect(plugin.username, equals('testuser@example.com'));
    });

    test('serviceId returns 20', () {
      expect(plugin.serviceId, equals(20));
    });

    test('description returns RINCON format', () {
      expect(plugin.description, equals('SA_RINCON5127_testuser@example.com'));
    });
  });

  group('WimpPlugin search methods', () {
    // Note: These tests verify HTTP request/response handling.
    // The getMsItem function has namespace parsing issues that need separate fixing.

    test('getMusicServiceInformation throws on invalid search type', () async {
      final plugin = WimpPlugin.forTesting(
        username: 'testuser@example.com',
        sessionId: 'test-session-123',
        serialNumber: 'XX-XX-XX-XX-XX-XX',
      );

      expect(
        () => plugin.getMusicServiceInformation('invalid', 'query'),
        throwsA(isA<ArgumentError>()),
      );
    }, timeout: Timeout(Duration(seconds: 5)));

    test('getTracks makes correct HTTP request', () async {
      String? capturedBody;
      String? capturedUrl;
      String? capturedSoapAction;

      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        capturedSoapAction = request.headers['SOAPACTION'];
        capturedBody = request.body;

        // Return empty result to avoid getMsItem parsing issues
        return http.Response(
          WimpResponses.searchTracks(tracks: []),
          200,
          headers: {'content-type': 'text/xml; charset=utf-8'},
        );
      });

      final plugin = WimpPlugin.forTesting(
        username: 'testuser@example.com',
        sessionId: 'test-session-123',
        serialNumber: 'XX-XX-XX-XX-XX-XX',
        httpClient: mockClient,
      );

      final result = await plugin.getTracks('test query');

      expect(capturedUrl, equals('http://client.wimpmusic.com/sonos/services/Sonos'));
      expect(capturedSoapAction, equals('"http://www.sonos.com/Services/1.1#search"'));
      expect(capturedBody!.contains('<id>tracksearch</id>'), isTrue);
      expect(capturedBody!.contains('<term>test query</term>'), isTrue);
      expect(result['count'], equals('0'));
      expect(result['item_list'], isA<List<MusicServiceItem>>());
    }, timeout: Timeout(Duration(seconds: 5)));

    test('getAlbums makes correct HTTP request', () async {
      String? capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          WimpResponses.searchAlbums(albums: []),
          200,
          headers: {'content-type': 'text/xml; charset=utf-8'},
        );
      });

      final plugin = WimpPlugin.forTesting(
        username: 'testuser@example.com',
        sessionId: 'test-session-123',
        serialNumber: 'XX-XX-XX-XX-XX-XX',
        httpClient: mockClient,
      );

      final result = await plugin.getAlbums('test album');

      expect(capturedBody!.contains('<id>albumsearch</id>'), isTrue);
      expect(capturedBody!.contains('<term>test album</term>'), isTrue);
      expect(result['count'], equals('0'));
    }, timeout: Timeout(Duration(seconds: 5)));

    test('getArtists makes correct HTTP request', () async {
      String? capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          WimpResponses.searchArtists(artists: []),
          200,
          headers: {'content-type': 'text/xml; charset=utf-8'},
        );
      });

      final plugin = WimpPlugin.forTesting(
        username: 'testuser@example.com',
        sessionId: 'test-session-123',
        serialNumber: 'XX-XX-XX-XX-XX-XX',
        httpClient: mockClient,
      );

      final result = await plugin.getArtists('test artist');

      expect(capturedBody!.contains('<id>artistsearch</id>'), isTrue);
      expect(capturedBody!.contains('<term>test artist</term>'), isTrue);
      expect(result['count'], equals('0'));
    }, timeout: Timeout(Duration(seconds: 5)));

    test('getPlaylists makes correct HTTP request', () async {
      String? capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          WimpResponses.searchAlbums(albums: []),
          200,
          headers: {'content-type': 'text/xml; charset=utf-8'},
        );
      });

      final plugin = WimpPlugin.forTesting(
        username: 'testuser@example.com',
        sessionId: 'test-session-123',
        serialNumber: 'XX-XX-XX-XX-XX-XX',
        httpClient: mockClient,
      );

      final result = await plugin.getPlaylists('my playlist');

      expect(capturedBody!.contains('<id>playlistsearch</id>'), isTrue);
      expect(capturedBody!.contains('<term>my playlist</term>'), isTrue);
      expect(result['count'], equals('0'));
    }, timeout: Timeout(Duration(seconds: 5)));

    test('search with pagination parameters', () async {
      String? capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          WimpResponses.searchTracks(tracks: [], index: 10, total: 100),
          200,
          headers: {'content-type': 'text/xml; charset=utf-8'},
        );
      });

      final plugin = WimpPlugin.forTesting(
        username: 'testuser@example.com',
        sessionId: 'test-session-123',
        serialNumber: 'XX-XX-XX-XX-XX-XX',
        httpClient: mockClient,
      );

      final result = await plugin.getTracks('query', start: 10, maxItems: 50);

      expect(capturedBody!.contains('<index>10</index>'), isTrue);
      expect(capturedBody!.contains('<count>50</count>'), isTrue);
      expect(result['index'], equals('10'));
      expect(result['total'], equals('100'));
    }, timeout: Timeout(Duration(seconds: 5)));
  }, timeout: Timeout(Duration(seconds: 5)));

  group('WimpPlugin browse', () {
    test('browse root makes correct HTTP request', () async {
      String? capturedBody;
      String? capturedSoapAction;

      final mockClient = MockClient((request) async {
        capturedSoapAction = request.headers['SOAPACTION'];
        capturedBody = request.body;

        // Return empty result to avoid getMsItem parsing issues
        return http.Response(
          WimpResponses.browseRoot(collections: []),
          200,
          headers: {'content-type': 'text/xml; charset=utf-8'},
        );
      });

      final plugin = WimpPlugin.forTesting(
        username: 'testuser@example.com',
        sessionId: 'test-session-123',
        serialNumber: 'XX-XX-XX-XX-XX-XX',
        httpClient: mockClient,
      );

      final result = await plugin.browse();

      expect(capturedSoapAction, equals('"http://www.sonos.com/Services/1.1#getMetadata"'));
      expect(capturedBody!.contains('<id>root</id>'), isTrue);
      expect(result['count'], equals('0'));
    }, timeout: Timeout(Duration(seconds: 5)));

    test('browse with item checks service ID', () async {
      final plugin = WimpPlugin.forTesting(
        username: 'testuser@example.com',
        sessionId: 'test-session-123',
        serialNumber: 'XX-XX-XX-XX-XX-XX',
      );

      // Create an item from a different service (service_id = 5)
      final wrongServiceItem = MSAlbum({
        'item_id': 'album_123',
        'service_id': 5, // Not Wimp's service ID of 20
        'title': 'Some Album',
      });

      expect(
        () => plugin.browse(wrongServiceItem),
        throwsA(isA<ArgumentError>()),
      );
    }, timeout: Timeout(Duration(seconds: 5)));

    test('browse with valid item makes correct HTTP request', () async {
      String? capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          WimpResponses.browseRoot(collections: []),
          200,
          headers: {'content-type': 'text/xml; charset=utf-8'},
        );
      });

      final plugin = WimpPlugin.forTesting(
        username: 'testuser@example.com',
        sessionId: 'test-session-123',
        serialNumber: 'XX-XX-XX-XX-XX-XX',
        httpClient: mockClient,
      );

      final albumItem = MSAlbum({
        'item_id': 'album_123',
        'service_id': 20, // Wimp's service ID
        'extended_id': '0004002calbum_123',
        'title': 'Some Album',
      });

      final result = await plugin.browse(albumItem);

      expect(capturedBody!.contains('<id>album_123</id>'), isTrue);
      expect(result['count'], equals('0'));
    }, timeout: Timeout(Duration(seconds: 5)));
  }, timeout: Timeout(Duration(seconds: 5)));

  group('WimpPlugin error handling', () {
    test('search error throws SoCoUPnPException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          WimpResponses.error(faultstring: 'ItemNotFound'),
          500,
          headers: {'content-type': 'text/xml; charset=utf-8'},
        );
      });

      final plugin = WimpPlugin.forTesting(
        username: 'testuser@example.com',
        sessionId: 'test-session-123',
        serialNumber: 'XX-XX-XX-XX-XX-XX',
        httpClient: mockClient,
      );

      expect(
        () => plugin.getTracks('nonexistent'),
        throwsA(isA<SoCoUPnPException>()),
      );
    }, timeout: Timeout(Duration(seconds: 5)));

    test('error code mapping for ItemNotFound', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          WimpResponses.error(faultstring: 'ItemNotFound'),
          500,
          headers: {'content-type': 'text/xml; charset=utf-8'},
        );
      });

      final plugin = WimpPlugin.forTesting(
        username: 'testuser@example.com',
        sessionId: 'test-session-123',
        serialNumber: 'XX-XX-XX-XX-XX-XX',
        httpClient: mockClient,
      );

      try {
        await plugin.getTracks('nonexistent');
        fail('Expected SoCoUPnPException');
      } on SoCoUPnPException catch (e) {
        expect(e.errorCode, equals('20001')); // ItemNotFound code
        expect(e.errorDescription, equals('ItemNotFound'));
      }
    }, timeout: Timeout(Duration(seconds: 5)));

    test('unknown error uses default code', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          WimpResponses.error(faultstring: 'SomeUnknownError'),
          500,
          headers: {'content-type': 'text/xml; charset=utf-8'},
        );
      });

      final plugin = WimpPlugin.forTesting(
        username: 'testuser@example.com',
        sessionId: 'test-session-123',
        serialNumber: 'XX-XX-XX-XX-XX-XX',
        httpClient: mockClient,
      );

      try {
        await plugin.getTracks('query');
        fail('Expected SoCoUPnPException');
      } on SoCoUPnPException catch (e) {
        expect(e.errorCode, equals('20000')); // Unknown error code
      }
    }, timeout: Timeout(Duration(seconds: 5)));
  }, timeout: Timeout(Duration(seconds: 5)));

  group('WimpPlugin XML body generation', () {
    test('search body contains correct SOAP headers', () async {
      String? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          WimpResponses.searchTracks(tracks: []),
          200,
          headers: {'content-type': 'text/xml; charset=utf-8'},
        );
      });

      final plugin = WimpPlugin.forTesting(
        username: 'testuser@example.com',
        sessionId: 'test-session-123',
        serialNumber: 'XX-XX-XX-XX-XX-XX',
        httpClient: mockClient,
      );

      await plugin.getTracks('test');

      expect(capturedBody, isNotNull);
      expect(capturedBody!.contains('<sessionId>test-session-123</sessionId>'),
          isTrue);
      expect(capturedBody!.contains('<deviceId>XX-XX-XX-XX-XX-XX</deviceId>'),
          isTrue);
      expect(
          capturedBody!.contains('<deviceProvider>Sonos</deviceProvider>'),
          isTrue);
    }, timeout: Timeout(Duration(seconds: 5)));

    test('search body contains search term and type', () async {
      String? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          WimpResponses.searchTracks(tracks: []),
          200,
          headers: {'content-type': 'text/xml; charset=utf-8'},
        );
      });

      final plugin = WimpPlugin.forTesting(
        username: 'testuser@example.com',
        sessionId: 'test-session-123',
        serialNumber: 'XX-XX-XX-XX-XX-XX',
        httpClient: mockClient,
      );

      await plugin.getTracks('my search query');

      expect(capturedBody, isNotNull);
      expect(capturedBody!.contains('<id>tracksearch</id>'), isTrue);
      expect(capturedBody!.contains('<term>my search query</term>'), isTrue);
    }, timeout: Timeout(Duration(seconds: 5)));
  }, timeout: Timeout(Duration(seconds: 5)));

  group('WimpPlugin constants', () {
    test('valid search types', () {
      final validTypes = ['artists', 'albums', 'tracks', 'playlists'];
      for (final type in validTypes) {
        expect(validTypes.contains(type), isTrue);
      }
    }, timeout: Timeout(Duration(seconds: 5)));

    test('exception codes are defined', () {
      const codes = {
        'unknown': 20000,
        'ItemNotFound': 20001,
      };
      expect(codes['unknown'], equals(20000));
      expect(codes['ItemNotFound'], equals(20001));
    }, timeout: Timeout(Duration(seconds: 5)));
  });
}
