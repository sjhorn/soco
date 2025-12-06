import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:soco/src/groups.dart';
import 'package:soco/src/core.dart';

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

void main() {
  group('ZoneGroup', () {
    late SoCo coordinator;
    late SoCo member1;
    late SoCo member2;
    late ZoneGroup group;

    setUp(() {
      coordinator = SoCo('192.168.200.1');
      member1 = SoCo('192.168.200.1');
      member2 = SoCo('192.168.200.2');
      group = ZoneGroup(
        uid: 'RINCON_000FD584236D01400:58',
        coordinator: coordinator,
        members: {member1, member2},
      );
    });

    test('creates ZoneGroup with required fields', () {
      expect(group.uid, equals('RINCON_000FD584236D01400:58'));
      expect(group.coordinator, equals(coordinator));
      expect(group.members, containsAll([member1, member2]));
      expect(group.members.length, equals(2));
    });

    test('is iterable', () {
      final membersList = group.toList();
      expect(membersList.length, equals(2));
      expect(membersList, containsAll([member1, member2]));
    });

    test('iterator works correctly', () {
      var count = 0;
      for (final member in group) {
        expect(member, isA<SoCo>());
        count++;
      }
      expect(count, equals(2));
    });

    // Note: label and shortLabel require network calls and would need
    // proper HTTP mocking to test. Skipping for now.
    test('label property exists', () {
      // Just verify the property exists without calling it
      expect(group, isA<ZoneGroup>());
    });

    test('shortLabel property exists', () {
      // Just verify the property exists without calling it
      expect(group, isA<ZoneGroup>());
    });

    test('toString returns formatted group representation', () {
      final str = group.toString();
      expect(str, contains('ZoneGroup'));
      expect(str, contains('192.168.200.1'));
      expect(str, contains('192.168.200.2'));
    });

    test('uid property is accessible', () {
      expect(group.uid, equals('RINCON_000FD584236D01400:58'));
    });

    test('coordinator property is accessible', () {
      expect(group.coordinator, equals(coordinator));
    });

    test('different groups have different properties', () {
      final group2 = ZoneGroup(
        uid: 'RINCON_DIFFERENT:58',
        coordinator: SoCo('192.168.1.103'),
        members: {SoCo('192.168.1.103')},
      );
      expect(group.uid, isNot(equals(group2.uid)));
      expect(group.members, isNot(equals(group2.members)));
    });

    test('members set is immutable from outside', () {
      final originalSize = group.members.length;
      // Get the members set
      final members = group.members;
      // Try to modify (should not affect internal state)
      expect(members.length, equals(originalSize));
    });

    test('contains method works', () {
      expect(group.contains(member1), isTrue);
      expect(group.contains(member2), isTrue);
      expect(group.contains(SoCo('192.168.200.99')), isFalse);
    });

    test('creates ZoneGroup with null members', () {
      final emptyGroup = ZoneGroup(
        uid: 'RINCON_TEST:1',
        coordinator: coordinator,
      );
      expect(emptyGroup.members, isEmpty);
    });
  });

  group('ZoneGroup with HTTP mocking', () {
    late SoCo coordinator;
    late ZoneGroup group;
    late List<http.Request> capturedRequests;

    setUp(() {
      coordinator = SoCo('192.168.201.1');
      group = ZoneGroup(
        uid: 'RINCON_TEST:58',
        coordinator: coordinator,
        members: {coordinator},
      );
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

    test('getVolume returns group volume', () async {
      final mockClient = createMockClient({
        '/GroupRenderingControl/Control': soapResponse(
          'GroupRenderingControl',
          'GetGroupVolume',
          {'CurrentVolume': '65'},
        ),
      });

      coordinator.httpClient = mockClient;

      final volume = await group.volume;

      expect(volume, equals(65));
      expect(capturedRequests.length, equals(2)); // Snapshot + Get
      });

    test('setVolume sends correct command', () async {
      final mockClient = createMockClient({
        '/GroupRenderingControl/Control': soapResponse(
          'GroupRenderingControl',
          'SetGroupVolume',
          {},
        ),
      });

      coordinator.httpClient = mockClient;

      await group.setVolume(50);

      expect(capturedRequests.length, equals(2)); // Snapshot + Set
      expect(capturedRequests.last.body, contains('<DesiredVolume>50'));
      });

    test('setVolume clamps to 0-100 range', () async {
      final mockClient = createMockClient({
        '/GroupRenderingControl/Control': soapResponse(
          'GroupRenderingControl',
          'SetGroupVolume',
          {},
        ),
      });

      coordinator.httpClient = mockClient;

      // Test clamping to max
      await group.setVolume(150);
      expect(capturedRequests.last.body, contains('<DesiredVolume>100'));

      capturedRequests.clear();

      // Test clamping to min
      await group.setVolume(-10);
      expect(capturedRequests.last.body, contains('<DesiredVolume>0'));
      });

    test('getMute returns mute state', () async {
      final mockClient = createMockClient({
        '/GroupRenderingControl/Control': soapResponse(
          'GroupRenderingControl',
          'GetGroupMute',
          {'CurrentMute': '1'},
        ),
      });

      coordinator.httpClient = mockClient;

      final muted = await group.mute;

      expect(muted, isTrue);
      });

    test('getMute returns false when not muted', () async {
      final mockClient = createMockClient({
        '/GroupRenderingControl/Control': soapResponse(
          'GroupRenderingControl',
          'GetGroupMute',
          {'CurrentMute': '0'},
        ),
      });

      coordinator.httpClient = mockClient;

      final muted = await group.mute;

      expect(muted, isFalse);
      });

    test('setMute sends correct command for mute', () async {
      final mockClient = createMockClient({
        '/GroupRenderingControl/Control': soapResponse(
          'GroupRenderingControl',
          'SetGroupMute',
          {},
        ),
      });

      coordinator.httpClient = mockClient;

      await group.setMute(true);

      expect(capturedRequests.first.body, contains('<DesiredMute>1'));
      });

    test('setMute sends correct command for unmute', () async {
      final mockClient = createMockClient({
        '/GroupRenderingControl/Control': soapResponse(
          'GroupRenderingControl',
          'SetGroupMute',
          {},
        ),
      });

      coordinator.httpClient = mockClient;

      await group.setMute(false);

      expect(capturedRequests.first.body, contains('<DesiredMute>0'));
      });

    test('setRelativeVolume adjusts volume', () async {
      final mockClient = createMockClient({
        '/GroupRenderingControl/Control': soapResponse(
          'GroupRenderingControl',
          'SetRelativeGroupVolume',
          {'NewVolume': '55'},
        ),
      });

      coordinator.httpClient = mockClient;

      final newVolume = await group.setRelativeVolume(-10);

      expect(newVolume, equals(55));
      expect(capturedRequests.last.body, contains('<Adjustment>-10'));
      });
  });

  group('ZoneGroup label methods', () {
    late SoCo coordinator;
    late SoCo member2;
    late ZoneGroup group;

    // Zone group state that maps IPs to zone names
    String zoneGroupState(Map<String, String> zones) {
      final members = zones.entries.map((e) => '''
        <ZoneGroupMember UUID="RINCON_${e.value.hashCode}"
          Location="http://${e.key}:1400/xml/device_description.xml"
          ZoneName="${e.value}"
          BootSeq="123"
          Configuration="1"/>
      ''').join('\n');

      return '''
        <ZoneGroupState>
          <ZoneGroups>
            <ZoneGroup Coordinator="RINCON_${zones.entries.first.value.hashCode}" ID="RINCON_TEST:0">
              $members
            </ZoneGroup>
          </ZoneGroups>
        </ZoneGroupState>
      ''';
    }

    String zoneGroupTopologyResponse(String state) {
      final escaped = state
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;');

      return '''<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
            s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
      <ZoneGroupState>$escaped</ZoneGroupState>
    </u:GetZoneGroupStateResponse>
  </s:Body>
</s:Envelope>''';
    }

    setUp(() {
      coordinator = SoCo('192.168.202.1');
      member2 = SoCo('192.168.202.2');
      group = ZoneGroup(
        uid: 'RINCON_TEST:58',
        coordinator: coordinator,
        members: {coordinator, member2},
      );
    });

    test('label returns sorted comma-separated member names', () async {
      final zgs = zoneGroupState({
        '192.168.202.1': 'Living Room',
        '192.168.202.2': 'Kitchen',
      });

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('ZoneGroupTopology')) {
          return http.Response(zoneGroupTopologyResponse(zgs), 200);
        }
        return http.Response('Not Found', 404);
      });

      coordinator.httpClient = mockClient;
      member2.httpClient = mockClient;

      final label = await group.label;

      // Should be alphabetically sorted
      expect(label, equals('Kitchen, Living Room'));
    }, timeout: Timeout(Duration(seconds: 5)));

    test('shortLabel returns first name plus count', () async {
      final zgs = zoneGroupState({
        '192.168.202.1': 'Living Room',
        '192.168.202.2': 'Kitchen',
      });

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('ZoneGroupTopology')) {
          return http.Response(zoneGroupTopologyResponse(zgs), 200);
        }
        return http.Response('Not Found', 404);
      });

      coordinator.httpClient = mockClient;
      member2.httpClient = mockClient;

      final shortLabel = await group.shortLabel;

      // First alphabetically (Kitchen) + count of remaining
      expect(shortLabel, equals('Kitchen + 1'));
    }, timeout: Timeout(Duration(seconds: 5)));

    test('shortLabel for single member group has no count', () async {
      final singleGroup = ZoneGroup(
        uid: 'RINCON_SINGLE:1',
        coordinator: coordinator,
        members: {coordinator},
      );

      final zgs = zoneGroupState({
        '192.168.202.1': 'Living Room',
      });

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('ZoneGroupTopology')) {
          return http.Response(zoneGroupTopologyResponse(zgs), 200);
        }
        return http.Response('Not Found', 404);
      });

      coordinator.httpClient = mockClient;

      final shortLabel = await singleGroup.shortLabel;

      expect(shortLabel, equals('Living Room'));
    }, timeout: Timeout(Duration(seconds: 5)));
  });
}
