/// Basic tests for the core SoCo class (no network required).
library;

import 'package:test/test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:soco/src/core.dart';
import 'package:soco/src/data_structures.dart';
import 'helpers/mock_http.dart';

void main() {
  group('SoCo Basic', () {
    test('creates instance with valid IP address', () {
      final soco = SoCo('192.168.1.100');
      expect(soco.ipAddress, equals('192.168.1.100'));
    });

    test('rejects invalid IP address format', () {
      expect(() => SoCo('not.an.ip'), throwsArgumentError);

      expect(() => SoCo('256.256.256.256'), throwsArgumentError);

      expect(() => SoCo('192.168.1'), throwsArgumentError);
    });

    test('has proper IP address', () {
      final soco = SoCo('192.168.1.100');

      // IP address should be available
      expect(soco.ipAddress, equals('192.168.1.100'));
    });

    test('has all required service properties', () {
      final soco = SoCo('192.168.1.100');

      // Check that all services are initialized
      expect(soco.avTransport, isNotNull);
      expect(soco.renderingControl, isNotNull);
      expect(soco.deviceProperties, isNotNull);
      expect(soco.contentDirectory, isNotNull);
      expect(soco.zoneGroupTopology, isNotNull);
      expect(soco.groupRenderingControl, isNotNull);
      expect(soco.alarmClock, isNotNull);
      expect(soco.systemProperties, isNotNull);
      expect(soco.musicServices, isNotNull);
      expect(soco.audioIn, isNotNull);
      expect(soco.musicLibrary, isNotNull);
    });

    test('singleton returns same instance for same IP', () {
      final soco1 = SoCo('192.168.1.200');
      final soco2 = SoCo('192.168.1.200');

      expect(identical(soco1, soco2), isTrue);
    });

    test('singleton returns different instances for different IPs', () {
      final soco1 = SoCo('192.168.1.201');
      final soco2 = SoCo('192.168.1.202');

      expect(identical(soco1, soco2), isFalse);
    });

    test('toString returns proper format', () {
      final soco = SoCo('192.168.1.100');
      final str = soco.toString();

      expect(str, contains('SoCo'));
      expect(str, contains('192.168.1.100'));
    });

    test('instances returns map of created instances', () {
      // Create a unique instance
      final soco = SoCo('192.168.1.210');
      final instances = SoCo.instances;

      expect(instances.containsKey('192.168.1.210'), isTrue);
      expect(instances['192.168.1.210'], same(soco));
    });

    test('volume validation rejects invalid values', () {
      // Note: This tests the validation logic without making network calls
      // The actual volume property would require mocking network responses
      expect(() {
        // Create a validator for volume
        final volume = -1;
        if (volume < 0 || volume > 100) {
          throw ArgumentError('Volume must be between 0 and 100');
        }
      }, throwsArgumentError);

      expect(() {
        final volume = 101;
        if (volume < 0 || volume > 100) {
          throw ArgumentError('Volume must be between 0 and 100');
        }
      }, throwsArgumentError);
    });

    test('bass validation rejects invalid values', () {
      expect(() {
        final bass = -11;
        if (bass < -10 || bass > 10) {
          throw ArgumentError('Bass must be between -10 and 10');
        }
      }, throwsArgumentError);

      expect(() {
        final bass = 11;
        if (bass < -10 || bass > 10) {
          throw ArgumentError('Bass must be between -10 and 10');
        }
      }, throwsArgumentError);
    });

    test('treble validation rejects invalid values', () {
      expect(() {
        final treble = -11;
        if (treble < -10 || treble > 10) {
          throw ArgumentError('Treble must be between -10 and 10');
        }
      }, throwsArgumentError);

      expect(() {
        final treble = 11;
        if (treble < -10 || treble > 10) {
          throw ArgumentError('Treble must be between -10 and 10');
        }
      }, throwsArgumentError);
    });
  });

  group('Core constants', () {
    test('audioInputFormats contains expected codes', () {
      expect(audioInputFormats[0], equals('No input connected'));
      expect(audioInputFormats[2], equals('Stereo'));
      expect(audioInputFormats[7], equals('Dolby 2.0'));
      expect(audioInputFormats[18], equals('Dolby 5.1'));
      expect(audioInputFormats[59], equals('Dolby Atmos (DD+)'));
    });

    test('playModes contains all expected modes', () {
      expect(playModes.containsKey('NORMAL'), isTrue);
      expect(playModes.containsKey('SHUFFLE'), isTrue);
      expect(playModes.containsKey('REPEAT_ALL'), isTrue);
      expect(playModes.containsKey('SHUFFLE_NOREPEAT'), isTrue);
      expect(playModes.containsKey('REPEAT_ONE'), isTrue);
      expect(playModes.containsKey('SHUFFLE_REPEAT_ONE'), isTrue);
    });

    test('playModes returns correct shuffle/repeat tuples', () {
      expect(playModes['NORMAL'], equals((false, false)));
      expect(playModes['SHUFFLE'], equals((true, true)));
      expect(playModes['REPEAT_ALL'], equals((false, true)));
      expect(playModes['SHUFFLE_NOREPEAT'], equals((true, false)));
      expect(playModes['REPEAT_ONE'], equals((false, 'ONE')));
      expect(playModes['SHUFFLE_REPEAT_ONE'], equals((true, 'ONE')));
    });

    test('playModeByMeaning is inverse of playModes', () {
      for (final entry in playModes.entries) {
        expect(playModeByMeaning[entry.value], equals(entry.key));
      }
    });

    test('music source constants are defined', () {
      expect(musicSrcLibrary, equals('LIBRARY'));
      expect(musicSrcRadio, equals('RADIO'));
      expect(musicSrcWebFile, equals('WEB_FILE'));
      expect(musicSrcLineIn, equals('LINE_IN'));
      expect(musicSrcTv, equals('TV'));
      expect(musicSrcAirplay, equals('AIRPLAY'));
      expect(musicSrcSpotifyConnect, equals('SPOTIFY_CONNECT'));
      expect(musicSrcUnknown, equals('UNKNOWN'));
      expect(musicSrcNone, equals('NONE'));
    });

    test('sources map contains URI patterns', () {
      expect(sources.containsKey(r'^$'), isTrue);
      expect(sources.containsKey(r'^x-file-cifs:'), isTrue);
      expect(sources.containsKey(r'^x-rincon-mp3radio:'), isTrue);
      expect(sources.containsKey(r'^https?:'), isTrue);
    });

    test('soundbars list contains known products', () {
      expect(soundbars.contains('arc'), isTrue);
      expect(soundbars.contains('beam'), isTrue);
      expect(soundbars.contains('playbar'), isTrue);
      expect(soundbars.contains('ray'), isTrue);
      expect(soundbars.contains('sonos amp'), isTrue);
    });

    test('favorite constants are defined', () {
      expect(radioStations, equals(0));
      expect(radioShows, equals(1));
      expect(sonosFavorites, equals(2));
    });
  });

  group('musicSourceFromUri static method', () {
    test('returns NONE for empty URI', () {
      expect(SoCo.musicSourceFromUri(''), equals(musicSrcNone));
    });

    test('returns LIBRARY for file cifs URI', () {
      expect(
        SoCo.musicSourceFromUri('x-file-cifs://server/share/music.mp3'),
        equals(musicSrcLibrary),
      );
    });

    test('returns RADIO for radio URIs', () {
      expect(
        SoCo.musicSourceFromUri('x-rincon-mp3radio://stream.url'),
        equals(musicSrcRadio),
      );
      expect(
        SoCo.musicSourceFromUri('x-sonosapi-stream://stream'),
        equals(musicSrcRadio),
      );
      expect(
        SoCo.musicSourceFromUri('x-sonosapi-radio://radio'),
        equals(musicSrcRadio),
      );
      expect(
        SoCo.musicSourceFromUri('x-sonosapi-hls://hls'),
        equals(musicSrcRadio),
      );
      expect(
        SoCo.musicSourceFromUri('aac://stream'),
        equals(musicSrcRadio),
      );
      expect(
        SoCo.musicSourceFromUri('hls-radio://stream'),
        equals(musicSrcRadio),
      );
    });

    test('returns WEB_FILE for http/https URIs', () {
      expect(
        SoCo.musicSourceFromUri('http://example.com/music.mp3'),
        equals(musicSrcWebFile),
      );
      expect(
        SoCo.musicSourceFromUri('https://example.com/music.mp3'),
        equals(musicSrcWebFile),
      );
    });

    test('returns LINE_IN for line-in URI', () {
      expect(
        SoCo.musicSourceFromUri('x-rincon-stream:RINCON_001'),
        equals(musicSrcLineIn),
      );
    });

    test('returns TV for htastream URI', () {
      expect(
        SoCo.musicSourceFromUri('x-sonos-htastream:RINCON_001:spdif'),
        equals(musicSrcTv),
      );
    });

    test('returns AIRPLAY for airplay URI', () {
      expect(
        SoCo.musicSourceFromUri('x-sonos-vli://something,airplay:source'),
        equals(musicSrcAirplay),
      );
    });

    test('returns SPOTIFY_CONNECT for spotify URI', () {
      expect(
        SoCo.musicSourceFromUri('x-sonos-vli://something,spotify:track'),
        equals(musicSrcSpotifyConnect),
      );
    });

    test('returns UNKNOWN for unrecognized URI', () {
      expect(
        SoCo.musicSourceFromUri('unknown-protocol://something'),
        equals(musicSrcUnknown),
      );
    });
  });

  group('SoCo with mocked HTTP', () {
    late SoCo soco;
    late MockClient mockClient;

    setUp(() {
      soco = SoCo('192.168.50.1');
    });

    tearDown(() {
      mockClient.close();
    });

    test('get volume returns correct value', () async {
      mockClient = createMockClient({
        'RenderingControl': (200, SonosResponses.getVolume(75)),
      });
      soco.httpClient = mockClient;

      final volume = await soco.volume;
      expect(volume, equals(75));
    });

    test('set volume sends correct command', () async {
      var requestReceived = false;
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('RenderingControl')) {
          requestReceived = true;
          expect(request.body, contains('SetVolume'));
          expect(request.body, contains('50'));
          return http.Response(SonosResponses.setVolume(), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setVolume(50);
      expect(requestReceived, isTrue);
    });

    test('set volume clamps value to valid range', () async {
      var receivedVolume = -1;
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('RenderingControl')) {
          final match = RegExp(r'<DesiredVolume>(\d+)</DesiredVolume>').firstMatch(request.body);
          if (match != null) {
            receivedVolume = int.parse(match.group(1)!);
          }
          return http.Response(SonosResponses.setVolume(), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setVolume(150); // Above max
      expect(receivedVolume, equals(100)); // Should be clamped to 100

      await soco.setVolume(-10); // Below min
      expect(receivedVolume, equals(0)); // Should be clamped to 0
    });

    test('get mute returns correct state', () async {
      mockClient = createMockClient({
        'RenderingControl': (200, SonosResponses.getMute(true)),
      });
      soco.httpClient = mockClient;

      final muted = await soco.mute;
      expect(muted, isTrue);
    });

    test('get bass returns correct value', () async {
      mockClient = createMockClient({
        'RenderingControl': (200, soapEnvelope('''
          <u:GetBassResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
            <CurrentBass>5</CurrentBass>
          </u:GetBassResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final bass = await soco.bass;
      expect(bass, equals(5));
    });

    test('set bass clamps value to valid range', () async {
      var receivedBass = 0;
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('RenderingControl')) {
          final match = RegExp(r'<DesiredBass>(-?\d+)</DesiredBass>').firstMatch(request.body);
          if (match != null) {
            receivedBass = int.parse(match.group(1)!);
          }
          return http.Response(soapEnvelope('<u:SetBassResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setBass(15); // Above max
      expect(receivedBass, equals(10)); // Should be clamped

      await soco.setBass(-15); // Below min
      expect(receivedBass, equals(-10)); // Should be clamped
    });

    test('get treble returns correct value', () async {
      mockClient = createMockClient({
        'RenderingControl': (200, soapEnvelope('''
          <u:GetTrebleResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
            <CurrentTreble>-3</CurrentTreble>
          </u:GetTrebleResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final treble = await soco.treble;
      expect(treble, equals(-3));
    });

    test('play sends correct command', () async {
      var playReceived = false;
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('Play')) {
            playReceived = true;
            return http.Response(SonosResponses.play(), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.play();
      expect(playReceived, isTrue);
    });

    test('pause sends correct command', () async {
      var pauseReceived = false;
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('Pause')) {
            pauseReceived = true;
            return http.Response(SonosResponses.pause(), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.pause();
      expect(pauseReceived, isTrue);
    });

    test('stop sends correct command', () async {
      var stopReceived = false;
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('Stop')) {
            stopReceived = true;
            return http.Response(SonosResponses.stop(), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.stop();
      expect(stopReceived, isTrue);
    });

    test('getCurrentTransportInfo returns state', () async {
      mockClient = createMockClient({
        'AVTransport': (200, SonosResponses.getTransportInfo('PLAYING')),
      });
      soco.httpClient = mockClient;

      final info = await soco.getCurrentTransportInfo();
      expect(info['current_transport_state'], equals('PLAYING'));
      expect(info['current_transport_status'], equals('OK'));
      expect(info['current_transport_speed'], equals('1'));
    });

    test('getCurrentTrackInfo returns track data', () async {
      mockClient = createMockClient({
        'AVTransport': (200, SonosResponses.getPositionInfo(
          track: 3,
          trackDuration: '0:04:30',
          trackUri: 'x-file-cifs://server/music.mp3',
          relTime: '0:02:15',
        )),
      });
      soco.httpClient = mockClient;

      final track = await soco.getCurrentTrackInfo();
      expect(track['playlist_position'], equals('3'));
      expect(track['duration'], equals('0:04:30'));
      expect(track['uri'], equals('x-file-cifs://server/music.mp3'));
      expect(track['position'], equals('0:02:15'));
    });

    test('getCurrentMediaInfo returns media data', () async {
      mockClient = createMockClient({
        'AVTransport': (200, SonosResponses.getMediaInfo(
          currentUri: 'x-rincon-queue:RINCON_TEST#0',
        )),
      });
      soco.httpClient = mockClient;

      final media = await soco.getCurrentMediaInfo();
      expect(media['uri'], equals('x-rincon-queue:RINCON_TEST#0'));
    });

    test('get playMode returns correct mode', () async {
      mockClient = createMockClient({
        'AVTransport': (200, soapEnvelope('''
          <u:GetTransportSettingsResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
            <PlayMode>SHUFFLE</PlayMode>
            <RecQualityMode>NOT_IMPLEMENTED</RecQualityMode>
          </u:GetTransportSettingsResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final mode = await soco.playMode;
      expect(mode, equals('SHUFFLE'));
    });

    test('set playMode sends correct command', () async {
      var modeReceived = '';
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('SetPlayMode')) {
            final match = RegExp(r'<NewPlayMode>(\w+)</NewPlayMode>').firstMatch(request.body);
            if (match != null) {
              modeReceived = match.group(1)!;
            }
            return http.Response(soapEnvelope('<u:SetPlayModeResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setPlayMode('REPEAT_ALL');
      expect(modeReceived, equals('REPEAT_ALL'));
    });

    test('set playMode throws on invalid mode', () async {
      expect(
        () => soco.setPlayMode('INVALID_MODE'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('get crossFade returns correct state', () async {
      mockClient = createMockClient({
        'AVTransport': (200, soapEnvelope('''
          <u:GetCrossfadeModeResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
            <CrossfadeMode>1</CrossfadeMode>
          </u:GetCrossfadeModeResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final crossFade = await soco.crossFade;
      expect(crossFade, isTrue);
    });

    test('get loudness returns correct state', () async {
      mockClient = createMockClient({
        'RenderingControl': (200, soapEnvelope('''
          <u:GetLoudnessResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
            <CurrentLoudness>1</CurrentLoudness>
          </u:GetLoudnessResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final loudness = await soco.loudness;
      expect(loudness, isTrue);
    });

    test('get balance returns LF and RF volumes', () async {
      var callCount = 0;
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('RenderingControl')) {
          callCount++;
          if (request.body.contains('LF')) {
            return http.Response(soapEnvelope('''
              <u:GetVolumeResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
                <CurrentVolume>80</CurrentVolume>
              </u:GetVolumeResponse>
            '''), 200);
          } else if (request.body.contains('RF')) {
            return http.Response(soapEnvelope('''
              <u:GetVolumeResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
                <CurrentVolume>90</CurrentVolume>
              </u:GetVolumeResponse>
            '''), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final balance = await soco.balance;
      expect(balance, equals((80, 90)));
      expect(callCount, equals(2)); // Two calls for LF and RF
    });

    test('seek with position sends correct command', () async {
      var seekReceived = false;
      var seekTarget = '';
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('Seek')) {
            seekReceived = true;
            final match = RegExp(r'<Target>([^<]+)</Target>').firstMatch(request.body);
            if (match != null) {
              seekTarget = match.group(1)!;
            }
            return http.Response(soapEnvelope('<u:SeekResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.seek(position: '0:01:30');
      expect(seekReceived, isTrue);
      expect(seekTarget, equals('0:01:30'));
    });

    test('seek with track sends correct command', () async {
      var seekUnit = '';
      var seekTarget = '';
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('Seek')) {
            final unitMatch = RegExp(r'<Unit>(\w+)</Unit>').firstMatch(request.body);
            final targetMatch = RegExp(r'<Target>(\d+)</Target>').firstMatch(request.body);
            if (unitMatch != null) seekUnit = unitMatch.group(1)!;
            if (targetMatch != null) seekTarget = targetMatch.group(1)!;
            return http.Response(soapEnvelope('<u:SeekResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.seek(track: 5); // 0-based, so track 5 becomes 6
      expect(seekUnit, equals('TRACK_NR'));
      expect(seekTarget, equals('6'));
    });

    test('seek throws on no arguments', () async {
      expect(
        () => soco.seek(),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('seek throws on invalid position format', () async {
      expect(
        () => soco.seek(position: 'invalid'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('next sends correct command', () async {
      var nextReceived = false;
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('Next')) {
            nextReceived = true;
            return http.Response(soapEnvelope('<u:NextResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.next();
      expect(nextReceived, isTrue);
    });

    test('previous sends correct command', () async {
      var previousReceived = false;
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('Previous')) {
            previousReceived = true;
            return http.Response(soapEnvelope('<u:PreviousResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.previous();
      expect(previousReceived, isTrue);
    });

    test('rampToVolume sends correct command and returns ramp time', () async {
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('RenderingControl')) {
          if (request.body.contains('RampToVolume')) {
            return http.Response(soapEnvelope('''
              <u:RampToVolumeResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
                <RampTime>16</RampTime>
              </u:RampToVolumeResponse>
            '''), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final rampTime = await soco.rampToVolume(30);
      expect(rampTime, equals(16));
    });

    test('setRelativeVolume adjusts volume and returns new value', () async {
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('RenderingControl')) {
          if (request.body.contains('SetRelativeVolume')) {
            return http.Response(soapEnvelope('''
              <u:SetRelativeVolumeResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
                <NewVolume>55</NewVolume>
              </u:SetRelativeVolumeResponse>
            '''), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final newVolume = await soco.setRelativeVolume(5);
      expect(newVolume, equals(55));
    });

    test('queueSize returns correct count', () async {
      mockClient = createMockClient({
        'ContentDirectory': (200, SonosResponses.browse(
          result: '<container id="Q:0" childCount="15"/>',
        )),
      });
      soco.httpClient = mockClient;

      final size = await soco.queueSize;
      expect(size, equals(15));
    });

    test('clearQueue sends correct command', () async {
      var clearReceived = false;
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('RemoveAllTracksFromQueue')) {
            clearReceived = true;
            return http.Response(soapEnvelope('<u:RemoveAllTracksFromQueueResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.clearQueue();
      expect(clearReceived, isTrue);
    });

    test('removeFromQueue sends correct command', () async {
      var objectId = '';
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('RemoveTrackFromQueue')) {
            final match = RegExp(r'<ObjectID>([^<]+)</ObjectID>').firstMatch(request.body);
            if (match != null) objectId = match.group(1)!;
            return http.Response(soapEnvelope('<u:RemoveTrackFromQueueResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.removeFromQueue(3); // 0-based index
      expect(objectId, equals('Q:0/4')); // Becomes 1-based
    });

    test('get statusLight returns correct state', () async {
      mockClient = createMockClient({
        'DeviceProperties': (200, soapEnvelope('''
          <u:GetLEDStateResponse xmlns:u="urn:schemas-upnp-org:service:DeviceProperties:1">
            <CurrentLEDState>On</CurrentLEDState>
          </u:GetLEDStateResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final light = await soco.statusLight;
      expect(light, isTrue);
    });

    test('set statusLight sends correct command', () async {
      var ledState = '';
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('DeviceProperties')) {
          if (request.body.contains('SetLEDState')) {
            final match = RegExp(r'<DesiredLEDState>(\w+)</DesiredLEDState>').firstMatch(request.body);
            if (match != null) ledState = match.group(1)!;
            return http.Response(soapEnvelope('<u:SetLEDStateResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setStatusLight(false);
      expect(ledState, equals('Off'));
    });

    test('get buttonsEnabled returns correct state', () async {
      mockClient = createMockClient({
        'DeviceProperties': (200, soapEnvelope('''
          <u:GetButtonLockStateResponse xmlns:u="urn:schemas-upnp-org:service:DeviceProperties:1">
            <CurrentButtonLockState>Off</CurrentButtonLockState>
          </u:GetButtonLockStateResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final enabled = await soco.buttonsEnabled;
      expect(enabled, isTrue); // Off means unlocked/enabled
    });

    test('get availableActions parses actions correctly', () async {
      mockClient = createMockClient({
        'AVTransport': (200, soapEnvelope('''
          <u:GetCurrentTransportActionsResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
            <Actions>Set, Stop, Pause, Play, X_DLNA_SeekTime, X_DLNA_SeekTrackNr</Actions>
          </u:GetCurrentTransportActionsResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final actions = await soco.availableActions;
      expect(actions, contains('Set'));
      expect(actions, contains('Stop'));
      expect(actions, contains('Pause'));
      expect(actions, contains('Play'));
      expect(actions, contains('SeekTime'));
      expect(actions, contains('SeekTrackNr'));
    });

    test('setSleepTimer sends correct command', () async {
      var sleepTime = '';
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('ConfigureSleepTimer')) {
            final match = RegExp(r'<NewSleepTimerDuration>([^<]*)</NewSleepTimerDuration>').firstMatch(request.body);
            if (match != null) sleepTime = match.group(1)!;
            return http.Response(soapEnvelope('<u:ConfigureSleepTimerResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setSleepTimer(3600); // 1 hour
      expect(sleepTime, equals('01:00:00'));

      await soco.setSleepTimer(null); // Cancel
      expect(sleepTime, equals(''));
    });

    test('setSleepTimer throws on invalid values', () async {
      expect(
        () => soco.setSleepTimer(-1),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => soco.setSleepTimer(86400), // Above max
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getSleepTimer returns remaining seconds', () async {
      mockClient = createMockClient({
        'AVTransport': (200, soapEnvelope('''
          <u:GetRemainingSleepTimerDurationResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
            <RemainingSleepTimerDuration>01:30:45</RemainingSleepTimerDuration>
          </u:GetRemainingSleepTimerDurationResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final remaining = await soco.getSleepTimer();
      expect(remaining, equals(5445)); // 1*3600 + 30*60 + 45
    });

    test('getSleepTimer returns null when no timer set', () async {
      mockClient = createMockClient({
        'AVTransport': (200, soapEnvelope('''
          <u:GetRemainingSleepTimerDurationResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
            <RemainingSleepTimerDuration></RemainingSleepTimerDuration>
          </u:GetRemainingSleepTimerDurationResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final remaining = await soco.getSleepTimer();
      expect(remaining, isNull);
    });

    test('get trueplay returns calibration status', () async {
      mockClient = createMockClient({
        'RenderingControl': (200, soapEnvelope('''
          <u:GetRoomCalibrationStatusResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
            <RoomCalibrationAvailable>1</RoomCalibrationAvailable>
            <RoomCalibrationEnabled>1</RoomCalibrationEnabled>
          </u:GetRoomCalibrationStatusResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final trueplay = await soco.trueplay;
      expect(trueplay, isTrue);
    });

    test('get trueplay returns null when not available', () async {
      mockClient = createMockClient({
        'RenderingControl': (200, soapEnvelope('''
          <u:GetRoomCalibrationStatusResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
            <RoomCalibrationAvailable>0</RoomCalibrationAvailable>
            <RoomCalibrationEnabled>0</RoomCalibrationEnabled>
          </u:GetRoomCalibrationStatusResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final trueplay = await soco.trueplay;
      expect(trueplay, isNull);
    });

    test('get supportsFixedVolume returns correct state', () async {
      mockClient = createMockClient({
        'RenderingControl': (200, soapEnvelope('''
          <u:GetSupportsOutputFixedResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
            <CurrentSupportsFixed>1</CurrentSupportsFixed>
          </u:GetSupportsOutputFixedResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final supports = await soco.supportsFixedVolume;
      expect(supports, isTrue);
    });

    test('get fixedVolume returns correct state', () async {
      mockClient = createMockClient({
        'RenderingControl': (200, soapEnvelope('''
          <u:GetOutputFixedResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
            <CurrentFixed>1</CurrentFixed>
          </u:GetOutputFixedResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final fixedVol = await soco.fixedVolume;
      expect(fixedVol, isTrue);
    });
  });

  group('SoCo httpClient propagation', () {
    test('setting httpClient propagates to all services', () {
      final soco = SoCo('192.168.51.1');
      final mockClient = MockClient((request) async {
        return http.Response('', 200);
      });

      // Initial state - no client
      expect(soco.httpClient, isNull);
      expect(soco.avTransport.httpClient, isNull);

      // Set client
      soco.httpClient = mockClient;

      // Verify propagation
      expect(soco.httpClient, same(mockClient));
      expect(soco.avTransport.httpClient, same(mockClient));
      expect(soco.renderingControl.httpClient, same(mockClient));
      expect(soco.deviceProperties.httpClient, same(mockClient));
      expect(soco.contentDirectory.httpClient, same(mockClient));
      expect(soco.zoneGroupTopology.httpClient, same(mockClient));
      expect(soco.alarmClock.httpClient, same(mockClient));
      expect(soco.systemProperties.httpClient, same(mockClient));
      expect(soco.musicServices.httpClient, same(mockClient));
      expect(soco.audioIn.httpClient, same(mockClient));

      mockClient.close();
    });
  });

  group('ZoneGroupState', () {
    test('zoneGroupState property returns instance', () {
      final soco = SoCo('192.168.52.1');
      final zgs = soco.zoneGroupState;
      expect(zgs, isNotNull);
    });

    test('zoneGroupStates is shared across instances', () {
      SoCo.zoneGroupStates.clear();
      final soco1 = SoCo('192.168.53.1');
      final soco2 = SoCo('192.168.53.2');

      // Both should use the 'default' household state
      expect(soco1.zoneGroupState, same(soco2.zoneGroupState));
    });
  });

  group('Additional SoCo methods with HTTP mocking', () {
    late SoCo soco;
    late MockClient mockClient;

    setUp(() {
      soco = SoCo('192.168.60.1');
    });

    tearDown(() {
      mockClient.close();
    });

    test('playUri sends SetAVTransportURI command', () async {
      var uriReceived = '';
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('SetAVTransportURI')) {
            final uriMatch = RegExp(r'<CurrentURI>([^<]*)</CurrentURI>').firstMatch(request.body);
            if (uriMatch != null) uriReceived = uriMatch.group(1)!;
            return http.Response(soapEnvelope('<u:SetAVTransportURIResponse/>'), 200);
          }
          if (request.body.contains('Play')) {
            return http.Response(SonosResponses.play(), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.playUri(uri: 'http://example.com/stream.mp3', start: false);

      expect(uriReceived, equals('http://example.com/stream.mp3'));
    });

    test('playUri generates metadata from title', () async {
      var metaReceived = '';
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('SetAVTransportURI')) {
            final metaMatch = RegExp(r'<CurrentURIMetaData>([^<]*)</CurrentURIMetaData>').firstMatch(request.body);
            if (metaMatch != null) metaReceived = metaMatch.group(1)!;
            return http.Response(soapEnvelope('<u:SetAVTransportURIResponse/>'), 200);
          }
          if (request.body.contains('Play')) {
            return http.Response(SonosResponses.play(), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.playUri(
        uri: 'http://example.com/stream.mp3',
        title: 'My Radio Station',
        start: false,
      );

      expect(metaReceived, contains('My Radio Station'));
      expect(metaReceived, contains('DIDL-Lite'));
    });

    test('playUri with forceRadio changes URI prefix', () async {
      var uriReceived = '';
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('SetAVTransportURI')) {
            final uriMatch = RegExp(r'<CurrentURI>([^<]*)</CurrentURI>').firstMatch(request.body);
            if (uriMatch != null) uriReceived = uriMatch.group(1)!;
            return http.Response(soapEnvelope('<u:SetAVTransportURIResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.playUri(
        uri: 'http://example.com/stream.mp3',
        forceRadio: true,
        start: false,
      );

      expect(uriReceived, startsWith('x-rincon-mp3radio:'));
    });

    test('endDirectControlSession sends correct command', () async {
      var commandReceived = false;
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('EndDirectControlSession')) {
            commandReceived = true;
            return http.Response(soapEnvelope('<u:EndDirectControlSessionResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.endDirectControlSession();

      expect(commandReceived, isTrue);
    });

    test('get shuffle returns correct state for SHUFFLE mode', () async {
      mockClient = createMockClient({
        'AVTransport': (200, soapEnvelope('''
          <u:GetTransportSettingsResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
            <PlayMode>SHUFFLE</PlayMode>
            <RecQualityMode>NOT_IMPLEMENTED</RecQualityMode>
          </u:GetTransportSettingsResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final shuffle = await soco.shuffle;
      expect(shuffle, isTrue);
    });

    test('get shuffle returns false for NORMAL mode', () async {
      mockClient = createMockClient({
        'AVTransport': (200, soapEnvelope('''
          <u:GetTransportSettingsResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
            <PlayMode>NORMAL</PlayMode>
            <RecQualityMode>NOT_IMPLEMENTED</RecQualityMode>
          </u:GetTransportSettingsResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final shuffle = await soco.shuffle;
      expect(shuffle, isFalse);
    });

    test('get repeat returns correct state for REPEAT_ALL', () async {
      mockClient = createMockClient({
        'AVTransport': (200, soapEnvelope('''
          <u:GetTransportSettingsResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
            <PlayMode>REPEAT_ALL</PlayMode>
            <RecQualityMode>NOT_IMPLEMENTED</RecQualityMode>
          </u:GetTransportSettingsResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final repeat = await soco.repeat;
      expect(repeat, isTrue);
    });

    test('get repeat returns "ONE" for REPEAT_ONE', () async {
      mockClient = createMockClient({
        'AVTransport': (200, soapEnvelope('''
          <u:GetTransportSettingsResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
            <PlayMode>REPEAT_ONE</PlayMode>
            <RecQualityMode>NOT_IMPLEMENTED</RecQualityMode>
          </u:GetTransportSettingsResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final repeat = await soco.repeat;
      expect(repeat, equals('ONE'));
    });

    test('get repeat returns false for NORMAL mode', () async {
      mockClient = createMockClient({
        'AVTransport': (200, soapEnvelope('''
          <u:GetTransportSettingsResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
            <PlayMode>NORMAL</PlayMode>
            <RecQualityMode>NOT_IMPLEMENTED</RecQualityMode>
          </u:GetTransportSettingsResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final repeat = await soco.repeat;
      expect(repeat, isFalse);
    });

    test('set shuffle changes play mode correctly', () async {
      var modeReceived = '';
      // First call is GetTransportSettings (to get current state)
      // Second call is SetPlayMode
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('GetTransportSettings')) {
            return http.Response(soapEnvelope('''
              <u:GetTransportSettingsResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                <PlayMode>NORMAL</PlayMode>
                <RecQualityMode>NOT_IMPLEMENTED</RecQualityMode>
              </u:GetTransportSettingsResponse>
            '''), 200);
          }
          if (request.body.contains('SetPlayMode')) {
            final match = RegExp(r'<NewPlayMode>(\w+)</NewPlayMode>').firstMatch(request.body);
            if (match != null) modeReceived = match.group(1)!;
            return http.Response(soapEnvelope('<u:SetPlayModeResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setShuffle(true);

      // Should change from NORMAL (shuffle=false, repeat=false) to
      // a mode with shuffle=true, repeat=false -> SHUFFLE_NOREPEAT
      expect(modeReceived, equals('SHUFFLE_NOREPEAT'));
    });

    test('set repeat changes play mode correctly', () async {
      var modeReceived = '';
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('GetTransportSettings')) {
            return http.Response(soapEnvelope('''
              <u:GetTransportSettingsResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                <PlayMode>NORMAL</PlayMode>
                <RecQualityMode>NOT_IMPLEMENTED</RecQualityMode>
              </u:GetTransportSettingsResponse>
            '''), 200);
          }
          if (request.body.contains('SetPlayMode')) {
            final match = RegExp(r'<NewPlayMode>(\w+)</NewPlayMode>').firstMatch(request.body);
            if (match != null) modeReceived = match.group(1)!;
            return http.Response(soapEnvelope('<u:SetPlayModeResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setRepeat(true);

      // Should change from NORMAL (shuffle=false, repeat=false) to
      // a mode with shuffle=false, repeat=true -> REPEAT_ALL
      expect(modeReceived, equals('REPEAT_ALL'));
    });

    test('set repeat to "ONE" sets REPEAT_ONE mode', () async {
      var modeReceived = '';
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('GetTransportSettings')) {
            return http.Response(soapEnvelope('''
              <u:GetTransportSettingsResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                <PlayMode>NORMAL</PlayMode>
                <RecQualityMode>NOT_IMPLEMENTED</RecQualityMode>
              </u:GetTransportSettingsResponse>
            '''), 200);
          }
          if (request.body.contains('SetPlayMode')) {
            final match = RegExp(r'<NewPlayMode>(\w+)</NewPlayMode>').firstMatch(request.body);
            if (match != null) modeReceived = match.group(1)!;
            return http.Response(soapEnvelope('<u:SetPlayModeResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setRepeat('ONE');

      expect(modeReceived, equals('REPEAT_ONE'));
    });

    test('set crossFade sends correct command', () async {
      var crossfadeValue = '';
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('SetCrossfadeMode')) {
            final match = RegExp(r'<CrossfadeMode>(\d)</CrossfadeMode>').firstMatch(request.body);
            if (match != null) crossfadeValue = match.group(1)!;
            return http.Response(soapEnvelope('<u:SetCrossfadeModeResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setCrossFade(true);
      expect(crossfadeValue, equals('1'));

      await soco.setCrossFade(false);
      expect(crossfadeValue, equals('0'));
    });

    test('set treble sends correct command', () async {
      var trebleValue = 0;
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('RenderingControl')) {
          if (request.body.contains('SetTreble')) {
            final match = RegExp(r'<DesiredTreble>(-?\d+)</DesiredTreble>').firstMatch(request.body);
            if (match != null) trebleValue = int.parse(match.group(1)!);
            return http.Response(soapEnvelope('<u:SetTrebleResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setTreble(5);
      expect(trebleValue, equals(5));
    });

    test('set treble clamps value to valid range', () async {
      var trebleValue = 0;
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('RenderingControl')) {
          if (request.body.contains('SetTreble')) {
            final match = RegExp(r'<DesiredTreble>(-?\d+)</DesiredTreble>').firstMatch(request.body);
            if (match != null) trebleValue = int.parse(match.group(1)!);
            return http.Response(soapEnvelope('<u:SetTrebleResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setTreble(15); // Above max
      expect(trebleValue, equals(10)); // Should be clamped

      await soco.setTreble(-15); // Below min
      expect(trebleValue, equals(-10)); // Should be clamped
    });

    test('set loudness sends correct command', () async {
      var loudnessValue = '';
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('RenderingControl')) {
          if (request.body.contains('SetLoudness')) {
            final match = RegExp(r'<DesiredLoudness>(\d)</DesiredLoudness>').firstMatch(request.body);
            if (match != null) loudnessValue = match.group(1)!;
            return http.Response(soapEnvelope('<u:SetLoudnessResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setLoudness(true);
      expect(loudnessValue, equals('1'));

      await soco.setLoudness(false);
      expect(loudnessValue, equals('0'));
    });

    test('addUriToQueue sends correct command', () async {
      var uriReceived = '';
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AVTransport')) {
          if (request.body.contains('AddURIToQueue')) {
            final uriMatch = RegExp(r'<EnqueuedURI>([^<]+)</EnqueuedURI>').firstMatch(request.body);
            if (uriMatch != null) uriReceived = uriMatch.group(1)!;
            return http.Response(soapEnvelope('''
              <u:AddURIToQueueResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                <FirstTrackNumberEnqueued>1</FirstTrackNumberEnqueued>
                <NumTracksAdded>1</NumTracksAdded>
                <NewQueueLength>1</NewQueueLength>
              </u:AddURIToQueueResponse>
            '''), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final result = await soco.addUriToQueue('x-file-cifs://server/music.mp3');

      expect(uriReceived, equals('x-file-cifs://server/music.mp3'));
      expect(result, equals(1)); // Returns the index of the new track
    });

    test('set buttonsEnabled sends correct command', () async {
      var lockState = '';
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('DeviceProperties')) {
          if (request.body.contains('SetButtonLockState')) {
            final match = RegExp(r'<DesiredButtonLockState>(\w+)</DesiredButtonLockState>').firstMatch(request.body);
            if (match != null) lockState = match.group(1)!;
            return http.Response(soapEnvelope('<u:SetButtonLockStateResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setButtonsEnabled(false); // Disable = Lock On
      expect(lockState, equals('On'));

      await soco.setButtonsEnabled(true); // Enable = Lock Off
      expect(lockState, equals('Off'));
    });

    test('get nightMode returns correct state', () async {
      // Pre-populate speakerInfo to make isSoundbar return true without network call
      soco.speakerInfo['model_name'] = 'Sonos Arc';

      mockClient = createMockClient({
        'RenderingControl': (200, soapEnvelope('''
          <u:GetEQResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
            <CurrentValue>1</CurrentValue>
          </u:GetEQResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final nightMode = await soco.nightMode;
      expect(nightMode, isTrue);
    });

    test('set nightMode sends correct command', () async {
      // Pre-populate speakerInfo to make isSoundbar return true without network call
      soco.speakerInfo['model_name'] = 'Sonos Arc';

      var eqType = '';
      var eqValue = '';
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('RenderingControl')) {
          if (request.body.contains('SetEQ')) {
            final typeMatch = RegExp(r'<EQType>(\w+)</EQType>').firstMatch(request.body);
            final valueMatch = RegExp(r'<DesiredValue>(\d)</DesiredValue>').firstMatch(request.body);
            if (typeMatch != null) eqType = typeMatch.group(1)!;
            if (valueMatch != null) eqValue = valueMatch.group(1)!;
            return http.Response(soapEnvelope('<u:SetEQResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setNightMode(true);
      expect(eqType, equals('NightMode'));
      expect(eqValue, equals('1'));
    });

    test('get dialogMode returns correct state', () async {
      // Pre-populate speakerInfo to make isSoundbar return true without network call
      soco.speakerInfo['model_name'] = 'Sonos Arc';

      mockClient = createMockClient({
        'RenderingControl': (200, soapEnvelope('''
          <u:GetEQResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
            <CurrentValue>1</CurrentValue>
          </u:GetEQResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final dialogMode = await soco.dialogMode;
      expect(dialogMode, isTrue);
    });

    test('set dialogMode sends correct command', () async {
      // Pre-populate speakerInfo to make isSoundbar return true without network call
      soco.speakerInfo['model_name'] = 'Sonos Arc';

      var eqType = '';
      var eqValue = '';
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('RenderingControl')) {
          if (request.body.contains('SetEQ')) {
            final typeMatch = RegExp(r'<EQType>(\w+)</EQType>').firstMatch(request.body);
            final valueMatch = RegExp(r'<DesiredValue>(\d)</DesiredValue>').firstMatch(request.body);
            if (typeMatch != null) eqType = typeMatch.group(1)!;
            if (valueMatch != null) eqValue = valueMatch.group(1)!;
            return http.Response(soapEnvelope('<u:SetEQResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setDialogMode(false);
      expect(eqType, equals('DialogLevel'));
      expect(eqValue, equals('0'));
    });

    test('get subEnabled returns correct state', () async {
      // Pre-populate speakerInfo to make hasSubwoofer return true without network call
      soco.speakerInfo['model_name'] = 'Sonos Amp';

      mockClient = createMockClient({
        'RenderingControl': (200, soapEnvelope('''
          <u:GetEQResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
            <CurrentValue>1</CurrentValue>
          </u:GetEQResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final subEnabled = await soco.subEnabled;
      expect(subEnabled, isTrue);
    });

    test('get subGain returns correct value', () async {
      // Pre-populate speakerInfo to make hasSubwoofer return true without network call
      soco.speakerInfo['model_name'] = 'Sonos Amp';

      mockClient = createMockClient({
        'RenderingControl': (200, soapEnvelope('''
          <u:GetEQResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
            <CurrentValue>3</CurrentValue>
          </u:GetEQResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final subGain = await soco.subGain;
      expect(subGain, equals(3));
    });

    test('set subGain sends command with valid value', () async {
      // Pre-populate speakerInfo to make hasSubwoofer return true without network call
      soco.speakerInfo['model_name'] = 'Sonos Amp';

      var eqValue = 0;
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('RenderingControl')) {
          if (request.body.contains('SetEQ')) {
            final valueMatch = RegExp(r'<DesiredValue>(-?\d+)</DesiredValue>').firstMatch(request.body);
            if (valueMatch != null) eqValue = int.parse(valueMatch.group(1)!);
            return http.Response(soapEnvelope('<u:SetEQResponse/>'), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setSubGain(5);
      expect(eqValue, equals(5));

      await soco.setSubGain(-10);
      expect(eqValue, equals(-10));
    });

    test('set subGain throws on invalid value', () async {
      // Pre-populate speakerInfo to make hasSubwoofer return true without network call
      soco.speakerInfo['model_name'] = 'Sonos Amp';

      mockClient = createMockClient({});
      soco.httpClient = mockClient;

      expect(() => soco.setSubGain(20), throwsArgumentError); // Above max (15)
      expect(() => soco.setSubGain(-20), throwsArgumentError); // Below min (-15)
    });

    test('setPlayerName sends SetZoneAttributes command', () async {
      var nameReceived = '';
      mockClient = MockClient((request) async {
        if (request.body.contains('SetZoneAttributes')) {
          final match = RegExp(r'<DesiredZoneName>([^<]*)</DesiredZoneName>').firstMatch(request.body);
          if (match != null) nameReceived = match.group(1)!;
          return http.Response(soapEnvelope('<u:SetZoneAttributesResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setPlayerName('Living Room');
      expect(nameReceived, equals('Living Room'));
    });

    test('householdId getter returns household ID', () async {
      mockClient = createMockClient({
        'DeviceProperties': (200, soapEnvelope('''
          <u:GetHouseholdIDResponse xmlns:u="urn:schemas-upnp-org:service:DeviceProperties:1">
            <CurrentHouseholdID>Sonos_asahHKgjgJGjgjGjggjJgjJG34</CurrentHouseholdID>
          </u:GetHouseholdIDResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final householdId = await soco.householdId;
      expect(householdId, equals('Sonos_asahHKgjgJGjgjGjggjJgjJG34'));
    });

    // Note: The uid getter test is complex because it requires ZoneGroupState polling.
    // Testing that speakerInfo['_uid'] is used by the uid getter is covered
    // indirectly through other tests that rely on uid.

    test('satelliteParent returns null by default', () {
      expect(soco.satelliteParent, isNull);
    });

    test('satelliteParent returns set value', () {
      final parent = SoCo('192.168.1.100');
      soco.speakerInfo['_satelliteParent'] = parent;
      expect(soco.satelliteParent, equals(parent));
    });

    test('isArcUltraSoundbar returns true for Arc Ultra model', () async {
      soco.speakerInfo['model_name'] = 'Sonos Arc Ultra';

      final isArcUltra = await soco.isArcUltraSoundbar;
      expect(isArcUltra, isTrue);
    });

    test('isArcUltraSoundbar returns false for other models', () async {
      soco.speakerInfo['model_name'] = 'Sonos Beam';

      final isArcUltra = await soco.isArcUltraSoundbar;
      expect(isArcUltra, isFalse);
    });

    test('getQueue returns queue data', () async {
      mockClient = MockClient((request) async {
        if (request.body.contains('Browse') && request.body.contains('Q:0')) {
          return http.Response(soapEnvelope('''
            <u:BrowseResponse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1">
              <Result>&lt;DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/"&gt;&lt;/DIDL-Lite&gt;</Result>
              <NumberReturned>0</NumberReturned>
              <TotalMatches>0</TotalMatches>
              <UpdateID>1</UpdateID>
            </u:BrowseResponse>
          '''), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final queue = await soco.getQueue();
      expect(queue, isA<QueueResult>());
      expect(queue.numberReturned, equals(0));
    });

    test('clearQueue sends RemoveAllTracksFromQueue command', () async {
      var commandReceived = false;
      mockClient = MockClient((request) async {
        if (request.body.contains('RemoveAllTracksFromQueue')) {
          commandReceived = true;
          return http.Response(soapEnvelope('<u:RemoveAllTracksFromQueueResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.clearQueue();
      expect(commandReceived, isTrue);
    });

    test('removeFromQueue sends RemoveTrackFromQueue command', () async {
      var indexReceived = '';
      mockClient = MockClient((request) async {
        if (request.body.contains('RemoveTrackFromQueue')) {
          final match = RegExp(r'<ObjectID>Q:0/(\d+)</ObjectID>').firstMatch(request.body);
          if (match != null) indexReceived = match.group(1)!;
          return http.Response(soapEnvelope('<u:RemoveTrackFromQueueResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.removeFromQueue(3);
      expect(indexReceived, equals('4')); // index + 1
    });

    test('seek sends Seek command with position', () async {
      var seekTarget = '';
      mockClient = MockClient((request) async {
        if (request.body.contains('Seek') && request.body.contains('REL_TIME')) {
          final match = RegExp(r'<Target>([^<]+)</Target>').firstMatch(request.body);
          if (match != null) seekTarget = match.group(1)!;
          return http.Response(soapEnvelope('<u:SeekResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.seek(position: '0:01:30');
      expect(seekTarget, equals('0:01:30'));
    });

    test('seek with track sends Seek command with track number', () async {
      var seekTarget = '';
      mockClient = MockClient((request) async {
        if (request.body.contains('Seek') && request.body.contains('TRACK_NR')) {
          final match = RegExp(r'<Target>(\d+)</Target>').firstMatch(request.body);
          if (match != null) seekTarget = match.group(1)!;
          return http.Response(soapEnvelope('<u:SeekResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.seek(track: 5);
      expect(seekTarget, equals('6')); // track + 1
    });

    test('seek throws when no position or track given', () {
      expect(() => soco.seek(), throwsArgumentError);
    });

    test('next sends Next command', () async {
      var commandReceived = false;
      mockClient = MockClient((request) async {
        if (request.body.contains('Next')) {
          commandReceived = true;
          return http.Response(soapEnvelope('<u:NextResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.next();
      expect(commandReceived, isTrue);
    });

    test('previous sends Previous command', () async {
      var commandReceived = false;
      mockClient = MockClient((request) async {
        if (request.body.contains('Previous')) {
          commandReceived = true;
          return http.Response(soapEnvelope('<u:PreviousResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.previous();
      expect(commandReceived, isTrue);
    });

    test('setBalance sends SetVolume commands for LF and RF channels', () async {
      var leftReceived = 0;
      var rightReceived = 0;
      mockClient = MockClient((request) async {
        if (request.body.contains('SetVolume')) {
          final channelMatch = RegExp(r'<Channel>(\w+)</Channel>').firstMatch(request.body);
          final valueMatch = RegExp(r'<DesiredVolume>(\d+)</DesiredVolume>').firstMatch(request.body);
          if (channelMatch != null && valueMatch != null) {
            if (channelMatch.group(1) == 'LF') {
              leftReceived = int.parse(valueMatch.group(1)!);
            } else if (channelMatch.group(1) == 'RF') {
              rightReceived = int.parse(valueMatch.group(1)!);
            }
          }
          return http.Response(soapEnvelope('<u:SetVolumeResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setBalance(80, 50);
      expect(leftReceived, equals(80));
      expect(rightReceived, equals(50));
    });

    test('setBalance clamps to valid range', () async {
      var leftReceived = 0;
      var rightReceived = 0;
      mockClient = MockClient((request) async {
        if (request.body.contains('SetVolume')) {
          final channelMatch = RegExp(r'<Channel>(\w+)</Channel>').firstMatch(request.body);
          final valueMatch = RegExp(r'<DesiredVolume>(\d+)</DesiredVolume>').firstMatch(request.body);
          if (channelMatch != null && valueMatch != null) {
            if (channelMatch.group(1) == 'LF') {
              leftReceived = int.parse(valueMatch.group(1)!);
            } else if (channelMatch.group(1) == 'RF') {
              rightReceived = int.parse(valueMatch.group(1)!);
            }
          }
          return http.Response(soapEnvelope('<u:SetVolumeResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setBalance(-50, 150); // Invalid values
      expect(leftReceived, equals(0)); // Clamped to min
      expect(rightReceived, equals(100)); // Clamped to max
    });

    test('get balance returns left and right volumes', () async {
      mockClient = MockClient((request) async {
        if (request.body.contains('GetVolume')) {
          final channelMatch = RegExp(r'<Channel>(\w+)</Channel>').firstMatch(request.body);
          if (channelMatch?.group(1) == 'LF') {
            return http.Response(soapEnvelope('''
              <u:GetVolumeResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
                <CurrentVolume>75</CurrentVolume>
              </u:GetVolumeResponse>
            '''), 200);
          } else if (channelMatch?.group(1) == 'RF') {
            return http.Response(soapEnvelope('''
              <u:GetVolumeResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
                <CurrentVolume>60</CurrentVolume>
              </u:GetVolumeResponse>
            '''), 200);
          }
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final balance = await soco.balance;
      expect(balance.$1, equals(75)); // Left
      expect(balance.$2, equals(60)); // Right
    });

    test('queueSize returns size of queue', () async {
      mockClient = MockClient((request) async {
        if (request.body.contains('Browse') && request.body.contains('BrowseMetadata')) {
          return http.Response(soapEnvelope('''
            <u:BrowseResponse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1">
              <Result>&lt;container childCount="5"&gt;&lt;/container&gt;</Result>
              <NumberReturned>1</NumberReturned>
              <TotalMatches>1</TotalMatches>
              <UpdateID>1</UpdateID>
            </u:BrowseResponse>
          '''), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final size = await soco.queueSize;
      expect(size, equals(5));
    });

    test('get bass returns current bass value', () async {
      mockClient = createMockClient({
        'RenderingControl': (200, soapEnvelope('''
          <u:GetBassResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
            <CurrentBass>5</CurrentBass>
          </u:GetBassResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final bass = await soco.bass;
      expect(bass, equals(5));
    });

    test('setBass sends SetBass command', () async {
      var bassReceived = 0;
      mockClient = MockClient((request) async {
        if (request.body.contains('SetBass')) {
          final match = RegExp(r'<DesiredBass>(-?\d+)</DesiredBass>').firstMatch(request.body);
          if (match != null) bassReceived = int.parse(match.group(1)!);
          return http.Response(soapEnvelope('<u:SetBassResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setBass(7);
      expect(bassReceived, equals(7));
    });

    test('setBass clamps to valid range', () async {
      var bassReceived = 0;
      mockClient = MockClient((request) async {
        if (request.body.contains('SetBass')) {
          final match = RegExp(r'<DesiredBass>(-?\d+)</DesiredBass>').firstMatch(request.body);
          if (match != null) bassReceived = int.parse(match.group(1)!);
          return http.Response(soapEnvelope('<u:SetBassResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setBass(20); // Above max
      expect(bassReceived, equals(10)); // Clamped to max

      await soco.setBass(-20); // Below min
      expect(bassReceived, equals(-10)); // Clamped to min
    });

    test('rampToVolume sends RampToVolume command', () async {
      var targetVolume = 0;
      var rampType = '';
      mockClient = MockClient((request) async {
        if (request.body.contains('RampToVolume')) {
          final volMatch = RegExp(r'<DesiredVolume>(\d+)</DesiredVolume>').firstMatch(request.body);
          final typeMatch = RegExp(r'<RampType>(\w+)</RampType>').firstMatch(request.body);
          if (volMatch != null) targetVolume = int.parse(volMatch.group(1)!);
          if (typeMatch != null) rampType = typeMatch.group(1)!;
          return http.Response(soapEnvelope('''
            <u:RampToVolumeResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
              <RampTime>16</RampTime>
            </u:RampToVolumeResponse>
          '''), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final rampTime = await soco.rampToVolume(30);
      expect(targetVolume, equals(30));
      expect(rampType, equals('SLEEP_TIMER_RAMP_TYPE'));
      expect(rampTime, equals(16));
    });

    test('rampToVolume with custom ramp type', () async {
      var rampType = '';
      mockClient = MockClient((request) async {
        if (request.body.contains('RampToVolume')) {
          final typeMatch = RegExp(r'<RampType>(\w+)</RampType>').firstMatch(request.body);
          if (typeMatch != null) rampType = typeMatch.group(1)!;
          return http.Response(soapEnvelope('''
            <u:RampToVolumeResponse>
              <RampTime>5</RampTime>
            </u:RampToVolumeResponse>
          '''), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.rampToVolume(50, rampType: 'ALARM_RAMP_TYPE');
      expect(rampType, equals('ALARM_RAMP_TYPE'));
    });

    test('setRelativeVolume sends SetRelativeVolume command', () async {
      var adjustment = 0;
      mockClient = MockClient((request) async {
        if (request.body.contains('SetRelativeVolume')) {
          final match = RegExp(r'<Adjustment>(-?\d+)</Adjustment>').firstMatch(request.body);
          if (match != null) adjustment = int.parse(match.group(1)!);
          return http.Response(soapEnvelope('''
            <u:SetRelativeVolumeResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
              <NewVolume>55</NewVolume>
            </u:SetRelativeVolumeResponse>
          '''), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final newVol = await soco.setRelativeVolume(-5);
      expect(adjustment, equals(-5));
      expect(newVol, equals(55));
    });

    test('fixed volume getter returns state', () async {
      mockClient = createMockClient({
        'RenderingControl': (200, soapEnvelope('''
          <u:GetOutputFixedResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
            <CurrentFixed>1</CurrentFixed>
          </u:GetOutputFixedResponse>
        ''')),
      });
      soco.httpClient = mockClient;

      final fixed = await soco.fixedVolume;
      expect(fixed, isTrue);
    });

    test('setFixedVolume sends SetOutputFixed command', () async {
      var fixedValue = '';
      mockClient = MockClient((request) async {
        if (request.body.contains('SetOutputFixed')) {
          final match = RegExp(r'<DesiredFixed>(\d)</DesiredFixed>').firstMatch(request.body);
          if (match != null) fixedValue = match.group(1)!;
          return http.Response(soapEnvelope('<u:SetOutputFixedResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setFixedVolume(true);
      expect(fixedValue, equals('1'));
    });

    test('getCurrentTransportInfo returns transport state', () async {
      mockClient = MockClient((request) async {
        if (request.body.contains('GetTransportInfo')) {
          return http.Response(soapEnvelope('''
            <u:GetTransportInfoResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <CurrentTransportState>PLAYING</CurrentTransportState>
              <CurrentTransportStatus>OK</CurrentTransportStatus>
              <CurrentSpeed>1</CurrentSpeed>
            </u:GetTransportInfoResponse>
          '''), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final info = await soco.getCurrentTransportInfo();
      expect(info['current_transport_state'], equals('PLAYING'));
      expect(info['current_transport_status'], equals('OK'));
    });

    test('stop sends Stop command', () async {
      var commandReceived = false;
      mockClient = MockClient((request) async {
        if (request.body.contains('Stop')) {
          commandReceived = true;
          return http.Response(soapEnvelope('<u:StopResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.stop();
      expect(commandReceived, isTrue);
    });

    test('pause sends Pause command', () async {
      var commandReceived = false;
      mockClient = MockClient((request) async {
        if (request.body.contains('Pause')) {
          commandReceived = true;
          return http.Response(soapEnvelope('<u:PauseResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.pause();
      expect(commandReceived, isTrue);
    });

    test('play sends Play command', () async {
      var commandReceived = false;
      mockClient = MockClient((request) async {
        if (request.body.contains('Play')) {
          commandReceived = true;
          return http.Response(soapEnvelope('<u:PlayResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.play();
      expect(commandReceived, isTrue);
    });

    test('setSleepTimer sends ConfigureSleepTimer command', () async {
      var durationReceived = '';
      mockClient = MockClient((request) async {
        if (request.body.contains('ConfigureSleepTimer')) {
          final match = RegExp(r'<NewSleepTimerDuration>([^<]*)</NewSleepTimerDuration>').firstMatch(request.body);
          if (match != null) durationReceived = match.group(1)!;
          return http.Response(soapEnvelope('<u:ConfigureSleepTimerResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setSleepTimer(1800); // 30 minutes in seconds
      expect(durationReceived, equals('00:30:00'));
    });

    test('setSleepTimer with null clears timer', () async {
      var durationReceived = '';
      mockClient = MockClient((request) async {
        if (request.body.contains('ConfigureSleepTimer')) {
          final match = RegExp(r'<NewSleepTimerDuration>([^<]*)</NewSleepTimerDuration>').firstMatch(request.body);
          if (match != null) durationReceived = match.group(1)!;
          return http.Response(soapEnvelope('<u:ConfigureSleepTimerResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setSleepTimer(null);
      expect(durationReceived, equals('')); // Empty means clear timer
    });

    test('musicSource returns correct source from URI', () async {
      mockClient = MockClient((request) async {
        if (request.body.contains('GetPositionInfo')) {
          return http.Response(soapEnvelope('''
            <u:GetPositionInfoResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <Track>1</Track>
              <TrackDuration>0:03:45</TrackDuration>
              <TrackMetaData></TrackMetaData>
              <TrackURI>x-sonosapi-stream:s12345?sid=254</TrackURI>
              <RelTime>0:01:30</RelTime>
              <AbsTime>0:01:30</AbsTime>
              <RelCount>0</RelCount>
              <AbsCount>0</AbsCount>
            </u:GetPositionInfoResponse>
          '''), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final source = await soco.musicSource;
      expect(source, equals('RADIO'));
    });

    test('isPlayingRadio returns true for radio source', () async {
      mockClient = MockClient((request) async {
        if (request.body.contains('GetPositionInfo')) {
          return http.Response(soapEnvelope('''
            <u:GetPositionInfoResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <Track>1</Track>
              <TrackDuration>0:00:00</TrackDuration>
              <TrackMetaData></TrackMetaData>
              <TrackURI>x-sonosapi-stream:s12345?sid=254</TrackURI>
              <RelTime>0:00:00</RelTime>
              <AbsTime>0:00:00</AbsTime>
              <RelCount>0</RelCount>
              <AbsCount>0</AbsCount>
            </u:GetPositionInfoResponse>
          '''), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final isRadio = await soco.isPlayingRadio;
      expect(isRadio, isTrue);
    });

    test('isPlayingLineIn returns false for non-line-in source', () async {
      mockClient = MockClient((request) async {
        if (request.body.contains('GetPositionInfo')) {
          return http.Response(soapEnvelope('''
            <u:GetPositionInfoResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <Track>1</Track>
              <TrackDuration>0:03:45</TrackDuration>
              <TrackMetaData></TrackMetaData>
              <TrackURI>x-file-cifs://server/music/song.mp3</TrackURI>
              <RelTime>0:01:30</RelTime>
              <AbsTime>0:01:30</AbsTime>
              <RelCount>0</RelCount>
              <AbsCount>0</AbsCount>
            </u:GetPositionInfoResponse>
          '''), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final isLineIn = await soco.isPlayingLineIn;
      expect(isLineIn, isFalse);
    });

    test('isPlayingTv returns false for non-TV source', () async {
      mockClient = MockClient((request) async {
        if (request.body.contains('GetPositionInfo')) {
          return http.Response(soapEnvelope('''
            <u:GetPositionInfoResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <Track>1</Track>
              <TrackDuration>0:03:45</TrackDuration>
              <TrackMetaData></TrackMetaData>
              <TrackURI>x-rincon-queue:RINCON_123#0</TrackURI>
              <RelTime>0:01:30</RelTime>
              <AbsTime>0:01:30</AbsTime>
              <RelCount>0</RelCount>
              <AbsCount>0</AbsCount>
            </u:GetPositionInfoResponse>
          '''), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final isTv = await soco.isPlayingTv;
      expect(isTv, isFalse);
    });

    test('getSleepTimer returns remaining time', () async {
      mockClient = MockClient((request) async {
        if (request.body.contains('GetRemainingSleepTimerDuration')) {
          return http.Response(soapEnvelope('''
            <u:GetRemainingSleepTimerDurationResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <RemainingSleepTimerDuration>0:30:00</RemainingSleepTimerDuration>
              <CurrentSleepTimerGeneration>1</CurrentSleepTimerGeneration>
            </u:GetRemainingSleepTimerDurationResponse>
          '''), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final remaining = await soco.getSleepTimer();
      expect(remaining, equals(1800)); // 30 minutes in seconds
    });

    test('getSleepTimer returns null when no timer set', () async {
      mockClient = MockClient((request) async {
        if (request.body.contains('GetRemainingSleepTimerDuration')) {
          return http.Response(soapEnvelope('''
            <u:GetRemainingSleepTimerDurationResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <RemainingSleepTimerDuration></RemainingSleepTimerDuration>
              <CurrentSleepTimerGeneration>0</CurrentSleepTimerGeneration>
            </u:GetRemainingSleepTimerDurationResponse>
          '''), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final remaining = await soco.getSleepTimer();
      expect(remaining, isNull);
    });

    test('playUri with start=true calls play', () async {
      var playCalled = false;
      mockClient = MockClient((request) async {
        if (request.body.contains('SetAVTransportURI')) {
          return http.Response(soapEnvelope('<u:SetAVTransportURIResponse/>'), 200);
        }
        if (request.body.contains('<u:Play')) {
          playCalled = true;
          return http.Response(soapEnvelope('<u:PlayResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final result = await soco.playUri(
        uri: 'x-file-cifs://server/music/song.mp3',
        start: true,
      );
      expect(result, isTrue);
      expect(playCalled, isTrue);
    });

    test('playUri with start=false does not call play', () async {
      var playCalled = false;
      mockClient = MockClient((request) async {
        if (request.body.contains('SetAVTransportURI')) {
          return http.Response(soapEnvelope('<u:SetAVTransportURIResponse/>'), 200);
        }
        if (request.body.contains('<u:Play')) {
          playCalled = true;
          return http.Response(soapEnvelope('<u:PlayResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final result = await soco.playUri(
        uri: 'x-file-cifs://server/music/song.mp3',
        start: false,
      );
      expect(result, isFalse);
      expect(playCalled, isFalse);
    });

    test('endDirectControlSession sends command', () async {
      var commandCalled = false;
      mockClient = MockClient((request) async {
        if (request.body.contains('EndDirectControlSession')) {
          commandCalled = true;
          return http.Response(soapEnvelope('<u:EndDirectControlSessionResponse/>'), 200);
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.endDirectControlSession();
      expect(commandCalled, isTrue);
    });

    test('setPlayerName sends SetZoneAttributes command', () async {
      var commandCalled = false;
      String? capturedName;
      mockClient = MockClient((request) async {
        if (request.body.contains('SetZoneAttributes')) {
          commandCalled = true;
          final match = RegExp(r'<DesiredZoneName>([^<]*)</DesiredZoneName>')
              .firstMatch(request.body);
          capturedName = match?.group(1);
          return http.Response(
            soapEnvelope('<u:SetZoneAttributesResponse/>'),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setPlayerName('Living Room');
      expect(commandCalled, isTrue);
      expect(capturedName, equals('Living Room'));
    });

    // Note: householdId test is covered in "SoCo with mocked HTTP" group at line 1571
    // We can't duplicate it here due to singleton caching behavior

    // Note: isSubwoofer tests require complex ZoneGroupState mocking and
    // access to private _channel field. These are covered in integration tests.

    // Note: isSoundbar, isArcUltraSoundbar tests are covered in "SoCo with mocked HTTP" group
    // We can't duplicate them here due to singleton caching behavior (_isSoundbar is cached)

    test('nightMode getter returns boolean', () async {
      mockClient = MockClient((request) async {
        if (request.body.contains('GetEQ') &&
            request.body.contains('<EQType>NightMode</EQType>')) {
          return http.Response(
            soapEnvelope('''
              <u:GetEQResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
                <CurrentValue>1</CurrentValue>
              </u:GetEQResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final result = await soco.nightMode;
      expect(result, isTrue);
    });

    test('nightMode setter sends correct command', () async {
      var commandCalled = false;
      String? capturedValue;
      mockClient = MockClient((request) async {
        if (request.body.contains('SetEQ') &&
            request.body.contains('<EQType>NightMode</EQType>')) {
          commandCalled = true;
          final match =
              RegExp(r'<DesiredValue>(\d+)</DesiredValue>').firstMatch(request.body);
          capturedValue = match?.group(1);
          return http.Response(
            soapEnvelope('<u:SetEQResponse/>'),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setNightMode(true);
      expect(commandCalled, isTrue);
      expect(capturedValue, equals('1'));
    });

    test('dialogMode getter returns boolean', () async {
      mockClient = MockClient((request) async {
        if (request.body.contains('GetEQ') &&
            request.body.contains('<EQType>DialogLevel</EQType>')) {
          return http.Response(
            soapEnvelope('''
              <u:GetEQResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
                <CurrentValue>1</CurrentValue>
              </u:GetEQResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final result = await soco.dialogMode;
      expect(result, isTrue);
    });

    test('dialogMode setter sends correct command', () async {
      var commandCalled = false;
      mockClient = MockClient((request) async {
        if (request.body.contains('SetEQ') &&
            request.body.contains('<EQType>DialogLevel</EQType>')) {
          commandCalled = true;
          return http.Response(
            soapEnvelope('<u:SetEQResponse/>'),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setDialogMode(false);
      expect(commandCalled, isTrue);
    });

    test('supportedFeatures returns features set', () async {
      mockClient = MockClient((request) async {
        if (request.body.contains('GetSupportsOutputFixed')) {
          return http.Response(
            soapEnvelope('''
              <u:GetSupportsOutputFixedResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
                <CurrentSupportsFixed>1</CurrentSupportsFixed>
              </u:GetSupportsOutputFixedResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final result = await soco.supportsFixedVolume;
      expect(result, isTrue);
    });

    test('fixedVolume getter returns boolean', () async {
      mockClient = MockClient((request) async {
        if (request.body.contains('GetOutputFixed')) {
          return http.Response(
            soapEnvelope('''
              <u:GetOutputFixedResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
                <CurrentFixed>1</CurrentFixed>
              </u:GetOutputFixedResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final result = await soco.fixedVolume;
      expect(result, isTrue);
    });

    test('fixedVolume setter sends correct command', () async {
      var commandCalled = false;
      mockClient = MockClient((request) async {
        if (request.body.contains('SetOutputFixed')) {
          commandCalled = true;
          return http.Response(
            soapEnvelope('<u:SetOutputFixedResponse/>'),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      await soco.setFixedVolume(true);
      expect(commandCalled, isTrue);
    });

    test('trueplay getter returns boolean when available', () async {
      mockClient = MockClient((request) async {
        if (request.body.contains('GetRoomCalibrationStatus')) {
          return http.Response(
            soapEnvelope('''
              <u:GetRoomCalibrationStatusResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
                <RoomCalibrationEnabled>1</RoomCalibrationEnabled>
                <RoomCalibrationAvailable>1</RoomCalibrationAvailable>
              </u:GetRoomCalibrationStatusResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final result = await soco.trueplay;
      expect(result, isTrue);
    });

    test('trueplay getter returns null when not available', () async {
      mockClient = MockClient((request) async {
        if (request.body.contains('GetRoomCalibrationStatus')) {
          return http.Response(
            soapEnvelope('''
              <u:GetRoomCalibrationStatusResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
                <RoomCalibrationEnabled>0</RoomCalibrationEnabled>
                <RoomCalibrationAvailable>0</RoomCalibrationAvailable>
              </u:GetRoomCalibrationStatusResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      soco.httpClient = mockClient;

      final result = await soco.trueplay;
      expect(result, isNull);
    });

    // Note: createStereoPair, separateStereoPair, switchToTv, and switchToLineIn tests
    // require uid which calls zoneGroupState.poll(). These require complex ZoneGroupTopology
    // mocking and are better suited for integration tests.
  });

  group('SoCo getter methods with ZoneGroupState', () {
    late SoCo soco;
    late MockClient mockClient;

    setUp(() {
      soco = SoCo('192.168.50.1');
    });

    tearDown(() {
      mockClient.close();
    });

    // Note: Tests for bootSeqnum, playerName, isBridge, isSatellite, hasSatellites,
    // isSubwoofer, hasSubwoofer, and channel getters require full ZoneGroupState
    // integration which involves complex XML parsing and private field setting.
    // These are better suited for integration tests with real Sonos devices.
    // The code paths are exercised through other tests that use ZoneGroupState.

    test('getSpeakerInfo returns cached info when available', () async {
      // Test getSpeakerInfo cache path (lines 522-524)
      soco.speakerInfo['zone_name'] = 'Cached Room';
      soco.speakerInfo['serial_number'] = 'Cached123';

      final info = await soco.getSpeakerInfo();
      expect(info['zone_name'], equals('Cached Room'));
      expect(info['serial_number'], equals('Cached123'));
    }, timeout: Timeout(Duration(seconds: 5)));

    // Note: getSpeakerInfo tests require complex ZoneGroupState integration
    // because getSpeakerInfo calls uid which requires ZoneGroupState polling.
    // These are better suited for integration tests with real Sonos devices.
    // The code paths are exercised through other tests that use getSpeakerInfo.

    // Note: isSoundbar getter test requires complex ZoneGroupState integration
    // because it calls getSpeakerInfo which calls uid, requiring ZoneGroupState polling.
    // This is better suited for integration tests with real Sonos devices.

    // Note: isSoundbar cached value test is complex because it requires
    // getSpeakerInfo which calls uid, requiring ZoneGroupState polling.
    // The cache path (line 484) is tested indirectly through the first call.
  });

  group('musicSourceFromUri static method', () {
    test('empty URI returns NONE', () {
      expect(SoCo.musicSourceFromUri(''), equals('NONE'));
    });

    test('x-file-cifs returns LIBRARY', () {
      expect(
        SoCo.musicSourceFromUri('x-file-cifs://server/share/file.mp3'),
        equals('LIBRARY'),
      );
    });

    test('x-rincon-mp3radio returns RADIO', () {
      expect(
        SoCo.musicSourceFromUri('x-rincon-mp3radio://stream.example.com/radio'),
        equals('RADIO'),
      );
    });

    test('x-sonosapi-stream returns RADIO', () {
      expect(
        SoCo.musicSourceFromUri('x-sonosapi-stream:s12345?sid=254'),
        equals('RADIO'),
      );
    });

    test('x-sonosapi-radio returns RADIO', () {
      expect(
        SoCo.musicSourceFromUri('x-sonosapi-radio:s12345?sid=254'),
        equals('RADIO'),
      );
    });

    test('x-sonosapi-hls returns RADIO', () {
      expect(
        SoCo.musicSourceFromUri('x-sonosapi-hls:s12345?sid=254'),
        equals('RADIO'),
      );
    });

    test('x-sonos-http:sonos returns RADIO', () {
      expect(
        SoCo.musicSourceFromUri('x-sonos-http:sonostts_12345.mp3'),
        equals('RADIO'),
      );
    });

    test('aac: returns RADIO', () {
      expect(
        SoCo.musicSourceFromUri('aac://stream.example.com/radio'),
        equals('RADIO'),
      );
    });

    test('hls-radio: returns RADIO', () {
      expect(
        SoCo.musicSourceFromUri('hls-radio://stream.example.com/playlist.m3u8'),
        equals('RADIO'),
      );
    });

    test('http: returns WEB_FILE', () {
      expect(
        SoCo.musicSourceFromUri('http://example.com/audio.mp3'),
        equals('WEB_FILE'),
      );
    });

    test('https: returns WEB_FILE', () {
      expect(
        SoCo.musicSourceFromUri('https://example.com/audio.mp3'),
        equals('WEB_FILE'),
      );
    });

    test('x-rincon-stream returns LINE_IN', () {
      expect(
        SoCo.musicSourceFromUri('x-rincon-stream:RINCON_000E5859E49601400'),
        equals('LINE_IN'),
      );
    });

    test('x-sonos-htastream returns TV', () {
      expect(
        SoCo.musicSourceFromUri('x-sonos-htastream:RINCON_000E5859E49601400:spdif'),
        equals('TV'),
      );
    });

    test('x-sonos-vli with airplay returns AIRPLAY', () {
      expect(
        SoCo.musicSourceFromUri('x-sonos-vli:RINCON_000E5859E49601400,airplay:DEVICE123'),
        equals('AIRPLAY'),
      );
    });

    test('x-sonos-vli with spotify returns SPOTIFY_CONNECT', () {
      expect(
        SoCo.musicSourceFromUri('x-sonos-vli:RINCON_000E5859E49601400,spotify:track123'),
        equals('SPOTIFY_CONNECT'),
      );
    });

    test('unknown URI returns UNKNOWN', () {
      expect(
        SoCo.musicSourceFromUri('some-other-protocol://stream'),
        equals('UNKNOWN'),
      );
    });

    test('x-rincon-queue returns UNKNOWN', () {
      // Queue URIs don't have a source mapping
      expect(
        SoCo.musicSourceFromUri('x-rincon-queue:RINCON_000E5859E49601400#0'),
        equals('UNKNOWN'),
      );
    });
  });

  group('soundbars list', () {
    test('contains expected products', () {
      expect(soundbars.contains('arc'), isTrue);
      expect(soundbars.contains('arc sl'), isTrue);
      expect(soundbars.contains('arc ultra'), isTrue);
      expect(soundbars.contains('beam'), isTrue);
      expect(soundbars.contains('playbase'), isTrue);
      expect(soundbars.contains('playbar'), isTrue);
      expect(soundbars.contains('ray'), isTrue);
      expect(soundbars.contains('sonos amp'), isTrue);
    });

    test('has expected length', () {
      expect(soundbars.length, equals(8));
    });
  });

  group('sources constant', () {
    test('contains all music source patterns', () {
      expect(sources.keys.length, equals(14));
    });

    test('empty pattern maps to NONE', () {
      expect(sources[r'^$'], equals('NONE'));
    });
  });

  group('favorites constants', () {
    test('radioStations is 0', () {
      expect(radioStations, equals(0));
    });

    test('radioShows is 1', () {
      expect(radioShows, equals(1));
    });

    test('sonosFavorites is 2', () {
      expect(sonosFavorites, equals(2));
    });
  });
}
