/// Tests for the core module with HTTP mocking.
library;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:soco/src/core.dart';
import 'package:soco/src/exceptions.dart';

/// Helper to create a successful SOAP response
String soapResponse(String service, String action, Map<String, String> values) {
  final args =
      values.entries.map((e) => '<${e.key}>${e.value}</${e.key}>').join();
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
      });

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
      });

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
      });
    });

    group('mute', () {
      test('getMute returns current mute state', () async {
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
      });

      test('getMute returns false when not muted', () async {
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
      });

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
      });
    });

    group('playback control', () {
      test('play sends Play command', () async {
        final mockClient = createMockClient({
          '/AVTransport/Control': soapResponse('AVTransport', 'Play', {}),
        });

        device.httpClient = mockClient;

        await device.play();

        expect(capturedRequests.length, equals(1));
        expect(
          capturedRequests.first.headers['SOAPACTION'],
          contains('Play'),
        );
        expect(capturedRequests.first.body, contains('<Speed>1'));
      });

      test('pause sends Pause command', () async {
        final mockClient = createMockClient({
          '/AVTransport/Control': soapResponse('AVTransport', 'Pause', {}),
        });

        device.httpClient = mockClient;

        await device.pause();

        expect(capturedRequests.length, equals(1));
        expect(
          capturedRequests.first.headers['SOAPACTION'],
          contains('Pause'),
        );
      });

      test('stop sends Stop command', () async {
        final mockClient = createMockClient({
          '/AVTransport/Control': soapResponse('AVTransport', 'Stop', {}),
        });

        device.httpClient = mockClient;

        await device.stop();

        expect(capturedRequests.length, equals(1));
        expect(
          capturedRequests.first.headers['SOAPACTION'],
          contains('Stop'),
        );
      });

      test('next sends Next command', () async {
        final mockClient = createMockClient({
          '/AVTransport/Control': soapResponse('AVTransport', 'Next', {}),
        });

        device.httpClient = mockClient;

        await device.next();

        expect(
          capturedRequests.first.headers['SOAPACTION'],
          contains('Next'),
        );
      });

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
      });
    });

    group('bass and treble', () {
      test('getBass returns current bass level', () async {
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
      });

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
      });

      test('getTreble returns current treble level', () async {
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
      });

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
      });
    });

    group('loudness', () {
      test('getLoudness returns current loudness state', () async {
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
      });

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
      });
    });

    group('play mode', () {
      test('getPlayMode returns current play mode', () async {
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
      });

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

        expect(capturedRequests.first.body, contains('<NewPlayMode>REPEAT_ALL'));
      });
    });

    group('crossfade', () {
      test('getCrossfade returns current crossfade state', () async {
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
      });

      test('setCrossfade sends correct command', () async {
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
      });
    });

    group('seek', () {
      test('seek by position sends correct command', () async {
        final mockClient = createMockClient({
          '/AVTransport/Control': soapResponse('AVTransport', 'Seek', {}),
        });

        device.httpClient = mockClient;

        await device.seek(position: '0:02:30');

        expect(capturedRequests.first.body, contains('<Unit>REL_TIME'));
        expect(capturedRequests.first.body, contains('<Target>0:02:30'));
      });

      test('seek by track sends correct command', () async {
        final mockClient = createMockClient({
          '/AVTransport/Control': soapResponse('AVTransport', 'Seek', {}),
        });

        device.httpClient = mockClient;

        // Note: The implementation uses 1-based index, so track 5 becomes Target 6
        await device.seek(track: 5);

        expect(capturedRequests.first.body, contains('<Unit>TRACK_NR'));
        expect(capturedRequests.first.body, contains('<Target>6'));
      });
    });

    group('getQueue', () {
      test('getQueue calls ContentDirectory Browse', () async {
        final mockClient = createMockClient({
          '/ContentDirectory/Control': soapResponse(
            'ContentDirectory',
            'Browse',
            {
              'Result': '&lt;DIDL-Lite&gt;&lt;/DIDL-Lite&gt;',
              'NumberReturned': '0',
              'TotalMatches': '12',
              'UpdateID': '1',
            },
          ),
        });

        device.httpClient = mockClient;

        await device.getQueue();

        expect(capturedRequests.length, greaterThan(0));
        expect(
          capturedRequests.first.headers['SOAPACTION'],
          contains('Browse'),
        );
      });
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
      });

      test('setStatusLight sends correct command', () async {
        final mockClient = createMockClient({
          '/DeviceProperties/Control': soapResponse(
            'DeviceProperties',
            'SetLEDState',
            {},
          ),
        });

        device.httpClient = mockClient;

        await device.setStatusLight(false);

        expect(
          capturedRequests.first.body,
          contains('<DesiredLEDState>Off'),
        );
      });
    });

    group('error handling', () {
      test('throws SoCoUPnPException on UPnP error', () async {
        final mockClient = MockClient((request) async {
          return http.Response(errorResponse(402, 'Invalid Args'), 500);
        });

        device.httpClient = mockClient;

        expect(
          () => device.volume,
          throwsA(isA<SoCoUPnPException>()),
        );
      });
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
}
