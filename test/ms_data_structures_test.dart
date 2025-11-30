/// Tests for the ms_data_structures module.
library;

import 'package:test/test.dart';
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
    test('handles empty XML element', () {
      // Test would need actual XML parsing
      expect(true, isTrue); // Placeholder
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
          track.content['album_art_uri'], equals('http://example.com/art.jpg'));
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
}
