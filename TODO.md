# SoCo Dart Port - TODO

## Status

**Published:** [soco v0.1.1](https://pub.dev/packages/soco)

| Metric | Python SoCo | Dart Port |
|--------|-------------|-----------|
| Source files | 34 | 32 |
| Source lines | ~28,000 | ~22,000 |
| Test files | 20 | 22 |
| Unit tests | - | 838 |
| Code coverage | - | 81% |
| Examples | - | 7 |
| Integration tested | - | ✓ |

---

## Porting Status

### Core Modules (18/18) ✓

| Python Source | Dart Port | Status |
|---------------|-----------|--------|
| `exceptions.py` | `exceptions.dart` | ✓ |
| `config.py` | `config.dart` | ✓ |
| `xml.py` | `xml.dart` | ✓ |
| `utils.py` | `utils.dart` | ✓ |
| `cache.py` | `cache.dart` | ✓ |
| `soap.py` | `soap.dart` | ✓ |
| `services.py` | `services.dart` | ✓ |
| `data_structures.py` | `data_structures.dart` | ✓ |
| `data_structures_entry.py` | `data_structures_entry.dart` | ✓ |
| `data_structure_quirks.py` | `data_structure_quirks.dart` | ✓ |
| `ms_data_structures.py` | `ms_data_structures.dart` | ✓ |
| `core.py` | `core.dart` | ✓ |
| `discovery.py` | `discovery.dart` | ✓ |
| `groups.py` | `groups.dart` | ✓ |
| `zonegroupstate.py` | `zonegroupstate.dart` | ✓ |
| `music_library.py` | `music_library.dart` | ✓ |
| `alarms.py` | `alarms.dart` | ✓ |
| `snapshot.py` | `snapshot.dart` | ✓ |

### Events System (2/4) ✓

| Python Source | Dart Port | Status |
|---------------|-----------|--------|
| `events_base.py` | `events_base.dart` | ✓ |
| `events.py` | `events.dart` | ✓ |
| `events_asyncio.py` | - | Skipped (Dart is async) |
| `events_twisted.py` | - | Skipped (not applicable) |

### Music Services (5/5) ✓

| Python Source | Dart Port | Status |
|---------------|-----------|--------|
| `__init__.py` | `music_services.dart` | ✓ |
| `accounts.py` | `accounts.dart` | ✓ |
| `token_store.py` | `token_store.dart` | ✓ |
| `data_structures.py` | `data_structures.dart` | ✓ |
| `music_service.py` | `music_service.dart` | ✓ |

### Plugins (5/5) ✓

| Python Source | Dart Port | Status |
|---------------|-----------|--------|
| `__init__.py` | `plugins.dart` | ✓ |
| `example.py` | `example.dart` | ✓ |
| `plex.py` | `plex.dart` | ✓ |
| `sharelink.py` | `sharelink.dart` | ✓ |
| `wimp.py` | `wimp.dart` | ✓ |
| `spotify.py` | - | Skipped (deprecated) |

---

## Future Work

### Code TODOs

**Core Module** (`lib/src/core.dart`):
- ~~Voice assistant methods (placeholder): `voiceServiceConfigured`, `micEnabled`, `setMicEnabled`~~ ✓
- ~~Playlist/favorites methods (~20 methods): `getSonosPlaylists`, `createSonosPlaylist`, etc.~~ ✓
- ~~Enhanced radio/DIDL metadata parsing~~ ✓
- ~~More robust queue item metadata extraction~~ ✓

**Services Module** (`lib/src/services.dart`):
- ~~Full SCPD document parsing for service introspection~~ ✓

**Data Structures** (`lib/src/data_structures.dart`):
- ~~Dynamic class creation for unknown DIDL types~~ ✓
- ~~Implement fromElement factory methods in data structures~~ ✓

**Music Services** (`lib/src/music_services/music_service.dart`):
- ~~Improved XML response parsing~~ ✓

### Deferred

- ~~Performance benchmarking~~ ✓ (benchmark script created)

### Completed

- ✓ Integration tests with real Sonos devices (v0.1.1)
- ✓ Fixed UPnP service control URLs for real hardware compatibility
- ✓ Fixed getSpeakerInfo caching with ZoneGroupState data
- ✓ Implemented voice assistant methods: `voiceServiceConfigured`, `micEnabled`, `setMicEnabled` (placeholder)
- ✓ Implemented playlist/favorites methods (11 methods)
- ✓ Enhanced DIDL metadata parsing in `getCurrentTrackInfo()` and `getCurrentMediaInfo()`
- ✓ Enhanced `getQueue()` to parse DIDL strings and return proper QueueResult with items
- ✓ Fixed zonegroupstate test timeout issue with proper async exception testing
- ✓ Implemented SCPD document parsing for service introspection (actions and event variables)
- ✓ Improved XML response parsing in music services (converts XmlElement to Map structure)
- ✓ Implemented dynamic class creation for unknown DIDL types (registry pattern with factory functions)
- ✓ Implemented fromElement factory methods in all DIDL classes - fromDidlString now returns proper DidlObject instances
- ✓ Refactored playUri() and addUriToQueue() to use proper DidlResource and DidlObject instead of manual XML strings
- ✓ Created performance benchmarking script (benchmark/benchmark.dart) - measures DIDL parsing, object creation, and serialization performance
- ✓ Fixed data_structures_entry_test.dart - updated tests to expect DidlObject instances instead of Maps after fromElement implementation

*Note: Coverage target of 80% achieved! Integration testing with real Sonos hardware validated all core functionality.

---

## Quick Reference

```bash
dart pub get          # Install dependencies
dart analyze          # Check for issues (should be zero)
dart format .         # Format code
dart test             # Run tests (838 tests)
dart pub publish      # Publish to pub.dev
```
