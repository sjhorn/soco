import 'package:test/test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:soco/src/core.dart';
import 'package:soco/src/exceptions.dart';
import 'package:soco/src/plugins/sharelink.dart';
import 'helpers/mock_http.dart';

void main() {
  group('SpotifyShare', () {
    final spotify = SpotifyShare();

    test('recognizes Spotify URIs', () {
      expect(
        spotify.canonicalUri('spotify:track:6NmXV4o6bmp704aPGyTVVG'),
        equals('spotify:track:6NmXV4o6bmp704aPGyTVVG'),
      );
    });

    test('recognizes Spotify HTTP links', () {
      expect(
        spotify.canonicalUri(
          'https://open.spotify.com/track/6NmXV4o6bmp704aPGyTVVG',
        ),
        equals('spotify:track:6NmXV4o6bmp704aPGyTVVG'),
      );
    });

    test('recognizes Spotify album links', () {
      expect(
        spotify.canonicalUri(
          'https://open.spotify.com/album/6wiUBliPe76YAVpNEdidpY',
        ),
        equals('spotify:album:6wiUBliPe76YAVpNEdidpY'),
      );
    });

    test('recognizes Spotify playlist links', () {
      expect(
        spotify.canonicalUri(
          'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M',
        ),
        equals('spotify:playlist:37i9dQZF1DXcBWIGoYBM5M'),
      );
    });

    test('returns null for non-Spotify URIs', () {
      expect(spotify.canonicalUri('https://tidal.com/track/123'), isNull);
    });

    test('returns correct service number', () {
      expect(spotify.serviceNumber(), equals(2311));
    });

    test('extracts share type and encoded URI', () {
      final (shareType, encodedUri) = spotify.extract(
        'spotify:track:6NmXV4o6bmp704aPGyTVVG',
      );
      expect(shareType, equals('track'));
      expect(encodedUri, equals('spotify%3atrack%3a6NmXV4o6bmp704aPGyTVVG'));
    });
  });

  group('SpotifyUSShare', () {
    final spotifyUS = SpotifyUSShare();

    test('has different service number than regular Spotify', () {
      expect(spotifyUS.serviceNumber(), equals(3079));
    });

    test('recognizes same URIs as Spotify', () {
      expect(
        spotifyUS.canonicalUri('spotify:track:6NmXV4o6bmp704aPGyTVVG'),
        equals('spotify:track:6NmXV4o6bmp704aPGyTVVG'),
      );
    });
  });

  group('TIDALShare', () {
    final tidal = TIDALShare();

    test('recognizes TIDAL track links', () {
      expect(
        tidal.canonicalUri('https://tidal.com/browse/track/157273956'),
        equals('tidal:track:157273956'),
      );
    });

    test('recognizes TIDAL album links', () {
      expect(
        tidal.canonicalUri('https://tidal.com/browse/album/123456'),
        equals('tidal:album:123456'),
      );
    });

    test('recognizes TIDAL playlist links', () {
      expect(
        tidal.canonicalUri('https://tidal.com/browse/playlist/abc-def-123'),
        equals('tidal:playlist:abc-def-123'),
      );
    });

    test('returns null for non-TIDAL URIs', () {
      expect(tidal.canonicalUri('https://spotify.com/track/123'), isNull);
    });

    test('returns correct service number', () {
      expect(tidal.serviceNumber(), equals(44551));
    });

    test('extracts share type and encoded URI', () {
      final (shareType, encodedUri) = tidal.extract(
        'https://tidal.com/browse/track/157273956',
      );
      expect(shareType, equals('track'));
      expect(encodedUri, equals('track%2f157273956'));
    });
  });

  group('DeezerShare', () {
    final deezer = DeezerShare();

    test('recognizes Deezer track links', () {
      expect(
        deezer.canonicalUri('https://www.deezer.com/track/12345678'),
        equals('deezer:track:12345678'),
      );
    });

    test('recognizes Deezer album links', () {
      expect(
        deezer.canonicalUri('https://www.deezer.com/album/987654'),
        equals('deezer:album:987654'),
      );
    });

    test('recognizes Deezer playlist links', () {
      expect(
        deezer.canonicalUri('https://www.deezer.com/playlist/12345-67890'),
        equals('deezer:playlist:12345-67890'),
      );
    });

    test('returns null for non-Deezer URIs', () {
      expect(deezer.canonicalUri('https://spotify.com/track/123'), isNull);
    });

    test('returns correct service number', () {
      expect(deezer.serviceNumber(), equals(519));
    });

    test('extracts share type and encoded URI', () {
      final (shareType, encodedUri) = deezer.extract(
        'https://www.deezer.com/track/12345678',
      );
      expect(shareType, equals('track'));
      expect(encodedUri, equals('track-12345678'));
    });
  });

  group('AppleMusicShare', () {
    final appleMusic = AppleMusicShare();

    test('recognizes Apple Music song links', () {
      expect(
        appleMusic.canonicalUri(
          'https://music.apple.com/dk/album/black-velvet/217502930?i=217503142',
        ),
        equals('song:217503142'),
      );
    });

    test('recognizes Apple Music album links', () {
      expect(
        appleMusic.canonicalUri(
          'https://music.apple.com/dk/album/amused-to-death/975952384',
        ),
        equals('album:975952384'),
      );
    });

    test('recognizes Apple Music curated playlist links', () {
      expect(
        appleMusic.canonicalUri(
          'https://music.apple.com/dk/playlist/power-ballads-essentials/pl.92e04ee75ed64804b9df468b5f45a161',
        ),
        equals('playlist:pl.92e04ee75ed64804b9df468b5f45a161'),
      );
    });

    test('recognizes Apple Music user playlist links', () {
      expect(
        appleMusic.canonicalUri(
          'https://music.apple.com/de/playlist/unnamed-playlist/pl.u-rR2PCrLdLJk',
        ),
        equals('playlist:pl.u-rR2PCrLdLJk'),
      );
    });

    test('returns null for non-Apple Music URIs', () {
      expect(appleMusic.canonicalUri('https://spotify.com/track/123'), isNull);
    });

    test('returns correct service number', () {
      expect(appleMusic.serviceNumber(), equals(52231));
    });

    test('extracts share type and encoded URI for song', () {
      final (shareType, encodedUri) = appleMusic.extract(
        'https://music.apple.com/dk/album/black-velvet/217502930?i=217503142',
      );
      expect(shareType, equals('song'));
      expect(encodedUri, equals('song%3a217503142'));
    });

    test('extracts share type and encoded URI for album', () {
      final (shareType, encodedUri) = appleMusic.extract(
        'https://music.apple.com/dk/album/amused-to-death/975952384',
      );
      expect(shareType, equals('album'));
      expect(encodedUri, equals('album%3a975952384'));
    });
  });

  group('ShareClass.magic', () {
    test('returns magic values for all share types', () {
      final magic = ShareClass.magic();

      expect(
        magic['album']!['prefix'],
        equals('x-rincon-cpcontainer:1004206c'),
      );
      expect(magic['album']!['key'], equals('00040000'));
      expect(
        magic['album']!['class'],
        equals('object.container.album.musicAlbum'),
      );

      expect(magic['track']!['prefix'], equals(''));
      expect(magic['track']!['key'], equals('00032020'));
      expect(
        magic['track']!['class'],
        equals('object.item.audioItem.musicTrack'),
      );

      expect(
        magic['playlist']!['prefix'],
        equals('x-rincon-cpcontainer:1006206c'),
      );
      expect(magic['playlist']!['key'], equals('1006206c'));
      expect(
        magic['playlist']!['class'],
        equals('object.container.playlistContainer'),
      );
    });
  });

  group('ShareLinkPlugin', () {
    late ShareLinkPlugin plugin;

    setUp(() {
      // Create a mock SoCo instance (we won't call methods on it in these tests)
      plugin = ShareLinkPlugin(null);
    });

    test('has correct name', () {
      expect(plugin.name, equals('ShareLink Plugin'));
    });

    test('isShareLink returns true for Spotify links', () {
      expect(
        plugin.isShareLink('spotify:track:6NmXV4o6bmp704aPGyTVVG'),
        isTrue,
      );
    });

    test('isShareLink returns true for TIDAL links', () {
      expect(
        plugin.isShareLink('https://tidal.com/browse/track/157273956'),
        isTrue,
      );
    });

    test('isShareLink returns true for Deezer links', () {
      expect(
        plugin.isShareLink('https://www.deezer.com/track/12345678'),
        isTrue,
      );
    });

    test('isShareLink returns true for Apple Music links', () {
      expect(
        plugin.isShareLink(
          'https://music.apple.com/dk/album/amused-to-death/975952384',
        ),
        isTrue,
      );
    });

    test('isShareLink returns false for unsupported links', () {
      expect(plugin.isShareLink('https://youtube.com/watch?v=123'), isFalse);
      expect(plugin.isShareLink('http://example.com'), isFalse);
    });

    test('has all supported services', () {
      expect(plugin.services.length, equals(5));
      expect(plugin.services[0], isA<SpotifyShare>());
      expect(plugin.services[1], isA<SpotifyUSShare>());
      expect(plugin.services[2], isA<TIDALShare>());
      expect(plugin.services[3], isA<DeezerShare>());
      expect(plugin.services[4], isA<AppleMusicShare>());
    });
  });

  group('ShareLinkPlugin.addShareLinkToQueue', () {
    late SoCo soco;
    late ShareLinkPlugin plugin;
    late MockClient mockClient;

    setUp(() {
      soco = SoCo('192.168.50.150');
    });

    tearDown(() {
      mockClient.close();
    });

    test('adds Spotify track to queue successfully', () async {
      mockClient = MockClient((request) async {
        if (request.body.contains('AddURIToQueue')) {
          expect(request.body, contains('EnqueuedURI'));
          expect(request.body, contains('spotify%3atrack%3a6NmXV4o6bmp704aPGyTVVG'));
          return http.Response(soapEnvelope('''
            <u:AddURIToQueueResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <FirstTrackNumberEnqueued>5</FirstTrackNumberEnqueued>
              <NumTracksAdded>1</NumTracksAdded>
              <NewQueueLength>10</NewQueueLength>
            </u:AddURIToQueueResponse>
          '''), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;
      plugin = ShareLinkPlugin(soco);

      final position = await plugin.addShareLinkToQueue(
        'spotify:track:6NmXV4o6bmp704aPGyTVVG',
      );
      expect(position, equals(5));
    });

    test('adds Spotify album to queue with title', () async {
      mockClient = MockClient((request) async {
        if (request.body.contains('AddURIToQueue')) {
          expect(request.body, contains('x-rincon-cpcontainer:1004206c'));
          expect(request.body, contains('My Album Title'));
          return http.Response(soapEnvelope('''
            <u:AddURIToQueueResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <FirstTrackNumberEnqueued>1</FirstTrackNumberEnqueued>
              <NumTracksAdded>12</NumTracksAdded>
              <NewQueueLength>12</NewQueueLength>
            </u:AddURIToQueueResponse>
          '''), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;
      plugin = ShareLinkPlugin(soco);

      final position = await plugin.addShareLinkToQueue(
        'spotify:album:6wiUBliPe76YAVpNEdidpY',
        dcTitle: 'My Album Title',
      );
      expect(position, equals(1));
    });

    test('adds TIDAL track to queue', () async {
      mockClient = MockClient((request) async {
        if (request.body.contains('AddURIToQueue')) {
          expect(request.body, contains('track%2f157273956'));
          expect(request.body, contains('SA_RINCON44551'));
          return http.Response(soapEnvelope('''
            <u:AddURIToQueueResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <FirstTrackNumberEnqueued>3</FirstTrackNumberEnqueued>
              <NumTracksAdded>1</NumTracksAdded>
              <NewQueueLength>3</NewQueueLength>
            </u:AddURIToQueueResponse>
          '''), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;
      plugin = ShareLinkPlugin(soco);

      final position = await plugin.addShareLinkToQueue(
        'https://tidal.com/browse/track/157273956',
      );
      expect(position, equals(3));
    });

    test('adds item at specific position', () async {
      var receivedPosition = -1;
      mockClient = MockClient((request) async {
        if (request.body.contains('AddURIToQueue')) {
          // Extract DesiredFirstTrackNumberEnqueued from request
          final match = RegExp(r'<DesiredFirstTrackNumberEnqueued>(\d+)</DesiredFirstTrackNumberEnqueued>')
              .firstMatch(request.body);
          if (match != null) {
            receivedPosition = int.parse(match.group(1)!);
          }
          return http.Response(soapEnvelope('''
            <u:AddURIToQueueResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <FirstTrackNumberEnqueued>7</FirstTrackNumberEnqueued>
              <NumTracksAdded>1</NumTracksAdded>
              <NewQueueLength>10</NewQueueLength>
            </u:AddURIToQueueResponse>
          '''), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;
      plugin = ShareLinkPlugin(soco);

      await plugin.addShareLinkToQueue(
        'spotify:track:6NmXV4o6bmp704aPGyTVVG',
        position: 7,
      );
      expect(receivedPosition, equals(7));
    });

    test('adds item with asNext=true', () async {
      var receivedAsNext = '';
      mockClient = MockClient((request) async {
        if (request.body.contains('AddURIToQueue')) {
          final match = RegExp(r'<EnqueueAsNext>(\d+)</EnqueueAsNext>')
              .firstMatch(request.body);
          if (match != null) {
            receivedAsNext = match.group(1)!;
          }
          return http.Response(soapEnvelope('''
            <u:AddURIToQueueResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <FirstTrackNumberEnqueued>2</FirstTrackNumberEnqueued>
              <NumTracksAdded>1</NumTracksAdded>
              <NewQueueLength>5</NewQueueLength>
            </u:AddURIToQueueResponse>
          '''), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;
      plugin = ShareLinkPlugin(soco);

      await plugin.addShareLinkToQueue(
        'spotify:track:6NmXV4o6bmp704aPGyTVVG',
        asNext: true,
      );
      expect(receivedAsNext, equals('1'));
    });

    test('throws for unsupported URI', () async {
      mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;
      plugin = ShareLinkPlugin(soco);

      expect(
        () => plugin.addShareLinkToQueue('https://youtube.com/watch?v=123'),
        throwsA(isA<SoCoException>().having(
          (e) => e.message,
          'message',
          contains('Unsupported URI'),
        )),
      );
    });

    test('tries next service on failure', () async {
      // The plugin should try SpotifyShare, then SpotifyUSShare
      var callCount = 0;
      mockClient = MockClient((request) async {
        if (request.body.contains('AddURIToQueue')) {
          callCount++;
          if (callCount == 1) {
            // First call (SpotifyShare) fails
            return http.Response(soapFault(faultcode: 's:Client', faultstring: 'UPnPError', errorCode: '714'), 500);
          }
          // Second call (SpotifyUSShare) succeeds
          return http.Response(soapEnvelope('''
            <u:AddURIToQueueResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <FirstTrackNumberEnqueued>1</FirstTrackNumberEnqueued>
              <NumTracksAdded>1</NumTracksAdded>
              <NewQueueLength>1</NewQueueLength>
            </u:AddURIToQueueResponse>
          '''), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;
      plugin = ShareLinkPlugin(soco);

      final position = await plugin.addShareLinkToQueue(
        'spotify:track:6NmXV4o6bmp704aPGyTVVG',
      );
      expect(position, equals(1));
      expect(callCount, equals(2));
    });
  });
}
