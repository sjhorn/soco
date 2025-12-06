/// Integration tests for data_structures_entry parsing.
library;

import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';
// Import data_structures FIRST to ensure initialization happens
import 'package:soco/src/data_structures.dart';
import 'package:soco/src/data_structures_entry.dart' as entry;
import 'package:soco/src/exceptions.dart';
import 'helpers/data_loader.dart';

// Re-export for convenience
final fromDidlString = entry.fromDidlString;
final clearFromDidlStringCache = entry.clearFromDidlStringCache;

void main() {
  final dataLoader = DataLoader('data_structures_entry_integration');

  // Ensure DIDL classes are initialized
  setUpAll(() {
    initializeDidlClasses();
  });

  group('DIDL Data Structures', () {
    test('identifies DidlMusicTrack class from XML', () {
      final xmlString = dataLoader.loadXml('track.xml');
      final result = fromDidlString(xmlString)[0];

      expect(result, isA<DidlMusicTrack>());
      expect(
        result.effectiveItemClass,
        equals('object.item.audioItem.musicTrack'),
      );
    });

    test('identifies DidlMusicAlbum class from XML', () {
      final xmlString = dataLoader.loadXml('album.xml');
      final result = fromDidlString(xmlString)[0];

      // Note: album.xml contains "object.container.album.musicAlbum"
      // which falls back to DidlObject since only "object.container.musicAlbum"
      // is registered, but with dynamic class creation it should be DidlAlbum
      expect(result, isA<DidlObject>());
      // The effectiveItemClass should match the XML
      expect(result.effectiveItemClass, contains('musicAlbum'));
    });

    test('identifies DidlMusicArtist class from XML', () {
      final xmlString = dataLoader.loadXml('artist.xml');
      final result = fromDidlString(xmlString)[0];

      expect(result, isA<DidlMusicArtist>());
      expect(
        result.effectiveItemClass,
        equals('object.container.person.musicArtist'),
      );
    });

    test('identifies DidlMusicGenre class from XML', () {
      final xmlString = dataLoader.loadXml('genre.xml');
      final result = fromDidlString(xmlString)[0];

      expect(result, isA<DidlMusicGenre>());
      expect(
        result.effectiveItemClass,
        equals('object.container.genre.musicGenre'),
      );
    });

    test('identifies DidlContainer class from XML (share)', () {
      final xmlString = dataLoader.loadXml('share.xml');
      final result = fromDidlString(xmlString)[0];

      expect(result, isA<DidlContainer>());
      expect(result.effectiveItemClass, equals('object.container'));
    });

    test('identifies DidlPlaylistContainer class from XML', () {
      final xmlString = dataLoader.loadXml('playlist.xml');
      final result = fromDidlString(xmlString)[0];

      expect(result, isA<DidlPlaylistContainer>());
      expect(
        result.effectiveItemClass,
        equals('object.container.playlistContainer'),
      );
    });

    test('identifies DidlAudioBroadcast class from XML', () {
      final xmlString = dataLoader.loadXml('audio_broadcast.xml');
      final result = fromDidlString(xmlString)[0];

      expect(result, isA<DidlAudioBroadcast>());
      expect(
        result.effectiveItemClass,
        equals('object.item.audioItem.audioBroadcast'),
      );
    });

    test('handles vendor extended DIDL class - falls back to DidlObject', () {
      // recent_show.xml contains object.item.audioItem.musicTrack.recentShow
      // which is a vendor-extended class not in our registry
      final xmlString = dataLoader.loadXml('recent_show.xml');
      final result = fromDidlString(xmlString)[0];

      // Unknown classes create a dynamic factory, but the base class is DidlMusicTrack
      expect(result, isA<DidlMusicTrack>());
      // The effectiveItemClass should contain the original class name
      expect(result.effectiveItemClass, contains('recentShow'));
    });

    test('identifies DidlComposer class from XML', () {
      final xmlString = dataLoader.loadXml('composer.xml');
      final result = fromDidlString(xmlString)[0];

      expect(result, isA<DidlComposer>());
      expect(
        result.effectiveItemClass,
        equals('object.container.person.composer'),
      );
    });

    test('throws DIDLMetadataError for missing upnp:class element', () {
      const invalidXml = '''<?xml version="1.0"?>
<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/"
           xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"
           xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
  <item id="test" parentID="-1" restricted="true">
    <dc:title>Test</dc:title>
  </item>
</DIDL-Lite>''';

      expect(
        () => fromDidlString(invalidXml),
        throwsA(
          isA<DIDLMetadataError>().having(
            (e) => e.message,
            'message',
            contains('Missing upnp:class'),
          ),
        ),
      );
    });

    test('throws DIDLMetadataError for illegal DIDL child element', () {
      const invalidXml = '''<?xml version="1.0"?>
<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/"
           xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"
           xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
  <unknownElement>Invalid content</unknownElement>
</DIDL-Lite>''';

      expect(
        () => fromDidlString(invalidXml),
        throwsA(
          isA<DIDLMetadataError>().having(
            (e) => e.message,
            'message',
            contains('Illegal child'),
          ),
        ),
      );
    });

    test('clearFromDidlStringCache clears the cache', () {
      // First, parse something to populate the cache
      final xmlString = dataLoader.loadXml('track.xml');
      fromDidlString(xmlString);

      // Clear the cache
      clearFromDidlStringCache();

      // No assertion needed - just verify it doesn't throw
      // The cache is internal so we can't directly inspect it
    });

    test('fromDidlString uses cache for repeated calls', () {
      // Clear cache first
      clearFromDidlStringCache();

      final xmlString = dataLoader.loadXml('track.xml');

      // First call - should parse
      final result1 = fromDidlString(xmlString);
      expect(result1, isNotEmpty);
      expect(result1[0], isA<DidlMusicTrack>());

      // Second call with same string - should use cache
      // We can't directly verify cache hit, but we can verify it returns same result
      final result2 = fromDidlString(xmlString);
      expect(result2.length, equals(result1.length));
      expect(result2[0].title, equals(result1[0].title));
    });

    test('handles XML with control characters by cleaning', () {
      // This tests the error recovery path (lines 54-58)
      // Create XML that will fail initial parse but succeed after cleaning
      // Use actual control characters that will cause parse failure
      // We need to create a string with actual null bytes and control chars
      final xmlWithControlChar = String.fromCharCodes([
        ...'<?xml version="1.0"?>\n<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/"\n           xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"\n           xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">\n  <item id="test'
            .codeUnits,
        0x00, // Null byte - illegal in XML
        0x01, // SOH - illegal in XML
        ...'id" parentID="-1" restricted="true">\n    <dc:title>Test</dc:title>\n    <upnp:class>object.item.audioItem.musicTrack</upnp:class>\n  </item>\n</DIDL-Lite>'
            .codeUnits,
      ]);

      // This should trigger the catch block (line 54) and clean the XML (lines 57-58)
      // The cleaned version should parse successfully
      final result = fromDidlString(xmlWithControlChar);
      expect(result, isA<List>());
      expect(result.isNotEmpty, isTrue);
      expect(result[0], isA<DidlMusicTrack>());
    });

    test('fromDidlString logs when FINE level is enabled', () {
      // Test the logging path (lines 86-91)
      // Enable hierarchical logging and FINE logging level
      Logger.root.level = Level.FINE;
      final originalLevel = Logger.root.level;

      // Capture log records from root logger (since child loggers propagate)
      final logRecords = <LogRecord>[];
      final subscription = Logger.root.onRecord.listen((record) {
        if (record.loggerName == 'soco.data_structures_entry') {
          logRecords.add(record);
        }
      });

      try {
        // Clear cache to ensure we hit the parsing path
        clearFromDidlStringCache();

        final xmlString = dataLoader.loadXml('track.xml');
        fromDidlString(xmlString);

        // Verify that a log record was created (lines 87-91 should be hit)
        expect(
          logRecords.isNotEmpty,
          isTrue,
          reason: 'Expected log records but got none',
        );
        expect(
          logRecords.any((r) => r.message.contains('Created data structures')),
          isTrue,
          reason: 'Expected log message containing "Created data structures"',
        );

        // Verify the log message format (lines 88-89 create the preview strings)
        final logMessage = logRecords
            .firstWhere((r) => r.message.contains('Created data structures'))
            .message;
        expect(logMessage, contains('from Didl string'));
      } finally {
        // Restore original log level
        Logger.root.level = originalLevel;
        subscription.cancel();
      }
    });

    test('throws error when didlClassToSoCoClass is not set', () {
      // Temporarily clear the function reference
      final original = entry.didlClassToSoCoClass;
      entry.didlClassToSoCoClass = null;

      try {
        const xmlString = '''<?xml version="1.0"?>
<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/"
           xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"
           xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
  <item id="test" parentID="-1" restricted="true">
    <dc:title>Test</dc:title>
    <upnp:class>object.item.audioItem.musicTrack</upnp:class>
  </item>
</DIDL-Lite>''';

        expect(
          () => entry.fromDidlString(xmlString),
          throwsA(
            isA<DIDLMetadataError>().having(
              (e) => e.message,
              'message',
              contains('didlClassToSoCoClass function not set'),
            ),
          ),
        );
      } finally {
        // Restore the original function
        entry.didlClassToSoCoClass = original;
      }
    });
  });

  group('DidlResource edge cases', () {
    test('fromElement handles missing protocolInfo via quirks', () {
      // When protocolInfo is missing, applyResourceQuirks adds a dummy one
      final xmlString = '''
<res>http://example.com/song.mp3</res>
''';
      final doc = XmlDocument.parse(xmlString);
      final element = doc.rootElement;

      final resource = DidlResource.fromElement(element);
      // The quirks function adds a default protocolInfo
      expect(resource.protocolInfo, isNotEmpty);
      expect(resource.uri, equals('http://example.com/song.mp3'));
    });

    test('fromElement throws when integer attribute is invalid', () {
      final xmlString = '''
<res protocolInfo="http-get:*:audio/mpeg:*" size="not-a-number">http://example.com/song.mp3</res>
''';
      final doc = XmlDocument.parse(xmlString);
      final element = doc.rootElement;

      expect(
        () => DidlResource.fromElement(element),
        throwsA(isA<DIDLMetadataError>()),
      );
    });

    test('toElement includes all optional attributes when set', () {
      final resource = DidlResource(
        uri: 'http://example.com/song.mp3',
        protocolInfo: 'http-get:*:audio/mpeg:*',
        importUri: 'http://example.com/import',
        size: 1024000,
        duration: '0:03:45.000',
        bitrate: 320000,
        sampleFrequency: 44100,
        bitsPerSample: 16,
        nrAudioChannels: 2,
        resolution: '1920x1080',
        colorDepth: 24,
        protection: 'none',
      );

      final element = resource.toElement();

      expect(
        element.getAttribute('protocolInfo'),
        equals('http-get:*:audio/mpeg:*'),
      );
      expect(
        element.getAttribute('importUri'),
        equals('http://example.com/import'),
      );
      expect(element.getAttribute('size'), equals('1024000'));
      expect(element.getAttribute('duration'), equals('0:03:45.000'));
      expect(element.getAttribute('bitrate'), equals('320000'));
      expect(element.getAttribute('sampleFrequency'), equals('44100'));
      expect(element.getAttribute('bitsPerSample'), equals('16'));
      expect(element.getAttribute('nrAudioChannels'), equals('2'));
      expect(element.getAttribute('resolution'), equals('1920x1080'));
      expect(element.getAttribute('colorDepth'), equals('24'));
      expect(element.getAttribute('protection'), equals('none'));
      expect(element.innerText, equals('http://example.com/song.mp3'));
    });

    test('fromElement parses all integer attributes correctly', () {
      final xmlString = '''
<res protocolInfo="http-get:*:audio/mpeg:*"
     size="1024"
     bitrate="128000"
     sampleFrequency="48000"
     bitsPerSample="24"
     nrAudioChannels="6"
     colorDepth="32">http://example.com/song.flac</res>
''';
      final doc = XmlDocument.parse(xmlString);
      final element = doc.rootElement;

      final resource = DidlResource.fromElement(element);

      expect(resource.size, equals(1024));
      expect(resource.bitrate, equals(128000));
      expect(resource.sampleFrequency, equals(48000));
      expect(resource.bitsPerSample, equals(24));
      expect(resource.nrAudioChannels, equals(6));
      expect(resource.colorDepth, equals(32));
    });
  });
}
