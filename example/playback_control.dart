/// Example of controlling Sonos playback.
///
/// This example demonstrates:
/// - Finding a specific Sonos device by name
/// - Controlling playback (play, pause, next, previous)
/// - Adjusting volume
/// - Getting current track information
library;

import 'package:soco/src/discovery.dart';

Future<void> main() async {
  print('Sonos Playback Control Example\n');

  try {
    // Find a specific device by zone name
    // Replace 'Living Room' with your actual zone name
    final device = await byName('Living Room');

    if (device == null) {
      print('Device "Living Room" not found.');
      print('Available zones:');
      final allDevices = await discover(timeout: 3);
      if (allDevices != null) {
        for (final d in allDevices) {
          final info = await d.getSpeakerInfo();
          print('  - ${info['zone_name']}');
        }
      }
      return;
    }

    final info = await device.getSpeakerInfo();
    print('Connected to: ${info['zone_name']}\n');

    // Get current track info
    print('Current Track Info:');
    final trackInfo = await device.getCurrentTrackInfo();
    print('  Title: ${trackInfo['title']}');
    print('  Artist: ${trackInfo['artist']}');
    print('  Album: ${trackInfo['album']}');
    print('  Position: ${trackInfo['position']} / ${trackInfo['duration']}\n');

    // Get current volume
    final currentVolume = await device.volume;
    print('Current Volume: $currentVolume\n');

    // Playback control examples
    print('Playback Controls:');

    // Play
    print('  Playing...');
    await device.play();
    await Future.delayed(Duration(seconds: 2));

    // Pause
    print('  Pausing...');
    await device.pause();
    await Future.delayed(Duration(seconds: 1));

    // Play again
    print('  Resuming...');
    await device.play();
    await Future.delayed(Duration(seconds: 2));

    // Volume control
    print('  Lowering volume to 20...');
    await device.setVolume(20);
    await Future.delayed(Duration(seconds: 2));

    // Restore original volume
    print('  Restoring volume to $currentVolume...');
    await device.setVolume(currentVolume);

    // Next track
    print('  Skipping to next track...');
    await device.next();
    await Future.delayed(Duration(seconds: 1));

    // Show new track info
    final newTrackInfo = await device.getCurrentTrackInfo();
    print('\nNow Playing:');
    print('  Title: ${newTrackInfo['title']}');
    print('  Artist: ${newTrackInfo['artist']}');

    // Play mode information
    print('\nPlay Mode Settings:');
    final playMode = await device.playMode;
    print('  Play Mode: $playMode');
    print('  Shuffle: ${await device.shuffle}');
    print('  Repeat: ${await device.repeat}');
    print('  Cross Fade: ${await device.crossFade}');

    print('\nExample complete!');
  } catch (e) {
    print('Error: $e');
  }
}
