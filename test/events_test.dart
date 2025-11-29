/// Tests for the events module.
library;

import 'package:test/test.dart';
import 'package:soco/src/events_base.dart';
import 'package:soco/src/services.dart';

const dummyEvent = '''
<e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
    <e:property>
        <ZoneGroupState>&lt;ZoneGroups&gt;&lt;
            ZoneGroup Coordinator="RINCON_000XXX01400"
            ID="RINCON_000XXX1400:56"&gt;&lt;
            ZoneGroupMember UUID="RINCON_000XXX400"
            Location="http://XXX" ZoneName="Living Room"
            Icon="x-rincon-roomicon:living" Configuration="1"
            SoftwareVersion="XXXX"
            MinCompatibleVersion="XXXX"
            LegacyCompatibleVersion="XXXX" BootSeq="48"/&gt;&lt;
            /ZoneGroup&gt;&lt;ZoneGroup Coordinator="RINCON_000XXXX01400"
            ID="RINCON_000XXXX1400:0"&gt;&lt;
            ZoneGroupMember UUID="RINCON_000XXXX1400"
            Location="http://192.168.1.100:1400/xml/device_description.xml"
            ZoneName="BRIDGE" Icon="x-rincon-roomicon:zoneextender"
            Configuration="1" Invisible="1" IsZoneBridge="1"
            SoftwareVersion="XXXX" MinCompatibleVersion="XXXX"
            LegacyCompatibleVersion="XXXX" BootSeq="37"/&gt;&lt;
            /ZoneGroup&gt;&lt;ZoneGroup Coordinator="RINCON_000XXXX1400"
            ID="RINCON_000XXXX1400:57"&gt;&lt;
            ZoneGroupMember UUID="RINCON_000XXXX01400"
            Location="http://192.168.1.102:1400/xml/device_description.xml"
            ZoneName="Kitchen" Icon="x-rincon-roomicon:kitchen"
            Configuration="1" SoftwareVersion="XXXX"
            MinCompatibleVersion="XXXX" LegacyCompatibleVersion="XXXX"
            BootSeq="56"/&gt;&lt;/ZoneGroup&gt;&lt;/ZoneGroups&gt;
         </ZoneGroupState>
    </e:property>
    <e:property>
        <ThirdPartyMediaServersX>...s+3N9Lby8yoJD/QOC4W</ThirdPartyMediaServersX>
    </e:property>
    <e:property>
        <AvailableSoftwareUpdate>&lt;UpdateItem
            xmlns="urn:schemas-rinconnetworks-com:update-1-0"
            Type="Software" Version="XXXX"
            UpdateURL="http://update-firmware.sonos.com/XXXX"
            DownloadSize="0"
            ManifestURL="http://update-firmware.sonos.com/XX"/&gt;
         </AvailableSoftwareUpdate>
    </e:property>
    <e:property>
        <AlarmRunSequence>RINCON_000EXXXXXX0:56:0</AlarmRunSequence>
    </e:property>
    <e:property>
        <ZoneGroupName>Kitchen</ZoneGroupName>
    </e:property>
    <e:property>
        <ZoneGroupID>RINCON_000XXXX01400:57</ZoneGroupID>
    </e:property>
    <e:property>
        <ZonePlayerUUIDsInGroup>RINCON_000XXX1400</ZonePlayerUUIDsInGroup>
    </e:property>
</e:propertyset>
''';

// Create a mock SoCo for testing
class MockSoCo {
  String get ipAddress => '192.168.1.100';
}

// Create a mock service for testing
class MockService extends Service {
  MockService() : super(MockSoCo()) {
    serviceType = 'TestService';
    serviceId = 'test_service';
  }
}

void main() {
  group('Events', () {
    test('Event object basic initialization', () {
      final dummyEvent = Event(
        '123',
        '456',
        MockService(),
        123456.7,
        variables: {'zone': 'kitchen'},
      );

      expect(dummyEvent.sid, equals('123'));
      expect(dummyEvent.seq, equals('456'));
      expect(dummyEvent.timestamp, equals(123456.7));
      expect(dummyEvent.service, isA<Service>());
      expect(dummyEvent.variables, equals({'zone': 'kitchen'}));
    });

    test('Event object attribute access via [] operator', () {
      final event = Event(
        '123',
        '456',
        MockService(),
        123456.7,
        variables: {'zone': 'kitchen'},
      );

      expect(event['zone'], equals('kitchen'));
    });

    test('Event object returns null for non-existent attributes', () {
      final event = Event(
        '123',
        '456',
        MockService(),
        123456.7,
        variables: {'zone': 'kitchen'},
      );

      expect(event['non_existent'], isNull);
    });

    test('Event parsing extracts variables correctly', () {
      final eventDict = parseEventXml(dummyEvent);

      expect(eventDict['zone_group_state'], isNotNull);
      expect(
        eventDict['alarm_run_sequence'],
        equals('RINCON_000EXXXXXX0:56:0'),
      );
      expect(eventDict['zone_group_id'], equals('RINCON_000XXXX01400:57'));
      expect(eventDict['zone_group_name'], equals('Kitchen'));
      expect(
        eventDict['zone_player_uui_ds_in_group'],
        equals('RINCON_000XXX1400'),
      );
    });

    test('Event toString includes basic info', () {
      final event = Event(
        '123',
        '456',
        MockService(),
        123456.7,
        variables: {'zone': 'kitchen'},
      );

      final str = event.toString();
      expect(str, contains('123'));
      expect(str, contains('456'));
      expect(str, contains('test_service'));
    });
  });
}
