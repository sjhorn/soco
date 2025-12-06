/// Performance benchmarks for SoCo Dart library.
///
/// This script measures the performance of key operations:
/// - DIDL parsing (fromDidlString)
/// - XML parsing and serialization
/// - DIDL object creation and conversion
///
/// Run with: dart run benchmark/benchmark.dart

import 'package:xml/xml.dart';

import 'package:soco/src/data_structures.dart';
import 'package:soco/src/data_structures_entry.dart' as entry;

void main() async {
  print('SoCo Dart Performance Benchmarks\n');
  print('=' * 50);

  // Initialize DIDL classes
  initializeDidlClasses();
  entry.didlClassToSoCoClass = didlClassToSoCoClass;

  // Sample DIDL strings for benchmarking
  final simpleDidl = '''
<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" 
           xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" 
           xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" 
           xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
  <item id="1" parentID="0" restricted="true">
    <dc:title>Test Track</dc:title>
    <upnp:class>object.item.audioItem.musicTrack</upnp:class>
    <res protocolInfo="http-get:*:audio/mpeg:*">http://example.com/track.mp3</res>
  </item>
</DIDL-Lite>''';

  final complexDidl = '''
<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" 
           xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" 
           xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" 
           xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
  <item id="1" parentID="0" restricted="true">
    <dc:title>Test Track</dc:title>
    <dc:creator>Test Artist</dc:creator>
    <upnp:class>object.item.audioItem.musicTrack</upnp:class>
    <upnp:artist>Test Artist</upnp:artist>
    <upnp:album>Test Album</upnp:album>
    <upnp:originalTrackNumber>1</upnp:originalTrackNumber>
    <res protocolInfo="http-get:*:audio/mpeg:*">http://example.com/track.mp3</res>
  </item>
  <container id="2" parentID="0" restricted="true">
    <dc:title>Test Album</dc:title>
    <upnp:class>object.container.album.musicAlbum</upnp:class>
    <upnp:artist>Test Artist</upnp:artist>
  </container>
</DIDL-Lite>''';

  // Benchmark 1: Simple DIDL parsing
  print('\n1. Simple DIDL Parsing (fromDidlString)');
  print('-' * 50);
  await benchmark(
    'Parse simple DIDL (1000 iterations)',
    () => entry.fromDidlString(simpleDidl),
    iterations: 1000,
  );

  // Benchmark 2: Complex DIDL parsing
  print('\n2. Complex DIDL Parsing');
  print('-' * 50);
  await benchmark(
    'Parse complex DIDL (1000 iterations)',
    () => entry.fromDidlString(complexDidl),
    iterations: 1000,
  );

  // Benchmark 3: DIDL object creation
  print('\n3. DIDL Object Creation');
  print('-' * 50);
  await benchmark(
    'Create DidlMusicTrack (10000 iterations)',
    () {
      return DidlMusicTrack(
        title: 'Test Track',
        parentId: '0',
        itemId: '1',
        restricted: true,
        resources: [
          DidlResource(
            uri: 'http://example.com/track.mp3',
            protocolInfo: 'http-get:*:audio/mpeg:*',
          ),
        ],
        metadata: {
          'artist': 'Test Artist',
          'album': 'Test Album',
        },
      );
    },
    iterations: 10000,
  );

  // Benchmark 4: DIDL to string conversion
  print('\n4. DIDL to String Conversion (toDidlString)');
  print('-' * 50);
  final parsedObjects = entry.fromDidlString(complexDidl);
  await benchmark(
    'Convert DIDL objects to string (1000 iterations)',
    () => toDidlString(parsedObjects),
    iterations: 1000,
  );

  // Benchmark 5: Round-trip (parse -> create -> serialize)
  print('\n5. Round-trip Performance');
  print('-' * 50);
  await benchmark(
    'Parse -> Serialize round-trip (500 iterations)',
    () {
      final objects = entry.fromDidlString(complexDidl);
      return toDidlString(objects);
    },
    iterations: 500,
  );

  // Benchmark 6: fromElement performance
  print('\n6. fromElement Performance');
  print('-' * 50);
  final parsed = entry.fromDidlString(simpleDidl);
  if (parsed.isNotEmpty) {
    // Get the XML element from the parsed object (we'll need to parse again)
    final doc = XmlDocument.parse(simpleDidl);
    final element = doc.rootElement.childElements.first;
    await benchmark(
      'Create DidlObject from XML element (5000 iterations)',
      () => DidlObject.fromElement(element),
      iterations: 5000,
    );
  }

  print('\n' + '=' * 50);
  print('Benchmarks completed!');
}

/// Run a benchmark and print results.
Future<void> benchmark(
  String name,
  dynamic Function() operation, {
  int iterations = 1000,
  int warmupIterations = 100,
}) async {
  // Warmup
  for (int i = 0; i < warmupIterations; i++) {
    operation();
  }

  // Actual benchmark
  final stopwatch = Stopwatch()..start();
  for (int i = 0; i < iterations; i++) {
    operation();
  }
  stopwatch.stop();

  final totalMs = stopwatch.elapsedMilliseconds;
  final totalMicros = stopwatch.elapsedMicroseconds;
  final avgMs = totalMicros / iterations / 1000.0;
  final opsPerSec = totalMs > 0
      ? (iterations / totalMs * 1000).round()
      : (iterations / (totalMicros / 1000000.0)).round();

  print('$name:');
  print('  Total: ${totalMs}ms');
  print('  Average: ${avgMs.toStringAsFixed(3)}ms per operation');
  print('  Throughput: $opsPerSec ops/sec');
}

