# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial Dart port of Python SoCo library
- Core SoCo class with 120+ methods for speaker control
- Device discovery via SSDP multicast and network scanning
- Playback control (play, pause, stop, next, previous, seek)
- Volume and audio controls (volume, mute, bass, treble, loudness)
- Queue management (get, add, remove, clear, reorder)
- Group/zone management (join, unjoin, party mode)
- Music library browsing and searching
- Alarm management with full CRUD operations
- State snapshot and restore functionality
- UPnP event subscriptions with Dart Streams
- Advanced speaker settings (night mode, dialog mode, surround, subwoofer, etc.)
- Sleep timer and battery info support
- DIDL-Lite metadata structures
- 72 unit tests covering core functionality
- 3 working examples with documentation
- Comprehensive README and project documentation

## [0.1.0-dev] - 2025-11-10

### Initial Development Release

First development release of the SoCo Dart port. Core functionality is complete
and working, but not yet ready for production use.

**What's Working:**
- All core Sonos control features
- Device discovery, playback, volume, queue, groups
- Alarms, snapshots, events, advanced settings

**What's Pending:**
- Music service integrations
- Plugin system
- Full test coverage
- Publication to pub.dev

**Project Statistics:**
- 21 source modules (~9,700 lines)
- 72 passing unit tests
- Zero analyzer warnings

[Unreleased]: https://github.com/shorn/soco-dart/compare/v0.1.0-dev...HEAD
[0.1.0-dev]: https://github.com/shorn/soco-dart/releases/tag/v0.1.0-dev
