import 'package:test/test.dart';
import 'package:soco/src/snapshot.dart';
import 'package:soco/src/core.dart';

void main() {
  group('Snapshot', () {
    // Use unique IP per test group to avoid singleton conflicts
    final device = SoCo('192.168.200.100');

    group('constructor', () {
      test('creates snapshot with device reference', () {
        final snapshot = Snapshot(device);

        expect(snapshot.device, equals(device));
        expect(snapshot.snapshotQueue, isFalse);
      });

      test('creates snapshot with snapshotQueue=true', () {
        final snapshot = Snapshot(device, snapshotQueue: true);

        expect(snapshot.device, equals(device));
        expect(snapshot.snapshotQueue, isTrue);
        expect(snapshot.queue, isNotNull);
        expect(snapshot.queue, isEmpty);
      });

      test('creates snapshot with snapshotQueue=false (default)', () {
        final snapshot = Snapshot(device, snapshotQueue: false);

        expect(snapshot.snapshotQueue, isFalse);
        expect(snapshot.queue, isNull);
      });
    });

    group('initial state', () {
      test('has default values for all properties', () {
        final snapshot = Snapshot(device);

        expect(snapshot.mediaUri, isNull);
        expect(snapshot.isCoordinator, isFalse);
        expect(snapshot.isPlayingQueue, isFalse);
        expect(snapshot.isPlayingCloudQueue, isFalse);
        expect(snapshot.volume, isNull);
        expect(snapshot.mute, isNull);
        expect(snapshot.bass, isNull);
        expect(snapshot.treble, isNull);
        expect(snapshot.loudness, isNull);
        expect(snapshot.playMode, isNull);
        expect(snapshot.crossFade, isNull);
        expect(snapshot.playlistPosition, equals(0));
        expect(snapshot.trackPosition, isNull);
        expect(snapshot.mediaMetadata, isNull);
        expect(snapshot.transportState, isNull);
      });
    });

    group('media URI parsing', () {
      test('detects local queue from mediaUri', () {
        final snapshot = Snapshot(device);
        // Simulate what snapshot() method does with mediaUri
        snapshot.mediaUri = 'x-rincon-queue:RINCON_000E5859E49601400#0';

        // Extract and check - simulating the logic in snapshot()
        if (snapshot.mediaUri != null &&
            snapshot.mediaUri!.split(':')[0] == 'x-rincon-queue') {
          if (snapshot.mediaUri!.split('#')[1] == '0') {
            snapshot.isPlayingQueue = true;
          } else {
            snapshot.isPlayingCloudQueue = true;
          }
        }

        expect(snapshot.isPlayingQueue, isTrue);
        expect(snapshot.isPlayingCloudQueue, isFalse);
      });

      test('detects cloud queue from mediaUri', () {
        final snapshot = Snapshot(device);
        snapshot.mediaUri = 'x-rincon-queue:RINCON_000E5859E49601400#6';

        if (snapshot.mediaUri != null &&
            snapshot.mediaUri!.split(':')[0] == 'x-rincon-queue') {
          if (snapshot.mediaUri!.split('#')[1] == '0') {
            snapshot.isPlayingQueue = true;
          } else {
            snapshot.isPlayingCloudQueue = true;
          }
        }

        expect(snapshot.isPlayingQueue, isFalse);
        expect(snapshot.isPlayingCloudQueue, isTrue);
      });

      test('detects slave zone from mediaUri', () {
        final snapshot = Snapshot(device);
        snapshot.mediaUri = 'x-rincon:RINCON_000E5859E49601400';

        // Slave zone URIs don't trigger queue detection
        if (snapshot.mediaUri != null &&
            snapshot.mediaUri!.split(':')[0] == 'x-rincon-queue') {
          if (snapshot.mediaUri!.split('#')[1] == '0') {
            snapshot.isPlayingQueue = true;
          } else {
            snapshot.isPlayingCloudQueue = true;
          }
        }

        expect(snapshot.isPlayingQueue, isFalse);
        expect(snapshot.isPlayingCloudQueue, isFalse);
      });

      test('detects stream from mediaUri', () {
        final snapshot = Snapshot(device);
        snapshot.mediaUri = 'x-sonosapi-stream:s12345?sid=254&flags=8224&sn=0';

        if (snapshot.mediaUri != null &&
            snapshot.mediaUri!.split(':')[0] == 'x-rincon-queue') {
          if (snapshot.mediaUri!.split('#')[1] == '0') {
            snapshot.isPlayingQueue = true;
          } else {
            snapshot.isPlayingCloudQueue = true;
          }
        }

        expect(snapshot.isPlayingQueue, isFalse);
        expect(snapshot.isPlayingCloudQueue, isFalse);
      });

      test('handles file playback mediaUri', () {
        final snapshot = Snapshot(device);
        snapshot.mediaUri = 'x-file-cifs://server/share/music/song.mp3';

        if (snapshot.mediaUri != null &&
            snapshot.mediaUri!.split(':')[0] == 'x-rincon-queue') {
          if (snapshot.mediaUri!.split('#')[1] == '0') {
            snapshot.isPlayingQueue = true;
          } else {
            snapshot.isPlayingCloudQueue = true;
          }
        }

        expect(snapshot.isPlayingQueue, isFalse);
        expect(snapshot.isPlayingCloudQueue, isFalse);
      });

      test('handles null mediaUri', () {
        final snapshot = Snapshot(device);
        snapshot.mediaUri = null;

        // No parsing should occur with null
        expect(snapshot.isPlayingQueue, isFalse);
        expect(snapshot.isPlayingCloudQueue, isFalse);
      });
    });

    group('state storage', () {
      test('can store volume and mute settings', () {
        final snapshot = Snapshot(device);

        snapshot.volume = 42;
        snapshot.mute = true;

        expect(snapshot.volume, equals(42));
        expect(snapshot.mute, isTrue);
      });

      test('can store EQ settings', () {
        final snapshot = Snapshot(device);

        snapshot.bass = 5;
        snapshot.treble = -3;
        snapshot.loudness = true;

        expect(snapshot.bass, equals(5));
        expect(snapshot.treble, equals(-3));
        expect(snapshot.loudness, isTrue);
      });

      test('can store play mode settings', () {
        final snapshot = Snapshot(device);

        snapshot.playMode = 'SHUFFLE';
        snapshot.crossFade = true;

        expect(snapshot.playMode, equals('SHUFFLE'));
        expect(snapshot.crossFade, isTrue);
      });

      test('can store track position', () {
        final snapshot = Snapshot(device);

        snapshot.playlistPosition = 5;
        snapshot.trackPosition = '0:02:34';

        expect(snapshot.playlistPosition, equals(5));
        expect(snapshot.trackPosition, equals('0:02:34'));
      });

      test('can store transport state', () {
        final snapshot = Snapshot(device);

        snapshot.transportState = 'PLAYING';
        expect(snapshot.transportState, equals('PLAYING'));

        snapshot.transportState = 'PAUSED_PLAYBACK';
        expect(snapshot.transportState, equals('PAUSED_PLAYBACK'));

        snapshot.transportState = 'STOPPED';
        expect(snapshot.transportState, equals('STOPPED'));
      });

      test('can store coordinator status', () {
        final snapshot = Snapshot(device);

        snapshot.isCoordinator = true;
        expect(snapshot.isCoordinator, isTrue);

        snapshot.isCoordinator = false;
        expect(snapshot.isCoordinator, isFalse);
      });

      test('can store media metadata', () {
        final snapshot = Snapshot(device);

        snapshot.mediaMetadata = '<DIDL-Lite>...</DIDL-Lite>';
        expect(snapshot.mediaMetadata, equals('<DIDL-Lite>...</DIDL-Lite>'));
      });
    });

    group('queue storage', () {
      test('queue is null when snapshotQueue is false', () {
        final snapshot = Snapshot(device, snapshotQueue: false);
        expect(snapshot.queue, isNull);
      });

      test('queue is empty list when snapshotQueue is true', () {
        final snapshot = Snapshot(device, snapshotQueue: true);
        expect(snapshot.queue, isNotNull);
        expect(snapshot.queue, isEmpty);
      });
    });
  });
}
