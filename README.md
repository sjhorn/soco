# SoCo - Sonos Controller

[![pub package](https://img.shields.io/pub/v/soco.svg)](https://pub.dev/packages/soco)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A pure Dart library for controlling Sonos speakers programmatically.

This is a Dart port of the Python [SoCo library](https://github.com/SoCo/SoCo), which was originally created at Music Hack Day Sydney by Rahim Sonawalla.

## What is SoCo?

SoCo (Sonos Controller) allows you to control Sonos speakers programmatically using Dart. It provides a simple, idiomatic Dart API for interacting with Sonos devices on your local network.

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  soco: ^0.1.0
```

Then run:

```bash
dart pub get
```

## Basic Usage

### Discovering Sonos Speakers

The easiest way to get started is to use the `discover()` function to find all Sonos speakers on your network:

```dart
import 'package:soco/soco.dart';

void main() async {
  // Discover all Sonos speakers on the network
  final zones = await discover();

  for (final zone in zones) {
    print(zone.playerName);
  }
}
```

### Controlling a Specific Speaker

If you know the IP address of a Sonos speaker, you can create a `SoCo` instance directly:

```dart
import 'package:soco/soco.dart';

void main() async {
  // Connect to a specific speaker
  final kitchen = SoCo('192.168.1.101');

  // Get player name
  print(await kitchen.playerName);

  // Control the speaker
  await kitchen.setStatusLight(true);
  await kitchen.setVolume(10);
}
```

### Playing Music

```dart
import 'package:soco/soco.dart';

void main() async {
  final sonos = SoCo('192.168.1.102');

  // Play a URI
  await sonos.playUri(
    'http://example.com/audio.mp3',
  );

  // Get current track info
  final track = await sonos.getCurrentTrackInfo();
  print('Now playing: ${track.title}');

  // Control playback
  await sonos.pause();
  await sonos.play();
}
```

## Features

SoCo for Dart supports the following controls:

### Playback Control
- Play, Pause, Stop
- Next track, Previous track
- Seek to position
- Play from queue

### Volume & Audio
- Volume get and set
- Mute/unmute
- Bass and treble EQ
- Loudness compensation
- Night mode and dialog mode (for compatible devices)

### Track Information
- Track title, artist, album
- Album art (if available)
- Track length and current position
- Playlist position
- Track URI

### Queue Management
- Get queue contents
- Add items to queue
- Clear queue
- Remove items from queue
- Reorder queue

### Speaker Groups
- Join or unjoin speakers from groups
- Create party mode (all speakers)
- Get group information

### Discovery & Network
- Discover all Sonos devices on network
- Get speaker information (name, ID, serial, etc.)
- Set speaker name

### Advanced Features
- Event subscriptions (speaker state changes)
- Local music library search and playback
- Sonos favorites
- Alarms management
- Sleep timers
- Line-in and TV input switching
- Home theater configuration
- Surround speakers and subwoofer control
- Music library updates

### Music Services
- Search and play from music services (limited support)
- TuneIn radio
- Saved favorites

## Architecture

This library follows the same architecture as the Python SoCo:

- **Core**: Main `SoCo` class for speaker control
- **Discovery**: Network discovery of Sonos devices
- **Services**: Low-level access to UPnP/SOAP services
- **Data Structures**: Type-safe models for tracks, albums, playlists, etc.
- **Events**: Stream-based event system for state changes
- **Music Services**: Integration with streaming services
- **Plugins**: Extensible plugin system

## Differences from Python SoCo

While we aim to maintain API compatibility where possible, this Dart port makes some adaptations:

- **Async/Await**: All I/O operations are async and return `Future`s
- **Streams**: Events use Dart `Stream`s instead of callbacks
- **Null Safety**: Full null-safety support
- **Naming**: Uses Dart naming conventions (camelCase instead of snake_case)
- **Immutable Data**: Prefers immutable data structures
- **Type Safety**: Leverages Dart's strong type system

## Examples

See the [example/](example/) directory for more comprehensive examples:

- Basic speaker control
- Discovery and grouping
- Queue management
- Event handling
- Plugin usage

## Project Status

This is a complete Dart port of the Python SoCo library.

**Release Stats:**
- 18 core modules fully ported
- 5 music service modules
- 4 plugin modules
- 21 test modules with 567+ unit tests
- 80% code coverage
- 7 comprehensive examples
- Zero analyzer warnings

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## Requirements

- Dart SDK 3.9.2 or higher
- Sonos speakers on your local network

## Testing

Run tests with:

```bash
dart test
```

## Contributing

Contributions are welcome! This is a port of the Python SoCo library, so we aim to maintain feature parity while following Dart best practices.

Please see [AGENTS.md](AGENTS.md) for development guidelines.

## Related Projects

- **[SoCo (Python)](https://github.com/SoCo/SoCo)** - The original Python library
- **[Socos](https://github.com/SoCo/socos)** - Command-line tool for Sonos (Python)
- **[SoCo-CLI](https://github.com/avantrec/soco-cli)** - Full-featured CLI tool (Python)

## Support

For questions and discussions:
- Open an issue on GitHub
- Check the [Python SoCo documentation](https://soco.readthedocs.org/) for API reference

## License

SoCo is released under the [MIT License](LICENSE).

This Dart port maintains the same license as the original Python library.

## Acknowledgments

- **Rahim Sonawalla** - Original SoCo creator
- **SoCo Contributors** - Python SoCo library maintainers and contributors
- **Sonos** - For creating the speaker ecosystem (though this is an unofficial library)

## Disclaimer

This library is not affiliated with or endorsed by Sonos, Inc. It is an independent open-source project.
