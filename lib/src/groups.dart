/// This module contains classes and functionality relating to Sonos Groups.
library;

import 'core.dart';

/// A class representing a Sonos Group.
///
/// Example:
/// ```dart
/// ZoneGroup(
///   uid: 'RINCON_000FD584236D01400:58',
///   coordinator: SoCo("192.168.1.101"),
///   members: {SoCo("192.168.1.101"), SoCo("192.168.1.102")}
/// )
/// ```
///
/// Any SoCo instance can tell you what group it is in:
/// ```dart
/// final device = await anySoco();
/// final group = await device.group;
/// print(group);
/// ```
///
/// From there, you can find the coordinator for the current group:
/// ```dart
/// final coordinator = group.coordinator;
/// ```
///
/// or, for example, its name:
/// ```dart
/// final name = await group.coordinator.playerName;
/// print(name); // Kitchen
/// ```
///
/// or a set of the members:
/// ```dart
/// final members = group.members;
/// print(members); // {SoCo("192.168.1.101"), SoCo("192.168.1.102")}
/// ```
///
/// For convenience, ZoneGroup is also iterable:
/// ```dart
/// for (final player in group) {
///   print(await player.playerName);
/// }
/// ```
///
/// A consistent readable label for the group members can be returned with
/// the [label] and [shortLabel] properties.
///
/// Properties are available to get and set the group [volume] and the group
/// [mute] state, and the [setRelativeVolume] method can be used to make
/// relative adjustments to the group volume, e.g.:
/// ```dart
/// await group.setVolume(25);
/// print(await group.volume); // 25
/// await group.setRelativeVolume(-10);
/// print(await group.volume); // 15
/// print(await group.mute); // false
/// await group.setMute(true);
/// print(await group.mute); // true
/// ```
class ZoneGroup extends Iterable<SoCo> {
  /// The unique Sonos ID for this group (e.g., RINCON_000FD584236D01400:5)
  final String uid;

  /// The SoCo instance which coordinates this group
  final SoCo coordinator;

  /// A set of SoCo instances which are members of the group
  final Set<SoCo> members;

  /// Creates a ZoneGroup.
  ///
  /// Parameters:
  ///   - [uid]: The unique Sonos ID for this group
  ///   - [coordinator]: The SoCo instance representing the coordinator
  ///   - [members]: A set of SoCo instances which are members of this group
  ZoneGroup({
    required this.uid,
    required this.coordinator,
    Set<SoCo>? members,
  }) : members = members ?? {};

  @override
  Iterator<SoCo> get iterator => members.iterator;

  @override
  bool contains(Object? element) => members.contains(element);

  @override
  String toString() {
    return 'ZoneGroup(uid: \'$uid\', coordinator: $coordinator, members: $members)';
  }

  /// A description of the group.
  ///
  /// Example: 'Kitchen, Living Room'
  Future<String> get label async {
    final groupNames = <String>[];
    for (final member in members) {
      groupNames.add(await member.playerName);
    }
    groupNames.sort();
    return groupNames.join(', ');
  }

  /// A short description of the group.
  ///
  /// Example: 'Kitchen + 1'
  Future<String> get shortLabel async {
    final groupNames = <String>[];
    for (final member in members) {
      groupNames.add(await member.playerName);
    }
    groupNames.sort();

    var groupLabel = groupNames[0];
    if (groupNames.length > 1) {
      groupLabel += ' + ${groupNames.length - 1}';
    }
    return groupLabel;
  }

  /// The volume of the group.
  ///
  /// An integer between 0 and 100.
  Future<int> get volume async {
    await coordinator.groupRenderingControl.sendCommand(
      'SnapshotGroupVolume',
      args: [MapEntry('InstanceID', 0)],
    );
    final response = await coordinator.groupRenderingControl.sendCommand(
      'GetGroupVolume',
      args: [MapEntry('InstanceID', 0)],
    );
    return int.parse(response['CurrentVolume'] ?? '0');
  }

  /// Set the volume of the group.
  ///
  /// Parameters:
  ///   - [groupVolume]: The desired volume (0-100)
  Future<void> setVolume(int groupVolume) async {
    // Coerce to valid range
    groupVolume = groupVolume.clamp(0, 100);

    await coordinator.groupRenderingControl.sendCommand(
      'SnapshotGroupVolume',
      args: [MapEntry('InstanceID', 0)],
    );
    await coordinator.groupRenderingControl.sendCommand(
      'SetGroupVolume',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('DesiredVolume', groupVolume),
      ],
    );
  }

  /// The mute state for the group.
  ///
  /// Returns `true` if the group is muted, `false` otherwise.
  Future<bool> get mute async {
    final response = await coordinator.groupRenderingControl.sendCommand(
      'GetGroupMute',
      args: [MapEntry('InstanceID', 0)],
    );
    final muteState = response['CurrentMute'];
    return muteState == '1';
  }

  /// Set the mute state for the group.
  ///
  /// Parameters:
  ///   - [groupMute]: `true` to mute, `false` to unmute
  Future<void> setMute(bool groupMute) async {
    final muteValue = groupMute ? '1' : '0';
    await coordinator.groupRenderingControl.sendCommand(
      'SetGroupMute',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('DesiredMute', muteValue),
      ],
    );
  }

  /// Adjust the group volume up or down by a relative amount.
  ///
  /// If the adjustment causes the volume to overshoot the maximum value
  /// of 100, the volume will be set to 100. If the adjustment causes the
  /// volume to undershoot the minimum value of 0, the volume will be set
  /// to 0.
  ///
  /// Note that this method is an alternative to using addition and
  /// subtraction on the volume property. This method requires only one
  /// network call instead of two.
  ///
  /// Parameters:
  ///   - [relativeGroupVolume]: The relative volume adjustment. Can be
  ///     positive or negative.
  ///
  /// Returns:
  ///   The new group volume setting.
  Future<int> setRelativeVolume(int relativeGroupVolume) async {
    // Sonos automatically handles out-of-range values
    await coordinator.groupRenderingControl.sendCommand(
      'SnapshotGroupVolume',
      args: [MapEntry('InstanceID', 0)],
    );
    final response = await coordinator.groupRenderingControl.sendCommand(
      'SetRelativeGroupVolume',
      args: [
        MapEntry('InstanceID', 0),
        MapEntry('Adjustment', relativeGroupVolume),
      ],
    );
    return int.parse(response['NewVolume'] ?? '0');
  }
}
