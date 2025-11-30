# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-11-30

### Initial Release

First public release of the SoCo Dart port. This is a complete port of the Python
[SoCo library](https://github.com/SoCo/SoCo), providing programmatic control of
Sonos speakers from Dart applications.

### Added

#### Core Features
- **SoCo class** with 120+ methods for comprehensive speaker control
- **Device discovery** via SSDP multicast and network scanning
- **Playback control**: play, pause, stop, next, previous, seek, play from queue
- **Volume & audio**: volume, mute, bass, treble, loudness, balance
- **Queue management**: get, add, remove, clear, reorder queue items
- **Group management**: join, unjoin, party mode, zone groups
- **Music library**: browse and search local music library
- **Alarms**: full CRUD operations for Sonos alarms
- **Snapshot/restore**: save and restore speaker state
- **Events**: UPnP subscriptions with Dart Streams
- **Sleep timer** and **battery info** support

#### Advanced Features
- **Home theater**: night mode, dialog mode, audio delay
- **Surround speakers**: enable/disable, volume control
- **Subwoofer**: enable/disable, gain, crossover settings
- **Stereo pairs**: create and separate stereo pairs
- **Trueplay** and **fixed volume** support
- **Line-in** and **TV input** switching

#### Music Services
- Music service accounts management
- Token store for service authentication
- Service-specific data structures
- Music service browsing and playback

#### Plugins
- Plugin system base infrastructure
- **ShareLink plugin**: Share music links across services
- **Plex plugin**: Plex media server integration
- Example plugin template

#### Data Structures
- DIDL-Lite metadata classes (tracks, albums, artists, playlists)
- Search results with pagination
- Zone group and zone member structures
- Alarm and snapshot data models

### Project Statistics
- **18 core modules** fully ported
- **5 music service modules**
- **4 plugin modules**
- **21 test modules** with 567+ unit tests
- **80% code coverage** (1843/2304 lines)
- **7 comprehensive examples**
- **Zero analyzer warnings**

### Differences from Python SoCo
- All I/O operations are async (`Future`-based)
- Events use Dart `Stream`s instead of callbacks
- Full null-safety support
- Dart naming conventions (camelCase)
- Immutable data structures where appropriate

## [Unreleased]

### Planned
- Additional music service integrations
- Performance optimizations
- More comprehensive documentation

[0.1.0]: https://github.com/shorn/soco-dart/releases/tag/v0.1.0
[Unreleased]: https://github.com/shorn/soco-dart/compare/v0.1.0...HEAD
