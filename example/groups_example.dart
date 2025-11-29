/// Example demonstrating zone group management with the Dart SoCo library.
///
/// This example shows how to:
/// - Discover all Sonos zones and their groups
/// - Get information about groups
/// - Join and unjoin zones
/// - Control group playback
/// - Adjust group volume
library;

import 'package:soco/soco.dart';

Future<void> main() async {
  print('=== Sonos Zone Groups Example ===\n');

  // Discover all zones
  print('Discovering all Sonos zones...');
  final device = await anySoco();
  if (device == null) {
    print('No Sonos devices found!');
    return;
  }

  final zones = await device.allZones;

  if (zones.isEmpty) {
    print('No Sonos zones found!');
    return;
  }

  print('Found ${zones.length} zones:\n');
  for (final zone in zones) {
    final name = await zone.playerName;
    print('  - $name (${zone.ipAddress})');
  }

  // Get the first zone for examples
  final masterZone = zones.first;
  final masterName = await masterZone.playerName;
  print('\nUsing "$masterName" for examples\n');

  // Get all groups
  print('--- Current Groups ---');
  final allGroups = await masterZone.allGroups;
  final groupsList = allGroups.toList();

  for (var i = 0; i < groupsList.length; i++) {
    final group = groupsList[i];
    print('\nGroup ${i + 1}:');
    print('  UID: ${group.uid}');
    print('  Coordinator: ${await group.coordinator.playerName}');
    print('  Members: ${group.members.length}');

    for (final member in group) {
      final memberName = await member.playerName;
      final isCoordinator = member == group.coordinator;
      print('    - $memberName${isCoordinator ? ' (coordinator)' : ''}');
    }

    // Get group labels
    final label = await group.label;
    final shortLabel = await group.shortLabel;
    print('  Label: $label');
    print('  Short Label: $shortLabel');
  }

  // Check if the zone is in a group
  final group = await masterZone.group;
  print('\n--- Zone Group Info ---');
  print('$masterName is in group: ${group.uid}');
  print('Group size: ${group.members.length}');

  if (group.members.length > 1) {
    print('This zone is part of a group!');
  } else {
    print('This zone is standalone.');
  }

  // Example: Group volume control
  if (group.members.length > 1) {
    print('\n--- Group Volume Control ---');
    try {
      final currentVolume = await group.volume;
      print('Current group volume: $currentVolume');

      // Adjust volume relatively
      print('Decreasing group volume by 5...');
      await group.setRelativeVolume(-5);

      final newVolume = await group.volume;
      print('New group volume: $newVolume');

      // Restore original volume
      await group.setVolume(currentVolume);
      print('Restored group volume to: $currentVolume');
    } catch (e) {
      print('Error controlling group volume: $e');
    }
  }

  // Example: Group mute control
  if (group.members.length > 1) {
    print('\n--- Group Mute Control ---');
    try {
      final isMuted = await group.mute;
      print('Group is ${isMuted ? 'muted' : 'not muted'}');

      // Toggle mute (commented out for safety)
      // await group.setMute(!isMuted);
      // print('Toggled group mute');
    } catch (e) {
      print('Error checking group mute: $e');
    }
  }

  // Example: Joining zones (commented out for safety)
  /*
  if (zones.length > 1) {
    print('\n--- Joining Zones Example (Commented Out) ---');
    print('To join zones:');
    print('  await zones[1].join(zones[0]);');
    print('This would join zone 2 to zone 1\'s group');
  }
  */

  // Example: Party mode (all zones in one group)
  /*
  print('\n--- Party Mode Example (Commented Out) ---');
  print('To create party mode (all zones in one group):');
  print('  await masterZone.partymode();');
  print('This would group all zones together');
  */

  // Example: Unjoining a zone
  /*
  if (group.members.length > 1) {
    print('\n--- Unjoin Example (Commented Out) ---');
    print('To unjoin this zone from its group:');
    print('  await masterZone.unjoin();');
    print('This would remove the zone from its current group');
  }
  */

  // Show visible zones (excludes satellites/surrounds)
  print('\n--- Visible Zones ---');
  final visibleZones = await masterZone.visibleZones;
  print('Visible zones (excludes satellites):');
  for (final zone in visibleZones) {
    final name = await zone.playerName;
    print('  - $name');
  }

  print('\n=== Example Complete ===');
  print('\nNote: Group modification examples are commented out for safety.');
  print('Uncomment them if you want to test joining/unjoining zones.');
}
