/// The core module contains the SoCo class that implements
/// the main entry to the SoCo functionality.
library;

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'exceptions.dart';
import 'music_library.dart';
import 'services.dart';
import 'zonegroupstate.dart';

final _log = Logger('soco.core');

/// Audio input format codes and their descriptions
const Map<int, String> audioInputFormats = {
  0: 'No input connected',
  2: 'Stereo',
  7: 'Dolby 2.0',
  18: 'Dolby 5.1',
  21: 'No input',
  22: 'No audio',
  59: 'Dolby Atmos (DD+)',
  61: 'Dolby Atmos (TrueHD)',
  63: 'Dolby Atmos (MAT 2.0)',
  33554434: 'PCM 2.0',
  33554454: 'PCM 2.0 no audio',
  33554488: 'Dolby 2.0',
  33554490: 'Dolby Digital Plus 2.0',
  33554492: 'Dolby TrueHD 2.0',
  33554494: 'Dolby Multichannel PCM 2.0',
  84934658: 'Multichannel PCM 5.1',
  84934713: 'Dolby 5.1',
  84934714: 'Dolby Digital Plus 5.1',
  84934716: 'Dolby TrueHD 5.1',
  84934718: 'Dolby Multichannel PCM 5.1',
  84934721: 'DTS 5.1',
  118489146: 'Dolby Digital Plus 7.1',
};

/// Valid play modes
const Map<String, (bool, dynamic)> playModes = {
  'NORMAL': (false, false),
  'SHUFFLE_NOREPEAT': (true, false),
  'SHUFFLE': (true, true),
  'REPEAT_ALL': (false, true),
  'SHUFFLE_REPEAT_ONE': (true, 'ONE'),
  'REPEAT_ONE': (false, 'ONE'),
};

/// Inverse mapping of play modes
final Map<(bool, dynamic), String> playModeByMeaning = {
  for (final entry in playModes.entries) entry.value: entry.key,
};

/// Music source names
const String musicSrcLibrary = 'LIBRARY';
const String musicSrcRadio = 'RADIO';
const String musicSrcWebFile = 'WEB_FILE';
const String musicSrcLineIn = 'LINE_IN';
const String musicSrcTv = 'TV';
const String musicSrcAirplay = 'AIRPLAY';
const String musicSrcSpotifyConnect = 'SPOTIFY_CONNECT';
const String musicSrcUnknown = 'UNKNOWN';
const String musicSrcNone = 'NONE';

/// URI prefixes for music sources
const Map<String, String> sources = {
  r'^$': musicSrcNone,
  r'^x-file-cifs:': musicSrcLibrary,
  r'^x-rincon-mp3radio:': musicSrcRadio,
  r'^x-sonosapi-stream:': musicSrcRadio,
  r'^x-sonosapi-radio:': musicSrcRadio,
  r'^x-sonosapi-hls:': musicSrcRadio,
  r'^x-sonos-http:sonos': musicSrcRadio,
  r'^aac:': musicSrcRadio,
  r'^hls-radio:': musicSrcRadio,
  r'^https?:': musicSrcWebFile,
  r'^x-rincon-stream:': musicSrcLineIn,
  r'^x-sonos-htastream:': musicSrcTv,
  r'^x-sonos-vli:.*,airplay:': musicSrcAirplay,
  r'^x-sonos-vli:.*,spotify:': musicSrcSpotifyConnect,
};

/// Soundbar product names
const List<String> soundbars = [
  'arc',
  'arc sl',
  'arc ultra',
  'beam',
  'playbase',
  'playbar',
  'ray',
  'sonos amp',
];

const String arcUltraProductName = 'arc ultra';

/// Constants for favorites
const int radioStations = 0;
const int radioShows = 1;
const int sonosFavorites = 2;

/// Cache for SoCo instances (singleton pattern)
final Map<String, SoCo> _socoInstances = {};

/// A simple class for controlling a Sonos speaker.
///
/// For any given IP address, only one instance of this class may be created.
/// Subsequent attempts to create an instance with the same IP address will
/// return the previously created instance. This means that all SoCo instances
/// created with the same IP address are in fact the *same* SoCo instance,
/// reflecting the real world position.
///
/// ## Basic Methods
/// - [playFromQueue]
/// - [play]
/// - [playUri]
/// - [pause]
/// - [stop]
/// - [endDirectControlSession]
/// - [seek]
/// - [next]
/// - [previous]
/// - [mute]
/// - [volume]
/// - [playMode]
/// - [shuffle]
/// - [repeat]
/// - [crossFade]
/// - [rampToVolume]
/// - [setRelativeVolume]
/// - [getCurrentTrackInfo]
/// - [getCurrentMediaInfo]
/// - [getSpeakerInfo]
/// - [getCurrentTransportInfo]
///
/// ## Queue Management
/// - [getQueue]
/// - [queueSize]
/// - [addToQueue]
/// - [addUriToQueue]
/// - [addMultipleToQueue]
/// - [removeFromQueue]
/// - [clearQueue]
///
/// ## Group Management
/// - [group]
/// - [partymode]
/// - [join]
/// - [unjoin]
/// - [allGroups]
/// - [allZones]
/// - [visibleZones]
///
/// ## Player Identity and Settings
/// - [playerName]
/// - [uid]
/// - [householdId]
/// - [isVisible]
/// - [isBridge]
/// - [isCoordinator]
/// - [isSoundbar]
/// - [isSatellite]
/// - [hasSatellites]
/// - [subCrossover]
/// - [subEnabled]
/// - [subGain]
/// - [isSubwoofer]
/// - [hasSubwoofer]
/// - [channel]
/// - [bass]
/// - [treble]
/// - [loudness]
/// - [balance]
/// - [audioDelay]
/// - [nightMode]
/// - [dialogMode]
/// - [surroundEnabled]
/// - [surroundFullVolumeEnabled]
/// - [surroundVolumeTv]
/// - [surroundVolumeMusic]
/// - [soundbarAudioInputFormat]
/// - [supportsFixedVolume]
/// - [fixedVolume]
/// - [trueplay]
/// - [statusLight]
/// - [buttonsEnabled]
/// - [voiceServiceConfigured]
/// - [micEnabled]
///
/// ## Playlists and Favorites
/// - [getSonosPlaylists]
/// - [createSonosPlaylist]
/// - [createSonosPlaylistFromQueue]
/// - [removeSonosPlaylist]
/// - [addItemToSonosPlaylist]
/// - [reorderSonosPlaylist]
/// - [clearSonosPlaylist]
/// - [moveInSonosPlaylist]
/// - [removeFromSonosPlaylist]
/// - [getSonosPlaylistByAttr]
/// - [getFavoriteRadioShows]
/// - [getFavoriteRadioStations]
/// - [getSonosFavorites]
///
/// ## Miscellaneous
/// - [musicSource]
/// - [musicSourceFromUri]
/// - [isPlayingRadio]
/// - [isPlayingTv]
/// - [isPlayingLineIn]
/// - [switchToLineIn]
/// - [switchToTv]
/// - [availableActions]
/// - [setSleepTimer]
/// - [getSleepTimer]
/// - [createStereoPair]
/// - [separateStereoPair]
/// - [getBatteryInfo]
/// - [bootSeqnum]
///
/// Warning: Properties on this object are not generally cached and may obtain
/// information over the network, so may take longer than expected to set
/// or return a value. It may be a good idea for you to cache the value in
/// your own code.
///
/// Note: Since all methods/properties on this object will result in a UPnP
/// request, they might result in an exception without it being mentioned
/// in the documentation. In most cases, the exception will be a
/// [SoCoUPnPException] (if the player returns a UPnP error code), but in
/// special cases it might also be another [SoCoException] or even an HTTP
/// exception.
class SoCo {
  /// Static cache for zone group states
  static final Map<String, ZoneGroupState> zoneGroupStates = {};

  /// Get all SoCo instances (for discovery purposes)
  static Map<String, SoCo> get instances => Map.unmodifiable(_socoInstances);

  /// The speaker's IP address
  final String ipAddress;

  /// Information about the current speaker
  Map<String, dynamic> speakerInfo = {};

  // Services
  late final AVTransport avTransport;
  late final ContentDirectory contentDirectory;
  late final DeviceProperties deviceProperties;
  late final RenderingControl renderingControl;
  late final GroupRenderingControl groupRenderingControl;
  late final ZoneGroupTopology zoneGroupTopology;
  late final AlarmClock alarmClock;
  late final SystemProperties systemProperties;
  late final MusicServices musicServices;
  late final AudioIn audioIn;

  late final MusicLibrary musicLibrary;

  // Private attributes
  int? _bootSeqnum;
  String? _channelMap;
  String? _htSatChanMap;
  bool? _isBridge;
  String? _channel;
  bool? _isSoundbar;
  String? _playerName;
  String? _uid;
  String? _householdId;

  /// Factory constructor to implement singleton pattern per IP address.
  factory SoCo(String ipAddress) {
    if (_socoInstances.containsKey(ipAddress)) {
      return _socoInstances[ipAddress]!;
    }
    final instance = SoCo._internal(ipAddress);
    _socoInstances[ipAddress] = instance;
    return instance;
  }

  /// Internal constructor for the singleton pattern.
  SoCo._internal(this.ipAddress) {
    // Validate IP address (IPv4 only - Sonos does not support IPv6)
    try {
      InternetAddress(ipAddress, type: InternetAddressType.IPv4);
    } catch (e) {
      throw ArgumentError('Not a valid IPv4 address string: $ipAddress');
    }

    // Initialize services
    avTransport = AVTransport(this);
    contentDirectory = ContentDirectory(this);
    deviceProperties = DeviceProperties(this);
    renderingControl = RenderingControl(this);
    groupRenderingControl = GroupRenderingControl(this);
    zoneGroupTopology = ZoneGroupTopology(this);
    alarmClock = AlarmClock(this);
    systemProperties = SystemProperties(this);
    musicServices = MusicServices(this);
    audioIn = AudioIn(this);

    musicLibrary = MusicLibrary(this);

    _log.fine('Created SoCo instance for ip: $ipAddress');
  }

  @override
  String toString() => '<SoCo object at ip $ipAddress>';

  /// The boot sequence number.
  Future<int> get bootSeqnum async {
    await zoneGroupState.poll(this);
    return _bootSeqnum!;
  }

  /// The speaker's name.
  Future<String> get playerName async {
    await zoneGroupState.poll(this);
    // Check speakerInfo first (populated by ZGS), then fall back to _playerName
    if (speakerInfo.containsKey('_playerName')) {
      return speakerInfo['_playerName'] as String;
    }
    return _playerName!;
  }

  /// Set the speaker's name.
  Future<void> setPlayerName(String name) async {
    await deviceProperties.sendCommand(
      'SetZoneAttributes',
      args: [
        MapEntry('DesiredZoneName', name),
        MapEntry('DesiredIcon', ''),
        MapEntry('DesiredConfiguration', ''),
      ],
    );
  }

  /// A unique identifier.
  ///
  /// Looks like: `'RINCON_000XXXXXXXXXX1400'`
  Future<String> get uid async {
    if (_uid != null) {
      return _uid!;
    }
    await zoneGroupState.poll(this);
    return _uid!;
  }

  /// A unique identifier for all players in a household.
  ///
  /// Looks like: `'Sonos_asahHKgjgJGjgjGjggjJgjJG34'`
  Future<String> get householdId async {
    if (_householdId == null) {
      final result = await deviceProperties.sendCommand('GetHouseholdID');
      _householdId = result['CurrentHouseholdID'];
    }
    return _householdId!;
  }

  /// Is this zone visible?
  ///
  /// A zone might be invisible if, for example, it is a bridge, or the slave
  /// part of stereo pair.
  Future<bool> get isVisible async {
    final zones = await visibleZones;
    return zones.contains(this);
  }

  /// Is this zone a bridge?
  Future<bool> get isBridge async {
    if (_isBridge != null) {
      return _isBridge!;
    }
    await zoneGroupState.poll(this);
    return _isBridge!;
  }

  /// Is this zone a group coordinator?
  Future<bool> get isCoordinator async {
    await zoneGroupState.poll(this);
    return speakerInfo['_isCoordinator'] as bool? ?? false;
  }

  /// Is this zone a satellite in a home theater setup?
  Future<bool> get isSatellite async {
    await zoneGroupState.poll(this);
    return speakerInfo['_isSatellite'] as bool? ?? false;
  }

  /// The parent device if this zone is a satellite, null otherwise.
  SoCo? get satelliteParent {
    return speakerInfo['_satelliteParent'] as SoCo?;
  }

  /// Is this zone configured with satellites in a home theater setup?
  ///
  /// Will only return true on the primary device in a home theater configuration.
  Future<bool> get hasSatellites async {
    await zoneGroupState.poll(this);
    return speakerInfo['_hasSatellites'] as bool? ?? false;
  }

  /// Is this zone a subwoofer?
  Future<bool> get isSubwoofer async {
    final ch = await channel;
    return ch == 'SW';
  }

  /// Is this zone configured with a subwoofer?
  ///
  /// Only provides reliable results when called on the soundbar
  /// or subwoofer devices if configured in a home theater setup.
  ///
  /// Sonos Amp devices support a directly-connected 3rd party subwoofer
  /// connected over RCA. This property is always enabled for those devices.
  Future<bool> get hasSubwoofer async {
    if (speakerInfo.isEmpty) {
      await getSpeakerInfo();
    }

    final modelName = (speakerInfo['model_name'] as String?)?.toLowerCase();
    if (modelName?.endsWith('sonos amp') ?? false) {
      return true;
    }

    await zoneGroupState.poll(this);
    final channelMap = _channelMap ?? _htSatChanMap;
    if (channelMap == null) {
      return false;
    }

    return channelMap.contains(':SW');
  }

  /// Location of this zone in a home theater or paired configuration.
  ///
  /// Can be one of "LF,RF", "LF", "RF", "LR", "RR", "SW", or null.
  Future<String?> get channel async {
    await zoneGroupState.poll(this);
    // Omit repeated channel entries (e.g., "RF,RF" -> "RF")
    if (_channel != null) {
      final channels = _channel!.split(',').toSet();
      if (channels.length == 1) {
        return channels.first;
      }
    }
    return _channel;
  }

  /// Is this zone a soundbar (i.e. has night mode etc.)?
  Future<bool> get isSoundbar async {
    if (_isSoundbar == null) {
      if (speakerInfo.isEmpty) {
        await getSpeakerInfo();
      }

      final modelName = (speakerInfo['model_name'] as String?)?.toLowerCase();
      _isSoundbar = soundbars.any((s) => modelName?.endsWith(s) ?? false);
    }

    return _isSoundbar!;
  }

  /// Is this zone an Arc Ultra soundbar?
  Future<bool> get isArcUltraSoundbar async {
    if (speakerInfo.isEmpty) {
      await getSpeakerInfo();
    }

    final modelName = (speakerInfo['model_name'] as String?)?.toLowerCase();
    return modelName?.endsWith(arcUltraProductName) ?? false;
  }

  /// Get information about the Sonos speaker.
  ///
  /// Parameters:
  ///   - [refresh]: Refresh the speaker info cache.
  ///   - [timeout]: How long to wait for the server to send data before
  ///     giving up.
  ///
  /// Returns:
  ///   Information about the Sonos speaker, such as the UID, MAC Address,
  ///   and Zone Name.
  Future<Map<String, dynamic>> getSpeakerInfo({
    bool refresh = false,
    Duration? timeout,
  }) async {
    if (speakerInfo.isNotEmpty && !refresh) {
      return speakerInfo;
    }

    final url = 'http://$ipAddress:1400/xml/device_description.xml';
    final response = await http
        .get(
          Uri.parse(url),
          // Dart http package uses Duration instead of timeout tuple
        )
        .timeout(timeout ?? const Duration(seconds: 30));

    final document = XmlDocument.parse(response.body);
    final device = document.findAllElements('device').firstOrNull;

    if (device != null) {
      speakerInfo['zone_name'] = device
          .findElements('roomName')
          .firstOrNull
          ?.innerText;
      speakerInfo['player_icon'] = device
          .findElements('iconList')
          .firstOrNull
          ?.findElements('icon')
          .firstOrNull
          ?.findElements('url')
          .firstOrNull
          ?.innerText;

      speakerInfo['uid'] = await uid;
      speakerInfo['serial_number'] = device
          .findElements('serialNum')
          .firstOrNull
          ?.innerText;
      speakerInfo['software_version'] = device
          .findElements('softwareVersion')
          .firstOrNull
          ?.innerText;
      speakerInfo['hardware_version'] = device
          .findElements('hardwareVersion')
          .firstOrNull
          ?.innerText;
      speakerInfo['model_number'] = device
          .findElements('modelNumber')
          .firstOrNull
          ?.innerText;
      speakerInfo['model_name'] = device
          .findElements('modelName')
          .firstOrNull
          ?.innerText;
      speakerInfo['display_version'] = device
          .findElements('displayVersion')
          .firstOrNull
          ?.innerText;

      // Extract MAC address from serial number
      final serialNumber = speakerInfo['serial_number'] as String?;
      if (serialNumber != null) {
        final mac = serialNumber.split(':')[0];
        speakerInfo['mac_address'] = mac;
      }

      return speakerInfo;
    }

    return {};
  }

  ///////////////////////////////////////////////////////////////////////////
  // PLAYBACK CONTROL METHODS
  ///////////////////////////////////////////////////////////////////////////

  /// Play a track from the queue by index.
  ///
  /// The index number is required as an argument, where the first index is 0.
  ///
  /// Parameters:
  ///   - [index]: 0-based index of the track to play
  ///   - [start]: If the item that has been set should start playing
  Future<void> playFromQueue(int index, {bool start = true}) async {
    // Grab the speaker's information if we haven't already
    if (speakerInfo.isEmpty) {
      await getSpeakerInfo();
    }

    // First, set the queue itself as the source URI
    final uri = 'x-rincon-queue:${await uid}#0';
    await avTransport.sendCommand(
      'SetAVTransportURI',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('CurrentURI', uri),
        MapEntry('CurrentURIMetaData', ''),
      ],
    );

    // Second, set the track number with a seek command
    await avTransport.sendCommand(
      'Seek',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('Unit', 'TRACK_NR'),
        MapEntry('Target', index + 1),
      ],
    );

    // Finally, just play what's set if needed
    if (start) {
      await play();
    }
  }

  /// Play the currently selected track.
  ///
  /// Parameters:
  ///   - [timeout]: Optional timeout for the request
  Future<void> play({Duration? timeout}) async {
    await avTransport.sendCommand(
      'Play',
      args: [MapEntry('InstanceID', 0), MapEntry('Speed', 1)],
    );
  }

  /// Play a URI.
  ///
  /// Playing a URI will replace what was playing with the stream given by the
  /// URI. For some streams at least a title is required as metadata. This can
  /// be provided using the [meta] argument or the [title] argument. If the
  /// [title] argument is provided minimal metadata will be generated. If [meta]
  /// argument is provided the [title] argument is ignored.
  ///
  /// Parameters:
  ///   - [uri]: URI of the stream to be played
  ///   - [meta]: The metadata to show in the player, DIDL format
  ///   - [title]: The title to show in the player (if no meta)
  ///   - [start]: If the URI that has been set should start playing
  ///   - [forceRadio]: Forces a URI to play as a radio stream
  ///
  /// On a Sonos controller music is shown with one of the following display
  /// formats and controls:
  ///
  /// * Radio format: Shows the name of the radio station and other available
  ///   data. No seek, next, previous, or voting capability.
  ///   Examples: TuneIn, radioPup
  /// * Smart Radio: Shows track name, artist, and album. Limited seek, next
  ///   and sometimes voting capability depending on the Music Service.
  ///   Examples: Amazon Prime Stations, Pandora Radio Stations.
  /// * Track format: Shows track name, artist, and album the same as when
  ///   playing from a queue. Full seek, next and previous capabilities.
  ///   Examples: Spotify, Napster, Rhapsody.
  ///
  /// How it is displayed is determined by the URI prefix:
  /// `x-sonosapi-stream:`, `x-sonosapi-radio:`, `x-rincon-mp3radio:`,
  /// `hls-radio:` default to radio or smart radio format depending on the
  /// stream. Others default to track format: `x-file-cifs:`, `aac:`, `http:`,
  /// `https:`, `x-sonos-spotify:` (used by Spotify), `x-sonosapi-hls-static:`
  /// (Amazon Prime), `x-sonos-http:` (Google Play & Napster).
  ///
  /// Some URIs that default to track format could be radio streams, typically
  /// `http:`, `https:` or `aac:`. To force display and controls to Radio
  /// format set [forceRadio] to true.
  Future<bool> playUri({
    String uri = '',
    String meta = '',
    String title = '',
    bool start = true,
    bool forceRadio = false,
  }) async {
    var finalMeta = meta;
    var finalUri = uri;

    if (meta.isEmpty && title.isNotEmpty) {
      const metaTemplate =
          '<DIDL-Lite xmlns:dc="http://purl.org/dc/elements'
          '/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" '
          'xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" '
          'xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">'
          '<item id="R:0/0/0" parentID="R:0/0" restricted="true">'
          '<dc:title>{title}</dc:title><upnp:class>'
          'object.item.audioItem.audioBroadcast</upnp:class><desc '
          'id="cdudn" nameSpace="urn:schemas-rinconnetworks-com:'
          'metadata-1-0/">{service}</desc></item></DIDL-Lite>';
      const tuneinService = 'SA_RINCON65031_';

      // Radio stations need to have at least a title to play
      final escapedTitle = _xmlEscape(title);
      finalMeta = metaTemplate
          .replaceAll('{title}', escapedTitle)
          .replaceAll('{service}', tuneinService);
    }

    // Change URI prefix to force radio style display and commands
    if (forceRadio) {
      final colonIndex = uri.indexOf(':');
      if (colonIndex > 0) {
        finalUri = 'x-rincon-mp3radio${uri.substring(colonIndex)}';
      }
    }

    await avTransport.sendCommand(
      'SetAVTransportURI',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('CurrentURI', finalUri),
        MapEntry('CurrentURIMetaData', finalMeta),
      ],
    );

    // The track is enqueued, now play it if needed
    if (start) {
      await play();
      return true;
    }
    return false;
  }

  /// Pause the currently playing track.
  Future<void> pause() async {
    await avTransport.sendCommand(
      'Pause',
      args: [MapEntry('InstanceID', 0), MapEntry('Speed', 1)],
    );
  }

  /// Stop the currently playing track.
  Future<void> stop() async {
    await avTransport.sendCommand(
      'Stop',
      args: [MapEntry('InstanceID', 0), MapEntry('Speed', 1)],
    );
  }

  /// Ends all third-party controlled streaming sessions.
  Future<void> endDirectControlSession() async {
    await avTransport.sendCommand(
      'EndDirectControlSession',
      args: [MapEntry('InstanceID', 0)],
    );
  }

  /// Seek to a given position.
  ///
  /// You can seek both a relative position in the current track and a track
  /// number in the queue.
  ///
  /// Parameters:
  ///   - [position]: The desired timestamp in the current track, specified in
  ///     the format of HH:MM:SS or H:MM:SS
  ///   - [track]: The (zero-based) track index in the queue
  ///
  /// Throws:
  ///   - [ArgumentError]: If neither position nor track are specified.
  ///   - [SoCoUPnPException]: UPnP Error 701 if seeking is not supported,
  ///     UPnP Error 711 if the target is invalid.
  ///
  /// Note:
  ///   The [track] parameter can only be used if the queue is currently
  ///   playing. If not, use [playFromQueue].
  ///
  ///   This is currently faster than [playFromQueue] if already using the
  ///   queue, as it does not reinstate the queue.
  ///
  ///   If speaker is already playing it will continue to play after seek.
  ///   If paused it will remain paused.
  Future<void> seek({String? position, int? track}) async {
    if (track == null && position == null) {
      throw ArgumentError('No position or track information given');
    }

    if (track != null) {
      await avTransport.sendCommand(
        'Seek',
        args: [
          MapEntry('InstanceID', 0),
          MapEntry('Unit', 'TRACK_NR'),
          MapEntry('Target', track + 1),
        ],
      );
    }

    if (position != null) {
      if (!RegExp(r'^[0-9][0-9]?:[0-9][0-9]:[0-9][0-9]$').hasMatch(position)) {
        throw ArgumentError('invalid timestamp, use HH:MM:SS format');
      }

      await avTransport.sendCommand(
        'Seek',
        args: [
          MapEntry('InstanceID', 0),
          MapEntry('Unit', 'REL_TIME'),
          MapEntry('Target', position),
        ],
      );
    }
  }

  /// Go to the next track.
  ///
  /// Keep in mind that next() can return errors for a variety of reasons.
  /// For example, if the Sonos is streaming Pandora and you call next()
  /// several times in quick succession an error code will likely be returned
  /// (since Pandora has limits on how many songs can be skipped).
  Future<void> next() async {
    await avTransport.sendCommand(
      'Next',
      args: [MapEntry('InstanceID', 0), MapEntry('Speed', 1)],
    );
  }

  /// Go back to the previously played track.
  ///
  /// Keep in mind that previous() can return errors for a variety of reasons.
  /// For example, previous() will return an error code (error code 701) if
  /// the Sonos is streaming Pandora since you can't go back on tracks.
  Future<void> previous() async {
    await avTransport.sendCommand(
      'Previous',
      args: [MapEntry('InstanceID', 0), MapEntry('Speed', 1)],
    );
  }

  ///////////////////////////////////////////////////////////////////////////
  // VOLUME AND AUDIO CONTROL METHODS
  ///////////////////////////////////////////////////////////////////////////

  /// The speaker's mute state.
  ///
  /// Returns true if muted, false otherwise.
  Future<bool> get mute async {
    final response = await renderingControl.sendCommand(
      'GetMute',
      args: [MapEntry('InstanceID', 0), MapEntry('Channel', 'Master')],
    );
    final muteState = response['CurrentMute'];
    return muteState == '1';
  }

  /// Mute (or unmute) the speaker.
  Future<void> setMute(bool mute) async {
    final muteValue = mute ? '1' : '0';
    await renderingControl.sendCommand(
      'SetMute',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('Channel', 'Master'),
        MapEntry('DesiredMute', muteValue),
      ],
    );
  }

  /// The speaker's volume.
  ///
  /// Returns an integer between 0 and 100.
  Future<int> get volume async {
    final response = await renderingControl.sendCommand(
      'GetVolume',
      args: [MapEntry('InstanceID', 0), MapEntry('Channel', 'Master')],
    );
    final volumeStr = response['CurrentVolume'];
    return int.parse(volumeStr ?? '0');
  }

  /// Set the speaker's volume.
  ///
  /// Volume is coerced to be between 0 and 100.
  Future<void> setVolume(int volume) async {
    final clampedVolume = volume.clamp(0, 100);
    await renderingControl.sendCommand(
      'SetVolume',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('Channel', 'Master'),
        MapEntry('DesiredVolume', clampedVolume),
      ],
    );
  }

  /// The speaker's bass EQ.
  ///
  /// Returns an integer between -10 and 10.
  Future<int> get bass async {
    final response = await renderingControl.sendCommand(
      'GetBass',
      args: [MapEntry('InstanceID', 0)],
    );
    final bassStr = response['CurrentBass'];
    return int.parse(bassStr ?? '0');
  }

  /// Set the speaker's bass EQ.
  ///
  /// Bass is coerced to be between -10 and 10.
  Future<void> setBass(int bass) async {
    final clampedBass = bass.clamp(-10, 10);
    await renderingControl.sendCommand(
      'SetBass',
      args: [MapEntry('InstanceID', 0), MapEntry('DesiredBass', clampedBass)],
    );
  }

  /// The speaker's treble EQ.
  ///
  /// Returns an integer between -10 and 10.
  Future<int> get treble async {
    final response = await renderingControl.sendCommand(
      'GetTreble',
      args: [MapEntry('InstanceID', 0)],
    );
    final trebleStr = response['CurrentTreble'];
    return int.parse(trebleStr ?? '0');
  }

  /// Set the speaker's treble EQ.
  ///
  /// Treble is coerced to be between -10 and 10.
  Future<void> setTreble(int treble) async {
    final clampedTreble = treble.clamp(-10, 10);
    await renderingControl.sendCommand(
      'SetTreble',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('DesiredTreble', clampedTreble),
      ],
    );
  }

  /// Smoothly change the volume.
  ///
  /// There are three ramp types available:
  ///
  /// * `'SLEEP_TIMER_RAMP_TYPE'` (default): Linear ramp from the current
  ///   volume up or down to the new volume. The ramp rate is 1.25 steps per
  ///   second. For example: To change from volume 50 to volume 30 would take
  ///   16 seconds.
  /// * `'ALARM_RAMP_TYPE'`: Resets the volume to zero, waits for about 30
  ///   seconds, and then ramps the volume up to the desired value at a rate
  ///   of 2.5 steps per second. For example: Volume 30 would take 12 seconds
  ///   for the ramp up (not considering the wait time).
  /// * `'AUTOPLAY_RAMP_TYPE'`: Resets the volume to zero and then quickly
  ///   ramps up at a rate of 50 steps per second. For example: Volume 30 will
  ///   take only 0.6 seconds.
  ///
  /// The ramp rate is selected by Sonos based on the chosen ramp type and
  /// the resulting transition time returned. This method is non blocking and
  /// has no network overhead once sent.
  ///
  /// Parameters:
  ///   - [volume]: The new volume
  ///   - [rampType]: The desired ramp type, as described above
  ///
  /// Returns:
  ///   The ramp time in seconds, rounded down. Note that this does not
  ///   include the wait time.
  Future<int> rampToVolume(
    int volume, {
    String rampType = 'SLEEP_TIMER_RAMP_TYPE',
  }) async {
    final response = await renderingControl.sendCommand(
      'RampToVolume',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('Channel', 'Master'),
        MapEntry('RampType', rampType),
        MapEntry('DesiredVolume', volume),
        MapEntry('ResetVolumeAfter', false),
        MapEntry('ProgramURI', ''),
      ],
    );
    return int.parse(response['RampTime'] ?? '0');
  }

  /// Adjust the volume up or down by a relative amount.
  ///
  /// If the adjustment causes the volume to overshoot the maximum value of
  /// 100, the volume will be set to 100. If the adjustment causes the volume
  /// to undershoot the minimum value of 0, the volume will be set to 0.
  ///
  /// Note that this method is an alternative to using addition and subtraction
  /// assignment operators (+=, -=) on the volume property. These operators
  /// perform the same function but require two network calls per operation
  /// instead of one.
  ///
  /// Parameters:
  ///   - [relativeVolume]: The relative volume adjustment. Can be positive or
  ///     negative.
  ///
  /// Returns:
  ///   The new volume setting.
  Future<int> setRelativeVolume(int relativeVolume) async {
    // Sonos will automatically handle out-of-range adjustments
    final response = await renderingControl.sendCommand(
      'SetRelativeVolume',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('Channel', 'Master'),
        MapEntry('Adjustment', relativeVolume),
      ],
    );
    return int.parse(response['NewVolume'] ?? '0');
  }

  /// Simple XML escape helper
  String _xmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Convert camelCase to snake_case
  String _camelToUnderscore(String text) {
    return text
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .replaceFirst(RegExp(r'^_'), '');
  }

  ///////////////////////////////////////////////////////////////////////////
  // PLAY MODE AND TRANSPORT INFO METHODS
  ///////////////////////////////////////////////////////////////////////////

  /// The queue's play mode.
  ///
  /// Case-insensitive options are:
  ///
  /// * `'NORMAL'` -- Turns off shuffle and repeat.
  /// * `'REPEAT_ALL'` -- Turns on repeat and turns off shuffle.
  /// * `'SHUFFLE'` -- Turns on shuffle *and* repeat.
  /// * `'SHUFFLE_NOREPEAT'` -- Turns on shuffle and turns off repeat.
  /// * `'REPEAT_ONE'` -- Turns on repeat one and turns off shuffle.
  /// * `'SHUFFLE_REPEAT_ONE'` -- Turns on shuffle *and* repeat one.
  Future<String> get playMode async {
    final result = await avTransport.sendCommand(
      'GetTransportSettings',
      args: [MapEntry('InstanceID', 0)],
    );
    return result['PlayMode'] ?? 'NORMAL';
  }

  /// Set the speaker's play mode.
  Future<void> setPlayMode(String playMode) async {
    final upperMode = playMode.toUpperCase();
    if (!playModes.containsKey(upperMode)) {
      throw ArgumentError("'$playMode' is not a valid play mode");
    }

    await avTransport.sendCommand(
      'SetPlayMode',
      args: [MapEntry('InstanceID', 0), MapEntry('NewPlayMode', upperMode)],
    );
  }

  /// The queue's shuffle option.
  ///
  /// Returns true if enabled, false otherwise.
  Future<bool> get shuffle async {
    final mode = await playMode;
    final meaning = playModes[mode];
    return meaning?.$1 ?? false;
  }

  /// Set the queue's shuffle option.
  Future<void> setShuffle(bool shuffle) async {
    final repeat = await this.repeat;
    final newMode = playModeByMeaning[(shuffle, repeat)];
    if (newMode != null) {
      await setPlayMode(newMode);
    }
  }

  /// The queue's repeat option.
  ///
  /// Returns true if enabled, false otherwise.
  /// Can also be the string 'ONE' for play mode 'REPEAT_ONE'.
  Future<dynamic> get repeat async {
    final mode = await playMode;
    final meaning = playModes[mode];
    return meaning?.$2 ?? false;
  }

  /// Set the queue's repeat option.
  Future<void> setRepeat(dynamic repeat) async {
    final shuffle = await this.shuffle;
    final newMode = playModeByMeaning[(shuffle, repeat)];
    if (newMode != null) {
      await setPlayMode(newMode);
    }
  }

  /// The speaker's cross fade state.
  ///
  /// Returns true if enabled, false otherwise.
  Future<bool> get crossFade async {
    final response = await avTransport.sendCommand(
      'GetCrossfadeMode',
      args: [MapEntry('InstanceID', 0)],
    );
    final crossFadeState = response['CrossfadeMode'];
    return crossFadeState == '1';
  }

  /// Set the speaker's cross fade state.
  Future<void> setCrossFade(bool crossFade) async {
    final crossFadeValue = crossFade ? '1' : '0';
    await avTransport.sendCommand(
      'SetCrossfadeMode',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('CrossfadeMode', crossFadeValue),
      ],
    );
  }

  /// Get information about the currently playing track.
  ///
  /// Returns a dictionary containing information about the currently playing
  /// track: playlist_position, duration, title, artist, album, position
  /// and album_art.
  ///
  /// If we're unable to return data for a field, we'll return an empty
  /// string. This can happen for all kinds of reasons so be sure to check
  /// values. For example, a track may not have complete metadata and be
  /// missing an album name. In this case track['album'] will be an empty
  /// string.
  Future<Map<String, dynamic>> getCurrentTrackInfo() async {
    final response = await avTransport.sendCommand(
      'GetPositionInfo',
      args: [MapEntry('InstanceID', 0)],
    );

    final track = <String, dynamic>{
      'title': '',
      'artist': '',
      'album': '',
      'album_art': '',
      'position': '',
    };

    track['playlist_position'] = response['Track'] ?? '0';
    track['duration'] = response['TrackDuration'] ?? '0:00:00';
    track['uri'] = response['TrackURI'] ?? '';
    track['position'] = response['RelTime'] ?? '0:00:00';

    final metadata = response['TrackMetaData'];

    // Duration seems to be '0:00:00' when listening to radio
    if (track['duration'] == '0:00:00' &&
        metadata != null &&
        metadata.isNotEmpty) {
      // TODO: Parse radio metadata
      // This would require XML parsing of the metadata
    }

    if (metadata != null &&
        metadata.isNotEmpty &&
        metadata != 'NOT_IMPLEMENTED') {
      // TODO: Parse DIDL metadata to extract title, artist, album, album_art
      // This requires XML parsing which we'll implement when needed
    }

    return track;
  }

  /// Get information about the currently playing media.
  ///
  /// Returns a dictionary containing information about the currently
  /// playing media: uri, channel.
  ///
  /// If we're unable to return data for a field, we'll return an empty
  /// string.
  Future<Map<String, String>> getCurrentMediaInfo() async {
    final response = await avTransport.sendCommand(
      'GetMediaInfo',
      args: [MapEntry('InstanceID', 0)],
    );

    final media = <String, String>{'uri': '', 'channel': ''};

    media['uri'] = response['CurrentURI'] ?? '';

    final metadata = response['CurrentURIMetaData'];
    if (metadata != null && metadata.isNotEmpty) {
      // TODO: Parse metadata to extract channel title
      // This requires XML parsing
    }

    return media;
  }

  /// Get the current playback state.
  ///
  /// Returns information about the speaker's playing state:
  ///
  /// * current_transport_state (`PLAYING`, `TRANSITIONING`,
  ///   `PAUSED_PLAYBACK`, `STOPPED`)
  /// * current_transport_status (OK, ?)
  /// * current_speed (1, ?)
  ///
  /// This allows us to know if speaker is playing or not.
  Future<Map<String, String>> getCurrentTransportInfo() async {
    final response = await avTransport.sendCommand(
      'GetTransportInfo',
      args: [MapEntry('InstanceID', 0)],
    );

    return {
      'current_transport_state': response['CurrentTransportState'] ?? '',
      'current_transport_status': response['CurrentTransportStatus'] ?? '',
      'current_transport_speed': response['CurrentSpeed'] ?? '',
    };
  }

  /// The transport actions that are currently available on the speaker.
  ///
  /// Returns a list of strings representing the available actions, such as
  /// ['Set', 'Stop', 'Play'].
  ///
  /// Possible list items are: 'Set', 'Stop', 'Pause', 'Play', 'Next',
  /// 'Previous', 'SeekTime', 'SeekTrackNr'.
  Future<List<String>> get availableActions async {
    final result = await avTransport.sendCommand(
      'GetCurrentTransportActions',
      args: [MapEntry('InstanceID', 0)],
    );
    final actions = result['Actions'] ?? '';

    // The actions might look like 'X_DLNA_SeekTime', but we only want the
    // last part
    return actions.split(', ').map((action) => action.split('_').last).toList();
  }

  ///////////////////////////////////////////////////////////////////////////
  // MUSIC SOURCE DETECTION METHODS
  ///////////////////////////////////////////////////////////////////////////

  /// Determine a music source from a URI.
  ///
  /// Parameters:
  ///   - [uri]: The URI representing the music source
  ///
  /// Returns:
  ///   The current source of music.
  ///
  /// Possible return values are:
  ///
  /// * `'NONE'` -- speaker has no music to play.
  /// * `'LIBRARY'` -- speaker is playing queued titles from the music library.
  /// * `'RADIO'` -- speaker is playing radio.
  /// * `'WEB_FILE'` -- speaker is playing a music file via http/https.
  /// * `'LINE_IN'` -- speaker is playing music from line-in.
  /// * `'TV'` -- speaker is playing input from TV.
  /// * `'AIRPLAY'` -- speaker is playing from AirPlay.
  /// * `'SPOTIFY_CONNECT'` -- speaker is playing from Spotify Connect.
  /// * `'UNKNOWN'` -- any other input.
  static String musicSourceFromUri(String uri) {
    for (final entry in sources.entries) {
      if (RegExp(entry.key).hasMatch(uri)) {
        return entry.value;
      }
    }
    return musicSrcUnknown;
  }

  /// The current music source (radio, TV, line-in, etc.).
  ///
  /// Possible return values are the same as used in [musicSourceFromUri].
  Future<String> get musicSource async {
    final response = await avTransport.sendCommand(
      'GetPositionInfo',
      args: [MapEntry('InstanceID', 0)],
    );
    return musicSourceFromUri(response['TrackURI'] ?? '');
  }

  /// Is the speaker playing radio?
  Future<bool> get isPlayingRadio async {
    final source = await musicSource;
    return source == musicSrcRadio;
  }

  /// Is the speaker playing from line-in?
  Future<bool> get isPlayingLineIn async {
    final source = await musicSource;
    return source == musicSrcLineIn;
  }

  /// Is the speaker playing from TV?
  Future<bool> get isPlayingTv async {
    final source = await musicSource;
    return source == musicSrcTv;
  }

  /// Switch the playbar speaker's input to TV.
  Future<void> switchToTv() async {
    final speakerUid = await uid;
    await avTransport.sendCommand(
      'SetAVTransportURI',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('CurrentURI', 'x-sonos-htastream:$speakerUid:spdif'),
        MapEntry('CurrentURIMetaData', ''),
      ],
    );
  }

  /// Switch to line-in input.
  Future<void> switchToLineIn() async {
    final speakerUid = await uid;
    await avTransport.sendCommand(
      'SetAVTransportURI',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('CurrentURI', 'x-rincon-stream:$speakerUid'),
        MapEntry('CurrentURIMetaData', ''),
      ],
    );
  }

  ///////////////////////////////////////////////////////////////////////////
  // SLEEP TIMER AND BATTERY METHODS
  ///////////////////////////////////////////////////////////////////////////

  /// Sets the sleep timer.
  ///
  /// Parameters:
  ///   - [sleepTimeSeconds]: How long to wait before turning off speaker in
  ///     seconds, null to cancel a sleep timer. Maximum value of 86399.
  ///
  /// Throws:
  ///   - [SoCoException]: Upon errors interacting with Sonos controller
  ///   - [ArgumentError]: Invalid argument/syntax errors
  ///
  /// Note: A value of null for sleepTimeSeconds is valid, and needs to be
  /// preserved distinctly separate from 0. 0 means go to sleep now, which
  /// will immediately start the sound tapering, while null means cancel the
  /// current timer.
  Future<void> setSleepTimer(int? sleepTimeSeconds) async {
    try {
      String sleepTime;
      if (sleepTimeSeconds == null) {
        sleepTime = '';
      } else {
        if (sleepTimeSeconds < 0 || sleepTimeSeconds > 86399) {
          throw ArgumentError(
            'invalid sleep_time_seconds, must be integer value between 0 and 86399 inclusive or null',
          );
        }
        // Format as HH:MM:SS
        final duration = Duration(seconds: sleepTimeSeconds);
        final hours = duration.inHours;
        final minutes = duration.inMinutes.remainder(60);
        final seconds = duration.inSeconds.remainder(60);
        sleepTime =
            '${hours.toString().padLeft(2, '0')}:'
            '${minutes.toString().padLeft(2, '0')}:'
            '${seconds.toString().padLeft(2, '0')}';
      }

      await avTransport.sendCommand(
        'ConfigureSleepTimer',
        args: [
          MapEntry('InstanceID', 0),
          MapEntry('NewSleepTimerDuration', sleepTime),
        ],
      );
    } on SoCoUPnPException catch (err) {
      if (err.toString().contains('Error 402 received')) {
        throw ArgumentError(
          'invalid sleep_time_seconds, must be integer value between 0 and 86399 inclusive or null',
        );
      }
      rethrow;
    }
  }

  /// Retrieves remaining sleep time, if any.
  ///
  /// Returns:
  ///   Number of seconds left in timer. If there is no sleep timer currently
  ///   set it will return null.
  Future<int?> getSleepTimer() async {
    final resp = await avTransport.sendCommand(
      'GetRemainingSleepTimerDuration',
      args: [MapEntry('InstanceID', 0)],
    );

    final remaining = resp['RemainingSleepTimerDuration'];
    if (remaining != null && remaining.isNotEmpty) {
      final parts = remaining.split(':');
      return int.parse(parts[0]) * 3600 +
          int.parse(parts[1]) * 60 +
          int.parse(parts[2]);
    }
    return null;
  }

  /// Get battery information for a Sonos speaker.
  ///
  /// Obtains battery information for Sonos speakers that report it. This only
  /// applies to Sonos Move speakers at the time of writing.
  ///
  /// This method may only work on Sonos 'S2' systems.
  ///
  /// Parameters:
  ///   - [timeout]: The timeout to use when making the HTTP request.
  ///
  /// Returns:
  ///   A map containing battery status data.
  ///
  ///   Example return value:
  ///   ```
  ///   {
  ///     'Health': 'GREEN',
  ///     'Level': 100,
  ///     'Temperature': 'NORMAL',
  ///     'PowerSource': 'SONOS_CHARGING_RING'
  ///   }
  ///   ```
  ///
  /// Throws:
  ///   - [NotSupportedException]: If the speaker does not report battery
  ///     information.
  ///   - [Exception]: If the HTTP connection failed, or returned an
  ///     unsuccessful status code or timed out.
  Future<Map<String, dynamic>> getBatteryInfo({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final url = 'http://$ipAddress:1400/status/batterystatus';
      final response = await http.get(Uri.parse(url)).timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'HTTP request failed with status ${response.statusCode}',
        );
      }

      // Parse XML response
      final document = XmlDocument.parse(response.body);
      final batteryInfo = <String, dynamic>{};

      // Navigate to battery status data
      final zpInfo = document.findAllElements('ZPSupportInfo').firstOrNull;
      if (zpInfo == null) {
        throw NotSupportedException('Battery information not supported');
      }

      final localBatteryStatus = zpInfo
          .findElements('LocalBatteryStatus')
          .firstOrNull;
      if (localBatteryStatus == null) {
        throw NotSupportedException('Battery information not supported');
      }

      for (final dataElement in localBatteryStatus.findElements('Data')) {
        final name = dataElement.getAttribute('name');
        final text = dataElement.innerText;
        if (name != null) {
          batteryInfo[name] = text;
        }
      }

      // Convert Level to int if present
      if (batteryInfo.containsKey('Level')) {
        try {
          batteryInfo['Level'] = int.parse(batteryInfo['Level']);
        } catch (_) {
          // Leave as string if conversion fails
        }
      }

      return batteryInfo;
    } on TimeoutException {
      throw TimeoutException('Battery info request timed out');
    } catch (e) {
      if (e is NotSupportedException) {
        rethrow;
      }
      throw NotSupportedException('Battery information not supported: $e');
    }
  }

  ///////////////////////////////////////////////////////////////////////////
  // QUEUE MANAGEMENT METHODS
  ///////////////////////////////////////////////////////////////////////////

  /// Get information about the queue.
  ///
  /// Parameters:
  ///   - [start]: Starting number of returned matches
  ///   - [maxItems]: Maximum number of returned matches
  ///   - [fullAlbumArtUri]: If the album art URI should include the IP address
  ///
  /// Returns:
  ///   A Queue object containing queue items and metadata
  ///
  /// Note: This method is heavily based on Sam Soffes' (aka soffes) ruby
  /// implementation.
  Future<dynamic> getQueue({
    int start = 0,
    int maxItems = 100,
    bool fullAlbumArtUri = false,
  }) async {
    final response = await contentDirectory.sendCommand(
      'Browse',
      args: [
        MapEntry('ObjectID', 'Q:0'),
        MapEntry('BrowseFlag', 'BrowseDirectChildren'),
        MapEntry('Filter', '*'),
        MapEntry('StartingIndex', start),
        MapEntry('RequestedCount', maxItems),
        MapEntry('SortCriteria', ''),
      ],
    );

    // final result = response['Result']; // TODO: Parse this when implementing Queue
    final metadata = <String, int>{};

    // Convert metadata to underscore notation
    for (final tag in ['NumberReturned', 'TotalMatches', 'UpdateID']) {
      if (response.containsKey(tag)) {
        final key = _camelToUnderscore(tag);
        metadata[key] = int.parse(response[tag] ?? '0');
      }
    }

    // TODO: Parse DIDL string and create Queue object
    // For now, return a map with metadata
    // This requires implementing fromDidlString and Queue class properly
    return {
      'items': [], // Will be populated when fromDidlString is implemented
      'metadata': metadata,
    };
  }

  /// Size of the queue.
  Future<int> get queueSize async {
    final response = await contentDirectory.sendCommand(
      'Browse',
      args: [
        MapEntry('ObjectID', 'Q:0'),
        MapEntry('BrowseFlag', 'BrowseMetadata'),
        MapEntry('Filter', '*'),
        MapEntry('StartingIndex', 0),
        MapEntry('RequestedCount', 1),
        MapEntry('SortCriteria', ''),
      ],
    );

    final resultXml = response['Result'];
    if (resultXml == null || resultXml.isEmpty) {
      return 0;
    }

    try {
      final document = XmlDocument.parse(resultXml);
      final container = document.findAllElements('container').firstOrNull;
      if (container != null) {
        final childCount = container.getAttribute('childCount');
        if (childCount != null) {
          return int.parse(childCount);
        }
      }
    } catch (e) {
      _log.warning('Failed to parse queue size: $e');
    }

    return 0;
  }

  /// Add a URI to the queue.
  ///
  /// Parameters:
  ///   - [uri]: URI of the item to add
  ///   - [position]: The index (1-based) at which the URI should be added.
  ///     Default is 0 (add at the end of the queue).
  ///   - [asNext]: Whether this URI should be played as the next track in
  ///     shuffle mode. This only works if play_mode=SHUFFLE.
  ///
  /// Returns:
  ///   The index of the new item in the queue.
  Future<int> addUriToQueue(
    String uri, {
    int position = 0,
    bool asNext = false,
  }) async {
    // Create a minimal DIDL resource
    // TODO: Use proper DidlResource and DidlObject when fully implemented
    final metadata =
        '<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" '
        'xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" '
        'xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">'
        '<item id="-1" parentID="-1" restricted="true">'
        '<res protocolInfo="x-rincon-playlist:*:*:*">$uri</res>'
        '<upnp:class>object.item</upnp:class>'
        '<dc:title></dc:title>'
        '</item></DIDL-Lite>';

    final response = await avTransport.sendCommand(
      'AddURIToQueue',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('EnqueuedURI', uri),
        MapEntry('EnqueuedURIMetaData', metadata),
        MapEntry('DesiredFirstTrackNumberEnqueued', position),
        MapEntry('EnqueueAsNext', asNext ? 1 : 0),
      ],
    );

    final qnumber = response['FirstTrackNumberEnqueued'];
    return int.parse(qnumber ?? '0');
  }

  /// Remove a track from the queue by index.
  ///
  /// The index number is required as an argument, where the first index is 0.
  ///
  /// Parameters:
  ///   - [index]: The (0-based) index of the track to remove
  Future<void> removeFromQueue(int index) async {
    const updid = '0';
    final objid = 'Q:0/${index + 1}';

    await avTransport.sendCommand(
      'RemoveTrackFromQueue',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('ObjectID', objid),
        MapEntry('UpdateID', updid),
      ],
    );
  }

  /// Remove all tracks from the queue.
  Future<void> clearQueue() async {
    await avTransport.sendCommand(
      'RemoveAllTracksFromQueue',
      args: [MapEntry('InstanceID', 0)],
    );
  }

  ///////////////////////////////////////////////////////////////////////////
  // SPEAKER SETTINGS METHODS
  ///////////////////////////////////////////////////////////////////////////

  /// The white Sonos status light between the mute button and the volume up
  /// button on the speaker.
  ///
  /// Returns true if on, otherwise false.
  Future<bool> get statusLight async {
    final result = await deviceProperties.sendCommand('GetLEDState');
    final ledState = result['CurrentLEDState'];
    return ledState == 'On';
  }

  /// Set the status light on or off.
  Future<void> setStatusLight(bool on) async {
    final state = on ? 'On' : 'Off';
    await deviceProperties.sendCommand(
      'SetLEDState',
      args: [MapEntry('DesiredLEDState', state)],
    );
  }

  /// Whether the control buttons on the speaker are enabled.
  ///
  /// Returns true if buttons are enabled, false if disabled/locked.
  Future<bool> get buttonsEnabled async {
    final result = await deviceProperties.sendCommand('GetButtonLockState');
    final lockState = result['CurrentButtonLockState'];
    return lockState == 'Off';
  }

  /// Enable or disable the control buttons on the speaker.
  Future<void> setButtonsEnabled(bool enabled) async {
    final state = enabled ? 'Off' : 'On'; // Note: Off means unlocked
    await deviceProperties.sendCommand(
      'SetButtonLockState',
      args: [MapEntry('DesiredButtonLockState', state)],
    );
  }

  /// The speaker's loudness compensation.
  ///
  /// Returns true if on, false otherwise.
  ///
  /// Loudness is a complicated topic. You can read about it on
  /// Wikipedia: https://en.wikipedia.org/wiki/Loudness
  Future<bool> get loudness async {
    final response = await renderingControl.sendCommand(
      'GetLoudness',
      args: [MapEntry('InstanceID', 0), MapEntry('Channel', 'Master')],
    );
    final loudnessValue = response['CurrentLoudness'];
    return loudnessValue == '1';
  }

  /// Switch on/off the speaker's loudness compensation.
  Future<void> setLoudness(bool loudness) async {
    final loudnessValue = loudness ? '1' : '0';
    await renderingControl.sendCommand(
      'SetLoudness',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('Channel', 'Master'),
        MapEntry('DesiredLoudness', loudnessValue),
      ],
    );
  }

  /// The left/right balance for the speaker(s).
  ///
  /// Returns a 2-tuple (left_channel, right_channel) of integers between 0
  /// and 100, representing the volume of each channel. E.g., (100, 100)
  /// represents full volume to both channels, whereas (100, 0) represents
  /// left channel at full volume, right channel at zero volume.
  Future<(int, int)> get balance async {
    final responseLf = await renderingControl.sendCommand(
      'GetVolume',
      args: [MapEntry('InstanceID', 0), MapEntry('Channel', 'LF')],
    );
    final responseRf = await renderingControl.sendCommand(
      'GetVolume',
      args: [MapEntry('InstanceID', 0), MapEntry('Channel', 'RF')],
    );
    final volumeLf = int.parse(responseLf['CurrentVolume'] ?? '0');
    final volumeRf = int.parse(responseRf['CurrentVolume'] ?? '0');
    return (volumeLf, volumeRf);
  }

  /// Set the left/right balance for the speaker(s).
  Future<void> setBalance(int left, int right) async {
    final clampedLeft = left.clamp(0, 100);
    final clampedRight = right.clamp(0, 100);

    await renderingControl.sendCommand(
      'SetVolume',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('Channel', 'LF'),
        MapEntry('DesiredVolume', clampedLeft),
      ],
    );
    await renderingControl.sendCommand(
      'SetVolume',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('Channel', 'RF'),
        MapEntry('DesiredVolume', clampedRight),
      ],
    );
  }

  /// The TV Dialog Sync audio delay.
  ///
  /// Returns the current value or null if not supported.
  Future<int?> get audioDelay async {
    if (!await isSoundbar) {
      return null;
    }

    final response = await renderingControl.sendCommand(
      'GetEQ',
      args: [MapEntry('InstanceID', 0), MapEntry('EQType', 'AudioDelay')],
    );
    return int.parse(response['CurrentValue'] ?? '0');
  }

  /// Control the delay added to incoming audio sources.
  ///
  /// Also called TV Dialog Sync in Home Theater settings.
  ///
  /// Parameters:
  ///   - [delay]: Delay to apply to audio in the range of 0 to 5
  Future<void> setAudioDelay(int delay) async {
    if (!await isSoundbar) {
      throw NotSupportedException('Audio delay only supported on soundbars');
    }

    final clampedDelay = delay.clamp(0, 5);
    await renderingControl.sendCommand(
      'SetEQ',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('EQType', 'AudioDelay'),
        MapEntry('DesiredValue', clampedDelay),
      ],
    );
  }

  /// The speaker's night mode.
  ///
  /// Returns true if on, false if off, null if not supported.
  Future<bool?> get nightMode async {
    if (!await isSoundbar) {
      return null;
    }

    final response = await renderingControl.sendCommand(
      'GetEQ',
      args: [MapEntry('InstanceID', 0), MapEntry('EQType', 'NightMode')],
    );
    return response['CurrentValue'] == '1';
  }

  /// Switch on/off the speaker's night mode.
  Future<void> setNightMode(bool nightMode) async {
    if (!await isSoundbar) {
      throw NotSupportedException('Night mode only supported on soundbars');
    }

    await renderingControl.sendCommand(
      'SetEQ',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('EQType', 'NightMode'),
        MapEntry('DesiredValue', nightMode ? 1 : 0),
      ],
    );
  }

  /// The speaker's dialog mode.
  ///
  /// Returns true if on, false if off, null if not supported.
  Future<bool?> get dialogMode async {
    if (!await isSoundbar) {
      return null;
    }

    final response = await renderingControl.sendCommand(
      'GetEQ',
      args: [MapEntry('InstanceID', 0), MapEntry('EQType', 'DialogLevel')],
    );
    return response['CurrentValue'] == '1';
  }

  /// Switch on/off the speaker's dialog mode (voice enhancement).
  Future<void> setDialogMode(bool dialogMode) async {
    if (!await isSoundbar) {
      throw NotSupportedException('Dialog mode only supported on soundbars');
    }

    await renderingControl.sendCommand(
      'SetEQ',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('EQType', 'DialogLevel'),
        MapEntry('DesiredValue', dialogMode ? 1 : 0),
      ],
    );
  }

  ///////////////////////////////////////////////////////////////////////////
  // SURROUND AND SUBWOOFER SETTINGS
  ///////////////////////////////////////////////////////////////////////////

  /// Reports if the home theater surround speakers are enabled.
  ///
  /// Should only be called on the primary device in a home theater setup.
  /// Returns true if on, false if off, null if not supported.
  Future<bool?> get surroundEnabled async {
    if (!await isSoundbar) {
      return null;
    }

    final response = await renderingControl.sendCommand(
      'GetEQ',
      args: [MapEntry('InstanceID', 0), MapEntry('EQType', 'SurroundEnable')],
    );
    return response['CurrentValue'] == '1';
  }

  /// Enable/disable the connected surround speakers.
  Future<void> setSurroundEnabled(bool enable) async {
    if (!await isSoundbar) {
      throw NotSupportedException('Surround only supported on soundbars');
    }

    await renderingControl.sendCommand(
      'SetEQ',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('EQType', 'SurroundEnable'),
        MapEntry('DesiredValue', enable ? 1 : 0),
      ],
    );
  }

  /// Reports the current subwoofer crossover frequency in Hz.
  ///
  /// Only supported on Amp devices. Returns null if not supported.
  Future<int?> get subCrossover async {
    if (speakerInfo.isEmpty) {
      await getSpeakerInfo();
    }

    final modelName = (speakerInfo['model_name'] as String?)?.toLowerCase();
    if (modelName?.endsWith('sonos amp') != true) {
      return null;
    }

    final response = await renderingControl.sendCommand(
      'GetEQ',
      args: [MapEntry('InstanceID', 0), MapEntry('EQType', 'SubCrossover')],
    );
    return int.parse(response['CurrentValue'] ?? '0');
  }

  /// Set the subwoofer crossover frequency.
  ///
  /// Only supported on Amp devices.
  ///
  /// Parameters:
  ///   - [frequency]: Desired subwoofer crossover frequency in Hz (50-110)
  Future<void> setSubCrossover(int frequency) async {
    if (speakerInfo.isEmpty) {
      await getSpeakerInfo();
    }

    final modelName = (speakerInfo['model_name'] as String?)?.toLowerCase();
    if (modelName?.endsWith('sonos amp') != true) {
      throw NotSupportedException(
        'Subwoofer crossover not supported on this device',
      );
    }

    if (frequency < 50 || frequency > 110) {
      throw ArgumentError(
        'Invalid value, must be integer between 50 and 110 inclusive',
      );
    }

    await renderingControl.sendCommand(
      'SetEQ',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('EQType', 'SubCrossover'),
        MapEntry('DesiredValue', frequency),
      ],
    );
  }

  /// Reports if the subwoofer is enabled.
  ///
  /// Returns true if on, false if off, null if not supported.
  Future<bool?> get subEnabled async {
    if (!await hasSubwoofer) {
      return null;
    }

    final response = await renderingControl.sendCommand(
      'GetEQ',
      args: [MapEntry('InstanceID', 0), MapEntry('EQType', 'SubEnable')],
    );
    return response['CurrentValue'] == '1';
  }

  /// Enable/disable the connected subwoofer.
  Future<void> setSubEnabled(bool enable) async {
    if (!await hasSubwoofer) {
      throw NotSupportedException('This group does not have a subwoofer');
    }

    await renderingControl.sendCommand(
      'SetEQ',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('EQType', 'SubEnable'),
        MapEntry('DesiredValue', enable ? 1 : 0),
      ],
    );
  }

  /// The current subwoofer gain level.
  ///
  /// Returns the current value or null if not supported.
  Future<int?> get subGain async {
    if (!await hasSubwoofer) {
      return null;
    }

    final response = await renderingControl.sendCommand(
      'GetEQ',
      args: [MapEntry('InstanceID', 0), MapEntry('EQType', 'SubGain')],
    );
    return int.parse(response['CurrentValue'] ?? '0');
  }

  /// Set the subwoofer gain level.
  ///
  /// Parameters:
  ///   - [level]: Desired subwoofer gain level (-15 to 15)
  Future<void> setSubGain(int level) async {
    if (!await hasSubwoofer) {
      throw NotSupportedException('This group does not have a subwoofer');
    }

    if (level < -15 || level > 15) {
      throw ArgumentError(
        'Invalid value, must be integer between -15 and 15 inclusive',
      );
    }

    await renderingControl.sendCommand(
      'SetEQ',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('EQType', 'SubGain'),
        MapEntry('DesiredValue', level),
      ],
    );
  }

  /// Return True if surround full volume is enabled for surround music playback.
  ///
  /// If False, playback on surround speakers uses ambient volume.
  /// Note: does not apply to TV playback.
  Future<bool?> get surroundFullVolumeEnabled async {
    if (!await isSoundbar) {
      return null;
    }

    final response = await renderingControl.sendCommand(
      'GetEQ',
      args: [MapEntry('InstanceID', 0), MapEntry('EQType', 'SurroundMode')],
    );
    return response['CurrentValue'] == '1';
  }

  /// Toggle surround music playback mode.
  ///
  /// True = full volume, False = ambient mode.
  /// Note: this does not apply to TV playback.
  Future<void> setSurroundFullVolumeEnabled(bool value) async {
    if (!await isSoundbar) {
      throw NotSupportedException('Surround only supported on soundbars');
    }

    await renderingControl.sendCommand(
      'SetEQ',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('EQType', 'SurroundMode'),
        MapEntry('DesiredValue', value ? 1 : 0),
      ],
    );
  }

  /// Get the relative volume for surround speakers in TV playback mode.
  ///
  /// Ranges from -15 to +15.
  Future<int?> get surroundVolumeTv async {
    if (!await isSoundbar) {
      return null;
    }

    final response = await renderingControl.sendCommand(
      'GetEQ',
      args: [MapEntry('InstanceID', 0), MapEntry('EQType', 'SurroundLevel')],
    );
    return int.parse(response['CurrentValue'] ?? '0');
  }

  /// Set the relative volume for surround speakers in TV playback mode.
  ///
  /// Range: -15 to +15
  Future<void> setSurroundVolumeTv(int relativeVolume) async {
    if (!await isSoundbar) {
      throw NotSupportedException('Surround only supported on soundbars');
    }

    if (relativeVolume < -15 || relativeVolume > 15) {
      throw ArgumentError('Value must be [-15, 15]');
    }

    await renderingControl.sendCommand(
      'SetEQ',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('EQType', 'SurroundLevel'),
        MapEntry('DesiredValue', relativeVolume),
      ],
    );
  }

  /// Return the relative volume for surround speakers in music mode.
  ///
  /// Range: -15 to +15
  Future<int?> get surroundVolumeMusic async {
    if (!await isSoundbar) {
      return null;
    }

    final response = await renderingControl.sendCommand(
      'GetEQ',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('EQType', 'MusicSurroundLevel'),
      ],
    );
    return int.parse(response['CurrentValue'] ?? '0');
  }

  /// Set the relative volume for surround speakers in music mode.
  ///
  /// Range: -15 to +15
  Future<void> setSurroundVolumeMusic(int relativeVolume) async {
    if (!await isSoundbar) {
      throw NotSupportedException('Surround only supported on soundbars');
    }

    if (relativeVolume < -15 || relativeVolume > 15) {
      throw ArgumentError('Value must be [-15, 15]');
    }

    await renderingControl.sendCommand(
      'SetEQ',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('EQType', 'MusicSurroundLevel'),
        MapEntry('DesiredValue', relativeVolume),
      ],
    );
  }

  /// Whether Trueplay is enabled on this device.
  ///
  /// Returns true if on, false if off.
  ///
  /// Devices that do not support Trueplay, or which do not have a current
  /// Trueplay calibration, will return null.
  Future<bool?> get trueplay async {
    final response = await renderingControl.sendCommand(
      'GetRoomCalibrationStatus',
      args: [MapEntry('InstanceID', 0)],
    );

    if (response['RoomCalibrationAvailable'] == '0') {
      return null;
    }
    return response['RoomCalibrationEnabled'] == '1';
  }

  /// Toggle the device's TruePlay setting.
  ///
  /// Only available to Sonos speakers that have a current Trueplay calibration.
  Future<void> setTrueplay(bool trueplay) async {
    final available = await this.trueplay;
    if (available == null) {
      throw NotSupportedException(
        'Trueplay not available or not calibrated on this device',
      );
    }

    if (!await isVisible) {
      throw SoCoNotVisibleException(
        'Trueplay can only be set on visible devices',
      );
    }

    await renderingControl.sendCommand(
      'SetRoomCalibrationStatus',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('RoomCalibrationEnabled', trueplay ? '1' : '0'),
      ],
    );
  }

  /// Whether the device supports fixed volume output.
  Future<bool> get supportsFixedVolume async {
    final response = await renderingControl.sendCommand(
      'GetSupportsOutputFixed',
      args: [MapEntry('InstanceID', 0)],
    );
    return response['CurrentSupportsFixed'] == '1';
  }

  /// The device's fixed volume output setting.
  ///
  /// Returns true if on, false if off. Only applicable to certain Sonos
  /// devices (Connect and Port at the time of writing). All other devices
  /// always return false.
  Future<bool> get fixedVolume async {
    final response = await renderingControl.sendCommand(
      'GetOutputFixed',
      args: [MapEntry('InstanceID', 0)],
    );
    return response['CurrentFixed'] == '1';
  }

  /// Switch on/off the device's fixed volume output setting.
  ///
  /// Only applicable to certain Sonos devices.
  Future<void> setFixedVolume(bool fixedVolume) async {
    try {
      await renderingControl.sendCommand(
        'SetOutputFixed',
        args: [
          MapEntry('InstanceID', 0),
          MapEntry('DesiredFixed', fixedVolume ? '1' : '0'),
        ],
      );
    } on SoCoUPnPException catch (error) {
      throw NotSupportedException(
        'Fixed volume not supported on this device: $error',
      );
    }
  }

  ///////////////////////////////////////////////////////////////////////////
  // GROUP MANAGEMENT METHODS
  ///////////////////////////////////////////////////////////////////////////

  /// Return the associated ZoneGroupState instance.
  ZoneGroupState get zoneGroupState {
    // Note: This uses a synchronous access pattern
    // householdId must be fetched async first if needed
    final hid = _householdId ?? 'default';
    var zgs = SoCo.zoneGroupStates[hid];
    if (zgs == null) {
      zgs = ZoneGroupState();
      SoCo.zoneGroupStates[hid] = zgs;
    }
    return zgs;
  }

  /// All available groups.
  Future<Set<dynamic>> get allGroups async {
    await zoneGroupState.poll(this);
    return {...zoneGroupState.groups};
  }

  /// The Zone Group of which this device is a member.
  ///
  /// Returns null if this zone is a slave in a stereo pair.
  Future<dynamic> get group async {
    final groups = await allGroups;
    for (final group in groups) {
      if (group.contains(this)) {
        return group;
      }
    }
    return null;
  }

  /// All available zones.
  Future<Set<SoCo>> get allZones async {
    await zoneGroupState.poll(this);
    return {...zoneGroupState.allZones};
  }

  /// All visible zones.
  Future<Set<SoCo>> get visibleZones async {
    await zoneGroupState.poll(this);
    return {...zoneGroupState.visibleZones};
  }

  /// Put all the speakers in the network in the same group (Party Mode).
  ///
  /// This blog shows the initial research responsible for this:
  /// http://blog.travelmarx.com/2010/06/exploring-sonos-via-upnp.html
  ///
  /// The trick seems to be to tell each speaker which to join.
  Future<void> partymode() async {
    final zones = await visibleZones;
    for (final zone in zones) {
      if (zone != this) {
        await zone.join(this);
      }
    }
  }

  /// Join this speaker to another "master" speaker.
  Future<void> join(SoCo master) async {
    final masterUid = await master.uid;
    await avTransport.sendCommand(
      'SetAVTransportURI',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('CurrentURI', 'x-rincon:$masterUid'),
        MapEntry('CurrentURIMetaData', ''),
      ],
    );
    zoneGroupState.clearCache();
  }

  /// Remove this speaker from a group.
  ///
  /// Seems to work ok even if you remove what was previously the group master
  /// from its own group. If the speaker was not in a group also returns ok.
  Future<void> unjoin() async {
    await avTransport.sendCommand(
      'BecomeCoordinatorOfStandaloneGroup',
      args: [MapEntry('InstanceID', 0)],
    );
    zoneGroupState.clearCache();
  }

  ///////////////////////////////////////////////////////////////////////////
  // VOICE ASSISTANT AND STEREO PAIR METHODS
  ///////////////////////////////////////////////////////////////////////////

  /// Whether a voice service is configured on this device.
  Future<bool> get voiceServiceConfigured async {
    // This would require checking voice config state
    // Placeholder implementation
    return false; // TODO: Implement voice service check
  }

  /// Whether the microphone is enabled on this device.
  Future<bool?> get micEnabled async {
    // This would require checking mic state
    // Placeholder implementation
    return null; // TODO: Implement mic enabled check
  }

  /// Set the microphone enabled state.
  Future<void> setMicEnabled(bool enabled) async {
    // TODO: Implement mic enabled setter
    throw UnimplementedError('setMicEnabled not yet implemented');
  }

  /// Create a stereo pair.
  ///
  /// This speaker becomes the master, left-hand speaker of the stereo pair.
  /// The [rhSlaveSpeaker] becomes the right-hand speaker.
  ///
  /// Note that this operation will succeed on dissimilar speakers, unlike
  /// when using the official Sonos apps.
  Future<void> createStereoPair(SoCo rhSlaveSpeaker) async {
    final masterUid = await uid;
    final slaveUid = await rhSlaveSpeaker.uid;

    await deviceProperties.sendCommand(
      'AddBondedZones',
      args: [MapEntry('ChannelMapSet', '$masterUid:LF,LF;$slaveUid:RF,RF')],
    );
    zoneGroupState.clearCache();
  }

  /// Separate a stereo pair.
  ///
  /// This speaker must be part of a stereo pair for this to work.
  Future<void> separateStereoPair() async {
    final masterUid = await uid;

    await deviceProperties.sendCommand(
      'RemoveBondedZones',
      args: [
        MapEntry('ChannelMapSet', '$masterUid:LF,LF'),
        MapEntry('KeepGrouped', '0'),
      ],
    );
    zoneGroupState.clearCache();
  }

  // TODO: Implement playlist and favorites methods (~20 methods)
  // These require more complex integration with music_library
  // - getSonosPlaylists()
  // - createSonosPlaylist()
  // - removeSonosPlaylist()
  // - addItemToSonosPlaylist()
  // - reorderSonosPlaylist()
  // - clearSonosPlaylist()
  // - moveInSonosPlaylist()
  // - removeFromSonosPlaylist()
  // - getSonosPlaylistByAttr()
  // - getFavoriteRadioShows()
  // - getFavoriteRadioStations()
  // - getSonosFavorites()
}
