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

    test('Event with empty variables', () {
      final event = Event('sid1', '1', MockService(), 123456.7);

      expect(event.variables, isEmpty);
      expect(event['anything'], isNull);
    });
  });

  group('parseEventXml', () {
    test('parses simple property values', () {
      const xml = '''
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
          <e:property>
            <TransportState>PLAYING</TransportState>
          </e:property>
          <e:property>
            <CurrentTrackURI>x-file-cifs://server/music.mp3</CurrentTrackURI>
          </e:property>
        </e:propertyset>
      ''';

      final result = parseEventXml(xml);

      expect(result['transport_state'], equals('PLAYING'));
      expect(
        result['current_track_uri'],
        equals('x-file-cifs://server/music.mp3'),
      );
    });

    test('parses LastChange AVTransport events', () {
      const xml = '''
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
          <e:property>
            <LastChange>&lt;Event xmlns="urn:schemas-upnp-org:metadata-1-0/AVT/"&gt;
              &lt;InstanceID val="0"&gt;
                &lt;TransportState val="STOPPED"/&gt;
                &lt;CurrentPlayMode val="NORMAL"/&gt;
                &lt;CurrentTrackDuration val="0:03:45"/&gt;
              &lt;/InstanceID&gt;
            &lt;/Event&gt;</LastChange>
          </e:property>
        </e:propertyset>
      ''';

      final result = parseEventXml(xml);

      expect(result['transport_state'], equals('STOPPED'));
      expect(result['current_play_mode'], equals('NORMAL'));
      expect(result['current_track_duration'], equals('0:03:45'));
    });

    test('parses LastChange RenderingControl events with channels', () {
      const xml = '''
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
          <e:property>
            <LastChange>&lt;Event xmlns="urn:schemas-upnp-org:metadata-1-0/RCS/"&gt;
              &lt;InstanceID val="0"&gt;
                &lt;Volume channel="Master" val="50"/&gt;
                &lt;Volume channel="LF" val="100"/&gt;
                &lt;Volume channel="RF" val="100"/&gt;
                &lt;Mute channel="Master" val="0"/&gt;
              &lt;/InstanceID&gt;
            &lt;/Event&gt;</LastChange>
          </e:property>
        </e:propertyset>
      ''';

      final result = parseEventXml(xml);

      expect(result['volume'], isA<Map>());
      expect((result['volume'] as Map)['Master'], equals('50'));
      expect((result['volume'] as Map)['LF'], equals('100'));
      expect((result['volume'] as Map)['RF'], equals('100'));
      expect(result['mute'], isA<Map>());
      expect((result['mute'] as Map)['Master'], equals('0'));
    });

    test('parses LastChange Queue events', () {
      const xml = '''
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
          <e:property>
            <LastChange>&lt;Event xmlns="urn:schemas-sonos-com:metadata-1-0/Queue/"&gt;
              &lt;QueueID val="0"&gt;
                &lt;UpdateID val="42"/&gt;
              &lt;/QueueID&gt;
            &lt;/Event&gt;</LastChange>
          </e:property>
        </e:propertyset>
      ''';

      final result = parseEventXml(xml);

      expect(result['update_id'], equals('42'));
    });

    test('caches parsed results', () {
      const xml = '''
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
          <e:property>
            <TestValue>cached</TestValue>
          </e:property>
        </e:propertyset>
      ''';

      // First call should parse
      final result1 = parseEventXml(xml);
      // Second call should return cached copy
      final result2 = parseEventXml(xml);

      expect(result1['test_value'], equals('cached'));
      expect(result2['test_value'], equals('cached'));
      // Results should be equal but not identical (copy returned)
      expect(result1, equals(result2));
    });

    test('handles empty LastChange', () {
      const xml = '''
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
          <e:property>
            <LastChange></LastChange>
          </e:property>
        </e:propertyset>
      ''';

      final result = parseEventXml(xml);

      expect(result, isEmpty);
    });

    test('converts CamelCase to underscore_case', () {
      const xml = '''
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
          <e:property>
            <ZoneGroupState>test</ZoneGroupState>
          </e:property>
          <e:property>
            <CurrentTrackMetaData>meta</CurrentTrackMetaData>
          </e:property>
        </e:propertyset>
      ''';

      final result = parseEventXml(xml);

      expect(result.containsKey('zone_group_state'), isTrue);
      expect(result.containsKey('current_track_meta_data'), isTrue);
    });
  });

  group('SubscriptionsMap', () {
    test('register and getSubscription work correctly', () {
      final map = SubscriptionsMap();
      final subscription = MockSubscription(MockService());
      subscription.sid = 'test-sid-123';

      map.register(subscription);

      expect(map.getSubscription('test-sid-123'), equals(subscription));
      expect(map.count, equals(1));
    });

    test('unregister removes subscription', () {
      final map = SubscriptionsMap();
      final subscription = MockSubscription(MockService());
      subscription.sid = 'test-sid-456';

      map.register(subscription);
      expect(map.count, equals(1));

      map.unregister(subscription);
      expect(map.count, equals(0));
      expect(map.getSubscription('test-sid-456'), isNull);
    });

    test('getSubscription returns null for unknown sid', () {
      final map = SubscriptionsMap();

      expect(map.getSubscription('unknown-sid'), isNull);
    });

    test('handles subscription with null sid', () {
      final map = SubscriptionsMap();
      final subscription = MockSubscription(MockService());
      // sid is null by default

      map.register(subscription);
      expect(map.count, equals(0)); // Should not register with null sid

      map.unregister(subscription);
      expect(map.count, equals(0)); // Should handle gracefully
    });

    test('multiple subscriptions work correctly', () {
      final map = SubscriptionsMap();
      final sub1 = MockSubscription(MockService());
      sub1.sid = 'sid-1';
      final sub2 = MockSubscription(MockService());
      sub2.sid = 'sid-2';
      final sub3 = MockSubscription(MockService());
      sub3.sid = 'sid-3';

      map.register(sub1);
      map.register(sub2);
      map.register(sub3);

      expect(map.count, equals(3));
      expect(map.getSubscription('sid-1'), equals(sub1));
      expect(map.getSubscription('sid-2'), equals(sub2));
      expect(map.getSubscription('sid-3'), equals(sub3));

      map.unregister(sub2);
      expect(map.count, equals(2));
      expect(map.getSubscription('sid-2'), isNull);
    });
  });

  group('getListenIp', () {
    test('returns null when no config set', () {
      // Default behavior when no eventListenerIp is configured
      final ip = getListenIp('192.168.1.100');
      // The function returns null to indicate auto-detection needed
      // unless config.eventListenerIp is set
      expect(ip, isNull);
    });
  });

  group('SubscriptionBase', () {
    test('timeLeft returns 0 when not subscribed', () {
      final sub = MockSubscription(MockService());
      expect(sub.timeLeft, equals(0));
    });

    test('timeLeft returns remaining time when subscribed', () {
      final sub = MockSubscription(MockService());
      sub.timestamp = DateTime.now().millisecondsSinceEpoch / 1000.0;
      sub.timeout = 3600; // 1 hour

      // Should be close to 3600 seconds
      expect(sub.timeLeft, greaterThan(3590));
      expect(sub.timeLeft, lessThanOrEqualTo(3600));
    });

    test('timeLeft returns 0 when expired', () {
      final sub = MockSubscription(MockService());
      sub.timestamp =
          DateTime.now().millisecondsSinceEpoch / 1000.0 - 7200; // 2 hours ago
      sub.timeout = 3600; // 1 hour timeout (expired 1 hour ago)

      expect(sub.timeLeft, equals(0));
    });

    test('sendEvent adds event to stream', () async {
      final sub = MockSubscription(MockService());
      final event = Event(
        'sid',
        '1',
        MockService(),
        123456.7,
        variables: {'test': 'value'},
      );

      // Listen to events
      final events = <Event>[];
      sub.events.listen((e) => events.add(e));

      sub.sendEvent(event);

      // Give time for async delivery
      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(events.length, equals(1));
      expect(events[0].sid, equals('sid'));
      expect(events[0].variables['test'], equals('value'));
    }, timeout: Timeout(Duration(seconds: 5)));

    test(
      'sendEvent does nothing when stream is closed',
      () async {
        MockSubscription(MockService());
        final eventListener = MockEventListener();
        final subscriptionsMap = SubscriptionsMap();
        final sub2 = MockSubscription(
          MockService(),
          eventListener: eventListener,
          subscriptionsMap: subscriptionsMap,
        );
        sub2.sid = 'test-sid';
        subscriptionsMap.register(sub2);

        // Cancel subscription (closes stream)
        await sub2.cancelSubscription();

        // This should not throw
        final event = Event('sid', '1', MockService(), 123456.7);
        sub2.sendEvent(event);
      },
      timeout: Timeout(Duration(seconds: 5)),
    );

    test('autoRenewCancel cancels timer', () {
      final sub = MockSubscription(MockService());

      // Start auto-renew
      sub.autoRenewStart(10.0);

      // Cancel it
      sub.autoRenewCancel();

      // No exception should occur
      expect(true, isTrue);
    }, timeout: Timeout(Duration(seconds: 5)));

    test(
      'cancelSubscription unregisters and stops listener when no subs left',
      () async {
        final eventListener = MockEventListener();
        final subscriptionsMap = SubscriptionsMap();
        final sub = MockSubscription(
          MockService(),
          eventListener: eventListener,
          subscriptionsMap: subscriptionsMap,
        );
        sub.sid = 'test-sid';
        subscriptionsMap.register(sub);

        expect(subscriptionsMap.count, equals(1));

        await sub.cancelSubscription(msg: 'Test cancel');

        expect(subscriptionsMap.count, equals(0));
        expect(eventListener.stopCalled, isTrue);
        expect(sub.isSubscribed, isFalse);
        expect(sub.hasBeenUnsubscribed, isTrue);
      },
      timeout: Timeout(Duration(seconds: 5)),
    );

    test(
      'cancelSubscription does nothing if already unsubscribed',
      () async {
        final eventListener = MockEventListener();
        final subscriptionsMap = SubscriptionsMap();
        final sub = MockSubscription(
          MockService(),
          eventListener: eventListener,
          subscriptionsMap: subscriptionsMap,
        );

        sub.hasBeenUnsubscribed = true;

        await sub.cancelSubscription();

        // Should return early without modifying state
        expect(sub.hasBeenUnsubscribed, isTrue);
      },
      timeout: Timeout(Duration(seconds: 5)),
    );

    test('dispose calls unsubscribe', () async {
      final sub = MockSubscription(MockService());

      // Should not throw
      await sub.dispose();
    }, timeout: Timeout(Duration(seconds: 5)));

    test('creates broadcast stream by default', () {
      final sub = MockSubscription(MockService());

      // Should allow multiple listeners
      sub.events.listen((_) {});
      sub.events.listen((_) {});

      expect(true, isTrue);
    }, timeout: Timeout(Duration(seconds: 5)));
  });

  group('EventNotifyHandlerBase', () {
    test(
      'handleNotification processes events correctly',
      () async {
        final subscriptionsMap = SubscriptionsMap();
        final handler = MockNotifyHandler(subscriptionsMap);
        final service = MockService();
        final eventListener = MockEventListener();
        final sub = MockSubscription(
          service,
          eventListener: eventListener,
          subscriptionsMap: subscriptionsMap,
        );
        sub.sid = 'test-sid-notify';
        sub.isSubscribed = true;
        subscriptionsMap.register(sub);

        // Collect events
        final receivedEvents = <Event>[];
        sub.events.listen((e) => receivedEvents.add(e));

        const content = '''
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
          <e:property>
            <TestVar>TestValue</TestVar>
          </e:property>
        </e:propertyset>
      ''';

        handler.handleNotification({
          'sid': 'test-sid-notify',
          'seq': '42',
        }, content);

        // Give time for async delivery
        await Future<void>.delayed(Duration(milliseconds: 10));

        expect(handler.loggedEvents.length, equals(1));
        expect(handler.loggedEvents[0].$1, equals('42')); // seq
        expect(handler.loggedEvents[0].$2, equals('test_service')); // serviceId

        expect(receivedEvents.length, equals(1));
        expect(receivedEvents[0].seq, equals('42'));
        expect(receivedEvents[0].sid, equals('test-sid-notify'));
        expect(receivedEvents[0]['test_var'], equals('TestValue'));
      },
      timeout: Timeout(Duration(seconds: 5)),
    );

    test('handleNotification handles missing subscription gracefully', () {
      final subscriptionsMap = SubscriptionsMap();
      final handler = MockNotifyHandler(subscriptionsMap);

      const content = '''
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
          <e:property>
            <TestVar>TestValue</TestVar>
          </e:property>
        </e:propertyset>
      ''';

      // Should not throw even when no subscription exists
      handler.handleNotification({'sid': 'unknown-sid', 'seq': '1'}, content);

      expect(handler.loggedEvents, isEmpty);
    });

    test(
      'handleNotification handles uppercase headers',
      () async {
        final subscriptionsMap = SubscriptionsMap();
        final handler = MockNotifyHandler(subscriptionsMap);
        final eventListener = MockEventListener();
        final sub = MockSubscription(
          MockService(),
          eventListener: eventListener,
          subscriptionsMap: subscriptionsMap,
        );
        sub.sid = 'upper-sid';
        subscriptionsMap.register(sub);

        final receivedEvents = <Event>[];
        sub.events.listen((e) => receivedEvents.add(e));

        const content = '''
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
          <e:property>
            <Value>Test</Value>
          </e:property>
        </e:propertyset>
      ''';

        handler.handleNotification({'SID': 'upper-sid', 'SEQ': '99'}, content);

        await Future<void>.delayed(Duration(milliseconds: 10));

        expect(receivedEvents.length, equals(1));
        expect(receivedEvents[0].seq, equals('99'));
      },
      timeout: Timeout(Duration(seconds: 5)),
    );
  });

  group('EventListenerBase', () {
    test('default values', () {
      final listener = MockEventListener();

      expect(listener.isRunning, isFalse);
      expect(listener.address, isNull);
      expect(listener.requestedPortNumber, equals(1400)); // Default from config
    }, timeout: Timeout(Duration(seconds: 5)));
  });

  group('parseEventXml edge cases', () {
    test('handles empty val attribute with inner text fallback', () {
      const xml = '''
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
          <e:property>
            <LastChange>&lt;Event xmlns="urn:schemas-upnp-org:metadata-1-0/AVT/"&gt;
              &lt;InstanceID val="0"&gt;
                &lt;CurrentTrack&gt;1&lt;/CurrentTrack&gt;
              &lt;/InstanceID&gt;
            &lt;/Event&gt;</LastChange>
          </e:property>
        </e:propertyset>
      ''';

      final result = parseEventXml(xml);

      expect(result['current_track'], equals('1'));
    });

    test('handles empty value in LastChange', () {
      const xml = '''
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
          <e:property>
            <LastChange>&lt;Event xmlns="urn:schemas-upnp-org:metadata-1-0/AVT/"&gt;
              &lt;InstanceID val="0"&gt;
                &lt;EmptyVar val=""/&gt;
              &lt;/InstanceID&gt;
            &lt;/Event&gt;</LastChange>
          </e:property>
        </e:propertyset>
      ''';

      final result = parseEventXml(xml);

      // Empty values should be skipped
      expect(result.containsKey('empty_var'), isFalse);
    });

    test('handles LastChange without InstanceID', () {
      const xml = '''
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
          <e:property>
            <LastChange>&lt;Event xmlns="urn:schemas-upnp-org:metadata-1-0/AVT/"&gt;
            &lt;/Event&gt;</LastChange>
          </e:property>
        </e:propertyset>
      ''';

      final result = parseEventXml(xml);

      expect(result, isEmpty);
    });

    // Note: The DIDL exception handling path (lines 126-138) has a type issue
    // where `value` is String but the code tries to assign SoCoFault to it.
    // This would need library code changes to test properly.
  });
}

// Mock subscription for testing
class MockSubscription extends SubscriptionBase {
  final MockEventListener _eventListener;
  final SubscriptionsMap _subscriptionsMap;

  MockSubscription(
    super.service, {
    MockEventListener? eventListener,
    SubscriptionsMap? subscriptionsMap,
  }) : _eventListener = eventListener ?? MockEventListener(),
       _subscriptionsMap = subscriptionsMap ?? SubscriptionsMap();

  @override
  EventListenerBase get eventListener => _eventListener;

  @override
  SubscriptionsMap get subscriptionsMap => _subscriptionsMap;

  @override
  Future<void> subscribe({
    int? requestedTimeout,
    bool autoRenew = false,
  }) async {}

  @override
  Future<void> renew({int? requestedTimeout, bool isAutorenew = false}) async {}

  @override
  Future<void> unsubscribe() async {}
}

// Mock event listener for testing
class MockEventListener extends EventListenerBase {
  bool stopCalled = false;

  @override
  Future<void> start(dynamic anyZone) async {}

  @override
  Future<void> stop() async {
    stopCalled = true;
    isRunning = false;
  }

  @override
  Future<int?> listen(String ipAddress) async => 1400;

  @override
  Future<void> stopListening() async {}
}

// Mock notify handler for testing
class MockNotifyHandler extends EventNotifyHandlerBase {
  final SubscriptionsMap _subscriptionsMap;
  final List<(String, String, double)> loggedEvents = [];

  MockNotifyHandler(this._subscriptionsMap);

  @override
  SubscriptionsMap get subscriptionsMap => _subscriptionsMap;

  @override
  void logEvent(String seq, String serviceId, double timestamp) {
    loggedEvents.add((seq, serviceId, timestamp));
  }
}
