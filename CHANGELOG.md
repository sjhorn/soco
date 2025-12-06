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

## [0.1.1] - 2025-11-30

### Fixed

- **UPnP Service Control URLs**: Fixed incorrect control URLs that caused HTTP 405 errors
  when communicating with real Sonos hardware. Services now use correct paths:
  - RenderingControl: `/MediaRenderer/RenderingControl/Control`
  - AVTransport: `/MediaRenderer/AVTransport/Control`
  - ContentDirectory: `/MediaServer/ContentDirectory/Control`
  - And other services with appropriate prefixes

- **getSpeakerInfo Caching**: Fixed issue where `getSpeakerInfo()` would return
  incomplete data after device discovery. The method now correctly fetches speaker
  info even when ZoneGroupState data is already present.

### Added

- **Integration Test Suite**: Added comprehensive integration test (`test_integration.dart`)
  that validates all core functionality against real Sonos hardware:
  - Discovery (11 devices found)
  - Volume and mute controls
  - Transport state and track info
  - Speaker info (zone name, model, versions)
  - Group operations (coordinator, members, all groups)
  - Play mode (shuffle, repeat)
  - Audio settings (bass, treble, loudness)
  - Sleep timer and available actions
  - TV/Line-in/Radio detection
  - Music library browsing
  - Zone enumeration (all zones, visible zones)

### Changed

- Updated `services.dart` with proper `eventSubscriptionUrl` and `defaultArgs`
  for all UPnP services to match Python SoCo implementation

## [0.1.2] - 2025-12-01

### Performance Improvements

- **XML Serialization Optimizations**: Significant performance improvements for DIDL-Lite XML operations:
  - Direct XML builder usage (`toElementInBuilder`) avoids intermediate object creation
  - Pre-computed namespace tags for common DIDL elements (dc:title, upnp:class, etc.)
  - Optimized child element lookup using pre-built maps instead of repeated tree traversal
  - Pre-computed translation lookup keys for faster metadata extraction
  - Conditional logging to eliminate overhead when logging is disabled
  - Cache key optimization using hash codes instead of full strings

- **Performance Benchmarks**: Added comprehensive benchmark suite (`benchmark/benchmark.dart`) comparing Dart vs Python SoCo:
  - DIDL to String: **50% faster** (~30K ops/sec vs ~20K ops/sec baseline)
  - Round-trip (parse → serialize): **84% faster** (~83K ops/sec vs ~45K ops/sec baseline)
  - fromElement: Maintained high performance (~151K ops/sec)
  - Round-trip operations now **2x faster** than Python SoCo

### Added

- **Performance Benchmark Suite**: Added `benchmark/benchmark.dart` and `benchmark/benchmark_python.py` for performance comparison
- **Performance Documentation**: Added `benchmark/PERFORMANCE_COMPARISON.md` and `benchmark/OPTIMIZATION_NOTES.md` documenting optimizations

### Changed

- `DidlResource.toElementInBuilder()`: New optimized method for direct XML building
- `DidlObject.toElement()`: Now uses optimized boolean string conversion
- `fromDidlString()`: Improved error recovery using pre-compiled RegExp
- Metadata extraction: Uses pre-computed lookup keys for faster access

### Technical Details

- XML serialization now uses direct builder methods instead of parse/serialize cycles
- Child element collection optimized to single pass with map-based lookups
- Namespace tag generation uses pre-computed constants for common cases
- Translation lookup keys pre-computed at class initialization

[0.1.2]: https://github.com/sjhorn/soco/releases/tag/v0.1.2
[0.1.1]: https://github.com/sjhorn/soco/releases/tag/v0.1.1
[0.1.0]: https://github.com/sjhorn/soco/releases/tag/v0.1.0
[Unreleased]: https://github.com/sjhorn/soco/compare/v0.1.2...HEAD
