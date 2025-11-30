// Test getMsItem XML parsing with namespaces
import 'package:xml/xml.dart';
import 'package:test/test.dart';
import 'package:soco/src/ms_data_structures.dart';

void main() {
  group('getMsItem with namespaced XML', () {
    test('parses track from namespaced XML', () {
      final xml = XmlDocument.parse('''
<?xml version="1.0" encoding="UTF-8"?>
<mediaMetadata xmlns="http://www.sonos.com/Services/1.1">
  <id>track_1</id>
  <itemType>track</itemType>
  <title>Test Song</title>
  <mimeType>audio/aac</mimeType>
  <trackMetadata>
    <artistId>artistid_1</artistId>
    <artist>Test Artist</artist>
    <albumId>albumid_1</albumId>
    <album>Test Album</album>
    <duration>180</duration>
    <canPlay>true</canPlay>
  </trackMetadata>
</mediaMetadata>''');

      // Mock service with required properties
      final mockService = _MockWimpService();
      final item = getMsItem(xml.rootElement, mockService, 'parent_123');

      expect(item, isA<MSTrack>());
      expect(item.title, equals('Test Song'));
    });

    test('parses album from namespaced XML', () {
      final xml = XmlDocument.parse('''
<?xml version="1.0" encoding="UTF-8"?>
<mediaCollection xmlns="http://www.sonos.com/Services/1.1">
  <id>album_123</id>
  <itemType>album</itemType>
  <title>Test Album</title>
  <artistId>artist_1</artistId>
  <artist>Test Artist</artist>
  <canPlay>true</canPlay>
</mediaCollection>''');

      final mockService = _MockWimpService();
      final item = getMsItem(xml.rootElement, mockService, 'parent_123');

      expect(item, isA<MSAlbum>());
      expect(item.title, equals('Test Album'));
    });

    test('parses artist from namespaced XML', () {
      final xml = XmlDocument.parse('''
<?xml version="1.0" encoding="UTF-8"?>
<mediaCollection xmlns="http://www.sonos.com/Services/1.1">
  <id>artist_123</id>
  <itemType>artist</itemType>
  <title>Test Artist</title>
  <canPlay>false</canPlay>
</mediaCollection>''');

      final mockService = _MockWimpService();
      final item = getMsItem(xml.rootElement, mockService, 'parent_123');

      expect(item, isA<MSArtist>());
      expect(item.title, equals('Test Artist'));
    });

    test('parses favorites from namespaced XML', () {
      final xml = XmlDocument.parse('''
<?xml version="1.0" encoding="UTF-8"?>
<mediaCollection xmlns="http://www.sonos.com/Services/1.1">
  <id>favorites_123</id>
  <itemType>favorites</itemType>
  <title>My Favorites</title>
  <canPlay>false</canPlay>
</mediaCollection>''');

      final mockService = _MockWimpService();
      final item = getMsItem(xml.rootElement, mockService, 'parent_123');

      expect(item, isA<MSFavorites>());
      expect(item.title, equals('My Favorites'));
    });

    test('parses collection from namespaced XML', () {
      final xml = XmlDocument.parse('''
<?xml version="1.0" encoding="UTF-8"?>
<mediaCollection xmlns="http://www.sonos.com/Services/1.1">
  <id>collection_123</id>
  <itemType>collection</itemType>
  <title>My Music</title>
  <canPlay>false</canPlay>
</mediaCollection>''');

      final mockService = _MockWimpService();
      final item = getMsItem(xml.rootElement, mockService, 'parent_123');

      expect(item, isA<MSCollection>());
      expect(item.title, equals('My Music'));
    });

    test('throws StateError when itemType element is missing', () {
      final xml = XmlDocument.parse('''
<?xml version="1.0" encoding="UTF-8"?>
<mediaCollection xmlns="http://www.sonos.com/Services/1.1">
  <id>missing_type</id>
  <title>No Item Type</title>
</mediaCollection>''');

      final mockService = _MockWimpService();
      expect(
        () => getMsItem(xml.rootElement, mockService, 'parent_123'),
        throwsA(isA<StateError>()),
      );
    });

    test('throws ArgumentError for unknown item type', () {
      final xml = XmlDocument.parse('''
<?xml version="1.0" encoding="UTF-8"?>
<mediaCollection xmlns="http://www.sonos.com/Services/1.1">
  <id>unknown_123</id>
  <itemType>unknownType</itemType>
  <title>Unknown Type</title>
</mediaCollection>''');

      final mockService = _MockWimpService();
      expect(
        () => getMsItem(xml.rootElement, mockService, 'parent_123'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

/// Mock service for testing getMsItem
class _MockWimpService {
  int get serviceId => 20;
  String get description => 'SA_RINCON5127_test';
}
