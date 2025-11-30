/// Access to Sonos Alarms.
///
/// This module provides the [Alarm] and [Alarms] classes for creating,
/// modifying, and removing Sonos alarms.
library;

import 'package:meta/meta.dart';
import 'package:xml/xml.dart';

import 'core.dart';
import 'discovery.dart';
import 'exceptions.dart';

/// Time format for alarm times
const timeFormat = 'HH:mm:ss';

/// Recurrence keyword equivalents
const Map<String, String> recurrenceKeywordEquivalent = {
  'DAILY': 'ON_0123456',
  'ONCE': 'ON_', // Never reoccurs
  'WEEKDAYS': 'ON_12345',
  'WEEKENDS': 'ON_06',
};

/// Check that [text] is a valid recurrence string.
///
/// A valid recurrence string is `DAILY`, `ONCE`, `WEEKDAYS`, `WEEKENDS`
/// or of the form `ON_DDDDDD` where `D` is a number from 0-6 representing
/// a day of the week (Sunday is 0), e.g. `ON_034` meaning Sunday, Wednesday
/// and Thursday.
///
/// Parameters:
///   - [text]: the recurrence string to check
///
/// Returns:
///   `true` if the recurrence string is valid, else `false`
///
/// Examples:
/// ```dart
/// isValidRecurrence('WEEKENDS')  // true
/// isValidRecurrence('')  // false
/// isValidRecurrence('ON_132')  // true (Mon, Tue, Wed)
/// isValidRecurrence('ON_666')  // true (Sat)
/// isValidRecurrence('ON_3421')  // true (Mon, Tue, Wed, Thur)
/// isValidRecurrence('ON_123456789')  // false (Too many digits)
/// ```
bool isValidRecurrence(String text) {
  if (const ['DAILY', 'ONCE', 'WEEKDAYS', 'WEEKENDS'].contains(text)) {
    return true;
  }
  final pattern = RegExp(r'^ON_[0-6]{1,7}$');
  return pattern.hasMatch(text);
}

/// A singleton class representing all known Sonos Alarms.
///
/// Every [Alarms] object will return the same instance per household.
///
/// Example use:
/// ```dart
/// final alarmsMap = await getAlarms();
/// print(alarmsMap);  // {469: <Alarm id:469@22:07:41>, ...}
///
/// final alarms = Alarms();
/// await alarms.update();
/// print(alarms.alarms);  // {469: <Alarm id:469@22:07:41>, ...}
///
/// for (final alarm in alarms) {
///   print(alarm);
/// }
///
/// print(alarms[470]);  // Access alarm by ID
///
/// final newAlarm = Alarm(zone);
/// await newAlarm.save();
/// print(newAlarm.alarmId);  // 471
///
/// newAlarm.recurrence = 'ONCE';
/// await newAlarm.save();
///
/// await alarms[470]?.remove();
/// ```
class Alarms extends Iterable<Alarm> {
  /// All known alarms, keyed by alarm ID
  final Map<String, Alarm> alarms = {};

  /// Last zone used for updates
  @visibleForTesting
  SoCo? lastZoneUsed;

  /// Last alarm list version seen
  String? _lastAlarmListVersion;

  /// Reset state for testing
  @visibleForTesting
  void resetForTesting() {
    alarms.clear();
    lastZoneUsed = null;
    _lastAlarmListVersion = null;
    lastUid = null;
    lastId = 0;
  }

  /// Last UID seen
  String? lastUid;

  /// Last ID seen
  int lastId = 0;

  /// The singleton instance
  static final Alarms _instance = Alarms._internal();

  /// Private constructor
  Alarms._internal();

  /// Factory constructor returns singleton
  factory Alarms() => _instance;

  /// Return last seen alarm list version
  String? get lastAlarmListVersion => _lastAlarmListVersion;

  /// Store alarm list version and extract UID/ID values
  set lastAlarmListVersion(String? alarmListVersion) {
    if (alarmListVersion != null) {
      final parts = alarmListVersion.split(':');
      lastUid = parts[0];
      lastId = int.parse(parts[1]);
      _lastAlarmListVersion = alarmListVersion;
    }
  }

  @override
  Iterator<Alarm> get iterator => alarms.values.iterator;

  @override
  int get length => alarms.length;

  /// Return the alarm by ID
  Alarm? operator [](String alarmId) => alarms[alarmId];

  /// Return the alarm by ID or null
  Alarm? get(String alarmId) => alarms[alarmId];

  /// Update all alarms and current alarm list version.
  ///
  /// Raises:
  ///   [SoCoException]: If the 'CurrentAlarmListVersion' value is unexpected.
  ///     May occur if the provided zone is from a different household.
  Future<void> update([SoCo? zone]) async {
    zone ??= lastZoneUsed ?? await anySoco();

    if (zone == null) {
      throw SoCoException('No Sonos devices found on network');
    }

    lastZoneUsed = zone;

    final response = await zone.alarmClock.sendCommand('ListAlarms');
    final currentAlarmListVersion = response['CurrentAlarmListVersion'];

    if (_lastAlarmListVersion != null && currentAlarmListVersion != null) {
      final parts = currentAlarmListVersion.split(':');
      final alarmListUid = parts[0];
      final alarmListId = int.parse(parts[1]);

      if (lastUid != alarmListUid) {
        final allZones = await zone.allZones;
        SoCo? matchingZone;
        for (final z in allZones) {
          if (await z.uid == alarmListUid) {
            matchingZone = z;
            break;
          }
        }

        if (matchingZone == null) {
          throw SoCoException(
            'Alarm list UID $currentAlarmListVersion does not match $_lastAlarmListVersion',
          );
        }
      }

      if (alarmListId <= lastId) {
        return;
      }
    }

    lastAlarmListVersion = currentAlarmListVersion;

    final newAlarms = await _parseAlarmPayload(response, zone);

    // Update existing and create new Alarm instances
    for (final entry in newAlarms.entries) {
      final alarmId = entry.key;
      final kwargs = entry.value;

      final existingAlarm = alarms[alarmId];
      if (existingAlarm != null) {
        existingAlarm._updateFromMap(kwargs);
      } else {
        final newAlarm = Alarm._fromMap(kwargs);
        newAlarm._alarmId = alarmId;
        alarms[alarmId] = newAlarm;
      }
    }

    // Prune alarms removed externally
    final alarmIds = alarms.keys.toList();
    for (final alarmId in alarmIds) {
      if (!newAlarms.containsKey(alarmId)) {
        alarms.remove(alarmId);
      }
    }
  }

  /// Get the next alarm trigger datetime.
  ///
  /// Parameters:
  ///   - [fromDatetime]: a datetime to reference next alarms from. This
  ///     argument filters by alarms on or after this exact time. Defaults
  ///     to [DateTime.now].
  ///   - [includeDisabled]: If `true` then disabled alarms will be included
  ///     in searching for the next alarm. Defaults to `false`.
  ///   - [zoneUid]: If set the alarms will be filtered by zone with this UID.
  ///     Defaults to `null`.
  ///
  /// Returns:
  ///   The next alarm trigger datetime or null if disabled
  Future<DateTime?> getNextAlarmDatetime({
    DateTime? fromDatetime,
    bool includeDisabled = false,
    String? zoneUid,
  }) async {
    fromDatetime ??= DateTime.now();

    DateTime? nextAlarmDatetime;
    for (final alarm in alarms.values) {
      if (zoneUid != null && await alarm.zone.uid != zoneUid) {
        continue;
      }
      final thisNextDatetime = alarm.getNextAlarmDatetime(
        fromDatetime: fromDatetime,
        includeDisabled: includeDisabled,
      );
      if (thisNextDatetime != null &&
          (nextAlarmDatetime == null ||
              thisNextDatetime.isBefore(nextAlarmDatetime))) {
        nextAlarmDatetime = thisNextDatetime;
      }
    }
    return nextAlarmDatetime;
  }

  /// Parse the XML payload response and return a map of Alarm data.
  Future<Map<String, Map<String, dynamic>>> _parseAlarmPayload(
    Map<String, dynamic> payload,
    SoCo zone,
  ) async {
    final alarmList = payload['CurrentAlarmList'] as String;
    final tree = XmlDocument.parse(alarmList);

    final alarmElements = tree.rootElement.findElements('Alarm');
    final alarmArgs = <String, Map<String, dynamic>>{};

    final allZones = await zone.allZones;

    for (final alarmElement in alarmElements) {
      final alarmId = alarmElement.getAttribute('ID')!;

      final roomUuid = alarmElement.getAttribute('RoomUUID')!;
      SoCo? alarmZone;
      for (final z in allZones) {
        if (await z.uid == roomUuid) {
          alarmZone = z;
          break;
        }
      }

      if (alarmZone == null) {
        // Some alarms are not associated with a zone, ignore these
        continue;
      }

      final startTimeStr = alarmElement.getAttribute('StartTime')!;
      final durationStr = alarmElement.getAttribute('Duration')!;
      final programUri = alarmElement.getAttribute('ProgramURI')!;

      final args = <String, dynamic>{
        'zone': alarmZone,
        'start_time': _parseTime(startTimeStr),
        'duration': durationStr.isEmpty ? null : _parseTime(durationStr),
        'recurrence': alarmElement.getAttribute('Recurrence')!,
        'enabled': alarmElement.getAttribute('Enabled') == '1',
        'program_uri': programUri == 'x-rincon-buzzer:0' ? null : programUri,
        'program_metadata': alarmElement.getAttribute('ProgramMetaData') ?? '',
        'play_mode': alarmElement.getAttribute('PlayMode')!,
        'volume': int.parse(alarmElement.getAttribute('Volume')!),
        'include_linked_zones':
            alarmElement.getAttribute('IncludeLinkedZones') == '1',
      };

      alarmArgs[alarmId] = args;
    }

    return alarmArgs;
  }

  /// Parse a time string (HH:MM:SS) into a DateTime (time portion only)
  DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return DateTime(
      0,
      1,
      1,
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}

/// A class representing a Sonos Alarm.
///
/// Alarms may be created or updated and saved to, or removed from the Sonos
/// system. An alarm is not automatically saved. Call [save] to do that.
class Alarm {
  /// The SoCo instance which will play the alarm
  final SoCo zone;

  /// The alarm's start time (time portion only)
  DateTime startTime;

  /// The alarm's duration (time portion only), or null for unlimited
  DateTime? duration;

  /// How often the alarm should be triggered
  String _recurrence;

  /// Whether the alarm is enabled
  bool enabled;

  /// The URI to play, or null for the built-in chime
  String? programUri;

  /// The metadata associated with programUri
  String programMetadata;

  /// The play mode for the alarm
  String _playMode;

  /// The alarm's volume (0-100)
  int _volume;

  /// Whether the alarm should be played on linked zones
  bool includeLinkedZones;

  /// The alarm ID (internal)
  String? _alarmId;

  /// Creates a new Alarm.
  ///
  /// Parameters:
  ///   - [zone]: The SoCo instance which will play the alarm
  ///   - [startTime]: The alarm's start time (time portion only). Defaults
  ///     to current time.
  ///   - [duration]: The alarm's duration (time portion only). May be null
  ///     for unlimited duration. Defaults to null.
  ///   - [recurrence]: A string representing how often the alarm should be
  ///     triggered. Can be `DAILY`, `ONCE`, `WEEKDAYS`, `WEEKENDS` or of the
  ///     form `ON_DDDDDD` where `D` is a number from 0-6 representing a day
  ///     of the week (Sunday is 0), e.g. `ON_034` meaning Sunday, Wednesday
  ///     and Thursday. Defaults to `DAILY`.
  ///   - [enabled]: `true` if alarm is enabled, `false` otherwise. Defaults
  ///     to `true`.
  ///   - [programUri]: The uri to play. If null, the built-in Sonos chime
  ///     sound will be used. Defaults to null.
  ///   - [programMetadata]: The metadata associated with 'programUri'.
  ///     Defaults to ''.
  ///   - [playMode]: The play mode for the alarm. Can be one of `NORMAL`,
  ///     `SHUFFLE_NOREPEAT`, `SHUFFLE`, `REPEAT_ALL`, `REPEAT_ONE`,
  ///     `SHUFFLE_REPEAT_ONE`. Defaults to `NORMAL`.
  ///   - [volume]: The alarm's volume (0-100). Defaults to 20.
  ///   - [includeLinkedZones]: `true` if the alarm should be played on the
  ///     other speakers in the same group, `false` otherwise. Defaults to
  ///     `false`.
  Alarm(
    this.zone, {
    DateTime? startTime,
    this.duration,
    String recurrence = 'DAILY',
    this.enabled = true,
    this.programUri,
    this.programMetadata = '',
    String playMode = 'NORMAL',
    int volume = 20,
    this.includeLinkedZones = false,
  }) : startTime = startTime ?? _getCurrentTime(),
       _recurrence = recurrence,
       _playMode = playMode,
       _volume = volume {
    // Validate recurrence
    this.recurrence = recurrence;
    // Validate play mode
    this.playMode = playMode;
    // Validate volume
    this.volume = volume;
  }

  /// Internal constructor from map
  Alarm._fromMap(Map<String, dynamic> map)
    : zone = map['zone'] as SoCo,
      startTime = map['start_time'] as DateTime,
      duration = map['duration'] as DateTime?,
      _recurrence = map['recurrence'] as String,
      enabled = map['enabled'] as bool,
      programUri = map['program_uri'] as String?,
      programMetadata = map['program_metadata'] as String,
      _playMode = map['play_mode'] as String,
      _volume = map['volume'] as int,
      includeLinkedZones = map['include_linked_zones'] as bool;

  /// Update this alarm from a map
  void _updateFromMap(Map<String, dynamic> map) {
    if (map.containsKey('start_time')) {
      startTime = map['start_time'] as DateTime;
    }
    if (map.containsKey('duration')) {
      duration = map['duration'] as DateTime?;
    }
    if (map.containsKey('recurrence')) {
      _recurrence = map['recurrence'] as String;
    }
    if (map.containsKey('enabled')) {
      enabled = map['enabled'] as bool;
    }
    if (map.containsKey('program_uri')) {
      programUri = map['program_uri'] as String?;
    }
    if (map.containsKey('program_metadata')) {
      programMetadata = map['program_metadata'] as String;
    }
    if (map.containsKey('play_mode')) _playMode = map['play_mode'] as String;
    if (map.containsKey('volume')) _volume = map['volume'] as int;
    if (map.containsKey('include_linked_zones')) {
      includeLinkedZones = map['include_linked_zones'] as bool;
    }
  }

  /// Get current time with microseconds set to 0
  static DateTime _getCurrentTime() {
    final now = DateTime.now();
    return DateTime(0, 1, 1, now.hour, now.minute, now.second);
  }

  @override
  String toString() {
    final timeStr = _formatTime(startTime);
    return '<Alarm id:$alarmId@$timeStr>';
  }

  /// Format a DateTime (time portion) as HH:MM:SS
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  /// The play mode for the alarm.
  ///
  /// Can be one of `NORMAL`, `SHUFFLE_NOREPEAT`, `SHUFFLE`, `REPEAT_ALL`,
  /// `REPEAT_ONE`, `SHUFFLE_REPEAT_ONE`.
  String get playMode => _playMode;

  set playMode(String value) {
    final upperValue = value.toUpperCase();
    if (!playModes.containsKey(upperValue)) {
      throw ArgumentError('\'$value\' is not a valid play mode');
    }
    _playMode = upperValue;
  }

  /// The alarm's volume (0-100)
  int get volume => _volume;

  set volume(int value) {
    // Coerce in range 0-100
    _volume = value.clamp(0, 100);
  }

  /// How often the alarm should be triggered.
  ///
  /// Can be `DAILY`, `ONCE`, `WEEKDAYS`, `WEEKENDS` or of the form
  /// `ON_DDDDDDD` where `D` is a number from 0-7 representing a day of
  /// the week (Sunday is 0), e.g. `ON_034` meaning Sunday, Wednesday and
  /// Thursday.
  String get recurrence => _recurrence;

  set recurrence(String value) {
    if (!isValidRecurrence(value)) {
      throw ArgumentError('\'$value\' is not a valid recurrence value');
    }
    _recurrence = value;
  }

  /// The ID of the alarm, or null if not saved
  String? get alarmId => _alarmId;

  /// Set alarm ID for testing purposes
  @visibleForTesting
  set alarmIdForTesting(String? id) => _alarmId = id;

  /// Save the alarm to the Sonos system.
  ///
  /// Returns:
  ///   The alarm ID, or null if no alarm was saved
  ///
  /// Throws:
  ///   [SoCoUPnPException]: if the alarm cannot be created because there
  ///     is already an alarm for this room at the specified time.
  Future<String?> save() async {
    final zoneUid = await zone.uid;
    final args = [
      MapEntry('StartLocalTime', _formatTime(startTime)),
      MapEntry('Duration', duration == null ? '' : _formatTime(duration!)),
      MapEntry('Recurrence', recurrence),
      MapEntry('Enabled', enabled ? '1' : '0'),
      MapEntry('RoomUUID', zoneUid),
      MapEntry('ProgramURI', programUri ?? 'x-rincon-buzzer:0'),
      MapEntry('ProgramMetaData', programMetadata),
      MapEntry('PlayMode', playMode),
      MapEntry('Volume', volume),
      MapEntry('IncludeLinkedZones', includeLinkedZones ? '1' : '0'),
    ];

    if (_alarmId == null) {
      final response = await zone.alarmClock.sendCommand(
        'CreateAlarm',
        args: args,
      );
      _alarmId = response['AssignedID'] as String;

      final alarms = Alarms();
      if (alarms.lastId == int.parse(_alarmId!) - 1) {
        alarms.lastAlarmListVersion = '${alarms.lastUid}:$_alarmId';
      }
      alarms.alarms[_alarmId!] = this;
    } else {
      // The alarm has been saved before. Update it instead.
      final updateArgs = [MapEntry('ID', _alarmId!), ...args];
      await zone.alarmClock.sendCommand('UpdateAlarm', args: updateArgs);
    }

    return _alarmId;
  }

  /// Remove the alarm from the Sonos system.
  ///
  /// There is no need to call [save]. The Dart instance is not deleted,
  /// and can be saved back to Sonos again if desired.
  ///
  /// Returns:
  ///   The result from the DestroyAlarm call
  Future<Map<String, dynamic>> remove() async {
    final result = await zone.alarmClock.sendCommand(
      'DestroyAlarm',
      args: [MapEntry('ID', _alarmId!)],
    );

    final alarms = Alarms();
    alarms.alarms.remove(_alarmId);
    _alarmId = null;

    return result;
  }

  /// Get the next alarm trigger datetime.
  ///
  /// Parameters:
  ///   - [fromDatetime]: a datetime to reference next alarms from. This
  ///     argument filters by alarms on or after this exact time. Since alarms
  ///     do not store timezone information, the output timezone will match
  ///     this input argument. Defaults to [DateTime.now].
  ///   - [includeDisabled]: If `true` then the next datetime will be computed
  ///     even if the alarm is disabled. Defaults to `false`.
  ///
  /// Returns:
  ///   The next alarm trigger datetime or null if disabled
  DateTime? getNextAlarmDatetime({
    DateTime? fromDatetime,
    bool includeDisabled = false,
  }) {
    if (!enabled && !includeDisabled) {
      return null;
    }

    fromDatetime ??= DateTime.now();

    // Convert helper words to number recurrences
    var recurrenceOnStr = recurrenceKeywordEquivalent[recurrence] ?? recurrence;

    // For the purpose of finding the next alarm a "once" trigger that has
    // yet to trigger is everyday (the next possible day)
    if (recurrenceOnStr == recurrenceKeywordEquivalent['ONCE']) {
      recurrenceOnStr = recurrenceKeywordEquivalent['DAILY']!;
    }

    // Trim the 'ON_' prefix, convert to int, remove duplicates
    final recurrenceSet = recurrenceOnStr
        .substring(3)
        .split('')
        .map(int.parse)
        .toSet();

    // Convert Sonos weekdays to Dart weekdays
    // Sonos starts on Sunday (0), Dart starts on Monday (1)
    final dartRecurrenceSet = <int>{};
    for (final day in recurrenceSet) {
      if (day == 0) {
        dartRecurrenceSet.add(7); // Sunday is 7 in Dart
      } else {
        dartRecurrenceSet.add(day);
      }
    }

    // Begin search from next day if it would have already triggered today
    var offset = 0;
    final fromTime = DateTime(
      0,
      1,
      1,
      fromDatetime.hour,
      fromDatetime.minute,
      fromDatetime.second,
    );
    if (!startTime.isAfter(fromTime)) {
      offset += 1;
    }

    // Find first day
    final fromDatetimeDay = fromDatetime.weekday;
    var offsetWeekday = (fromDatetimeDay + offset - 1) % 7 + 1;
    while (!dartRecurrenceSet.contains(offsetWeekday)) {
      offset += 1;
      offsetWeekday = (fromDatetimeDay + offset - 1) % 7 + 1;
    }

    return DateTime(
      fromDatetime.year,
      fromDatetime.month,
      fromDatetime.day + offset,
      startTime.hour,
      startTime.minute,
      startTime.second,
      0, // millisecond
      0, // microsecond
    ).toUtc();
  }
}

/// Get a set of all alarms known to the Sonos system.
///
/// Parameters:
///   - [zone]: a SoCo instance to query. If null, a random instance is used.
///
/// Returns:
///   A set of [Alarm] instances
Future<Set<Alarm>> getAlarms([SoCo? zone]) async {
  final alarms = Alarms();
  await alarms.update(zone);
  return alarms.alarms.values.toSet();
}

/// Remove an alarm from the Sonos system by its ID.
///
/// Parameters:
///   - [zone]: A SoCo instance, which can be any zone that belongs to the
///     Sonos system in which the required alarm is defined.
///   - [alarmId]: The ID of the alarm to be removed.
///
/// Returns:
///   `true` if the alarm is found and removed, `false` otherwise
Future<bool> removeAlarmById(SoCo zone, String alarmId) async {
  final alarms = Alarms();
  await alarms.update(zone);
  final alarm = alarms.get(alarmId);
  if (alarm == null) {
    return false;
  }
  await alarm.remove();
  return true;
}
