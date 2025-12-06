/// Tests for the core module with HTTP mocking.
library;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:soco/src/core.dart';
import 'package:soco/src/data_structures.dart';
import 'package:soco/src/exceptions.dart';

/// Helper to create a successful SOAP response
String soapResponse(String service, String action, Map<String, String> values) {
  final args = values.entries
      .map((e) => '<${e.key}>${e.value}</${e.key}>')
      .join();
  return '''<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
            s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:${action}Response xmlns:u="urn:schemas-upnp-org:service:$service:1">
      $args
    </u:${action}Response>
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

void main() {
  // Set default timeout for all tests (5 seconds)
  // Mocked HTTP tests should complete quickly
  group('SoCo with HTTP mocking', () {
    late SoCo device;
    late List<http.Request> capturedRequests;

    setUp(() {
      // Use unique IP to avoid singleton conflicts
      device = SoCo('192.168.99.1');
      capturedRequests = [];
    });

    MockClient createMockClient(
      Map<String, String> responses, {
      String? defaultResponse,
    }) {
      return MockClient((request) async {
        capturedRequests.add(request);

        // Find matching response by checking if URL contains key
        for (final entry in responses.entries) {
          if (request.url.path.contains(entry.key)) {
            return http.Response(entry.value, 200);
          }
        }

        if (defaultResponse != null) {
          return http.Response(defaultResponse, 200);
        }

        return http.Response('Not Found', 404);
      });
    }

    group('volume', () {
      test('getVolume returns current volume', () async {
        final mockClient = createMockClient({
          '/RenderingControl/Control': soapResponse(
            'RenderingControl',
            'GetVolume',
            {'CurrentVolume': '42'},
          ),
        });

        device.httpClient = mockClient;

        final volume = await device.volume;

        expect(volume, equals(42));
        expect(capturedRequests.length, equals(1));
        expect(
          capturedRequests.first.headers['SOAPACTION'],
          contains('GetVolume'),
        );
      }, timeout: Timeout(Duration(seconds: 5)));

      test('setVolume sends correct command', () async {
        final mockClient = createMockClient({
          '/RenderingControl/Control': soapResponse(
            'RenderingControl',
            'SetVolume',
            {},
          ),
        });

        device.httpClient = mockClient;

        await device.setVolume(75);

        expect(capturedRequests.length, equals(1));
        expect(capturedRequests.first.body, contains('<DesiredVolume>75'));
      }, timeout: Timeout(Duration(seconds: 5)));

      test('setVolume clamps to 0-100 range', () async {
        final mockClient = createMockClient({
          '/RenderingControl/Control': soapResponse(
            'RenderingControl',
            'SetVolume',
            {},
          ),
        });

        device.httpClient = mockClient;

        // Test clamping to max
        await device.setVolume(150);
        expect(capturedRequests.last.body, contains('<DesiredVolume>100'));

        // Test clamping to min
        await device.setVolume(-10);
        expect(capturedRequests.last.body, contains('<DesiredVolume>0'));
      }, timeout: Timeout(Duration(seconds: 5)));
    });

    group('mute', () {
      test(
        'getMute returns current mute state',
        () async {
          final mockClient = createMockClient({
            '/RenderingControl/Control': soapResponse(
              'RenderingControl',
              'GetMute',
              {'CurrentMute': '1'},
            ),
          });

          device.httpClient = mockClient;

          final muted = await device.mute;

          expect(muted, isTrue);
        },
        timeout: Timeout(Duration(seconds: 5)),
      );

      test(
        'getMute returns false when not muted',
        () async {
          final mockClient = createMockClient({
            '/RenderingControl/Control': soapResponse(
              'RenderingControl',
              'GetMute',
              {'CurrentMute': '0'},
            ),
          });

          device.httpClient = mockClient;

          final muted = await device.mute;

          expect(muted, isFalse);
        },
        timeout: Timeout(Duration(seconds: 5)),
      );

      test('setMute sends correct command', () async {
        final mockClient = createMockClient({
          '/RenderingControl/Control': soapResponse(
            'RenderingControl',
            'SetMute',
            {},
          ),
        });

        device.httpClient = mockClient;

        await device.setMute(true);

        expect(capturedRequests.first.body, contains('<DesiredMute>1'));
      }, timeout: Timeout(Duration(seconds: 5)));
    });

    group('playback control', () {
      test('play sends Play command', () async {
        final mockClient = createMockClient({
          '/AVTransport/Control': soapResponse('AVTransport', 'Play', {}),
        });

        device.httpClient = mockClient;

        await device.play();

        expect(capturedRequests.length, equals(1));
        expect(capturedRequests.first.headers['SOAPACTION'], contains('Play'));
        expect(capturedRequests.first.body, contains('<Speed>1'));
      }, timeout: Timeout(Duration(seconds: 5)));

      test('pause sends Pause command', () async {
        final mockClient = createMockClient({
          '/AVTransport/Control': soapResponse('AVTransport', 'Pause', {}),
        });

        device.httpClient = mockClient;

        await device.pause();

        expect(capturedRequests.length, equals(1));
        expect(capturedRequests.first.headers['SOAPACTION'], contains('Pause'));
      }, timeout: Timeout(Duration(seconds: 5)));

      test('stop sends Stop command', () async {
        final mockClient = createMockClient({
          '/AVTransport/Control': soapResponse('AVTransport', 'Stop', {}),
        });

        device.httpClient = mockClient;

        await device.stop();

        expect(capturedRequests.length, equals(1));
        expect(capturedRequests.first.headers['SOAPACTION'], contains('Stop'));
      }, timeout: Timeout(Duration(seconds: 5)));

      test('next sends Next command', () async {
        final mockClient = createMockClient({
          '/AVTransport/Control': soapResponse('AVTransport', 'Next', {}),
        });

        device.httpClient = mockClient;

        await device.next();

        expect(capturedRequests.first.headers['SOAPACTION'], contains('Next'));
      }, timeout: Timeout(Duration(seconds: 5)));

      test('previous sends Previous command', () async {
        final mockClient = createMockClient({
          '/AVTransport/Control': soapResponse('AVTransport', 'Previous', {}),
        });

        device.httpClient = mockClient;

        await device.previous();

        expect(
          capturedRequests.first.headers['SOAPACTION'],
          contains('Previous'),
        );
      }, timeout: Timeout(Duration(seconds: 5)));
    });

    group('bass and treble', () {
      test(
        'getBass returns current bass level',
        () async {
          final mockClient = createMockClient({
            '/RenderingControl/Control': soapResponse(
              'RenderingControl',
              'GetBass',
              {'CurrentBass': '5'},
            ),
          });

          device.httpClient = mockClient;

          final bass = await device.bass;

          expect(bass, equals(5));
        },
        timeout: Timeout(Duration(seconds: 5)),
      );

      test('setBass sends correct command', () async {
        final mockClient = createMockClient({
          '/RenderingControl/Control': soapResponse(
            'RenderingControl',
            'SetBass',
            {},
          ),
        });

        device.httpClient = mockClient;

        await device.setBass(7);

        expect(capturedRequests.first.body, contains('<DesiredBass>7'));
      }, timeout: Timeout(Duration(seconds: 5)));

      test(
        'getTreble returns current treble level',
        () async {
          final mockClient = createMockClient({
            '/RenderingControl/Control': soapResponse(
              'RenderingControl',
              'GetTreble',
              {'CurrentTreble': '-3'},
            ),
          });

          device.httpClient = mockClient;

          final treble = await device.treble;

          expect(treble, equals(-3));
        },
        timeout: Timeout(Duration(seconds: 5)),
      );

      test('setTreble sends correct command', () async {
        final mockClient = createMockClient({
          '/RenderingControl/Control': soapResponse(
            'RenderingControl',
            'SetTreble',
            {},
          ),
        });

        device.httpClient = mockClient;

        await device.setTreble(-5);

        expect(capturedRequests.first.body, contains('<DesiredTreble>-5'));
      }, timeout: Timeout(Duration(seconds: 5)));
    });

    group('loudness', () {
      test(
        'getLoudness returns current loudness state',
        () async {
          final mockClient = createMockClient({
            '/RenderingControl/Control': soapResponse(
              'RenderingControl',
              'GetLoudness',
              {'CurrentLoudness': '1'},
            ),
          });

          device.httpClient = mockClient;

          final loudness = await device.loudness;

          expect(loudness, isTrue);
        },
        timeout: Timeout(Duration(seconds: 5)),
      );

      test('setLoudness sends correct command', () async {
        final mockClient = createMockClient({
          '/RenderingControl/Control': soapResponse(
            'RenderingControl',
            'SetLoudness',
            {},
          ),
        });

        device.httpClient = mockClient;

        await device.setLoudness(true);

        expect(capturedRequests.first.body, contains('<DesiredLoudness>1'));
      }, timeout: Timeout(Duration(seconds: 5)));
    });

    group('play mode', () {
      test(
        'getPlayMode returns current play mode',
        () async {
          final mockClient = createMockClient({
            '/AVTransport/Control': soapResponse(
              'AVTransport',
              'GetTransportSettings',
              {'PlayMode': 'SHUFFLE', 'RecQualityMode': 'NOT_IMPLEMENTED'},
            ),
          });

          device.httpClient = mockClient;

          final mode = await device.playMode;

          expect(mode, equals('SHUFFLE'));
        },
        timeout: Timeout(Duration(seconds: 5)),
      );

      test('setPlayMode sends correct command', () async {
        final mockClient = createMockClient({
          '/AVTransport/Control': soapResponse(
            'AVTransport',
            'SetPlayMode',
            {},
          ),
        });

        device.httpClient = mockClient;

        await device.setPlayMode('REPEAT_ALL');

        expect(
          capturedRequests.first.body,
          contains('<NewPlayMode>REPEAT_ALL'),
        );
      }, timeout: Timeout(Duration(seconds: 5)));
    });

    group('crossfade', () {
      test(
        'getCrossfade returns current crossfade state',
        () async {
          final mockClient = createMockClient({
            '/AVTransport/Control': soapResponse(
              'AVTransport',
              'GetCrossfadeMode',
              {'CrossfadeMode': '1'},
            ),
          });

          device.httpClient = mockClient;

          final crossfade = await device.crossFade;

          expect(crossfade, isTrue);
        },
        timeout: Timeout(Duration(seconds: 5)),
      );

      test(
        'setCrossfade sends correct command',
        () async {
          final mockClient = createMockClient({
            '/AVTransport/Control': soapResponse(
              'AVTransport',
              'SetCrossfadeMode',
              {},
            ),
          });

          device.httpClient = mockClient;

          await device.setCrossFade(true);

          expect(capturedRequests.first.body, contains('<CrossfadeMode>1'));
        },
        timeout: Timeout(Duration(seconds: 5)),
      );
    });

    group('seek', () {
      test(
        'seek by position sends correct command',
        () async {
          final mockClient = createMockClient({
            '/AVTransport/Control': soapResponse('AVTransport', 'Seek', {}),
          });

          device.httpClient = mockClient;

          await device.seek(position: '0:02:30');

          expect(capturedRequests.first.body, contains('<Unit>REL_TIME'));
          expect(capturedRequests.first.body, contains('<Target>0:02:30'));
        },
        timeout: Timeout(Duration(seconds: 5)),
      );

      test(
        'seek by track sends correct command',
        () async {
          final mockClient = createMockClient({
            '/AVTransport/Control': soapResponse('AVTransport', 'Seek', {}),
          });

          device.httpClient = mockClient;

          // Note: The implementation uses 1-based index, so track 5 becomes Target 6
          await device.seek(track: 5);

          expect(capturedRequests.first.body, contains('<Unit>TRACK_NR'));
          expect(capturedRequests.first.body, contains('<Target>6'));
        },
        timeout: Timeout(Duration(seconds: 5)),
      );
    });

    group('getQueue', () {
      test(
        'getQueue calls ContentDirectory Browse',
        () async {
          final mockClient = createMockClient({
            '/ContentDirectory/Control':
                soapResponse('ContentDirectory', 'Browse', {
                  'Result': '&lt;DIDL-Lite&gt;&lt;/DIDL-Lite&gt;',
                  'NumberReturned': '0',
                  'TotalMatches': '12',
                  'UpdateID': '1',
                }),
          });

          device.httpClient = mockClient;

          await device.getQueue();

          expect(capturedRequests.length, greaterThan(0));
          expect(
            capturedRequests.first.headers['SOAPACTION'],
            contains('Browse'),
          );
        },
        timeout: Timeout(Duration(seconds: 5)),
      );
    });

    group('status light', () {
      test('getStatusLight returns LED state', () async {
        final mockClient = createMockClient({
          '/DeviceProperties/Control': soapResponse(
            'DeviceProperties',
            'GetLEDState',
            {'CurrentLEDState': 'On'},
          ),
        });

        device.httpClient = mockClient;

        final status = await device.statusLight;

        expect(status, isTrue);
      }, timeout: Timeout(Duration(seconds: 5)));

      test(
        'setStatusLight sends correct command',
        () async {
          final mockClient = createMockClient({
            '/DeviceProperties/Control': soapResponse(
              'DeviceProperties',
              'SetLEDState',
              {},
            ),
          });

          device.httpClient = mockClient;

          await device.setStatusLight(false);

          expect(capturedRequests.first.body, contains('<DesiredLEDState>Off'));
        },
        timeout: Timeout(Duration(seconds: 5)),
      );
    });

    group('error handling', () {
      test(
        'throws SoCoUPnPException on UPnP error',
        () async {
          final mockClient = MockClient((request) async {
            return http.Response(errorResponse(402, 'Invalid Args'), 500);
          });

          device.httpClient = mockClient;

          expect(() => device.volume, throwsA(isA<SoCoUPnPException>()));
        },
        timeout: Timeout(Duration(seconds: 5)),
      );
    });
  });

  group('SoCo static helpers', () {
    test('musicSourceFromUri identifies library source', () {
      expect(
        SoCo.musicSourceFromUri('x-file-cifs://server/music/song.mp3'),
        equals(musicSrcLibrary),
      );
    });

    test('musicSourceFromUri identifies radio source', () {
      expect(
        SoCo.musicSourceFromUri('x-sonosapi-stream:s12345'),
        equals(musicSrcRadio),
      );
    });

    test('musicSourceFromUri identifies TV source', () {
      expect(
        SoCo.musicSourceFromUri('x-sonos-htastream:RINCON_XXX:spdif'),
        equals(musicSrcTv),
      );
    });

    test('musicSourceFromUri identifies line-in source', () {
      expect(
        SoCo.musicSourceFromUri('x-rincon-stream:RINCON_XXX'),
        equals(musicSrcLineIn),
      );
    });

    test('musicSourceFromUri identifies web file source', () {
      expect(
        SoCo.musicSourceFromUri('https://example.com/stream.mp3'),
        equals(musicSrcWebFile),
      );
    });

    test('musicSourceFromUri returns unknown for unrecognized URI', () {
      expect(
        SoCo.musicSourceFromUri('some-unknown-protocol:data'),
        equals(musicSrcUnknown),
      );
    });

    test('musicSourceFromUri returns none for empty URI', () {
      expect(SoCo.musicSourceFromUri(''), equals(musicSrcNone));
    });
  });

  group('playModes constants', () {
    test('playModes contains all valid modes', () {
      expect(playModes.containsKey('NORMAL'), isTrue);
      expect(playModes.containsKey('SHUFFLE'), isTrue);
      expect(playModes.containsKey('SHUFFLE_NOREPEAT'), isTrue);
      expect(playModes.containsKey('REPEAT_ALL'), isTrue);
      expect(playModes.containsKey('REPEAT_ONE'), isTrue);
      expect(playModes.containsKey('SHUFFLE_REPEAT_ONE'), isTrue);
    });

    test('playModeByMeaning is inverse of playModes', () {
      for (final entry in playModes.entries) {
        expect(playModeByMeaning[entry.value], equals(entry.key));
      }
    });
  });

  group('audioInputFormats constants', () {
    test('audioInputFormats contains common formats', () {
      expect(audioInputFormats[0], equals('No input connected'));
      expect(audioInputFormats[2], equals('Stereo'));
      expect(audioInputFormats[18], equals('Dolby 5.1'));
    });
  });

  group('soundbars constant', () {
    test('soundbars list contains known models', () {
      expect(soundbars, contains('arc'));
      expect(soundbars, contains('beam'));
      expect(soundbars, contains('playbar'));
      expect(soundbars, contains('ray'));
    });
  });

  group('playlist and favorites methods', () {
    late SoCo device;
    late List<http.Request> capturedRequests;

    setUpAll(() {
      initializeDidlClasses();
    });

    setUp(() {
      device = SoCo('192.168.99.2');
      capturedRequests = [];
    });

    MockClient createMockClient(Map<String, String> responses) {
      return MockClient((request) async {
        capturedRequests.add(request);

        for (final entry in responses.entries) {
          if (request.url.path.contains(entry.key)) {
            return http.Response(entry.value, 200);
          }
        }

        return http.Response('Not Found', 404);
      });
    }

    /// Helper to create a Browse response
    String browseResponse({
      required String result,
      int numberReturned = 0,
      int totalMatches = 0,
      int updateId = 1,
    }) {
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

    /// Sample playlist DIDL
    const samplePlaylistDIDL =
        '''<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
<container id="SQ:1" parentID="SQ:" restricted="true">
<dc:title>My Playlist</dc:title>
<upnp:class>object.container.playlistContainer</upnp:class>
<res protocolInfo="x-rincon-playlist:*:*:*">file:///jffs/settings/savedqueues.rsq#1</res>
</container>
</DIDL-Lite>''';

    const emptyDIDL =
        '<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"></DIDL-Lite>';

    group('getSonosPlaylists', () {
      test(
        'calls music library with correct search type',
        () async {
          final mockClient = createMockClient({
            '/ContentDirectory/Control': browseResponse(
              result: emptyDIDL,
              numberReturned: 0,
              totalMatches: 0,
            ),
          });
          device.httpClient = mockClient;

          final result = await device.getSonosPlaylists();

          expect(result.items, isEmpty);
          expect(result.totalMatches, equals(0));
          expect(capturedRequests.length, greaterThan(0));
        },
        timeout: Timeout(Duration(seconds: 5)),
      );
    });

    group('getSonosFavorites', () {
      test(
        'calls music library getSonosFavorites',
        () async {
          final mockClient = createMockClient({
            '/ContentDirectory/Control': browseResponse(
              result: emptyDIDL,
              numberReturned: 0,
              totalMatches: 0,
            ),
          });
          device.httpClient = mockClient;

          final result = await device.getSonosFavorites();

          expect(result.items, isEmpty);
          expect(result.totalMatches, equals(0));
        },
        timeout: Timeout(Duration(seconds: 5)),
      );
    });

    group('getFavoriteRadioStations', () {
      test(
        'calls music library getFavoriteRadioStations',
        () async {
          final mockClient = createMockClient({
            '/ContentDirectory/Control': browseResponse(
              result: emptyDIDL,
              numberReturned: 0,
              totalMatches: 0,
            ),
          });
          device.httpClient = mockClient;

          final result = await device.getFavoriteRadioStations();

          expect(result.items, isEmpty);
          expect(result.totalMatches, equals(0));
        },
        timeout: Timeout(Duration(seconds: 5)),
      );
    });

    group('getFavoriteRadioShows', () {
      test(
        'calls music library getFavoriteRadioShows',
        () async {
          final mockClient = createMockClient({
            '/ContentDirectory/Control': browseResponse(
              result: emptyDIDL,
              numberReturned: 0,
              totalMatches: 0,
            ),
          });
          device.httpClient = mockClient;

          final result = await device.getFavoriteRadioShows();

          expect(result.items, isEmpty);
          expect(result.totalMatches, equals(0));
        },
        timeout: Timeout(Duration(seconds: 5)),
      );
    });

    group('createSonosPlaylist', () {
      test(
        'creates playlist with correct title',
        () async {
          final mockClient = createMockClient({
            '/AVTransport/Control': soapResponse(
              'AVTransport',
              'CreateSavedQueue',
              {'AssignedObjectID': 'SQ:123'},
            ),
          });
          device.httpClient = mockClient;

          final playlist = await device.createSonosPlaylist('Test Playlist');

          expect(playlist.title, equals('Test Playlist'));
          expect(playlist.itemId, equals('SQ:123'));
          expect(playlist.parentId, equals('SQ:'));
          expect(capturedRequests.length, equals(1));
          expect(
            capturedRequests.first.body,
            contains('<Title>Test Playlist</Title>'),
          );
        },
        timeout: Timeout(Duration(seconds: 5)),
      );
    });

    group('createSonosPlaylistFromQueue', () {
      test(
        'creates playlist from queue with correct title',
        () async {
          final mockClient = createMockClient({
            '/AVTransport/Control': soapResponse('AVTransport', 'SaveQueue', {
              'AssignedObjectID': 'SQ:456',
            }),
          });
          device.httpClient = mockClient;

          final playlist = await device.createSonosPlaylistFromQueue(
            'Queue Playlist',
          );

          expect(playlist.title, equals('Queue Playlist'));
          expect(playlist.itemId, equals('SQ:456'));
          expect(playlist.parentId, equals('SQ:'));
          expect(
            capturedRequests.first.body,
            contains('<Title>Queue Playlist</Title>'),
          );
        },
        timeout: Timeout(Duration(seconds: 5)),
      );
    });

    group('removeSonosPlaylist', () {
      test(
        'removes playlist by DidlPlaylistContainer',
        () async {
          final playlist = DidlPlaylistContainer(
            title: 'Test',
            parentId: 'SQ:',
            itemId: 'SQ:789',
          );

          final mockClient = createMockClient({
            '/ContentDirectory/Control': soapResponse(
              'ContentDirectory',
              'DestroyObject',
              {},
            ),
          });
          device.httpClient = mockClient;

          final result = await device.removeSonosPlaylist(playlist);

          expect(result, isTrue);
          expect(
            capturedRequests.first.body,
            contains('<ObjectID>SQ:789</ObjectID>'),
          );
        },
        timeout: Timeout(Duration(seconds: 5)),
      );

      test(
        'removes playlist by item_id string',
        () async {
          final mockClient = createMockClient({
            '/ContentDirectory/Control': soapResponse(
              'ContentDirectory',
              'DestroyObject',
              {},
            ),
          });
          device.httpClient = mockClient;

          final result = await device.removeSonosPlaylist('SQ:999');

          expect(result, isTrue);
          expect(
            capturedRequests.first.body,
            contains('<ObjectID>SQ:999</ObjectID>'),
          );
        },
        timeout: Timeout(Duration(seconds: 5)),
      );
    });

    group('addItemToSonosPlaylist', () {
      test('adds item to playlist', () async {
        final playlist = DidlPlaylistContainer(
          title: 'Test',
          parentId: 'SQ:',
          itemId: 'SQ:100',
        );
        final track = DidlObject(
          title: 'Test Track',
          parentId: 'A:TRACKS',
          itemId: 'A:TRACKS/track1',
          resources: [
            DidlResource(
              uri: 'x-file-cifs://server/track.mp3',
              protocolInfo: 'http-get:*:audio/mpeg:*',
            ),
          ],
        );

        final mockClient = createMockClient({
          '/ContentDirectory/Control': browseResponse(
            result: emptyDIDL,
            numberReturned: 0,
            totalMatches: 0,
            updateId: 5,
          ),
          '/AVTransport/Control': soapResponse(
            'AVTransport',
            'AddURIToSavedQueue',
            {},
          ),
        });
        device.httpClient = mockClient;

        await device.addItemToSonosPlaylist(track, playlist);

        expect(capturedRequests.length, equals(2));
        expect(
          capturedRequests[1].body,
          contains('<ObjectID>SQ:100</ObjectID>'),
        );
        expect(
          capturedRequests[1].body,
          contains('<EnqueuedURI>x-file-cifs://server/track.mp3</EnqueuedURI>'),
        );
      }, timeout: Timeout(Duration(seconds: 5)));
    });

    group('reorderSonosPlaylist', () {
      test('reorders tracks with int lists', () async {
        final playlist = DidlPlaylistContainer(
          title: 'Test',
          parentId: 'SQ:',
          itemId: 'SQ:200',
        );

        final mockClient = createMockClient({
          '/ContentDirectory/Control': browseResponse(
            result: emptyDIDL,
            numberReturned: 0,
            totalMatches: 0,
            updateId: 10,
          ),
          '/AVTransport/Control': soapResponse(
            'AVTransport',
            'ReorderTracksInSavedQueue',
            {
              'QueueLengthChange': '0',
              'NewUpdateID': '11',
              'NewQueueLength': '5',
            },
          ),
        });
        device.httpClient = mockClient;

        final result = await device.reorderSonosPlaylist(playlist, [0], [1]);

        expect(result['change'], equals(0));
        expect(result['update_id'], equals(11));
        expect(result['length'], equals(5));
      }, timeout: Timeout(Duration(seconds: 5)));

      test('removes track when newPos is null', () async {
        final playlist = DidlPlaylistContainer(
          title: 'Test',
          parentId: 'SQ:',
          itemId: 'SQ:300',
        );

        final mockClient = createMockClient({
          '/ContentDirectory/Control': browseResponse(
            result: emptyDIDL,
            numberReturned: 0,
            totalMatches: 0,
            updateId: 20,
          ),
          '/AVTransport/Control': soapResponse(
            'AVTransport',
            'ReorderTracksInSavedQueue',
            {
              'QueueLengthChange': '-1',
              'NewUpdateID': '21',
              'NewQueueLength': '4',
            },
          ),
        });
        device.httpClient = mockClient;

        final result = await device.reorderSonosPlaylist(playlist, [1], [null]);

        expect(result['change'], equals(-1));
        expect(result['length'], equals(4));
      }, timeout: Timeout(Duration(seconds: 5)));
    });

    group('clearSonosPlaylist', () {
      test('clears all tracks from playlist', () async {
        final playlist = DidlPlaylistContainer(
          title: 'Test',
          parentId: 'SQ:',
          itemId: 'SQ:400',
        );

        // First browse to get track count, then browse playlist contents
        final mockClient = createMockClient({
          '/ContentDirectory/Control': browseResponse(
            result: emptyDIDL,
            numberReturned: 3,
            totalMatches: 3,
            updateId: 30,
          ),
          '/AVTransport/Control': soapResponse(
            'AVTransport',
            'ReorderTracksInSavedQueue',
            {
              'QueueLengthChange': '-3',
              'NewUpdateID': '31',
              'NewQueueLength': '0',
            },
          ),
        });
        device.httpClient = mockClient;

        final result = await device.clearSonosPlaylist(playlist);

        expect(result['change'], equals(-3));
        expect(result['length'], equals(0));
      }, timeout: Timeout(Duration(seconds: 5)));

      test(
        'returns zero change for empty playlist',
        () async {
          final playlist = DidlPlaylistContainer(
            title: 'Empty',
            parentId: 'SQ:',
            itemId: 'SQ:500',
          );

          final mockClient = createMockClient({
            '/ContentDirectory/Control': browseResponse(
              result: emptyDIDL,
              numberReturned: 0,
              totalMatches: 0,
              updateId: 40,
            ),
          });
          device.httpClient = mockClient;

          final result = await device.clearSonosPlaylist(playlist);

          expect(result['change'], equals(0));
          expect(result['length'], equals(0));
        },
        timeout: Timeout(Duration(seconds: 5)),
      );
    });

    group('moveInSonosPlaylist', () {
      test('moves track to new position', () async {
        final playlist = DidlPlaylistContainer(
          title: 'Test',
          parentId: 'SQ:',
          itemId: 'SQ:600',
        );

        final mockClient = createMockClient({
          '/ContentDirectory/Control': browseResponse(
            result: emptyDIDL,
            numberReturned: 0,
            totalMatches: 0,
            updateId: 50,
          ),
          '/AVTransport/Control': soapResponse(
            'AVTransport',
            'ReorderTracksInSavedQueue',
            {
              'QueueLengthChange': '0',
              'NewUpdateID': '51',
              'NewQueueLength': '5',
            },
          ),
        });
        device.httpClient = mockClient;

        final result = await device.moveInSonosPlaylist(playlist, 0, 2);

        expect(result['change'], equals(0));
        expect(result['update_id'], equals(51));
      }, timeout: Timeout(Duration(seconds: 5)));
    });

    group('removeFromSonosPlaylist', () {
      test('removes track from playlist', () async {
        final playlist = DidlPlaylistContainer(
          title: 'Test',
          parentId: 'SQ:',
          itemId: 'SQ:700',
        );

        final mockClient = createMockClient({
          '/ContentDirectory/Control': browseResponse(
            result: emptyDIDL,
            numberReturned: 0,
            totalMatches: 0,
            updateId: 60,
          ),
          '/AVTransport/Control': soapResponse(
            'AVTransport',
            'ReorderTracksInSavedQueue',
            {
              'QueueLengthChange': '-1',
              'NewUpdateID': '61',
              'NewQueueLength': '4',
            },
          ),
        });
        device.httpClient = mockClient;

        final result = await device.removeFromSonosPlaylist(playlist, 1);

        expect(result['change'], equals(-1));
        expect(result['length'], equals(4));
      }, timeout: Timeout(Duration(seconds: 5)));
    });

    group('getSonosPlaylistByAttr', () {
      test('finds playlist by title', () async {
        final mockClient = createMockClient({
          '/ContentDirectory/Control': browseResponse(
            result: samplePlaylistDIDL,
            numberReturned: 1,
            totalMatches: 1,
          ),
        });
        device.httpClient = mockClient;

        final playlist = await device.getSonosPlaylistByAttr(
          'title',
          'My Playlist',
        );

        expect(playlist.title, equals('My Playlist'));
        expect(playlist.itemId, equals('SQ:1'));
      }, timeout: Timeout(Duration(seconds: 5)));

      test('finds playlist by item_id', () async {
        final mockClient = createMockClient({
          '/ContentDirectory/Control': browseResponse(
            result: samplePlaylistDIDL,
            numberReturned: 1,
            totalMatches: 1,
          ),
        });
        device.httpClient = mockClient;

        final playlist = await device.getSonosPlaylistByAttr('item_id', 'SQ:1');

        expect(playlist.itemId, equals('SQ:1'));
      }, timeout: Timeout(Duration(seconds: 5)));

      test('throws when playlist not found', () async {
        final mockClient = createMockClient({
          '/ContentDirectory/Control': browseResponse(
            result: emptyDIDL,
            numberReturned: 0,
            totalMatches: 0,
          ),
        });
        device.httpClient = mockClient;

        expect(
          device.getSonosPlaylistByAttr('title', 'Nonexistent'),
          throwsA(isA<SoCoException>()),
        );
      }, timeout: Timeout(Duration(seconds: 5)));
    });
  });

  group('voice assistant methods', () {
    late SoCo device;
    late List<http.Request> capturedRequests;

    setUp(() {
      // Use unique IP to avoid singleton conflicts
      device = SoCo('192.168.99.2');
      capturedRequests = [];
      // Clear ZoneGroupState cache and speakerInfo to ensure fresh data
      device.zoneGroupState.clearCache();
      device.speakerInfo.clear();
    });

    /// Helper to create ZoneGroupState XML with voice config and mic settings
    String zoneGroupStateWithVoice({
      String voiceConfigState = '0',
      String micEnabled = '0',
      String ip = '192.168.99.2',
      String uuid = 'RINCON_TEST001',
    }) {
      final escaped =
          '''
<ZoneGroupState>
  <ZoneGroups>
    <ZoneGroup Coordinator="$uuid" ID="$uuid:0">
      <ZoneGroupMember UUID="$uuid"
        Location="http://$ip:1400/xml/device_description.xml"
        ZoneName="Test Room"
        BootSeq="123"
        Configuration="1"
        VoiceConfigState="$voiceConfigState"
        MicEnabled="$micEnabled"/>
    </ZoneGroup>
  </ZoneGroups>
</ZoneGroupState>'''
              .replaceAll('&', '&amp;')
              .replaceAll('<', '&lt;')
              .replaceAll('>', '&gt;')
              .replaceAll('"', '&quot;');

      return soapResponse('ZoneGroupTopology', 'GetZoneGroupState', {
        'ZoneGroupState': escaped,
      });
    }

    MockClient createMockClient(Map<String, String> responses) {
      return MockClient((request) async {
        capturedRequests.add(request);
        for (final entry in responses.entries) {
          if (request.url.path.contains(entry.key)) {
            return http.Response(entry.value, 200);
          }
        }
        return http.Response('Not Found', 404);
      });
    }

    test(
      'voiceServiceConfigured returns false when voice not configured',
      () async {
        final mockClient = createMockClient({
          '/ZoneGroupTopology/Control': zoneGroupStateWithVoice(
            voiceConfigState: '0',
          ),
        });
        device.httpClient = mockClient;

        final configured = await device.voiceServiceConfigured;

        expect(configured, isFalse);
        expect(capturedRequests.length, greaterThan(0));
      },
      timeout: Timeout(Duration(seconds: 5)),
    );

    test(
      'voiceServiceConfigured returns true when voice configured',
      () async {
        final mockClient = createMockClient({
          '/ZoneGroupTopology/Control': zoneGroupStateWithVoice(
            voiceConfigState: '2',
          ),
        });
        device.httpClient = mockClient;

        final configured = await device.voiceServiceConfigured;

        expect(configured, isTrue);
      },
      timeout: Timeout(Duration(seconds: 5)),
    );

    test(
      'micEnabled returns null when voice not configured',
      () async {
        final mockClient = createMockClient({
          '/ZoneGroupTopology/Control': zoneGroupStateWithVoice(
            voiceConfigState: '0',
            micEnabled: '1',
          ),
        });
        device.httpClient = mockClient;

        final micEnabled = await device.micEnabled;

        expect(micEnabled, isNull);
      },
      timeout: Timeout(Duration(seconds: 5)),
    );

    test(
      'micEnabled returns false when voice configured but mic disabled',
      () async {
        final mockClient = createMockClient({
          '/ZoneGroupTopology/Control': zoneGroupStateWithVoice(
            voiceConfigState: '2',
            micEnabled: '0',
          ),
        });
        device.httpClient = mockClient;

        final micEnabled = await device.micEnabled;

        expect(micEnabled, isFalse);
      },
      timeout: Timeout(Duration(seconds: 5)),
    );

    test(
      'micEnabled returns true when voice configured and mic enabled',
      () async {
        final mockClient = createMockClient({
          '/ZoneGroupTopology/Control': zoneGroupStateWithVoice(
            voiceConfigState: '2',
            micEnabled: '1',
          ),
        });
        device.httpClient = mockClient;

        final micEnabled = await device.micEnabled;

        expect(micEnabled, isTrue);
      },
      timeout: Timeout(Duration(seconds: 5)),
    );

    test(
      'micEnabled returns null when micEnabled attribute missing',
      () async {
        // Create a zone group state without MicEnabled attribute
        final zgsWithoutMic =
            '''
<ZoneGroupState>
  <ZoneGroups>
    <ZoneGroup Coordinator="RINCON_TEST001" ID="RINCON_TEST001:0">
      <ZoneGroupMember UUID="RINCON_TEST001"
        Location="http://192.168.99.2:1400/xml/device_description.xml"
        ZoneName="Test Room"
        BootSeq="123"
        Configuration="1"
        VoiceConfigState="2"/>
    </ZoneGroup>
  </ZoneGroups>
</ZoneGroupState>'''
                .replaceAll('&', '&amp;')
                .replaceAll('<', '&lt;')
                .replaceAll('>', '&gt;')
                .replaceAll('"', '&quot;');

        final mockClient = createMockClient({
          '/ZoneGroupTopology/Control': soapResponse(
            'ZoneGroupTopology',
            'GetZoneGroupState',
            {'ZoneGroupState': zgsWithoutMic},
          ),
        });
        device.httpClient = mockClient;

        final micEnabled = await device.micEnabled;

        expect(micEnabled, isNull);
      },
      timeout: Timeout(Duration(seconds: 5)),
    );

    test(
      'setMicEnabled throws UnimplementedError',
      () async {
        expect(
          () => device.setMicEnabled(true),
          throwsA(isA<UnimplementedError>()),
        );
      },
      timeout: Timeout(Duration(seconds: 5)),
    );
  });
}
