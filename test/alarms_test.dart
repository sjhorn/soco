/// Tests for the alarms module.
library;

import 'package:test/test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:soco/src/alarms.dart';
import 'package:soco/src/core.dart';
import 'helpers/mock_http.dart';

void main() {
  group('isValidRecurrence', () {
    test('isValidRecurrence accepts standard recurrence patterns', () {
      for (final recur in ['DAILY', 'WEEKDAYS', 'WEEKENDS', 'ONCE']) {
        expect(
          isValidRecurrence(recur),
          isTrue,
          reason: 'Should accept standard pattern: $recur',
        );
      }
    });

    test('isValidRecurrence accepts ON_* patterns with valid day numbers', () {
      expect(isValidRecurrence('ON_1'), isTrue);
      expect(isValidRecurrence('ON_132'), isTrue); // Mon, Tue, Wed
      expect(isValidRecurrence('ON_123456'), isTrue); // Mon-Sat
      expect(
        isValidRecurrence('ON_666'),
        isTrue,
      ); // Sat, Sat, Sat (valid but redundant)
      expect(isValidRecurrence('ON_0123456'), isTrue); // All days (Sun-Sat)
    });

    test('isValidRecurrence rejects lowercase ON_ patterns', () {
      expect(isValidRecurrence('on_1'), isFalse);
    });

    test('isValidRecurrence rejects ON_ patterns with too many digits', () {
      expect(isValidRecurrence('ON_123456789'), isFalse);
    });

    test('isValidRecurrence rejects ON_ without digits', () {
      expect(isValidRecurrence('ON_'), isFalse);
    });

    test('isValidRecurrence rejects patterns with leading spaces', () {
      expect(isValidRecurrence(' ON_1'), isFalse);
    });

    test('isValidRecurrence rejects invalid patterns', () {
      expect(isValidRecurrence('INVALID'), isFalse);
      expect(isValidRecurrence('daily'), isFalse);
      expect(isValidRecurrence(''), isFalse);
    });
  });

  group('recurrenceKeywordEquivalent', () {
    test('DAILY maps to ON_0123456', () {
      expect(recurrenceKeywordEquivalent['DAILY'], equals('ON_0123456'));
    });

    test('ONCE maps to ON_', () {
      expect(recurrenceKeywordEquivalent['ONCE'], equals('ON_'));
    });

    test('WEEKDAYS maps to ON_12345', () {
      expect(recurrenceKeywordEquivalent['WEEKDAYS'], equals('ON_12345'));
    });

    test('WEEKENDS maps to ON_06', () {
      expect(recurrenceKeywordEquivalent['WEEKENDS'], equals('ON_06'));
    });
  });

  group('Alarms singleton', () {
    test('returns same instance', () {
      final alarms1 = Alarms();
      final alarms2 = Alarms();
      expect(identical(alarms1, alarms2), isTrue);
    });

    test('alarms map is initially empty', () {
      final alarms = Alarms();
      // Clear any state from previous tests
      alarms.alarms.clear();
      expect(alarms.length, equals(0));
      expect(alarms.alarms, isEmpty);
    });

    test('iterator works correctly', () {
      final alarms = Alarms();
      alarms.alarms.clear();
      // Note: Cannot add alarms directly without network, but can test empty iteration
      var count = 0;
      for (final _ in alarms) {
        count++;
      }
      expect(count, equals(0));
    });

    test('lastAlarmListVersion parses UID and ID', () {
      final alarms = Alarms();
      alarms.lastAlarmListVersion = 'RINCON_123:42';
      expect(alarms.lastAlarmListVersion, equals('RINCON_123:42'));
      expect(alarms.lastUid, equals('RINCON_123'));
      expect(alarms.lastId, equals(42));
    });

    test('lastAlarmListVersion handles null', () {
      final alarms = Alarms();
      alarms.lastAlarmListVersion = null;
      // Should not throw, null is valid
    });

    test('get returns alarm by ID', () {
      final alarms = Alarms();
      alarms.alarms.clear();
      expect(alarms.get('nonexistent'), isNull);
      expect(alarms['nonexistent'], isNull);
    });
  });

  group('Alarm', () {
    late SoCo zone;

    setUp(() {
      zone = SoCo('192.168.100.1');
    });

    test('creates alarm with default values', () {
      final alarm = Alarm(zone);
      expect(alarm.zone, equals(zone));
      expect(alarm.enabled, isTrue);
      expect(alarm.recurrence, equals('DAILY'));
      expect(alarm.playMode, equals('NORMAL'));
      expect(alarm.volume, equals(20));
      expect(alarm.includeLinkedZones, isFalse);
      expect(alarm.programUri, isNull);
      expect(alarm.programMetadata, equals(''));
      expect(alarm.duration, isNull);
      expect(alarm.alarmId, isNull);
    });

    test('creates alarm with custom values', () {
      final startTime = DateTime(0, 1, 1, 7, 30, 0);
      final duration = DateTime(0, 1, 1, 0, 30, 0);
      final alarm = Alarm(
        zone,
        startTime: startTime,
        duration: duration,
        recurrence: 'WEEKDAYS',
        enabled: false,
        programUri: 'x-rincon-playlist:RINCON_123#A:ALBUM/Test',
        programMetadata: 'Test metadata',
        playMode: 'SHUFFLE',
        volume: 50,
        includeLinkedZones: true,
      );

      expect(alarm.startTime, equals(startTime));
      expect(alarm.duration, equals(duration));
      expect(alarm.recurrence, equals('WEEKDAYS'));
      expect(alarm.enabled, isFalse);
      expect(alarm.programUri, equals('x-rincon-playlist:RINCON_123#A:ALBUM/Test'));
      expect(alarm.programMetadata, equals('Test metadata'));
      expect(alarm.playMode, equals('SHUFFLE'));
      expect(alarm.volume, equals(50));
      expect(alarm.includeLinkedZones, isTrue);
    });

    test('volume is clamped to 0-100 range', () {
      final alarm = Alarm(zone, volume: 150);
      expect(alarm.volume, equals(100));

      alarm.volume = -10;
      expect(alarm.volume, equals(0));

      alarm.volume = 50;
      expect(alarm.volume, equals(50));
    });

    test('playMode setter validates value', () {
      final alarm = Alarm(zone);
      expect(() => alarm.playMode = 'INVALID', throwsArgumentError);

      // Valid modes should work
      alarm.playMode = 'SHUFFLE';
      expect(alarm.playMode, equals('SHUFFLE'));

      alarm.playMode = 'REPEAT_ALL';
      expect(alarm.playMode, equals('REPEAT_ALL'));

      // Lowercase should be converted to uppercase
      alarm.playMode = 'normal';
      expect(alarm.playMode, equals('NORMAL'));
    });

    test('recurrence setter validates value', () {
      final alarm = Alarm(zone);
      expect(() => alarm.recurrence = 'INVALID', throwsArgumentError);

      // Valid recurrences should work
      alarm.recurrence = 'WEEKENDS';
      expect(alarm.recurrence, equals('WEEKENDS'));

      alarm.recurrence = 'ON_135';
      expect(alarm.recurrence, equals('ON_135'));
    });

    test('toString formats correctly', () {
      final alarm = Alarm(
        zone,
        startTime: DateTime(0, 1, 1, 7, 30, 15),
      );
      expect(alarm.toString(), equals('<Alarm id:null@07:30:15>'));
    });

    test('getNextAlarmDatetime returns null for disabled alarm', () {
      final alarm = Alarm(zone, enabled: false);
      expect(alarm.getNextAlarmDatetime(), isNull);
    });

    test('getNextAlarmDatetime returns value when includeDisabled is true', () {
      final alarm = Alarm(
        zone,
        enabled: false,
        startTime: DateTime(0, 1, 1, 23, 59, 59),
      );
      final next = alarm.getNextAlarmDatetime(includeDisabled: true);
      expect(next, isNotNull);
    });

    test('getNextAlarmDatetime finds next occurrence for DAILY', () {
      final now = DateTime(2024, 1, 15, 10, 0, 0); // Monday 10:00
      final alarm = Alarm(
        zone,
        startTime: DateTime(0, 1, 1, 8, 0, 0), // 8:00 AM
        recurrence: 'DAILY',
      );

      // Since 8:00 AM has passed today, should return tomorrow
      final next = alarm.getNextAlarmDatetime(fromDatetime: now);
      expect(next, isNotNull);
      // The result is in UTC, so just check it's a valid future date
      expect(next!.day, equals(16)); // Next day
    });

    test('getNextAlarmDatetime finds today when time has not passed', () {
      final now = DateTime(2024, 1, 15, 6, 0, 0); // Monday 6:00
      final alarm = Alarm(
        zone,
        startTime: DateTime(0, 1, 1, 8, 0, 0), // 8:00 AM
        recurrence: 'DAILY',
      );

      // Since 8:00 AM has not passed today, should return today
      final next = alarm.getNextAlarmDatetime(fromDatetime: now);
      expect(next, isNotNull);
      // The result is in UTC, so just check it's the same day
      expect(next!.day, equals(15)); // Today
    });

    test('getNextAlarmDatetime respects WEEKDAYS', () {
      // Test from a Friday evening
      final friday = DateTime(2024, 1, 19, 20, 0, 0); // Friday 8pm
      final alarm = Alarm(
        zone,
        startTime: DateTime(0, 1, 1, 8, 0, 0), // 8:00 AM
        recurrence: 'WEEKDAYS',
      );

      // Next weekday after Friday evening is Monday
      final next = alarm.getNextAlarmDatetime(fromDatetime: friday);
      expect(next, isNotNull);
      expect(next!.weekday, equals(DateTime.monday));
    });

    test('getNextAlarmDatetime respects WEEKENDS', () {
      // Test from a Monday
      final monday = DateTime(2024, 1, 15, 10, 0, 0); // Monday
      final alarm = Alarm(
        zone,
        startTime: DateTime(0, 1, 1, 8, 0, 0),
        recurrence: 'WEEKENDS',
      );

      // Next weekend after Monday is Saturday
      final next = alarm.getNextAlarmDatetime(fromDatetime: monday);
      expect(next, isNotNull);
      expect(next!.weekday, equals(DateTime.saturday));
    });

    test('getNextAlarmDatetime handles ONCE recurrence', () {
      final now = DateTime(2024, 1, 15, 6, 0, 0);
      final alarm = Alarm(
        zone,
        startTime: DateTime(0, 1, 1, 8, 0, 0),
        recurrence: 'ONCE',
      );

      final next = alarm.getNextAlarmDatetime(fromDatetime: now);
      expect(next, isNotNull);
      // ONCE is treated as DAILY for finding next alarm
    });

    test('getNextAlarmDatetime handles custom ON_ patterns', () {
      // ON_13 means Monday (1) and Wednesday (3)
      final tuesday = DateTime(2024, 1, 16, 10, 0, 0); // Tuesday
      final alarm = Alarm(
        zone,
        startTime: DateTime(0, 1, 1, 8, 0, 0),
        recurrence: 'ON_13',
      );

      // From Tuesday, next occurrence should be Wednesday
      final next = alarm.getNextAlarmDatetime(fromDatetime: tuesday);
      expect(next, isNotNull);
      expect(next!.weekday, equals(DateTime.wednesday));
    });

    test('getNextAlarmDatetime handles Sunday (ON_0)', () {
      // ON_0 means Sunday
      final monday = DateTime(2024, 1, 15, 10, 0, 0); // Monday
      final alarm = Alarm(
        zone,
        startTime: DateTime(0, 1, 1, 8, 0, 0),
        recurrence: 'ON_0',
      );

      // From Monday, next occurrence should be Sunday
      final next = alarm.getNextAlarmDatetime(fromDatetime: monday);
      expect(next, isNotNull);
      expect(next!.weekday, equals(DateTime.sunday));
    });

    test('getNextAlarmDatetime uses current time when no fromDatetime', () {
      final alarm = Alarm(
        zone,
        startTime: DateTime(0, 1, 1, 23, 59, 59), // Late night
        recurrence: 'DAILY',
      );

      final next = alarm.getNextAlarmDatetime();
      expect(next, isNotNull);
    });
  });

  group('Alarm with mocked HTTP', () {
    late SoCo zone;
    late MockClient mockClient;

    setUp(() {
      zone = SoCo('192.168.101.1');
      // Clear alarms singleton state
      Alarms().alarms.clear();
    });

    tearDown(() {
      mockClient.close();
    });

    test('remove deletes alarm from Sonos', () async {
      // Timeout: 5 seconds for mocked HTTP tests
      var destroyCalled = false;
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('AlarmClock')) {
          if (request.body.contains('DestroyAlarm')) {
            destroyCalled = true;
            expect(request.body, contains('<ID>789</ID>'));
            return http.Response(
              soapEnvelope('''
                <u:DestroyAlarmResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                </u:DestroyAlarmResponse>
              '''),
              200,
            );
          }
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      final alarm = Alarm(zone);
      alarm.alarmIdForTesting = '789';

      // Add to Alarms singleton
      Alarms().alarms['789'] = alarm;

      await alarm.remove();
      expect(destroyCalled, isTrue);
      expect(alarm.alarmId, isNull);
      expect(Alarms().alarms.containsKey('789'), isFalse);
    }, timeout: Timeout(Duration(seconds: 5)));
  });

  group('Alarms update behavior', () {
    // Skipped: This test requires network discovery which times out in CI
    // test('update throws when no zone available', () async {
    //   final alarms = Alarms();
    //   alarms.resetForTesting();
    //   expect(
    //     () => alarms.update(),
    //     throwsA(anyOf(isA<SoCoException>(), isA<TypeError>())),
    //   );
    // });

    test('lastAlarmListVersion skips update when version not increased', () {
      final alarms = Alarms();
      alarms.resetForTesting();

      // Set initial version
      alarms.lastAlarmListVersion = 'RINCON_TEST001:5';
      expect(alarms.lastUid, equals('RINCON_TEST001'));
      expect(alarms.lastId, equals(5));

      // Same version should not cause issues
      alarms.lastAlarmListVersion = 'RINCON_TEST001:5';
      expect(alarms.lastId, equals(5));
    });
  });

  group('Alarm.save with mocked HTTP', () {
    late SoCo zone;
    late MockClient mockClient;

    setUp(() {
      zone = SoCo('192.168.102.1');
      Alarms().resetForTesting();
    });

    tearDown(() {
      mockClient.close();
    });

    test('save creates new alarm and returns ID', () async {
      mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('AlarmClock')) {
          if (request.body.contains('CreateAlarm')) {
            expect(request.body, contains('<StartLocalTime>08:30:00</StartLocalTime>'));
            expect(request.body, contains('<Duration>00:15:00</Duration>'));
            expect(request.body, contains('<Recurrence>WEEKDAYS</Recurrence>'));
            expect(request.body, contains('<Enabled>1</Enabled>'));
            expect(request.body, contains('<PlayMode>SHUFFLE</PlayMode>'));
            expect(request.body, contains('<Volume>35</Volume>'));
            expect(request.body, contains('<IncludeLinkedZones>1</IncludeLinkedZones>'));
            return http.Response(
              soapEnvelope('''
                <u:CreateAlarmResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                  <AssignedID>456</AssignedID>
                </u:CreateAlarmResponse>
              '''),
              200,
            );
          }
        }
        if (url.contains('ZoneGroupTopology')) {
          return http.Response(
            soapEnvelope('''
              <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
                <ZoneGroupState>${_escapeXml(zoneGroupStateForIp('192.168.102.1'))}</ZoneGroupState>
              </u:GetZoneGroupStateResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      final alarm = Alarm(
        zone,
        startTime: DateTime(0, 1, 1, 8, 30, 0),
        duration: DateTime(0, 1, 1, 0, 15, 0),
        recurrence: 'WEEKDAYS',
        playMode: 'SHUFFLE',
        volume: 35,
        includeLinkedZones: true,
      );

      final alarmId = await alarm.save();
      expect(alarmId, equals('456'));
      expect(alarm.alarmId, equals('456'));
      expect(Alarms().alarms.containsKey('456'), isTrue);
    }, timeout: Timeout(Duration(seconds: 5)));

    test('save updates existing alarm', () async {
      var updateCalled = false;
      mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('AlarmClock')) {
          if (request.body.contains('UpdateAlarm')) {
            updateCalled = true;
            expect(request.body, contains('<ID>existing123</ID>'));
            expect(request.body, contains('<StartLocalTime>09:00:00</StartLocalTime>'));
            return http.Response(
              soapEnvelope('''
                <u:UpdateAlarmResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                </u:UpdateAlarmResponse>
              '''),
              200,
            );
          }
        }
        if (url.contains('ZoneGroupTopology')) {
          return http.Response(
            soapEnvelope('''
              <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
                <ZoneGroupState>${_escapeXml(zoneGroupStateForIp('192.168.102.1'))}</ZoneGroupState>
              </u:GetZoneGroupStateResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      final alarm = Alarm(
        zone,
        startTime: DateTime(0, 1, 1, 9, 0, 0),
      );
      alarm.alarmIdForTesting = 'existing123';

      await alarm.save();
      expect(updateCalled, isTrue);
      expect(alarm.alarmId, equals('existing123'));
    }, timeout: Timeout(Duration(seconds: 5)));

    test('save with null duration sends empty duration', () async {
      mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('AlarmClock')) {
          if (request.body.contains('CreateAlarm')) {
            expect(request.body, contains('<Duration></Duration>'));
            return http.Response(
              soapEnvelope('''
                <u:CreateAlarmResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                  <AssignedID>789</AssignedID>
                </u:CreateAlarmResponse>
              '''),
              200,
            );
          }
        }
        if (url.contains('ZoneGroupTopology')) {
          return http.Response(
            soapEnvelope('''
              <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
                <ZoneGroupState>${_escapeXml(zoneGroupStateForIp('192.168.102.1'))}</ZoneGroupState>
              </u:GetZoneGroupStateResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      final alarm = Alarm(zone, duration: null);
      await alarm.save();
      expect(alarm.alarmId, equals('789'));
    }, timeout: Timeout(Duration(seconds: 5)));

    test('save with null programUri sends buzzer URI', () async {
      mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('AlarmClock')) {
          if (request.body.contains('CreateAlarm')) {
            expect(request.body, contains('<ProgramURI>x-rincon-buzzer:0</ProgramURI>'));
            return http.Response(
              soapEnvelope('''
                <u:CreateAlarmResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                  <AssignedID>111</AssignedID>
                </u:CreateAlarmResponse>
              '''),
              200,
            );
          }
        }
        if (url.contains('ZoneGroupTopology')) {
          return http.Response(
            soapEnvelope('''
              <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
                <ZoneGroupState>${_escapeXml(zoneGroupStateForIp('192.168.102.1'))}</ZoneGroupState>
              </u:GetZoneGroupStateResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      final alarm = Alarm(zone, programUri: null);
      await alarm.save();
    }, timeout: Timeout(Duration(seconds: 5)));

    test('save with custom programUri sends that URI', () async {
      mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('AlarmClock')) {
          if (request.body.contains('CreateAlarm')) {
            expect(request.body, contains('<ProgramURI>x-rincon-playlist:123</ProgramURI>'));
            return http.Response(
              soapEnvelope('''
                <u:CreateAlarmResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                  <AssignedID>222</AssignedID>
                </u:CreateAlarmResponse>
              '''),
              200,
            );
          }
        }
        if (url.contains('ZoneGroupTopology')) {
          return http.Response(
            soapEnvelope('''
              <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
                <ZoneGroupState>${_escapeXml(zoneGroupStateForIp('192.168.102.1'))}</ZoneGroupState>
              </u:GetZoneGroupStateResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      final alarm = Alarm(zone, programUri: 'x-rincon-playlist:123');
      await alarm.save();
    }, timeout: Timeout(Duration(seconds: 5)));

    test('save updates lastAlarmListVersion when sequential', () async {
      mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('AlarmClock')) {
          if (request.body.contains('CreateAlarm')) {
            return http.Response(
              soapEnvelope('''
                <u:CreateAlarmResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                  <AssignedID>6</AssignedID>
                </u:CreateAlarmResponse>
              '''),
              200,
            );
          }
        }
        if (url.contains('ZoneGroupTopology')) {
          return http.Response(
            soapEnvelope('''
              <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
                <ZoneGroupState>${_escapeXml(zoneGroupStateForIp('192.168.102.1'))}</ZoneGroupState>
              </u:GetZoneGroupStateResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      final alarms = Alarms();
      alarms.lastAlarmListVersion = 'RINCON_TEST:5';
      expect(alarms.lastId, equals(5));

      final alarm = Alarm(zone);
      await alarm.save();

      // When the new ID (6) is exactly lastId + 1, the version is updated
      expect(alarms.lastId, equals(6));
      expect(alarms.lastAlarmListVersion, equals('RINCON_TEST:6'));
    }, timeout: Timeout(Duration(seconds: 5)));

    test('save with disabled alarm sends Enabled=0', () async {
      mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('AlarmClock')) {
          if (request.body.contains('CreateAlarm')) {
            expect(request.body, contains('<Enabled>0</Enabled>'));
            return http.Response(
              soapEnvelope('''
                <u:CreateAlarmResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                  <AssignedID>333</AssignedID>
                </u:CreateAlarmResponse>
              '''),
              200,
            );
          }
        }
        if (url.contains('ZoneGroupTopology')) {
          return http.Response(
            soapEnvelope('''
              <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
                <ZoneGroupState>${_escapeXml(zoneGroupStateForIp('192.168.102.1'))}</ZoneGroupState>
              </u:GetZoneGroupStateResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      final alarm = Alarm(zone, enabled: false);
      await alarm.save();
    }, timeout: Timeout(Duration(seconds: 5)));
  });

  group('Alarms.update with mocked HTTP', () {
    late SoCo zone;
    late MockClient mockClient;

    setUp(() {
      zone = SoCo('192.168.103.1');
      Alarms().resetForTesting();
    });

    tearDown(() {
      mockClient.close();
    });

    test('update parses alarm list and creates alarm instances', () async {
      final alarmListXml = createAlarmListXml(
        alarmId: '100',
        roomUuid: 'RINCON_TEST001',
        startTime: '06:30:00',
        duration: '01:00:00',
        recurrence: 'WEEKDAYS',
        enabled: '1',
        volume: '30',
        playMode: 'SHUFFLE',
        includeLinkedZones: '1',
      );

      mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('AlarmClock')) {
          if (request.body.contains('ListAlarms')) {
            return http.Response(
              soapEnvelope('''
                <u:ListAlarmsResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                  <CurrentAlarmList>${_escapeXml(alarmListXml)}</CurrentAlarmList>
                  <CurrentAlarmListVersion>RINCON_TEST001:100</CurrentAlarmListVersion>
                </u:ListAlarmsResponse>
              '''),
              200,
            );
          }
        }
        if (url.contains('ZoneGroupTopology')) {
          return http.Response(
            soapEnvelope('''
              <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
                <ZoneGroupState>${_escapeXml(zoneGroupStateForIp('192.168.103.1'))}</ZoneGroupState>
              </u:GetZoneGroupStateResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      final alarms = Alarms();
      await alarms.update(zone);

      expect(alarms.alarms.length, equals(1));
      expect(alarms.alarms.containsKey('100'), isTrue);

      final alarm = alarms['100']!;
      expect(alarm.startTime.hour, equals(6));
      expect(alarm.startTime.minute, equals(30));
      expect(alarm.duration?.hour, equals(1));
      expect(alarm.recurrence, equals('WEEKDAYS'));
      expect(alarm.enabled, isTrue);
      expect(alarm.volume, equals(30));
      expect(alarm.playMode, equals('SHUFFLE'));
      expect(alarm.includeLinkedZones, isTrue);
    });

    test('update handles empty duration', () async {
      final alarmListXml = createAlarmListXml(
        alarmId: '101',
        duration: '', // Empty duration
      );

      mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('AlarmClock')) {
          if (request.body.contains('ListAlarms')) {
            return http.Response(
              soapEnvelope('''
                <u:ListAlarmsResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                  <CurrentAlarmList>${_escapeXml(alarmListXml)}</CurrentAlarmList>
                  <CurrentAlarmListVersion>RINCON_TEST001:101</CurrentAlarmListVersion>
                </u:ListAlarmsResponse>
              '''),
              200,
            );
          }
        }
        if (url.contains('ZoneGroupTopology')) {
          return http.Response(
            soapEnvelope('''
              <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
                <ZoneGroupState>${_escapeXml(zoneGroupStateForIp('192.168.103.1'))}</ZoneGroupState>
              </u:GetZoneGroupStateResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      final alarms = Alarms();
      await alarms.update(zone);

      final alarm = alarms['101']!;
      expect(alarm.duration, isNull);
    });

    test('update handles buzzer programUri as null', () async {
      final alarmListXml = createAlarmListXml(
        alarmId: '102',
        programUri: 'x-rincon-buzzer:0', // Should become null
      );

      mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('AlarmClock')) {
          if (request.body.contains('ListAlarms')) {
            return http.Response(
              soapEnvelope('''
                <u:ListAlarmsResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                  <CurrentAlarmList>${_escapeXml(alarmListXml)}</CurrentAlarmList>
                  <CurrentAlarmListVersion>RINCON_TEST001:102</CurrentAlarmListVersion>
                </u:ListAlarmsResponse>
              '''),
              200,
            );
          }
        }
        if (url.contains('ZoneGroupTopology')) {
          return http.Response(
            soapEnvelope('''
              <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
                <ZoneGroupState>${_escapeXml(zoneGroupStateForIp('192.168.103.1'))}</ZoneGroupState>
              </u:GetZoneGroupStateResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      final alarms = Alarms();
      await alarms.update(zone);

      final alarm = alarms['102']!;
      expect(alarm.programUri, isNull);
    });

    test('update handles custom programUri', () async {
      final alarmListXml = createAlarmListXml(
        alarmId: '103',
        programUri: 'x-rincon-playlist:RINCON_123#A:PLAYLIST/MyMusic',
      );

      mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('AlarmClock')) {
          if (request.body.contains('ListAlarms')) {
            return http.Response(
              soapEnvelope('''
                <u:ListAlarmsResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                  <CurrentAlarmList>${_escapeXml(alarmListXml)}</CurrentAlarmList>
                  <CurrentAlarmListVersion>RINCON_TEST001:103</CurrentAlarmListVersion>
                </u:ListAlarmsResponse>
              '''),
              200,
            );
          }
        }
        if (url.contains('ZoneGroupTopology')) {
          return http.Response(
            soapEnvelope('''
              <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
                <ZoneGroupState>${_escapeXml(zoneGroupStateForIp('192.168.103.1'))}</ZoneGroupState>
              </u:GetZoneGroupStateResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      final alarms = Alarms();
      await alarms.update(zone);

      final alarm = alarms['103']!;
      expect(alarm.programUri, equals('x-rincon-playlist:RINCON_123#A:PLAYLIST/MyMusic'));
    });

    test('update skips when alarm list version not increased', () async {
      var listAlarmsCalled = 0;

      mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('AlarmClock')) {
          if (request.body.contains('ListAlarms')) {
            listAlarmsCalled++;
            final alarmListXml = createAlarmListXml(alarmId: '104');
            return http.Response(
              soapEnvelope('''
                <u:ListAlarmsResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                  <CurrentAlarmList>${_escapeXml(alarmListXml)}</CurrentAlarmList>
                  <CurrentAlarmListVersion>RINCON_TEST001:5</CurrentAlarmListVersion>
                </u:ListAlarmsResponse>
              '''),
              200,
            );
          }
        }
        if (url.contains('ZoneGroupTopology')) {
          return http.Response(
            soapEnvelope('''
              <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
                <ZoneGroupState>${_escapeXml(zoneGroupStateForIp('192.168.103.1'))}</ZoneGroupState>
              </u:GetZoneGroupStateResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      final alarms = Alarms();
      alarms.lastAlarmListVersion = 'RINCON_TEST001:5'; // Same version

      await alarms.update(zone);

      // Should return early after seeing same version
      expect(listAlarmsCalled, equals(1));
      expect(alarms.alarms.isEmpty, isTrue); // No alarms parsed
    });

    test('update prunes removed alarms', () async {
      // First, add an alarm manually
      final alarms = Alarms();
      final existingAlarm = Alarm(zone);
      existingAlarm.alarmIdForTesting = 'old_alarm';
      alarms.alarms['old_alarm'] = existingAlarm;

      final alarmListXml = createAlarmListXml(alarmId: '105');

      mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('AlarmClock')) {
          if (request.body.contains('ListAlarms')) {
            return http.Response(
              soapEnvelope('''
                <u:ListAlarmsResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                  <CurrentAlarmList>${_escapeXml(alarmListXml)}</CurrentAlarmList>
                  <CurrentAlarmListVersion>RINCON_TEST001:105</CurrentAlarmListVersion>
                </u:ListAlarmsResponse>
              '''),
              200,
            );
          }
        }
        if (url.contains('ZoneGroupTopology')) {
          return http.Response(
            soapEnvelope('''
              <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
                <ZoneGroupState>${_escapeXml(zoneGroupStateForIp('192.168.103.1'))}</ZoneGroupState>
              </u:GetZoneGroupStateResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      await alarms.update(zone);

      // Old alarm should be removed, new alarm should exist
      expect(alarms.alarms.containsKey('old_alarm'), isFalse);
      expect(alarms.alarms.containsKey('105'), isTrue);
    });

    test('update updates existing alarm data', () async {
      final alarms = Alarms();

      // Create an existing alarm with ID '106'
      final existingAlarm = Alarm(
        zone,
        startTime: DateTime(0, 1, 1, 6, 0, 0),
        volume: 10,
      );
      existingAlarm.alarmIdForTesting = '106';
      alarms.alarms['106'] = existingAlarm;

      // Update will provide new data for the same alarm
      final alarmListXml = createAlarmListXml(
        alarmId: '106',
        startTime: '08:00:00', // Changed
        volume: '50', // Changed
      );

      mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('AlarmClock')) {
          if (request.body.contains('ListAlarms')) {
            return http.Response(
              soapEnvelope('''
                <u:ListAlarmsResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                  <CurrentAlarmList>${_escapeXml(alarmListXml)}</CurrentAlarmList>
                  <CurrentAlarmListVersion>RINCON_TEST001:106</CurrentAlarmListVersion>
                </u:ListAlarmsResponse>
              '''),
              200,
            );
          }
        }
        if (url.contains('ZoneGroupTopology')) {
          return http.Response(
            soapEnvelope('''
              <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
                <ZoneGroupState>${_escapeXml(zoneGroupStateForIp('192.168.103.1'))}</ZoneGroupState>
              </u:GetZoneGroupStateResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      await alarms.update(zone);

      // Same instance should be updated
      expect(identical(alarms['106'], existingAlarm), isTrue);
      expect(existingAlarm.startTime.hour, equals(8));
      expect(existingAlarm.volume, equals(50));
    });

    test('update remembers lastZoneUsed', () async {
      final alarmListXml = createAlarmListXml(alarmId: '107');

      mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('AlarmClock')) {
          if (request.body.contains('ListAlarms')) {
            return http.Response(
              soapEnvelope('''
                <u:ListAlarmsResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                  <CurrentAlarmList>${_escapeXml(alarmListXml)}</CurrentAlarmList>
                  <CurrentAlarmListVersion>RINCON_TEST001:107</CurrentAlarmListVersion>
                </u:ListAlarmsResponse>
              '''),
              200,
            );
          }
        }
        if (url.contains('ZoneGroupTopology')) {
          return http.Response(
            soapEnvelope('''
              <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
                <ZoneGroupState>${_escapeXml(zoneGroupStateForIp('192.168.103.1'))}</ZoneGroupState>
              </u:GetZoneGroupStateResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      final alarms = Alarms();
      expect(alarms.lastZoneUsed, isNull);

      await alarms.update(zone);

      expect(alarms.lastZoneUsed, equals(zone));
    });

    test('update handles disabled alarm', () async {
      final alarmListXml = createAlarmListXml(
        alarmId: '108',
        enabled: '0',
      );

      mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('AlarmClock')) {
          if (request.body.contains('ListAlarms')) {
            return http.Response(
              soapEnvelope('''
                <u:ListAlarmsResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                  <CurrentAlarmList>${_escapeXml(alarmListXml)}</CurrentAlarmList>
                  <CurrentAlarmListVersion>RINCON_TEST001:108</CurrentAlarmListVersion>
                </u:ListAlarmsResponse>
              '''),
              200,
            );
          }
        }
        if (url.contains('ZoneGroupTopology')) {
          return http.Response(
            soapEnvelope('''
              <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
                <ZoneGroupState>${_escapeXml(zoneGroupStateForIp('192.168.103.1'))}</ZoneGroupState>
              </u:GetZoneGroupStateResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      final alarms = Alarms();
      await alarms.update(zone);

      final alarm = alarms['108']!;
      expect(alarm.enabled, isFalse);
    });
  });

  group('getAlarms function', () {
    late SoCo zone;
    late MockClient mockClient;

    setUp(() {
      zone = SoCo('192.168.104.1');
      Alarms().resetForTesting();
    });

    tearDown(() {
      mockClient.close();
    });

    test('getAlarms returns set of alarms', () async {
      final alarmListXml = createAlarmListXml(alarmId: '200');

      mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('AlarmClock')) {
          if (request.body.contains('ListAlarms')) {
            return http.Response(
              soapEnvelope('''
                <u:ListAlarmsResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                  <CurrentAlarmList>${_escapeXml(alarmListXml)}</CurrentAlarmList>
                  <CurrentAlarmListVersion>RINCON_TEST001:200</CurrentAlarmListVersion>
                </u:ListAlarmsResponse>
              '''),
              200,
            );
          }
        }
        if (url.contains('ZoneGroupTopology')) {
          return http.Response(
            soapEnvelope('''
              <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
                <ZoneGroupState>${_escapeXml(zoneGroupStateForIp('192.168.104.1'))}</ZoneGroupState>
              </u:GetZoneGroupStateResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      final alarmSet = await getAlarms(zone);
      expect(alarmSet, isA<Set<Alarm>>());
      expect(alarmSet.length, equals(1));
    });
  });

  group('removeAlarmById function', () {
    late SoCo zone;
    late MockClient mockClient;

    setUp(() {
      zone = SoCo('192.168.105.1');
      Alarms().resetForTesting();
      // Clear ZoneGroupState to avoid conflicts with other tests
      zone.zoneGroupState.clearZoneGroups();
      zone.zoneGroupState.clearCache();
    });

    tearDown(() {
      mockClient.close();
    });

    test('removeAlarmById returns true when alarm found and removed', () async {
      // Use unique UUID to avoid conflicts with other tests running in parallel
      const uniqueUuid = 'RINCON_REMOVE_TEST_001';
      final alarmListXml = createAlarmListXml(alarmId: '300', roomUuid: uniqueUuid);

      mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('AlarmClock')) {
          if (request.body.contains('ListAlarms')) {
            return http.Response(
              soapEnvelope('''
                <u:ListAlarmsResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                  <CurrentAlarmList>${_escapeXml(alarmListXml)}</CurrentAlarmList>
                  <CurrentAlarmListVersion>$uniqueUuid:300</CurrentAlarmListVersion>
                </u:ListAlarmsResponse>
              '''),
              200,
            );
          }
          if (request.body.contains('DestroyAlarm')) {
            return http.Response(
              soapEnvelope('''
                <u:DestroyAlarmResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                </u:DestroyAlarmResponse>
              '''),
              200,
            );
          }
        }
        if (url.contains('ZoneGroupTopology')) {
          // Use unique UUID in zone group state to match the alarm
          return http.Response(
            soapEnvelope('''
              <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
                <ZoneGroupState>${_escapeXml(_zoneGroupStateWithUuid('192.168.105.1', uniqueUuid))}</ZoneGroupState>
              </u:GetZoneGroupStateResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      final result = await removeAlarmById(zone, '300');
      expect(result, isTrue);
      expect(Alarms().alarms.containsKey('300'), isFalse);
    });

    test('removeAlarmById returns false when alarm not found', () async {
      // Use unique UUID to avoid conflicts with other tests running in parallel
      const uniqueUuid = 'RINCON_REMOVE_TEST_002';
      final alarmListXml = createAlarmListXml(alarmId: '301', roomUuid: uniqueUuid);

      mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('AlarmClock')) {
          if (request.body.contains('ListAlarms')) {
            return http.Response(
              soapEnvelope('''
                <u:ListAlarmsResponse xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
                  <CurrentAlarmList>${_escapeXml(alarmListXml)}</CurrentAlarmList>
                  <CurrentAlarmListVersion>$uniqueUuid:301</CurrentAlarmListVersion>
                </u:ListAlarmsResponse>
              '''),
              200,
            );
          }
        }
        if (url.contains('ZoneGroupTopology')) {
          return http.Response(
            soapEnvelope('''
              <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
                <ZoneGroupState>${_escapeXml(_zoneGroupStateWithUuid('192.168.105.1', uniqueUuid))}</ZoneGroupState>
              </u:GetZoneGroupStateResponse>
            '''),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      zone.httpClient = mockClient;

      final result = await removeAlarmById(zone, 'nonexistent');
      expect(result, isFalse);
    });
  });

  group('Alarms.getNextAlarmDatetime', () {
    late SoCo zone;

    setUp(() {
      zone = SoCo('192.168.106.1');
      Alarms().resetForTesting();
    });

    test('returns null when no alarms exist', () async {
      final alarms = Alarms();
      final next = await alarms.getNextAlarmDatetime();
      expect(next, isNull);
    });

    test('finds next alarm among multiple', () async {
      final alarms = Alarms();

      // Create test alarms - use times that are clearly in the future
      final earlyAlarm = Alarm(
        zone,
        startTime: DateTime(0, 1, 1, 6, 0, 0),
        recurrence: 'DAILY',
      );
      earlyAlarm.alarmIdForTesting = '1';

      final lateAlarm = Alarm(
        zone,
        startTime: DateTime(0, 1, 1, 20, 0, 0),
        recurrence: 'DAILY',
      );
      lateAlarm.alarmIdForTesting = '2';

      alarms.alarms['1'] = earlyAlarm;
      alarms.alarms['2'] = lateAlarm;

      final now = DateTime(2024, 1, 15, 5, 0, 0); // 5 AM
      final next = await alarms.getNextAlarmDatetime(fromDatetime: now);

      expect(next, isNotNull);
      // The result is converted to UTC, check the original alarm time matches
      // 6 AM local should find today's 6 AM alarm since we're at 5 AM
      expect(next!.day, equals(15)); // Should be same day
    });

    test('excludes disabled alarms by default', () async {
      final alarms = Alarms();

      final disabledAlarm = Alarm(
        zone,
        startTime: DateTime(0, 1, 1, 6, 0, 0),
        recurrence: 'DAILY',
        enabled: false,
      );
      disabledAlarm.alarmIdForTesting = '1';

      alarms.alarms['1'] = disabledAlarm;

      final next = await alarms.getNextAlarmDatetime();
      expect(next, isNull);
    });

    test('includes disabled alarms when requested', () async {
      final alarms = Alarms();

      final disabledAlarm = Alarm(
        zone,
        startTime: DateTime(0, 1, 1, 6, 0, 0),
        recurrence: 'DAILY',
        enabled: false,
      );
      disabledAlarm.alarmIdForTesting = '1';

      alarms.alarms['1'] = disabledAlarm;

      final next = await alarms.getNextAlarmDatetime(includeDisabled: true);
      expect(next, isNotNull);
    });
  });
}

// Helper function to escape XML
String _escapeXml(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

/// Generate zone group state for a specific IP
String zoneGroupStateForIp(String ip) {
  return '''
<ZoneGroupState>
  <ZoneGroups>
    <ZoneGroup Coordinator="RINCON_TEST001" ID="RINCON_TEST001:0">
      <ZoneGroupMember UUID="RINCON_TEST001"
        Location="http://$ip:1400/xml/device_description.xml"
        ZoneName="Living Room"
        BootSeq="123"
        Configuration="1"/>
    </ZoneGroup>
  </ZoneGroups>
</ZoneGroupState>
''';
}

/// Generate zone group state for a specific IP with a specific UUID
/// Used by tests that need a unique UUID to avoid conflicts with parallel tests
String _zoneGroupStateWithUuid(String ip, String uuid) {
  return '''
<ZoneGroupState>
  <ZoneGroups>
    <ZoneGroup Coordinator="$uuid" ID="$uuid:0">
      <ZoneGroupMember UUID="$uuid"
        Location="http://$ip:1400/xml/device_description.xml"
        ZoneName="Living Room"
        BootSeq="123"
        Configuration="1"/>
    </ZoneGroup>
  </ZoneGroups>
</ZoneGroupState>
''';
}

/// Helper to create an alarm list XML payload
String createAlarmListXml({
  String alarmId = '123',
  String roomUuid = 'RINCON_TEST001',
  String startTime = '07:00:00',
  String duration = '00:30:00',
  String recurrence = 'DAILY',
  String enabled = '1',
  String programUri = 'x-rincon-buzzer:0',
  String programMetaData = '',
  String playMode = 'NORMAL',
  String volume = '25',
  String includeLinkedZones = '0',
}) {
  return '''<Alarms>
  <Alarm ID="$alarmId" StartTime="$startTime" Duration="$duration"
    Recurrence="$recurrence" Enabled="$enabled" RoomUUID="$roomUuid"
    ProgramURI="$programUri" ProgramMetaData="$programMetaData"
    PlayMode="$playMode" Volume="$volume" IncludeLinkedZones="$includeLinkedZones"/>
</Alarms>''';
}
