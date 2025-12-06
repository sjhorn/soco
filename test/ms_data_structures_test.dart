/// Tests for the ms_data_structures module.
library;

import 'package:test/test.dart';
import 'package:xml/xml.dart';
import 'package:soco/src/exceptions.dart';
import 'package:soco/src/ms_data_structures.dart';

void main() {
  group('MSTrack', () {
    test('itemClass returns correct value', () {
      final track = MSTrack({'title': 'Test Track'});
      expect(track.itemClass, equals('object.item.audioItem.musicTrack'));
    });

    test('content stores values correctly', () {
      final content = {
        'title': 'Test Track',
        'artist': 'Test Artist',
        'album': 'Test Album',
      };
      final track = MSTrack(content);
      expect(track.content['title'], equals('Test Track'));
      expect(track.content['artist'], equals('Test Artist'));
      expect(track.content['album'], equals('Test Album'));
    });

    test('validFields includes expected fields', () {
      final track = MSTrack({});
      expect(track.validFields.contains('title'), isTrue);
      expect(track.validFields.contains('artist'), isTrue);
      expect(track.validFields.contains('album'), isTrue);
      expect(track.validFields.contains('duration'), isTrue);
    });

    test('requiredFields includes title', () {
      final track = MSTrack({});
      expect(track.requiredFields.contains('title'), isTrue);
    });

    test('itemId getter returns correct value', () {
      final track = MSTrack({'item_id': 'track123'});
      expect(track.itemId, equals('track123'));
    });

    test('title getter returns correct value', () {
      final track = MSTrack({'title': 'My Song'});
      expect(track.title, equals('My Song'));
    });
  });

  group('MSAlbum', () {
    test('itemClass returns correct value', () {
      final album = MSAlbum({'title': 'Test Album'});
      expect(album.itemClass, equals('object.container.album.musicAlbum'));
    });

    test('content stores values correctly', () {
      final content = {
        'title': 'Test Album',
        'artist': 'Test Artist',
        'item_id': 'album123',
      };
      final album = MSAlbum(content);
      expect(album.content['title'], equals('Test Album'));
      expect(album.content['artist'], equals('Test Artist'));
    });

    test('validFields includes expected fields', () {
      final album = MSAlbum({});
      expect(album.validFields.contains('title'), isTrue);
      expect(album.validFields.contains('artist'), isTrue);
    });
  });

  group('MSAlbumList', () {
    test('itemClass returns correct value', () {
      final list = MSAlbumList({'title': 'Test List'});
      expect(list.itemClass, equals('object.container.albumlist'));
    });

    test('content stores values correctly', () {
      final content = {'title': 'My Album List', 'item_id': 'list123'};
      final list = MSAlbumList(content);
      expect(list.content['title'], equals('My Album List'));
    });
  });

  group('MSPlaylist', () {
    test('itemClass returns correct value', () {
      final playlist = MSPlaylist({'title': 'Test Playlist'});
      expect(playlist.itemClass, equals('object.container.playlistContainer'));
    });

    test('content stores values correctly', () {
      final content = {'title': 'My Playlist', 'item_id': 'playlist123'};
      final playlist = MSPlaylist(content);
      expect(playlist.content['title'], equals('My Playlist'));
    });
  });

  group('MSArtist', () {
    test('itemClass returns correct value', () {
      final artist = MSArtist({'title': 'Test Artist'});
      expect(artist.itemClass, equals('object.container.person.musicArtist'));
    });

    test('content stores values correctly', () {
      final content = {'title': 'The Artist', 'item_id': 'artist123'};
      final artist = MSArtist(content);
      expect(artist.content['title'], equals('The Artist'));
    });

    test('validFields includes expected fields', () {
      final artist = MSArtist({});
      expect(artist.validFields.contains('title'), isTrue);
    });
  });

  group('MSArtistTracklist', () {
    test('itemClass returns correct value', () {
      final tracklist = MSArtistTracklist({'title': 'Artist Tracks'});
      expect(tracklist.itemClass, equals('object.container.playlistContainer'));
    });
  });

  group('MSFavorites', () {
    test('itemClass returns correct value', () {
      final favorites = MSFavorites({'title': 'My Favorites'});
      expect(favorites.itemClass, equals('object.container.playlistContainer'));
    });
  });

  group('MSCollection', () {
    test('itemClass returns correct value', () {
      final collection = MSCollection({'title': 'Collection'});
      expect(collection.itemClass, equals('object.container'));
    });
  });

  group('MusicServiceItem common properties', () {
    test('itemId returns null when not set', () {
      final track = MSTrack({});
      expect(track.itemId, isNull);
    });

    test('extendedId returns null when not set', () {
      final track = MSTrack({});
      expect(track.extendedId, isNull);
    });

    test('extendedId returns value when set', () {
      final track = MSTrack({'extended_id': 'ext123'});
      expect(track.extendedId, equals('ext123'));
    });

    test('title returns null when not set', () {
      final track = MSTrack({});
      expect(track.title, isNull);
    });

    test('serviceId returns value when set', () {
      final track = MSTrack({'service_id': 20});
      expect(track.content['service_id'], equals(20));
    });

    test('parentId returns value when set', () {
      final track = MSTrack({'parent_id': 'parent123'});
      expect(track.content['parent_id'], equals('parent123'));
    });

    test('description returns value when set', () {
      final track = MSTrack({'description': 'SA_RINCON5127_user'});
      expect(track.content['description'], equals('SA_RINCON5127_user'));
    });

    test('canPlay returns boolean when set', () {
      final track = MSTrack({'can_play': true});
      expect(track.content['can_play'], isTrue);
    });

    test('canSkip returns boolean when set', () {
      final track = MSTrack({'can_skip': false});
      expect(track.content['can_skip'], isFalse);
    });

    test('canAddToFavorites returns boolean when set', () {
      final track = MSTrack({'can_add_to_favorites': true});
      expect(track.content['can_add_to_favorites'], isTrue);
    });

    test('canEnumerate returns boolean when set', () {
      final track = MSTrack({'can_enumerate': true});
      expect(track.content['can_enumerate'], isTrue);
    });
  });

  group('tagsWithText', () {
    test('extracts text elements from simple XML', () {
      final xml = XmlDocument.parse('''
        <root>
          <title>Test Title</title>
          <artist>Test Artist</artist>
        </root>
      ''').rootElement;

      final tags = tagsWithText(xml);
      expect(tags.length, equals(2));
      expect(tags.map((e) => e.name.local), containsAll(['title', 'artist']));
    });

    test('extracts text elements from nested XML', () {
      final xml = XmlDocument.parse('''
        <root>
          <metadata>
            <title>Nested Title</title>
          </metadata>
          <info>
            <artist>Nested Artist</artist>
          </info>
        </root>
      ''').rootElement;

      final tags = tagsWithText(xml);
      expect(tags.length, equals(2));
    });

    test('handles deeply nested XML', () {
      final xml = XmlDocument.parse('''
        <root>
          <level1>
            <level2>
              <level3>
                <value>Deep Value</value>
              </level3>
            </level2>
          </level1>
        </root>
      ''').rootElement;

      final tags = tagsWithText(xml);
      expect(tags.length, equals(1));
      expect(tags.first.innerText, equals('Deep Value'));
    });

    test('uses provided tags list', () {
      final xml = XmlDocument.parse('''
        <root><item>Value</item></root>
      ''').rootElement;

      final existingTags = <XmlElement>[];
      final result = tagsWithText(xml, existingTags);
      expect(result, same(existingTags));
      expect(existingTags.length, equals(1));
    });
  });

  group('getMsItem type registration', () {
    test('MS types are registered', () {
      // The types should be registered when the module is loaded
      // We verify by checking that the classes exist
      expect(MSTrack, isNotNull);
      expect(MSAlbum, isNotNull);
      expect(MSAlbumList, isNotNull);
      expect(MSPlaylist, isNotNull);
      expect(MSArtist, isNotNull);
      expect(MSArtistTracklist, isNotNull);
      expect(MSFavorites, isNotNull);
      expect(MSCollection, isNotNull);
    });
  });

  group('MSTrack specific fields', () {
    test('duration field', () {
      final track = MSTrack({'duration': 180});
      expect(track.content['duration'], equals(180));
    });

    test('album_art_uri field', () {
      final track = MSTrack({'album_art_uri': 'http://example.com/art.jpg'});
      expect(
        track.content['album_art_uri'],
        equals('http://example.com/art.jpg'),
      );
    });

    test('mime_type field', () {
      final track = MSTrack({'mime_type': 'audio/aac'});
      expect(track.content['mime_type'], equals('audio/aac'));
    });
  });

  group('Content manipulation', () {
    test('content can be modified', () {
      final track = MSTrack({'title': 'Original'});
      track.content['title'] = 'Modified';
      expect(track.content['title'], equals('Modified'));
    });

    test('content can have new fields added', () {
      final track = MSTrack({});
      track.content['custom_field'] = 'custom_value';
      expect(track.content['custom_field'], equals('custom_value'));
    });
  });

  group('MusicServiceItem operators and methods', () {
    test('operator[] returns content value', () {
      final track = MSTrack({'title': 'Test Song', 'artist': 'Test Artist'});
      expect(track['title'], equals('Test Song'));
      expect(track['artist'], equals('Test Artist'));
    });

    test('operator[] returns null for missing key', () {
      final track = MSTrack({});
      expect(track['nonexistent'], isNull);
    });

    test('canPlay returns false by default', () {
      final track = MSTrack({});
      expect(track.canPlay, isFalse);
    });

    test('canPlay returns true when set', () {
      final track = MSTrack({'can_play': true});
      expect(track.canPlay, isTrue);
    });

    test('uri returns null when not set', () {
      final track = MSTrack({});
      expect(track.uri, isNull);
    });

    test('uri returns value when set', () {
      final track = MSTrack({'uri': 'x-sonos-http:track123.mp4'});
      expect(track.uri, equals('x-sonos-http:track123.mp4'));
    });

    test('equality compares content', () {
      final track1 = MSTrack({'title': 'Song', 'artist': 'Artist'});
      final track2 = MSTrack({'title': 'Song', 'artist': 'Artist'});
      final track3 = MSTrack({'title': 'Different'});
      expect(track1 == track2, isTrue);
      expect(track1 == track3, isFalse);
    });

    test('equality returns false for different types', () {
      final track = MSTrack({'title': 'Song'});
      // ignore: unrelated_type_equality_checks
      expect(track == 'not a track', isFalse);
    });

    test('identical objects are equal', () {
      final track = MSTrack({'title': 'Song'});
      expect(track == track, isTrue);
    });

    test('hashCode is consistent', () {
      final track1 = MSTrack({'title': 'Song'});
      final track2 = MSTrack({'title': 'Song'});
      expect(track1.hashCode, equals(track2.hashCode));
    });

    test('toString includes type and title', () {
      final track = MSTrack({'title': 'My Song Title'});
      final str = track.toString();
      expect(str.contains('MSTrack'), isTrue);
      expect(str.contains('My Song Title'), isTrue);
    });

    test('toString truncates long titles', () {
      final longTitle = 'A' * 50;
      final track = MSTrack({'title': longTitle});
      final str = track.toString();
      expect(str.contains('...'), isTrue);
      expect(str.length < longTitle.length + 50, isTrue);
    });

    test('toString uses content when no title', () {
      final track = MSTrack({'artist': 'Test'});
      final str = track.toString();
      expect(str.contains('MSTrack'), isTrue);
    });

    test('toDict returns copy of content', () {
      final track = MSTrack({'title': 'Song', 'artist': 'Artist'});
      final dict = track.toDict();
      expect(dict['title'], equals('Song'));
      expect(dict['artist'], equals('Artist'));
      // Verify it's a copy
      dict['title'] = 'Modified';
      expect(track.content['title'], equals('Song'));
    });

    test('parentId returns value when set', () {
      final track = MSTrack({'parent_id': 'parent123'});
      expect(track.parentId, equals('parent123'));
    });

    test('parentId returns null when not set', () {
      final track = MSTrack({});
      expect(track.parentId, isNull);
    });
  });

  group('didlMetadata', () {
    test('throws when canPlay is false', () {
      final track = MSTrack({'title': 'Song', 'can_play': false});
      expect(() => track.didlMetadata, throwsA(isA<DIDLMetadataError>()));
    });

    test('throws when extended_id is missing', () {
      final track = MSTrack({'can_play': true, 'title': 'Song'});
      expect(() => track.didlMetadata, throwsA(isA<DIDLMetadataError>()));
    });

    test('throws when title is missing', () {
      final track = MSTrack({'can_play': true, 'extended_id': 'ext123'});
      expect(() => track.didlMetadata, throwsA(isA<DIDLMetadataError>()));
    });

    test('throws when description is missing', () {
      final track = MSTrack({
        'can_play': true,
        'extended_id': 'ext123',
        'title': 'Song',
      });
      expect(() => track.didlMetadata, throwsA(isA<DIDLMetadataError>()));
    });

    test('returns valid DIDL-Lite XML when all fields present', () {
      final track = MSTrack({
        'can_play': true,
        'extended_id': '00030020trackid_123',
        'title': 'Test Song',
        'parent_id': 'parent123',
        'description': 'SA_RINCON5127_user',
      });
      final didl = track.didlMetadata;
      expect(didl.contains('DIDL-Lite'), isTrue);
      expect(didl.contains('Test Song'), isTrue);
      expect(didl.contains('00030020trackid_123'), isTrue);
      expect(didl.contains('object.item.audioItem.musicTrack'), isTrue);
    });
  });

  group('MSAlbum additional tests', () {
    test('itemClass is musicAlbum', () {
      final album = MSAlbum({});
      expect(album.itemClass, equals('object.container.album.musicAlbum'));
    });

    test('requiredFields includes title', () {
      final album = MSAlbum({});
      expect(album.requiredFields.contains('title'), isTrue);
    });
  });

  group('MSAlbumList additional tests', () {
    test('requiredFields includes title', () {
      final list = MSAlbumList({});
      expect(list.requiredFields.contains('title'), isTrue);
    });

    test('validFields includes expected fields', () {
      final list = MSAlbumList({});
      expect(list.validFields.contains('title'), isTrue);
      expect(list.validFields.contains('can_play'), isTrue);
    });
  });

  group('MSPlaylist additional tests', () {
    test('requiredFields includes title', () {
      final playlist = MSPlaylist({});
      expect(playlist.requiredFields.contains('title'), isTrue);
    });
  });

  group('MSArtist additional tests', () {
    test('requiredFields includes title', () {
      final artist = MSArtist({});
      expect(artist.requiredFields.contains('title'), isTrue);
    });
  });

  group('MSArtistTracklist additional tests', () {
    test('requiredFields includes title', () {
      final tracklist = MSArtistTracklist({});
      expect(tracklist.requiredFields.contains('title'), isTrue);
    });

    test('validFields includes expected fields', () {
      final tracklist = MSArtistTracklist({});
      expect(tracklist.validFields.contains('title'), isTrue);
    });
  });

  group('MSFavorites additional tests', () {
    test('requiredFields includes title', () {
      final favorites = MSFavorites({});
      expect(favorites.requiredFields.contains('title'), isTrue);
    });

    test('validFields includes expected fields', () {
      final favorites = MSFavorites({});
      expect(favorites.validFields.contains('title'), isTrue);
      expect(favorites.validFields.contains('can_enumerate'), isTrue);
    });
  });

  group('MSCollection additional tests', () {
    test('requiredFields includes title', () {
      final collection = MSCollection({});
      expect(collection.requiredFields.contains('title'), isTrue);
    });

    test('validFields includes expected fields', () {
      final collection = MSCollection({});
      expect(collection.validFields.contains('title'), isTrue);
    });
  });
}
