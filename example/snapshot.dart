/// Example of using snapshots to save and restore Sonos state.
///
/// This example demonstrates:
/// - Creating a snapshot of the current playback state
/// - Temporarily changing playback (e.g., for an announcement)
/// - Restoring the previous state
///
/// This is useful for:
/// - Playing announcements or alarms without losing what was playing
/// - Switching between different playback sources temporarily
library;

import 'package:soco/src/discovery.dart';
import 'package:soco/src/snapshot.dart';

Future<void> main() async {
  print('Sonos Snapshot Example\n');

  try {
    // Find any Sonos device
    final device = await anySoco();

    if (device == null) {
      print('No Sonos devices found on the network.');
      return;
    }

    final info = await device.getSpeakerInfo();
    print('Using device: ${info['zone_name']}\n');

    // Show current state
    print('Current State:');
    final currentTrack = await device.getCurrentTrackInfo();
    print('  Playing: ${currentTrack['title']}');
    final currentVolume = await device.volume;
    print('  Volume: $currentVolume');
    final isMuted = await device.mute;
    print('  Muted: $isMuted\n');

    // Create a snapshot
    print('Creating snapshot...');
    final snapshot = Snapshot(device);
    await snapshot.snapshot();
    print('Snapshot created!\n');

    // Make some changes
    print('Making temporary changes:');
    print('  Setting volume to 15...');
    await device.setVolume(15);

    print('  Pausing playback...');
    await device.pause();

    // You could play an announcement here
    // await device.playUri('http://example.com/announcement.mp3',
    //                       title: 'Announcement');

    print('  Waiting 3 seconds...\n');
    await Future.delayed(Duration(seconds: 3));

    // Restore the snapshot
    print('Restoring snapshot...');
    await snapshot.restore();

    print('Snapshot restored!\n');

    // Verify restoration
    print('Restored State:');
    final restoredTrack = await device.getCurrentTrackInfo();
    print('  Playing: ${restoredTrack['title']}');
    final restoredVolume = await device.volume;
    print('  Volume: $restoredVolume');
    final restoredMuted = await device.mute;
    print('  Muted: $restoredMuted');

    print('\nSnapshot example complete!');
  } catch (e) {
    print('Error: $e');
  }
}
