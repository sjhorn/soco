# CLAUDE.md - SoCo Dart Port

See [AGENTS.md](AGENTS.md) for project conventions and setup.

## Project Status

**Dart port of Python SoCo library** - controlling Sonos speakers programmatically.

### Completed (Phase 2 Complete ✅)

**Core Modules (18/18):**
- ✅ exceptions, config, xml, utils, cache, soap
- ✅ services (UPnP/SOAP abstractions)
- ✅ data_structures, data_structures_entry, data_structure_quirks
- ✅ ms_data_structures (music service data structures)
- ✅ core (120+ methods - playback, volume, queue, groups, home theater, etc.)
- ✅ discovery (SSDP multicast + network scanning)
- ✅ groups, zonegroupstate (zone group management)
- ✅ music_library (search/browse functionality)
- ✅ alarms (alarm management)
- ✅ snapshot (state capture/restore)
- ✅ events_base, events (UPnP subscriptions with Dart Streams)

**Music Services (5/5):**
- ✅ accounts, token_store, data_structures, music_service, music_services

**Plugins (4/5):**
- ✅ plugins base, example, plex, sharelink
- ⏸️ wimp.dart - deferred (complex legacy service)
- ⏭️ spotify.py - skipped (deprecated in Python SoCo)

**Tests (207 passing):**
- ✅ xml, utils, soap, alarms, cache, singleton, events, core_basic
- ✅ sharelink (37 tests), data_structures_entry (9 tests), groups (10 tests)
- ✅ snapshot (19 tests), zonegroupstate (17 tests), music_library (27 tests)

**Examples (7 complete):**
- ✅ basic_discovery, playback_control, snapshot, alarms, groups, music_library, events

### Current Focus

The port is functionally complete for core Sonos control. Remaining work:

1. **Test Coverage** - Add tests requiring HTTP mocking:
   - discovery_test.dart
   - services_test.dart
   - snapshot_test.dart
   - music_library_test.dart

2. **Documentation** - Dartdoc comments for public APIs

3. **Publishing** - Prepare for pub.dev release

### Quick Commands

```bash
dart pub get          # Install dependencies
dart analyze          # Check for issues (should be zero)
dart format .         # Format code
dart test             # Run tests (207 should pass)
```

### Python Source Reference

Python SoCo source is in `./SoCo/soco/` for reference during porting.

### Key Files

- `lib/soco.dart` - Main library export
- `lib/src/core.dart` - Main SoCo class (2390 lines)
- `lib/src/discovery.dart` - Device discovery (710 lines)
- `lib/src/events.dart` - UPnP event subscriptions (440 lines)
- `TODO.md` - Detailed progress tracking
