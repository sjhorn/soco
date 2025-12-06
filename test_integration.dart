/// Integration test script for comparing Dart SoCo with Python SoCo
library;

import 'package:soco/src/core.dart';
import 'package:soco/src/discovery.dart';
import 'package:soco/src/groups.dart';

Future<void> main() async {
  print('=== Dart SoCo Integration Tests ===\n');

  // Test discovery first
  print('--- Discovery Test ---');
  Set<SoCo> devices;
  try {
    final discovered = await discover(timeout: 5);
    devices = discovered ?? {};
    print('Found ${devices.length} devices:');
    for (final device in devices) {
      final name = await device.playerName;
      final uid = await device.uid;
      print('  - $name (${device.ipAddress}) [$uid]');
    }
  } catch (e) {
    print('Discovery error: $e');
    // Fall back to known device
    devices = {SoCo('192.168.1.224')};
    print('Falling back to known device: ${devices.first.ipAddress}');
  }

  if (devices.isEmpty) {
    print('No devices found!');
    return;
  }

  // Pick first device for testing
  final device = devices.first;
  final deviceName = await device.playerName;
  print('\n--- Testing with: $deviceName (${device.ipAddress}) ---\n');

  // Test volume controls
  print('=== Volume & Mute Tests ===');
  try {
    final vol = await device.volume;
    print('Current volume: $vol');

    final muted = await device.mute;
    print('Muted: $muted');

    // Test setting volume (save and restore)
    final originalVol = vol;
    await device.setVolume(vol > 10 ? vol - 5 : vol + 5);
    final newVol = await device.volume;
    print('Changed volume to: $newVol');
    await device.setVolume(originalVol);
    print('Restored volume to: $originalVol');
  } catch (e) {
    print('Volume test error: $e');
  }

  // Test transport info
  print('\n=== Transport Info Tests ===');
  try {
    final transport = await device.getCurrentTransportInfo();
    print('Transport state: ${transport['current_transport_state']}');
    print('Transport status: ${transport['current_transport_status']}');
    print('Transport speed: ${transport['current_transport_speed']}');
  } catch (e) {
    print('Transport info error: $e');
  }

  // Test current track info
  print('\n=== Current Track Info Tests ===');
  try {
    final track = await device.getCurrentTrackInfo();
    print('Queue position: ${track['playlist_position']}');
    print('Duration: ${track['duration']}');
    print('URI: ${track['uri']}');
    print('Title: ${track['title']}');
    print('Artist: ${track['artist']}');
    print('Album: ${track['album']}');
  } catch (e) {
    print('Track info error: $e');
  }

  // Test media info
  print('\n=== Media Info Tests ===');
  try {
    final media = await device.getCurrentMediaInfo();
    print('URI: ${media['uri']}');
    print('Channel: ${media['channel']}');
  } catch (e) {
    print('Media info error: $e');
  }

  // Test speaker info
  print('\n=== Speaker Info Tests ===');
  try {
    final info = await device.getSpeakerInfo();
    print('Zone name: ${info['zone_name']}');
    print('Model name: ${info['model_name']}');
    print('Model number: ${info['model_number']}');
    print('Software version: ${info['software_version']}');
    print('Hardware version: ${info['hardware_version']}');
    print('Serial number: ${info['serial_number']}');
    print('MAC address: ${info['mac_address']}');
  } catch (e) {
    print('Speaker info error: $e');
  }

  // Test play mode
  print('\n=== Play Mode Tests ===');
  try {
    final mode = await device.playMode;
    print('Play mode: $mode');

    final shuffle = await device.shuffle;
    print('Shuffle: $shuffle');

    final repeat = await device.repeat;
    print('Repeat: $repeat');
  } catch (e) {
    print('Play mode error: $e');
  }

  // Test audio settings
  print('\n=== Audio Settings Tests ===');
  try {
    final bass = await device.bass;
    print('Bass: $bass');

    final treble = await device.treble;
    print('Treble: $treble');

    final loudness = await device.loudness;
    print('Loudness: $loudness');
  } catch (e) {
    print('Audio settings error: $e');
  }

  // Test queue
  print('\n=== Queue Tests ===');
  try {
    final queueSize = await device.queueSize;
    print('Queue size: $queueSize');

    if (queueSize > 0) {
      final queue = await device.getQueue(maxItems: 5);
      print('First items in queue:');
      if (queue is Iterable) {
        for (final item in queue.items) {
          print('  - $item');
        }
      } else {
        print('  Queue: $queue');
      }
    }
  } catch (e) {
    print('Queue test error: $e');
  }

  // Test status light
  print('\n=== Status Light Test ===');
  try {
    final light = await device.statusLight;
    print('Status light on: $light');
  } catch (e) {
    print('Status light error: $e');
  }

  // Test groups
  print('\n=== Group Tests ===');
  try {
    final isCoord = await device.isCoordinator;
    print('Is coordinator: $isCoord');

    // Get device's group
    final deviceGroup = await device.group;
    if (deviceGroup != null) {
      final groupCoord = (deviceGroup as ZoneGroup).coordinator;
      final coordName = await groupCoord.playerName;
      print('Group coordinator: $coordName (${groupCoord.ipAddress})');
      print('Group members: ${deviceGroup.members.length}');
      for (final member in deviceGroup.members) {
        final memberName = await member.playerName;
        print('  - $memberName (${member.ipAddress})');
      }
    }

    // Test all groups in household
    final allGroups = await device.allGroups;
    print('\nAll groups in household: ${allGroups.length}');
    for (final grp in allGroups) {
      final group = grp as ZoneGroup;
      final groupCoordName = await group.coordinator.playerName;
      print('  Group: $groupCoordName (${group.members.length} members)');
    }
  } catch (e) {
    print('Group test error: $e');
  }

  // Test sleep timer
  print('\n=== Sleep Timer Tests ===');
  try {
    final sleepTimer = await device.getSleepTimer();
    print('Sleep timer: $sleepTimer');
  } catch (e) {
    print('Sleep timer error: $e');
  }

  // Test available actions
  print('\n=== Available Actions Test ===');
  try {
    final actions = await device.availableActions;
    print('Available actions: $actions');
  } catch (e) {
    print('Available actions error: $e');
  }

  // Test is_playing_tv
  print('\n=== TV/Line-in Tests ===');
  try {
    final playingTv = await device.isPlayingTv;
    print('Is playing TV: $playingTv');

    final playingLineIn = await device.isPlayingLineIn;
    print('Is playing Line-in: $playingLineIn');

    final playingRadio = await device.isPlayingRadio;
    print('Is playing Radio: $playingRadio');
  } catch (e) {
    print('TV/Line-in test error: $e');
  }

  // Test music library (if available)
  print('\n=== Music Library Tests ===');
  try {
    final library = device.musicLibrary;
    final result = await library.getArtists(maxItems: 5);
    print(
      'Artists in library: ${result.numberReturned} returned, ${result.totalMatches} total',
    );
    for (final artist in result.items) {
      print('  - ${artist.title}');
    }
  } catch (e) {
    print('Music library error: $e');
  }

  // Test all zones
  print('\n=== All Zones Tests ===');
  try {
    final allZones = await device.allZones;
    print('All zones: ${allZones.length}');
    for (final zone in allZones) {
      final zoneName = await zone.playerName;
      print('  - $zoneName (${zone.ipAddress})');
    }

    final visibleZones = await device.visibleZones;
    print('Visible zones: ${visibleZones.length}');
  } catch (e) {
    print('All zones error: $e');
  }

  print('\n=== Integration Tests Complete ===');
}
