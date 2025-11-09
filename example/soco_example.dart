import 'package:soco/soco.dart';

/// Example of discovering and controlling Sonos devices.
Future<void> main() async {
  print('Discovering Sonos devices on the network...');

  // Discover all Sonos zones
  final zones = await discover(timeout: 5);

  if (zones == null || zones.isEmpty) {
    print('No Sonos devices found on the network.');
    return;
  }

  print('Found ${zones.length} Sonos zone(s):');

  for (final zone in zones) {
    final playerName = await zone.playerName;
    final volume = await zone.volume;
    print('  - $playerName (IP: ${zone.ipAddress}, Volume: $volume)');
  }

  // Use the first zone for demonstration
  final speaker = zones.first;
  final name = await speaker.playerName;
  print('\nUsing speaker: $name');

  // Get current playback information
  try {
    final trackInfo = await speaker.getCurrentTrackInfo();
    print('Currently playing: ${trackInfo['title'] ?? 'Nothing'}');
    print('Artist: ${trackInfo['artist'] ?? 'Unknown'}');
  } catch (e) {
    print('Not currently playing anything');
  }

  // Example: Adjust volume
  print('\nCurrent volume: ${await speaker.volume}');
  // Uncomment to actually control the speaker:
  // await speaker.setVolume(25);
  // print('Volume set to 25');
}
