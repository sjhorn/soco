/// Functionality to support saving and restoring the current Sonos state.
///
/// This is useful for scenarios such as when you want to switch to radio
/// or an announcement and then back again to what was playing previously.
///
/// Warning:
///   Sonos has introduced control via Amazon Alexa. A new cloud queue is
///   created and at present there appears no way to restart this
///   queue from snapshot. Currently if a cloud queue was playing it will
///   not restart.
///
/// Warning:
///   This class is designed to be created used and destroyed. It is not
///   designed to be reused or long lived. The constructor sets up defaults
///   for one use.
library;

import 'core.dart';
import 'data_structures.dart';

/// A snapshot of the current state.
///
/// Note:
///   This does not change anything to do with the configuration
///   such as which group the speaker is in, just settings that impact
///   what is playing, or how it is played.
///
///   List of sources that may be playing using root of media_uri:
///
///   - `x-rincon-queue`: playing from Queue
///   - `x-sonosapi-stream`: playing a stream (eg radio)
///   - `x-file-cifs`: playing file
///   - `x-rincon`: slave zone (only change volume etc. rest from coordinator)
class Snapshot {
  /// The device to snapshot
  final SoCo device;

  /// Whether the queue should be snapshotted
  final bool snapshotQueue;

  // For all zones:
  /// The current media URI
  String? mediaUri;

  /// Whether this device is a coordinator
  bool isCoordinator = false;

  /// Whether playing from local queue
  bool isPlayingQueue = false;

  /// Whether playing from cloud queue (Alexa)
  bool isPlayingCloudQueue = false;

  /// Current volume
  int? volume;

  /// Current mute state
  bool? mute;

  /// Current bass level
  int? bass;

  /// Current treble level
  int? treble;

  /// Current loudness setting
  bool? loudness;

  // For coordinator zone playing from Queue:
  /// Current play mode
  String? playMode;

  /// Current cross fade setting
  bool? crossFade;

  /// Current playlist position (1-based)
  int playlistPosition = 0;

  /// Current track position (as time string)
  String? trackPosition;

  // For coordinator zone playing a Stream:
  /// Metadata for current media
  String? mediaMetadata;

  // For all coordinator zones
  /// Current transport state (PLAYING, STOPPED, PAUSED_PLAYBACK)
  String? transportState;

  /// The saved queue (if snapshotQueue is true)
  List<List<DidlObject>>? queue;

  /// Creates a Snapshot.
  ///
  /// Parameters:
  ///   - [device]: The device to snapshot
  ///   - [snapshotQueue]: Whether the queue should be snapshotted.
  ///     Defaults to `false`.
  ///
  /// Warning:
  ///   It is strongly advised that you do not snapshot the queue unless
  ///   you really need to as it takes a very long time to restore large
  ///   queues as it is done one track at a time.
  Snapshot(this.device, {this.snapshotQueue = false}) {
    // Only set the queue as a list if we are going to save it
    if (snapshotQueue) {
      queue = [];
    }
  }

  /// Record and store the current state of a device.
  ///
  /// Returns:
  ///   `true` if the device is a coordinator, `false` otherwise.
  ///   Useful for determining whether playing an alert on a device
  ///   will ungroup it.
  Future<bool> snapshot() async {
    // Get if device coordinator (or slave) - true (or false)
    isCoordinator = await device.isCoordinator;

    // Get information about the currently playing media
    final mediaInfo = await device.avTransport.sendCommand(
      'GetMediaInfo',
      args: [MapEntry('InstanceID', 0)],
    );
    mediaUri = mediaInfo['CurrentURI'];

    // Extract source from media uri - below some media URI value examples:
    //  'x-rincon-queue:RINCON_000E5859E49601400#0'
    //       - playing a local queue always #0 for local queue)
    //
    //  'x-rincon-queue:RINCON_000E5859E49601400#6'
    //       - playing a cloud queue where #x changes with each queue)
    //
    //  'x-rincon:RINCON_000E5859E49601400'
    //       - a slave player pointing to coordinator player

    if (mediaUri != null && mediaUri!.split(':')[0] == 'x-rincon-queue') {
      if (mediaUri!.split('#')[1] == '0') {
        // playing local queue
        isPlayingQueue = true;
      } else {
        // playing cloud queue - started from Alexa
        isPlayingCloudQueue = true;
      }
    }

    // Save the volume, mute and other sound settings
    volume = await device.volume;
    mute = await device.mute;
    bass = await device.bass;
    treble = await device.treble;
    loudness = await device.loudness;

    // Get details required for what's playing:
    if (isPlayingQueue) {
      // playing from queue - save repeat, random, cross fade, track, etc.
      playMode = await device.playMode;
      crossFade = await device.crossFade;

      // Get information about the currently playing track
      final trackInfo = await device.getCurrentTrackInfo();
      final position = trackInfo['playlist_position'];
      if (position != null && position is String && position.isNotEmpty) {
        // save as integer
        playlistPosition = int.parse(position);
      }
      trackPosition = trackInfo['position'];
    } else {
      // playing from a stream - save media metadata
      mediaMetadata = mediaInfo['CurrentURIMetaData'];
    }

    // Work out what the playing state is - if a coordinator
    if (isCoordinator) {
      final transportInfo = await device.getCurrentTransportInfo();
      transportState = transportInfo['current_transport_state'];
    }

    // Save of the current queue if we need to
    await _saveQueue();

    // return if device is a coordinator (helps usage)
    return isCoordinator;
  }

  /// Restore the state of a device to that which was previously saved.
  ///
  /// For coordinator devices restore everything. For slave devices
  /// only restore volume etc., not transport info (transport info
  /// comes from the slave's coordinator).
  ///
  /// Parameters:
  ///   - [fade]: Whether volume should be faded up on restore.
  Future<void> restore({bool fade = false}) async {
    try {
      if (isCoordinator) {
        await _restoreCoordinator();
      }
    } finally {
      await _restoreVolume(fade);
    }

    // Now everything is set, see if we need to be playing, stopped
    // or paused (only for coordinators)
    if (isCoordinator) {
      if (transportState == 'PLAYING') {
        await device.play();
      } else if (transportState == 'STOPPED') {
        await device.stop();
      }
    }
  }

  /// Do the coordinator-only part of the restore.
  Future<void> _restoreCoordinator() async {
    // Start by ensuring that the speaker is paused as we don't want
    // things all rolling back when we are changing them, as this could
    // include things like audio
    final transportInfo = await device.getCurrentTransportInfo();
    if (transportInfo['current_transport_state'] == 'PLAYING') {
      await device.pause();
    }

    // Check if the queue should be restored
    await _restoreQueue();

    // Reinstate what was playing
    if (isPlayingQueue && playlistPosition > 0) {
      // was playing from playlist

      // The position in the playlist returned by
      // get_current_track_info starts at 1, but when
      // playing from playlist, the index starts at 0
      final adjustedPosition = playlistPosition - 1;
      await device.playFromQueue(adjustedPosition, start: false);

      if (trackPosition != null && trackPosition!.isNotEmpty) {
        await device.seek(position: trackPosition);
      }

      // reinstate track, position, play mode, cross fade
      // Need to make sure there is a proper track selected first
      if (playMode != null) {
        await device.setPlayMode(playMode!);
      }
      if (crossFade != null) {
        await device.setCrossFade(crossFade!);
      }
    } else if (isPlayingCloudQueue) {
      // was playing a cloud queue started by Alexa
      // No way yet to re-start this so prevent it throwing an error!
      // Do nothing
    } else {
      // was playing a stream (radio station, file, or nothing)
      // reinstate uri and meta data
      if (mediaUri != null && mediaUri!.isNotEmpty) {
        await device.playUri(
          uri: mediaUri!,
          meta: mediaMetadata ?? '',
          start: false,
        );
      }
    }
  }

  /// Reinstate volume.
  ///
  /// Parameters:
  ///   - [fade]: Whether volume should be faded up on restore.
  Future<void> _restoreVolume(bool fade) async {
    if (mute != null) {
      await device.setMute(mute!);
    }

    // Can only change volume on device with fixed volume set to False
    // otherwise get uPnP error, so check first. Before issuing a network
    // command to check, fixed volume always has volume set to 100.
    // So only checked fixed volume if volume is 100.
    var fixedVol = false;
    if (volume == 100) {
      fixedVol = await device.fixedVolume;
    }

    // now set volume if not fixed
    if (!fixedVol) {
      if (bass != null) {
        await device.setBass(bass!);
      }
      if (treble != null) {
        await device.setTreble(treble!);
      }
      if (loudness != null) {
        await device.setLoudness(loudness!);
      }

      if (fade) {
        // if fade requested in restore
        // set volume to 0 then fade up to saved volume (non blocking)
        await device.setVolume(0);
        if (volume != null) {
          await device.rampToVolume(volume!);
        }
      } else {
        // set volume
        if (volume != null) {
          await device.setVolume(volume!);
        }
      }
    }
  }

  /// Save the current state of the queue.
  Future<void> _saveQueue() async {
    if (queue != null) {
      // Maximum batch is 486, anything larger will still only
      // return 486
      const batchSize = 400;
      var total = 0;
      var numReturn = batchSize;

      // Need to get all the tracks in batches, but Only get the next
      // batch if all the items requested were in the last batch
      while (numReturn == batchSize) {
        final queueItems = await device.getQueue(
          start: total,
          maxItems: batchSize,
        );
        // Check how many entries were returned
        numReturn = queueItems.length;
        // Make sure the queue is not empty
        if (numReturn > 0) {
          queue!.add(queueItems);
        }
        // Update the total that have been processed
        total = total + numReturn;
      }
    }
  }

  /// Restore the previous state of the queue.
  ///
  /// Note:
  ///   The restore currently adds the items back into the queue
  ///   using the URI, for items the Sonos system already knows about
  ///   this is OK, but for other items, they may be missing some of
  ///   their metadata as it will not be automatically picked up.
  Future<void> _restoreQueue() async {
    if (queue != null) {
      // Clear the queue so that it can be reset
      await device.clearQueue();
      // Now loop around all the queue entries adding them
      for (final queueGroup in queue!) {
        for (final queueItem in queueGroup) {
          await device.addUriToQueue(queueItem.resources.first.uri);
        }
      }
    }
  }
}
