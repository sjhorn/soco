/// Example demonstrating UPnP event subscriptions with the Dart SoCo library.
///
/// This example shows how to:
/// - Subscribe to transport events (play, pause, track changes)
/// - Subscribe to rendering control events (volume changes)
/// - Handle event callbacks
/// - Auto-renew subscriptions
/// - Unsubscribe from events
library;

import 'dart:async';
import 'package:soco/soco.dart';

Future<void> main() async {
  print('=== Sonos Events Example ===\n');

  // Discover a Sonos device
  print('Discovering Sonos devices...');
  final device = await anySoco();

  if (device == null) {
    print('No Sonos devices found!');
    return;
  }

  final playerName = await device.playerName;
  print('Connected to: $playerName\n');

  // Create subscriptions
  print('--- Setting Up Event Subscriptions ---');

  // Subscribe to transport events (play/pause/track changes)
  print('Subscribing to transport events...');
  final transportSub = await device.avTransport.subscribe();

  // Subscribe to rendering control events (volume/mute changes)
  print('Subscribing to rendering control events...');
  final renderSub = await device.renderingControl.subscribe();

  print('Subscriptions created!\n');

  // Listen to transport events
  print('--- Listening for Transport Events ---');
  print('(Play, pause, or skip tracks to see events)\n');

  final transportEvents = <Event>[];
  transportSub.eventStream.listen((event) {
    transportEvents.add(event);
    print('🎵 Transport Event Received:');
    print('  Service: ${event.service.serviceType}');
    print('  SID: ${event.sid}');
    print('  Sequence: ${event.seq}');

    // Print interesting variables
    if (event.variables.containsKey('TransportState')) {
      print('  Transport State: ${event.variables['TransportState']}');
    }
    if (event.variables.containsKey('CurrentTrackURI')) {
      print('  Track URI: ${event.variables['CurrentTrackURI']}');
    }
    if (event.variables.containsKey('CurrentTrackMetaData')) {
      print('  Track Metadata: [... metadata present ...]');
    }
    print('');
  });

  // Listen to rendering control events
  print('(Change volume or mute to see events)\n');

  final renderEvents = <Event>[];
  renderSub.eventStream.listen((event) {
    renderEvents.add(event);
    print('🔊 Rendering Control Event Received:');
    print('  Service: ${event.service.serviceType}');

    // Extract volume and mute state from LastChange XML
    if (event.variables.containsKey('LastChange')) {
      // The LastChange variable contains XML with detailed state changes
      print('  LastChange event received');

      // You can parse the LastChange XML to get specific values
      // For now, just show that we received it
      final changes = event.variables['LastChange'];
      if (changes is Map) {
        if (changes.containsKey('Volume')) {
          print('  Volume: ${changes['Volume']}');
        }
        if (changes.containsKey('Mute')) {
          print('  Mute: ${changes['Mute']}');
        }
      }
    }
    print('');
  });

  // Wait and show subscription status
  print('Listening for events for 30 seconds...');
  print('Try controlling playback or volume on your Sonos device.\n');

  await Future.delayed(Duration(seconds: 30));

  // Show statistics
  print('\n--- Event Statistics ---');
  print('Transport events received: ${transportEvents.length}');
  print('Rendering events received: ${renderEvents.length}');

  // Check subscription status
  print('\n--- Subscription Status ---');
  print('Transport subscription:');
  print('  SID: ${transportSub.sid}');
  print('  Requested timeout: ${transportSub.requestedTimeout}');
  print('  Is subscribed: ${transportSub.isSubscribed}');

  print('\nRendering control subscription:');
  print('  SID: ${renderSub.sid}');
  print('  Requested timeout: ${renderSub.requestedTimeout}');
  print('  Is subscribed: ${renderSub.isSubscribed}');

  // Unsubscribe
  print('\n--- Unsubscribing ---');
  print('Unsubscribing from transport events...');
  await transportSub.unsubscribe();

  print('Unsubscribing from rendering control events...');
  await renderSub.unsubscribe();

  print('Unsubscribed from all events.');

  print('\n=== Example Complete ===');
  print('\nNote: Event subscriptions use UPnP GENA protocol.');
  print('Subscriptions auto-renew until explicitly unsubscribed.');
  print('Remember to unsubscribe when done to free resources.');
}
