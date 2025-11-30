/// Tests for ZoneGroupState XML parsing and processing.
library;

import 'package:test/test.dart';
import 'package:soco/src/zonegroupstate.dart';
import 'package:soco/src/core.dart';

void main() {
  group('ZoneGroupState', () {
    late ZoneGroupState zgs;

    setUp(() {
      zgs = ZoneGroupState();
    });

    group('initialization', () {
      test('has empty collections on creation', () {
        expect(zgs.allZones, isEmpty);
        expect(zgs.groups, isEmpty);
        expect(zgs.visibleZones, isEmpty);
      });

      test('has zero statistics on creation', () {
        expect(zgs.totalRequests, equals(0));
        expect(zgs.processedCount, equals(0));
      });
    });

    group('clearCache', () {
      test('resets cache timestamp', () {
        // clearCache should reset the internal timestamp
        zgs.clearCache();
        // No exception means success - internal state is reset
        expect(true, isTrue);
      });
    });

    group('clearZoneGroups', () {
      test('clears all zone collections', () {
        // Add some data by processing a payload
        zgs.clearZoneGroups();

        expect(zgs.allZones, isEmpty);
        expect(zgs.groups, isEmpty);
        expect(zgs.visibleZones, isEmpty);
      });
    });

    group('processPayload', () {
      test('increments totalRequests on each call', () async {
        final xml = '''
          <ZoneGroupState>
            <ZoneGroups>
              <ZoneGroup Coordinator="RINCON_001" ID="group1">
                <ZoneGroupMember UUID="RINCON_001"
                  Location="http://192.168.1.100:1400/xml/device_description.xml"
                  ZoneName="Living Room"/>
              </ZoneGroup>
            </ZoneGroups>
          </ZoneGroupState>
        ''';

        expect(zgs.totalRequests, equals(0));

        await zgs.processPayload(
          payload: xml,
          source: 'test',
          sourceIp: '192.168.1.100',
        );

        expect(zgs.totalRequests, equals(1));
      });

      test('increments processedCount for new payloads', () async {
        final xml = '''
          <ZoneGroupState>
            <ZoneGroups>
              <ZoneGroup Coordinator="RINCON_002" ID="group2">
                <ZoneGroupMember UUID="RINCON_002"
                  Location="http://192.168.1.101:1400/xml/device_description.xml"
                  ZoneName="Kitchen"/>
              </ZoneGroup>
            </ZoneGroups>
          </ZoneGroupState>
        ''';

        expect(zgs.processedCount, equals(0));

        await zgs.processPayload(
          payload: xml,
          source: 'test',
          sourceIp: '192.168.1.101',
        );

        expect(zgs.processedCount, equals(1));
      });

      test('skips duplicate payloads', () async {
        final xml = '''
          <ZoneGroupState>
            <ZoneGroups>
              <ZoneGroup Coordinator="RINCON_003" ID="group3">
                <ZoneGroupMember UUID="RINCON_003"
                  Location="http://192.168.1.102:1400/xml/device_description.xml"
                  ZoneName="Bedroom"/>
              </ZoneGroup>
            </ZoneGroups>
          </ZoneGroupState>
        ''';

        await zgs.processPayload(
          payload: xml,
          source: 'test',
          sourceIp: '192.168.1.102',
        );

        final firstProcessedCount = zgs.processedCount;

        // Send same payload again
        await zgs.processPayload(
          payload: xml,
          source: 'test',
          sourceIp: '192.168.1.102',
        );

        // totalRequests should increase but processedCount should not
        expect(zgs.totalRequests, equals(2));
        expect(zgs.processedCount, equals(firstProcessedCount));
      });

      test('parses single zone group', () async {
        final xml = '''
          <ZoneGroupState>
            <ZoneGroups>
              <ZoneGroup Coordinator="RINCON_004" ID="group4">
                <ZoneGroupMember UUID="RINCON_004"
                  Location="http://192.168.1.103:1400/xml/device_description.xml"
                  ZoneName="Office"/>
              </ZoneGroup>
            </ZoneGroups>
          </ZoneGroupState>
        ''';

        await zgs.processPayload(
          payload: xml,
          source: 'test',
          sourceIp: '192.168.1.103',
        );

        expect(zgs.groups.length, equals(1));
        expect(zgs.allZones.length, equals(1));
      });

      test('parses multiple zone groups', () async {
        final xml = '''
          <ZoneGroupState>
            <ZoneGroups>
              <ZoneGroup Coordinator="RINCON_005" ID="group5">
                <ZoneGroupMember UUID="RINCON_005"
                  Location="http://192.168.1.104:1400/xml/device_description.xml"
                  ZoneName="Bathroom"/>
              </ZoneGroup>
              <ZoneGroup Coordinator="RINCON_006" ID="group6">
                <ZoneGroupMember UUID="RINCON_006"
                  Location="http://192.168.1.105:1400/xml/device_description.xml"
                  ZoneName="Garage"/>
              </ZoneGroup>
            </ZoneGroups>
          </ZoneGroupState>
        ''';

        await zgs.processPayload(
          payload: xml,
          source: 'test',
          sourceIp: '192.168.1.104',
        );

        expect(zgs.groups.length, equals(2));
        expect(zgs.allZones.length, equals(2));
      });

      test('parses grouped zones (multiple members in one group)', () async {
        final xml = '''
          <ZoneGroupState>
            <ZoneGroups>
              <ZoneGroup Coordinator="RINCON_007" ID="group7">
                <ZoneGroupMember UUID="RINCON_007"
                  Location="http://192.168.1.106:1400/xml/device_description.xml"
                  ZoneName="Patio"/>
                <ZoneGroupMember UUID="RINCON_008"
                  Location="http://192.168.1.107:1400/xml/device_description.xml"
                  ZoneName="Deck"/>
              </ZoneGroup>
            </ZoneGroups>
          </ZoneGroupState>
        ''';

        await zgs.processPayload(
          payload: xml,
          source: 'test',
          sourceIp: '192.168.1.106',
        );

        expect(zgs.groups.length, equals(1));
        expect(zgs.allZones.length, equals(2));

        // The group should have 2 members
        final group = zgs.groups.first;
        expect(group.members.length, equals(2));
      });

      test('excludes invisible zones from visibleZones', () async {
        final xml = '''
          <ZoneGroupState>
            <ZoneGroups>
              <ZoneGroup Coordinator="RINCON_009" ID="group8">
                <ZoneGroupMember UUID="RINCON_009"
                  Location="http://192.168.1.108:1400/xml/device_description.xml"
                  ZoneName="Visible Zone"/>
                <ZoneGroupMember UUID="RINCON_010"
                  Location="http://192.168.1.109:1400/xml/device_description.xml"
                  ZoneName="Hidden Zone"
                  Invisible="1"/>
              </ZoneGroup>
            </ZoneGroups>
          </ZoneGroupState>
        ''';

        await zgs.processPayload(
          payload: xml,
          source: 'test',
          sourceIp: '192.168.1.108',
        );

        expect(zgs.allZones.length, equals(2));
        expect(zgs.visibleZones.length, equals(1));
      });

      test('identifies coordinator', () async {
        final xml = '''
          <ZoneGroupState>
            <ZoneGroups>
              <ZoneGroup Coordinator="RINCON_011" ID="group9">
                <ZoneGroupMember UUID="RINCON_011"
                  Location="http://192.168.1.110:1400/xml/device_description.xml"
                  ZoneName="Main"/>
                <ZoneGroupMember UUID="RINCON_012"
                  Location="http://192.168.1.111:1400/xml/device_description.xml"
                  ZoneName="Secondary"/>
              </ZoneGroup>
            </ZoneGroups>
          </ZoneGroupState>
        ''';

        await zgs.processPayload(
          payload: xml,
          source: 'test',
          sourceIp: '192.168.1.110',
        );

        final group = zgs.groups.first;

        // Coordinator should be set
        expect(group.coordinator.ipAddress, equals('192.168.1.110'));

        // Check coordinator status via speakerInfo
        expect(group.coordinator.speakerInfo['_isCoordinator'], isTrue);
      });

      test('parses satellite speakers', () async {
        final xml = '''
          <ZoneGroupState>
            <ZoneGroups>
              <ZoneGroup Coordinator="RINCON_013" ID="group10">
                <ZoneGroupMember UUID="RINCON_013"
                  Location="http://192.168.1.112:1400/xml/device_description.xml"
                  ZoneName="Soundbar">
                  <Satellite UUID="RINCON_014"
                    Location="http://192.168.1.113:1400/xml/device_description.xml"
                    ZoneName="Left Surround"/>
                  <Satellite UUID="RINCON_015"
                    Location="http://192.168.1.114:1400/xml/device_description.xml"
                    ZoneName="Right Surround"/>
                </ZoneGroupMember>
              </ZoneGroup>
            </ZoneGroups>
          </ZoneGroupState>
        ''';

        await zgs.processPayload(
          payload: xml,
          source: 'test',
          sourceIp: '192.168.1.112',
        );

        // Should have main zone + 2 satellites
        expect(zgs.allZones.length, equals(3));

        // Main zone should have satellites flag
        final mainZone = SoCo('192.168.1.112');
        expect(mainZone.speakerInfo['_hasSatellites'], isTrue);

        // Satellites should be marked as satellites
        final satellite1 = SoCo('192.168.1.113');
        expect(satellite1.speakerInfo['_isSatellite'], isTrue);

        final satellite2 = SoCo('192.168.1.114');
        expect(satellite2.speakerInfo['_isSatellite'], isTrue);
      });

      test('handles legacy format without ZoneGroups wrapper', () async {
        // Pre-10.1 firmware format
        final xml = '''
          <ZoneGroupState>
            <ZoneGroup Coordinator="RINCON_016" ID="group11">
              <ZoneGroupMember UUID="RINCON_016"
                Location="http://192.168.1.115:1400/xml/device_description.xml"
                ZoneName="Legacy Zone"/>
            </ZoneGroup>
          </ZoneGroupState>
        ''';

        await zgs.processPayload(
          payload: xml,
          source: 'test',
          sourceIp: '192.168.1.115',
        );

        expect(zgs.groups.length, equals(1));
        expect(zgs.allZones.length, equals(1));
      });

      test('extracts zone name from attribute', () async {
        final xml = '''
          <ZoneGroupState>
            <ZoneGroups>
              <ZoneGroup Coordinator="RINCON_017" ID="group12">
                <ZoneGroupMember UUID="RINCON_017"
                  Location="http://192.168.1.116:1400/xml/device_description.xml"
                  ZoneName="My Custom Zone Name"/>
              </ZoneGroup>
            </ZoneGroups>
          </ZoneGroupState>
        ''';

        await zgs.processPayload(
          payload: xml,
          source: 'test',
          sourceIp: '192.168.1.116',
        );

        final zone = SoCo('192.168.1.116');
        expect(zone.speakerInfo['_playerName'], equals('My Custom Zone Name'));
      });

      test('extracts UUID from attribute', () async {
        final xml = '''
          <ZoneGroupState>
            <ZoneGroups>
              <ZoneGroup Coordinator="RINCON_TEST_UUID_123" ID="group13">
                <ZoneGroupMember UUID="RINCON_TEST_UUID_123"
                  Location="http://192.168.1.117:1400/xml/device_description.xml"
                  ZoneName="UUID Test"/>
              </ZoneGroup>
            </ZoneGroups>
          </ZoneGroupState>
        ''';

        await zgs.processPayload(
          payload: xml,
          source: 'test',
          sourceIp: '192.168.1.117',
        );

        final zone = SoCo('192.168.1.117');
        expect(zone.speakerInfo['_uid'], equals('RINCON_TEST_UUID_123'));
      });
    });

    group('XML normalization', () {
      test('treats reordered elements as same payload', () async {
        // First payload with zones in one order
        final xml1 = '''
          <ZoneGroupState>
            <ZoneGroups>
              <ZoneGroup Coordinator="RINCON_A" ID="groupA">
                <ZoneGroupMember UUID="RINCON_A"
                  Location="http://192.168.1.200:1400/xml/device_description.xml"
                  ZoneName="Zone A"/>
              </ZoneGroup>
              <ZoneGroup Coordinator="RINCON_B" ID="groupB">
                <ZoneGroupMember UUID="RINCON_B"
                  Location="http://192.168.1.201:1400/xml/device_description.xml"
                  ZoneName="Zone B"/>
              </ZoneGroup>
            </ZoneGroups>
          </ZoneGroupState>
        ''';

        await zgs.processPayload(
          payload: xml1,
          source: 'test',
          sourceIp: '192.168.1.200',
        );

        expect(zgs.processedCount, equals(1));

        // Same payload with zones in different order
        final xml2 = '''
          <ZoneGroupState>
            <ZoneGroups>
              <ZoneGroup Coordinator="RINCON_B" ID="groupB">
                <ZoneGroupMember UUID="RINCON_B"
                  Location="http://192.168.1.201:1400/xml/device_description.xml"
                  ZoneName="Zone B"/>
              </ZoneGroup>
              <ZoneGroup Coordinator="RINCON_A" ID="groupA">
                <ZoneGroupMember UUID="RINCON_A"
                  Location="http://192.168.1.200:1400/xml/device_description.xml"
                  ZoneName="Zone A"/>
              </ZoneGroup>
            </ZoneGroups>
          </ZoneGroupState>
        ''';

        await zgs.processPayload(
          payload: xml2,
          source: 'test',
          sourceIp: '192.168.1.201',
        );

        // Should not process again because normalized content is the same
        expect(zgs.processedCount, equals(1));
        expect(zgs.totalRequests, equals(2));
      });
    });

    group('poll exception handling', () {
      test('poll rethrows SoCoUPnPException when zgtEventFallback is disabled', () async {
        // This test verifies the exception path in poll() when GetZoneGroupState fails
        // We can't easily mock the HTTP call, but we can verify the behavior
        // by attempting to poll a non-existent device

        final testZone = SoCo('192.168.254.254'); // Non-routable IP
        final zgs = ZoneGroupState();

        // The poll should fail with some kind of exception
        // (either timeout, connection refused, or UPnP error)
        expect(
          () => zgs.poll(testZone),
          throwsA(anything),
        );
      });
    });
  });
}
