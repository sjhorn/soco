/// ShareLink Plugin.
///
/// This plugin allows adding music service share links (Spotify, TIDAL,
/// Deezer, Apple Music) to the Sonos queue.
library;

import '../exceptions.dart';
import 'plugins.dart';

/// Base class for supported music services.
abstract class ShareClass {
  /// Recognize a share link and return its canonical representation.
  ///
  /// Parameters:
  ///   - [uri]: A URI like "https://tidal.com/browse/album/157273956"
  ///
  /// Returns:
  ///   The canonical URI or null if not recognized
  String? canonicalUri(String uri);

  /// Return the service number.
  ///
  /// Returns:
  ///   A number identifying the supported music service
  int serviceNumber();

  /// Return magic prefix/key/class values for each share type.
  static Map<String, Map<String, String>> magic() {
    return {
      'album': {
        'prefix': 'x-rincon-cpcontainer:1004206c',
        'key': '00040000',
        'class': 'object.container.album.musicAlbum',
      },
      'episode': {
        'prefix': '',
        'key': '00032020',
        'class': 'object.item.audioItem.musicTrack',
      },
      'track': {
        'prefix': '',
        'key': '00032020',
        'class': 'object.item.audioItem.musicTrack',
      },
      'show': {
        'prefix': 'x-rincon-cpcontainer:1006206c',
        'key': '1006206c',
        'class': 'object.container.playlistContainer',
      },
      'song': {
        'prefix': '',
        'key': '10032020',
        'class': 'object.item.audioItem.musicTrack',
      },
      'playlist': {
        'prefix': 'x-rincon-cpcontainer:1006206c',
        'key': '1006206c',
        'class': 'object.container.playlistContainer',
      },
    };
  }

  /// Extract the share type and encoded URI from a share link.
  ///
  /// Returns:
  ///   A tuple of (shareType, encodedUri)
  (String, String) extract(String uri);
}

/// Spotify share class.
class SpotifyShare extends ShareClass {
  @override
  String? canonicalUri(String uri) {
    final pattern = RegExp(
      r'spotify.*[:/](album|episode|playlist|show|track)[:/](\w+)',
    );
    final match = pattern.firstMatch(uri);
    if (match != null) {
      return 'spotify:${match.group(1)}:${match.group(2)}';
    }
    return null;
  }

  @override
  int serviceNumber() => 2311;

  @override
  (String, String) extract(String uri) {
    final spotifyUri = canonicalUri(uri)!;
    final parts = spotifyUri.split(':');
    final shareType = parts[1];
    final encodedUri = spotifyUri.replaceAll(':', '%3a');
    return (shareType, encodedUri);
  }
}

/// Spotify US share class.
class SpotifyUSShare extends SpotifyShare {
  @override
  int serviceNumber() => 3079;
}

/// TIDAL share class.
class TIDALShare extends ShareClass {
  @override
  String? canonicalUri(String uri) {
    final pattern = RegExp(
      r'https://tidal.*[:/](album|track|playlist)[:/]([\w-]+)',
    );
    final match = pattern.firstMatch(uri);
    if (match != null) {
      return 'tidal:${match.group(1)}:${match.group(2)}';
    }
    return null;
  }

  @override
  int serviceNumber() => 44551;

  @override
  (String, String) extract(String uri) {
    final tidalUri = canonicalUri(uri)!;
    final parts = tidalUri.split(':');
    final shareType = parts[1];
    final encodedUri = tidalUri
        .replaceFirst('tidal:', '')
        .replaceAll(':', '%2f');
    return (shareType, encodedUri);
  }
}

/// Deezer share class.
class DeezerShare extends ShareClass {
  @override
  String? canonicalUri(String uri) {
    final pattern = RegExp(
      r'https://www.deezer.*[:/](album|track|playlist)[:/]([\w-]+)',
    );
    final match = pattern.firstMatch(uri);
    if (match != null) {
      return 'deezer:${match.group(1)}:${match.group(2)}';
    }
    return null;
  }

  @override
  int serviceNumber() => 519;

  @override
  (String, String) extract(String uri) {
    final deezerUri = canonicalUri(uri)!;
    final parts = deezerUri.split(':');
    final shareType = parts[1];
    final encodedUri = deezerUri
        .replaceFirst('deezer:', '')
        .replaceAll(':', '-');
    return (shareType, encodedUri);
  }
}

/// Apple Music share class.
class AppleMusicShare extends ShareClass {
  @override
  String? canonicalUri(String uri) {
    // Song: https://music.apple.com/dk/album/black-velvet/217502930?i=217503142
    var pattern = RegExp(
      r'https://music\.apple\.com/\w+/album/[^/]+/\d+\?i=(\d+)',
    );
    var match = pattern.firstMatch(uri);
    if (match != null) {
      return 'song:${match.group(1)}';
    }

    // Album: https://music.apple.com/dk/album/amused-to-death/975952384
    pattern = RegExp(r'https://music\.apple\.com/\w+/album/[^/]+/(\d+)');
    match = pattern.firstMatch(uri);
    if (match != null) {
      return 'album:${match.group(1)}';
    }

    // Playlist: https://music.apple.com/dk/playlist/power-ballads-essentials/pl.92e04ee75ed64804b9df468b5f45a161
    pattern = RegExp(
      r'https://music\.apple\.com/\w+/playlist/[^/]+/(pl\.[-a-zA-Z0-9]+)',
    );
    match = pattern.firstMatch(uri);
    if (match != null) {
      return 'playlist:${match.group(1)}';
    }

    return null;
  }

  @override
  int serviceNumber() => 52231;

  @override
  (String, String) extract(String uri) {
    final appleUri = canonicalUri(uri)!;
    final parts = appleUri.split(':');
    final shareType = parts[0];
    final encodedUri = appleUri.replaceAll(':', '%3a');
    return (shareType, encodedUri);
  }
}

/// A SoCo plugin for playing music service share links.
///
/// This plugin supports adding share links from Spotify, TIDAL, Deezer,
/// and Apple Music to the Sonos queue.
class ShareLinkPlugin extends SoCoPlugin {
  /// Supported music services
  final List<ShareClass> services = [
    SpotifyShare(),
    SpotifyUSShare(),
    TIDALShare(),
    DeezerShare(),
    AppleMusicShare(),
  ];

  /// Initialize the plugin
  ShareLinkPlugin(super.soco);

  @override
  String get name => 'ShareLink Plugin';

  /// Check if the URI is for a supported music service.
  bool isShareLink(String uri) {
    for (final service in services) {
      if (service.canonicalUri(uri) != null) {
        return true;
      }
    }
    return false;
  }

  /// Add a Spotify/TIDAL/Deezer/Apple Music item to the queue.
  ///
  /// This is similar to `soco.addUriToQueue()` but will work with
  /// music service share links that do not directly point to sound files.
  ///
  /// Parameters:
  ///   - [uri]: A URI like "spotify:album:6wiUBliPe76YAVpNEdidpY"
  ///   - [position]: The index (1-based) at which to add (0 = end of queue)
  ///   - [asNext]: Whether to play as the next track in shuffle mode
  ///   - [dcTitle]: Optional title for the metadata
  ///
  /// Returns:
  ///   The index of the new item in the queue
  Future<int> addShareLinkToQueue(
    String uri, {
    int position = 0,
    bool asNext = false,
    String dcTitle = '',
  }) async {
    SoCoException fault = SoCoException('Unsupported URI: $uri');

    for (final service in services) {
      if (service.canonicalUri(uri) != null) {
        final (shareType, encodedUri) = service.extract(uri);
        final magic = ShareClass.magic();

        final enqueueUri = magic[shareType]!['prefix']! + encodedUri;

        const metadataTemplate =
            '<DIDL-Lite xmlns:dc="http://purl.org/dc/elements'
            '/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata'
            '-1-0/upnp/" xmlns:r="urn:schemas-rinconnetworks-'
            'com:metadata-1-0/" xmlns="urn:schemas-upnp-org:m'
            'etadata-1-0/DIDL-Lite/"><item id="{item_id}" par'
            'entID="-1" restricted="true"><dc:title>{title}</'
            'dc:title><upnp:class>{item_class}</upnp:class><d'
            'esc id="cdudn" nameSpace="urn:schemas-rinconnetw'
            'orks-com:metadata-1-0/">SA_RINCON{sn}_X_#Svc{sn}'
            '-0-Token</desc></item></DIDL-Lite>';

        final metadata = metadataTemplate
            .replaceAll('{item_id}', magic[shareType]!['key']! + encodedUri)
            .replaceAll('{title}', dcTitle)
            .replaceAll('{item_class}', magic[shareType]!['class']!)
            .replaceAll('{sn}', service.serviceNumber().toString());

        try {
          final response = await soco.avTransport.addUriToQueue([
            MapEntry('InstanceID', 0),
            MapEntry('EnqueuedURI', enqueueUri),
            MapEntry('EnqueuedURIMetaData', metadata),
            MapEntry('DesiredFirstTrackNumberEnqueued', position),
            MapEntry('EnqueueAsNext', asNext ? 1 : 0),
          ]);

          final qnumber = response['FirstTrackNumberEnqueued'] as String;
          return int.parse(qnumber);
        } on SoCoException catch (err) {
          // Try remaining services on failure but keep the exception
          // around in case nothing succeeds
          fault = err;
        }
      }
    }

    throw fault;
  }
}
