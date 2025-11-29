# SoCo Dart Examples

This directory contains example code demonstrating how to use the SoCo Dart library to control Sonos devices.

## Prerequisites

Before running these examples, make sure:
- You have Dart SDK installed
- Your Sonos devices are powered on and connected to the same network as your computer
- You have added SoCo as a dependency in your `pubspec.yaml`

## Running the Examples

You can run any example using the Dart CLI:

```bash
dart run example/basic_discovery.dart
dart run example/playback_control.dart
dart run example/snapshot.dart
dart run example/alarms_example.dart
dart run example/groups_example.dart
dart run example/music_library_example.dart
dart run example/events_example.dart
```

## Examples Overview

### 1. Basic Discovery (`basic_discovery.dart`)

Demonstrates how to discover Sonos devices on your network and retrieve basic information about them.

**Key concepts:**
- Using `discover()` to find all devices
- Getting speaker information
- Checking current playback state
- Listing zone groups

**Usage:**
```bash
dart run example/basic_discovery.dart
```

### 2. Playback Control (`playback_control.dart`)

Shows how to control playback on a specific Sonos device.

**Key concepts:**
- Finding a device by zone name with `byName()`
- Basic playback controls (play, pause, next)
- Volume control
- Getting track information
- Play mode settings (shuffle, repeat, crossfade)

**Usage:**
```bash
dart run example/playback_control.dart
```

**Note:** You'll need to edit the example to match your zone name (default is "Living Room").

### 3. Snapshot (`snapshot.dart`)

Demonstrates how to save and restore the complete state of a Sonos device.

**Key concepts:**
- Creating a snapshot of current state
- Making temporary changes
- Restoring previous state

**Usage:**
```bash
dart run example/snapshot.dart
```

**Use cases:**
- Playing announcements without interrupting current playback
- Temporarily switching sources and returning to previous state
- Implementing custom "pause and resume" functionality

### 4. Alarms (`alarms_example.dart`)

Shows comprehensive alarm management capabilities.

**Key concepts:**
- Listing configured alarms
- Creating new alarms with different recurrence patterns
- Modifying alarm settings
- Deleting alarms
- Alarm properties (time, volume, recurrence, etc.)

**Usage:**
```bash
dart run example/alarms_example.dart
```

### 5. Zone Groups (`groups_example.dart`)

Demonstrates zone grouping and multi-room audio control.

**Key concepts:**
- Discovering all zones and groups
- Getting group information and labels
- Group volume and mute control
- Joining and unjoining zones
- Party mode (all zones grouped)

**Usage:**
```bash
dart run example/groups_example.dart
```

### 6. Music Library (`music_library_example.dart`)

Shows how to browse and search your local music library.

**Key concepts:**
- Browsing artists, albums, tracks, playlists
- Searching the library
- Paging through large result sets
- Getting album art URIs
- Browsing by genre and composer

**Usage:**
```bash
dart run example/music_library_example.dart
```

**Note:** Results depend on your local music library content.

### 7. Events (`events_example.dart`)

Demonstrates real-time event notifications using UPnP GENA subscriptions.

**Key concepts:**
- Subscribing to transport events (play/pause/track changes)
- Subscribing to rendering control events (volume/mute changes)
- Handling event callbacks with Dart Streams
- Auto-renewal of subscriptions
- Unsubscribing from events

**Usage:**
```bash
dart run example/events_example.dart
```

**Note:** This example listens for 30 seconds. Control your Sonos device during this time to see events.

## Common Patterns

### Finding Devices

```dart
// Find any device
final device = await anySoco();

// Find all devices
final devices = await discover();

// Find specific device by name
final device = await byName('Living Room');

// Find device by IP
final device = SoCo('192.168.1.100');
```

### Playback Control

```dart
// Basic controls
await device.play();
await device.pause();
await device.stop();
await device.next();
await device.previous();

// Volume
await device.setVolume(50);
final volume = await device.volume;

// Mute
await device.setMute(true);
final isMuted = await device.mute;
```

### Getting Information

```dart
// Speaker info
final info = await device.getSpeakerInfo();
print(info['zone_name']);
print(info['model_name']);

// Current track
final track = await device.getCurrentTrackInfo();
print(track['title']);
print(track['artist']);

// Transport state
final transport = await device.getCurrentTransportInfo();
print(transport['current_transport_state']); // PLAYING, PAUSED, STOPPED
```

### Group Management

```dart
// Get all groups
final groups = await device.allGroups;

// Join another device
await device.join(otherDevice);

// Leave group (become standalone)
await device.unjoin();

// Party mode (join all devices)
await device.partymode();
```

## Troubleshooting

### No Devices Found

If discovery returns no devices:
1. Check that your Sonos devices are powered on
2. Ensure your computer and Sonos are on the same network
3. Check firewall settings (UDP port 1900 for SSDP)
4. Try increasing the discovery timeout: `discover(timeout: Duration(seconds: 10))`

### Connection Timeouts

If operations time out:
1. Verify the IP address is correct
2. Check network connectivity
3. Some operations may take longer on slow networks

### Device Not Found by Name

If `byName()` returns null:
1. Run `basic_discovery.dart` to see all available zone names
2. Zone names are case-sensitive
3. Make sure the device is online

## Further Reading

- [Python SoCo Documentation](https://soco.readthedocs.io/) - Original library documentation (API is similar)
- [Sonos UPnP Control API](https://developer.sonos.com/) - Official Sonos developer resources
- [API Reference](../README.md) - SoCo Dart API documentation

## Contributing

Have a useful example? Feel free to contribute! Make sure your example:
- Is well-commented
- Includes error handling
- Demonstrates a specific use case
- Follows Dart style guidelines
