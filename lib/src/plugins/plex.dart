/// This plugin supports playback from a linked Plex music service.
/// See: https://support.plex.tv/articles/218168898-installing-plex-for-sonos/
///
/// Requires:
///   * Plex music service must be linked in the Sonos app
///   * Plex server URI must be reachable from Sonos speakers
///
/// Example usage:
///
/// ```dart
/// import 'package:soco/soco.dart';
/// import 'package:soco/src/plugins/plex.dart';
///
/// final speaker = SoCo('192.168.1.100');
/// final plugin = PlexPlugin(speaker);
///
/// // Integrate with your Plex client library
/// // then use plugin methods to enqueue content
/// ```
library;

import '../data_structures.dart';
import '../exceptions.dart';
import '../music_services/music_service.dart';
import 'plugins.dart';

/// Prefix lookup for Plex item types
const prefixLookup = {
  'album': '1004206c',
  'artist': '1005004c',
  'playlist': '1006206c',
  'track': '10036020',
  'albums:directory': '100d2066',
  'artists:directory': '10fe2066',
  'playlists:directory': '10fe2064',
};

/// Parent type mapping
const parentType = {
  'album': 'artist',
  'artist': 'artists:directory',
  'playlist': 'playlists:directory',
  'track': 'album',
};

/// A SoCo plugin for playing Plex media.
///
/// This plugin allows you to add Plex media items to the Sonos queue
/// using data from your Plex server.
class PlexPlugin extends SoCoPlugin {
  /// Cached service info
  Map<String, dynamic>? _serviceInfo;

  /// Initialize the plugin
  PlexPlugin(super.soco);

  @override
  String get name => 'Plex Plugin';

  /// Return the service name of the Plex music service
  String get serviceName => 'Plex';

  /// Cache and return the service info of the Plex music service
  Future<Map<String, dynamic>> get serviceInfo async {
    _serviceInfo ??= await MusicService.getDataForName(serviceName);
    return _serviceInfo!;
  }

  /// Return the service ID of the Plex music service
  Future<String> get serviceId async {
    final info = await serviceInfo;
    return info['ServiceID'] as String;
  }

  /// Return the service type of the Plex music service
  Future<String> get serviceType async {
    final info = await serviceInfo;
    return info['ServiceType'] as String;
  }

  /// Add the media to the end of the queue and immediately begin playback.
  ///
  /// Parameters:
  ///   - [plexMedia]: The Plex media object to play
  Future<void> playNow(PlexMedia plexMedia) async {
    final position = await addToQueue(plexMedia);
    await soco.playFromQueue(position - 1);
  }

  /// Add the provided media to the speaker's playback queue.
  ///
  /// Parameters:
  ///   - [plexMedia]: The Plex media to enqueue (can be a list)
  ///   - [position]: The index (1-based) at which to add (0 = append)
  ///   - [asNext]: Whether to play as the next track in shuffle mode
  ///
  /// Returns:
  ///   The index of the first item added to the queue
  Future<int> addToQueue(
    dynamic plexMedia, {
    int position = 0,
    bool asNext = false,
  }) async {
    // Handle a list of Plex media items
    if (plexMedia is List) {
      int? positionResult;
      int? firstAddedPosition;

      // If inserting, use reversed order; otherwise use original order
      final mediaItems = (asNext || position > 0)
          ? plexMedia.reversed
          : plexMedia;

      for (final mediaItem in mediaItems) {
        if (asNext || position > 0) {
          // Insert each item at the initial queue position in reverse order
          positionResult = await addToQueue(
            mediaItem,
            asNext: asNext,
            position: firstAddedPosition ?? position,
          );
        } else {
          // Append each item to the end of the queue in order
          positionResult = await addToQueue(mediaItem);
        }
        firstAddedPosition ??= positionResult;
      }

      if (!asNext) {
        return firstAddedPosition!;
      }
      return positionResult!;
    }

    final media = plexMedia as PlexMedia;
    final baseId = media.librarySectionId != null
        ? '${media.machineIdentifier}:${media.librarySectionId}'
        : '${media.machineIdentifier}:';

    final itemType = media.type;
    final parentTypeStr = parentType[itemType]!;
    final itemUri = '$baseId:${media.ratingKey}:$itemType';
    final svcType = await serviceType;
    final desc = 'SA_RINCON${svcType}_X_#Svc$svcType-0-Token';

    String parentUri;
    if (itemType == 'track') {
      parentUri = '$baseId:${media.albumRatingKey}:$parentTypeStr';
    } else if (itemType == 'album') {
      parentUri = '$baseId:${media.artistRatingKey}:$parentTypeStr';
    } else if (itemType == 'artist') {
      final firstWord = media.title.split(' ')[0];
      parentUri = '00020000artist:$firstWord';
    } else if (itemType == 'playlist') {
      if (!media.isAudio) {
        throw SoCoException('Non-audio playlists are not supported');
      }
      parentUri = '$baseId:$parentTypeStr';
    } else {
      throw SoCoException('Unknown media type: $itemType');
    }

    final parentIdStr =
        prefixLookup[parentTypeStr]! + Uri.encodeComponent(parentUri);
    final itemIdStr = prefixLookup[itemType]! + Uri.encodeComponent(itemUri);

    // Create the appropriate DIDL object based on type
    final DidlObject itemDidl;
    if (itemType == 'track') {
      itemDidl = DidlMusicTrack(
        title: media.title,
        parentId: parentIdStr,
        itemId: itemIdStr,
        desc: desc,
      );
    } else if (itemType == 'album') {
      itemDidl = DidlMusicAlbum(
        title: media.title,
        parentId: parentIdStr,
        itemId: itemIdStr,
        desc: desc,
      );
    } else if (itemType == 'artist') {
      itemDidl = DidlMusicArtist(
        title: media.title,
        parentId: parentIdStr,
        itemId: itemIdStr,
        desc: desc,
      );
    } else {
      // playlist
      itemDidl = DidlPlaylistContainer(
        title: media.title,
        parentId: parentIdStr,
        itemId: itemIdStr,
        desc: desc,
      );
    }

    final metadata = toDidlString([itemDidl]);
    final svcId = await serviceId;
    final enqueuedUri =
        'x-rincon-cpcontainer:${itemDidl.itemId}?sid=$svcId&flags=8300&sn=9';

    final response = await soco.avTransport.sendCommand(
      'AddURIToQueue',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('EnqueuedURI', enqueuedUri),
        MapEntry('EnqueuedURIMetaData', metadata),
        MapEntry('DesiredFirstTrackNumberEnqueued', position),
        MapEntry('EnqueueAsNext', asNext ? 1 : 0),
      ],
    );

    final qnumber = response['FirstTrackNumberEnqueued'] as String;
    return int.parse(qnumber);
  }
}

/// Represents Plex media metadata needed for Sonos integration.
///
/// This class should be populated with data from your Plex client library.
class PlexMedia {
  /// Machine identifier of the Plex server
  final String machineIdentifier;

  /// Library section ID (null for playlists)
  final String? librarySectionId;

  /// Rating key of the item
  final String ratingKey;

  /// Type of media (track, album, artist, playlist)
  final String type;

  /// Title of the media
  final String title;

  /// Whether this is audio content (for playlists)
  final bool isAudio;

  /// Album rating key (for tracks)
  final String? albumRatingKey;

  /// Artist rating key (for albums)
  final String? artistRatingKey;

  /// Create a Plex media object
  PlexMedia({
    required this.machineIdentifier,
    required this.librarySectionId,
    required this.ratingKey,
    required this.type,
    required this.title,
    this.isAudio = true,
    this.albumRatingKey,
    this.artistRatingKey,
  });
}
