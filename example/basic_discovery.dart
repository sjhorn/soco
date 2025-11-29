/// Basic example of discovering Sonos devices on your network.
///
/// This example demonstrates:
/// - Discovering all Sonos devices using SSDP
/// - Getting basic device information
/// - Listing all zones and their names
library;

import 'package:soco/src/discovery.dart';

Future<void> main() async {
  print('Discovering Sonos devices on your network...\n');

  try {
    // Discover all Sonos devices (timeout after 5 seconds)
    final devices = await discover(timeout: 5);

    if (devices == null || devices.isEmpty) {
      print('No Sonos devices found.');
      print(
        'Make sure your devices are powered on and connected to the network.',
      );
      return;
    }

    print('Found ${devices.length} Sonos device(s):\n');

    // Display information about each device
    for (final device in devices) {
      print('Device IP: ${device.ipAddress}');

      try {
        // Get speaker information
        final info = await device.getSpeakerInfo();
        print('  Zone Name: ${info['zone_name']}');
        print('  Model: ${info['model_name']}');
        print('  Software Version: ${info['software_version']}');
        print('  UID: ${info['uid']}');

        // Get current playback state
        final transportInfo = await device.getCurrentTransportInfo();
        final state = transportInfo['current_transport_state'];
        print('  Current State: $state');

        // If playing, show what's playing
        if (state == 'PLAYING') {
          final trackInfo = await device.getCurrentTrackInfo();
          final title = trackInfo['title'] ?? 'Unknown';
          final artist = trackInfo['artist'] ?? 'Unknown';
          print('  Now Playing: $title by $artist');
        }
      } catch (e) {
        print('  Error getting device info: $e');
      }

      print('');
    }

    // Show zone groups
    print('\nZone Groups:');
    final groups = await devices.first.allGroups;
    for (final group in groups) {
      print('  ${group.label}');
      print('    Coordinator: ${group.coordinator.ipAddress}');
      print('    Members: ${group.members.map((m) => m.ipAddress).join(', ')}');
    }
  } catch (e) {
    print('Error during discovery: $e');
  }
}
