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
export 'src/core.dart' show SoCo;
export 'src/config.dart' show cacheEnabled;
export 'src/exceptions.dart';

// Discovery
export 'src/discovery.dart' show discover, anySoco, byName, scanNetwork;

// Data structures (commonly used types)
export 'src/data_structures.dart'
    show
        DidlObject,
        DidlItem,
        DidlContainer,
        DidlResource,
        DidlMusicTrack,
        DidlMusicAlbum,
        DidlMusicArtist,
        DidlMusicGenre,
        DidlPlaylistContainer,
        DidlAudioBroadcast,
        SearchResult;
export 'src/data_structures_entry.dart' show fromDidlString;

// Music library and zone state
export 'src/music_library.dart' show MusicLibrary;
export 'src/groups.dart' show ZoneGroup;

// Alarms and snapshots
export 'src/alarms.dart' show Alarm, Alarms, getAlarms, removeAlarmById;
export 'src/snapshot.dart' show Snapshot;

// Events (core types)
export 'src/events.dart' show Subscription, eventListener, subscriptionsMap;
export 'src/events_base.dart' show Event;

// Music services
export 'src/music_services/music_services.dart'
    show
        MusicService,
        Account,
        TokenStoreBase,
        JsonFileTokenStore,
        MusicServiceItem,
        MediaMetadata,
        MediaCollection;

// Note: Advanced/internal APIs (services, soap, xml, utils, cache,
// zonegroupstate, ms_data_structures) are not exported by default.
// Import them directly if needed:
//   import 'package:soco/src/services.dart';
//   import 'package:soco/src/soap.dart';
//   etc.
