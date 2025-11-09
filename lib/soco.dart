/// A Dart library for controlling Sonos speakers programmatically.
///
/// This is a port of the Python SoCo library, providing a comprehensive API
/// for discovering and controlling Sonos devices on your local network.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:soco/soco.dart';
///
/// // Discover Sonos devices on the network
/// final zones = await discover();
/// if (zones != null && zones.isNotEmpty) {
///   final speaker = zones.first;
///
///   // Control playback
///   await speaker.play();
///   await speaker.pause();
///
///   // Adjust volume
///   await speaker.setVolume(25);
///
///   // Get current track info
///   final trackInfo = await speaker.getCurrentTrackInfo();
///   print('Now playing: ${trackInfo['title']}');
/// }
/// ```
library;

// Core functionality
export 'src/core.dart';
export 'src/config.dart';
export 'src/exceptions.dart';

// Discovery
export 'src/discovery.dart';

// Data structures
export 'src/data_structures.dart';
export 'src/data_structures_entry.dart' hide didlClassToSoCoClass;
export 'src/ms_data_structures.dart';

// Services and utilities
export 'src/services.dart';
export 'src/soap.dart';
export 'src/xml.dart';
export 'src/utils.dart';
export 'src/cache.dart';

// Music library and zone state
export 'src/music_library.dart';
export 'src/zonegroupstate.dart';
export 'src/groups.dart';
