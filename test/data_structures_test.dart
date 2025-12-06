/// Tests for the data_structures module.
library;

import 'package:test/test.dart';
import 'package:xml/xml.dart';
import 'package:soco/src/data_structures.dart';
import 'package:soco/src/exceptions.dart';

void main() {
  // Ensure DIDL classes are initialized
  setUpAll(() {
    initializeDidlClasses();
  });

  group('officialClasses', () {
    test('contains all standard DIDL classes', () {
      expect(officialClasses, contains('object'));
      expect(officialClasses, contains('object.item'));
      expect(officialClasses, contains('object.item.audioItem'));
      expect(officialClasses, contains('object.item.audioItem.musicTrack'));
      expect(officialClasses, contains('object.container'));
      expect(officialClasses, contains('object.container.person.musicArtist'));
      expect(officialClasses, contains('object.container.playlistContainer'));
    });
  });

  group('formName', () {
    test('forms correct name for sonos-favorite classes', () {
      expect(
        formName('object.item.audioItem.musicTrack.sonos-favorite'),
        equals('DidlMusicTrackFavorite'),
      );
      expect(
        formName('object.container.album.sonos-favorite'),
        equals('DidlAlbumFavorite'),
      );
    });

    test('forms correct name for vendor extensions', () {
      expect(
        formName('object.item.audioItem.podcast'),
        equals('DidlPodcast'),
      );
      expect(
        formName('object.container.album.photoAlbum'),
        equals('DidlPhotoAlbum'),
      );
    });

    test('handles list suffix correctly', () {
      expect(
        formName('object.container.playlistContainer.sameArtistlist'),
        equals('DidlSameArtistList'),
      );
    });

    test('throws for non-object classes', () {
      expect(
        () => formName('invalid.class'),
        throwsA(isA<DIDLMetadataError>()),
      );
    });
  });

  group('didlClassToSoCoClass', () {
    test('returns correct type for known classes', () {
      expect(didlClassToSoCoClass('object'), equals(DidlObject));
      expect(didlClassToSoCoClass('object.item'), equals(DidlItem));
      expect(
        didlClassToSoCoClass('object.item.audioItem.musicTrack'),
        equals(DidlMusicTrack),
      );
      expect(didlClassToSoCoClass('object.container'), equals(DidlContainer));
      expect(
        didlClassToSoCoClass('object.container.person.musicArtist'),
        equals(DidlMusicArtist),
      );
    });

    test('strips subclass syntax with .#', () {
      expect(
        didlClassToSoCoClass('object.item.audioItem.musicTrack.#something'),
        equals(DidlMusicTrack),
      );
    });

    test('strips subclass syntax with #', () {
      expect(
        didlClassToSoCoClass('object.item.audioItem.musicTrack#variant'),
        equals(DidlMusicTrack),
      );
    });

    test('returns DidlObject for unknown classes', () {
      expect(
        didlClassToSoCoClass('object.unknown.class'),
        equals(DidlObject),
      );
    });

    test('creates factory for unknown classes', () {
      // Clear any existing factories for this test
      final unknownClass = 'object.container.customExtension';
      
      // First call should return base class and create factory
      final baseClass = didlClassToSoCoClass(unknownClass);
      expect(baseClass, equals(DidlContainer));
      
      // Factory should be available
      final factory = getDidlClassFactory(unknownClass);
      expect(factory, isNotNull);
      
      // Factory should create instance with correct itemClass override
      final instance = factory!(
        title: 'Test',
        parentId: '0',
        itemId: '1',
      );
      
      expect(instance, isA<DidlContainer>());
      expect(instance.effectiveItemClass, equals(unknownClass));
    });

    test('creates factory for nested unknown classes', () {
      final unknownClass = 'object.container.album.customAlbum';
      
      // Should find base class DidlAlbum
      final baseClass = didlClassToSoCoClass(unknownClass);
      expect(baseClass, equals(DidlAlbum));
      
      // Factory should create instance with correct override
      final factory = getDidlClassFactory(unknownClass);
      expect(factory, isNotNull);
      
      final instance = factory!(
        title: 'Custom Album',
        parentId: '0',
        itemId: '1',
      );
      
      expect(instance, isA<DidlAlbum>());
      expect(instance.effectiveItemClass, equals(unknownClass));
    });
  });

  group('DidlResource', () {
    test('creates resource with required fields', () {
      final resource = DidlResource(
        uri: 'http://example.com/music.mp3',
        protocolInfo: 'http-get:*:audio/mpeg:*',
      );

      expect(resource.uri, equals('http://example.com/music.mp3'));
      expect(resource.protocolInfo, equals('http-get:*:audio/mpeg:*'));
      expect(resource.duration, isNull);
      expect(resource.size, isNull);
    });

    test('creates resource with all optional fields', () {
      final resource = DidlResource(
        uri: 'http://example.com/music.mp3',
        protocolInfo: 'http-get:*:audio/mpeg:*',
        importUri: 'http://example.com/import.mp3',
        size: 1024000,
        duration: '0:03:45',
        bitrate: 128000,
        sampleFrequency: 44100,
        bitsPerSample: 16,
        nrAudioChannels: 2,
        resolution: '1920x1080',
        colorDepth: 24,
        protection: 'none',
      );

      expect(resource.size, equals(1024000));
      expect(resource.duration, equals('0:03:45'));
      expect(resource.bitrate, equals(128000));
      expect(resource.sampleFrequency, equals(44100));
      expect(resource.bitsPerSample, equals(16));
      expect(resource.nrAudioChannels, equals(2));
      expect(resource.resolution, equals('1920x1080'));
      expect(resource.colorDepth, equals(24));
      expect(resource.protection, equals('none'));
    });

    test('parses from XML element', () {
      final xml = XmlDocument.parse('''
        <res protocolInfo="http-get:*:audio/mpeg:*"
             duration="0:04:32"
             size="5242880"
             bitrate="192000"
             sampleFrequency="48000"
             bitsPerSample="24"
             nrAudioChannels="2">http://192.168.1.1:1400/track.mp3</res>
      ''');
      final element = xml.rootElement;

      final resource = DidlResource.fromElement(element);

      expect(resource.uri, equals('http://192.168.1.1:1400/track.mp3'));
      expect(resource.protocolInfo, equals('http-get:*:audio/mpeg:*'));
      expect(resource.duration, equals('0:04:32'));
      expect(resource.size, equals(5242880));
      expect(resource.bitrate, equals(192000));
      expect(resource.sampleFrequency, equals(48000));
      expect(resource.bitsPerSample, equals(24));
      expect(resource.nrAudioChannels, equals(2));
    });

    test('applies quirk when protocolInfo is missing', () {
      // The quirks handler adds a dummy protocolInfo when missing
      final xml = XmlDocument.parse('''
        <res>http://192.168.1.1:1400/track.mp3</res>
      ''');
      final element = xml.rootElement;

      final resource = DidlResource.fromElement(element);

      // Quirk should have added dummy protocolInfo
      expect(resource.protocolInfo, equals('DUMMY_ADDED_BY_QUIRK'));
      expect(resource.uri, equals('http://192.168.1.1:1400/track.mp3'));
    });

    test('applies spotify quirk when protocolInfo is missing', () {
      // For Spotify URIs, a more specific quirk is applied
      final xml = XmlDocument.parse('''
        <res>x-sonos-spotify:spotify:track:123</res>
      ''');
      final element = xml.rootElement;

      final resource = DidlResource.fromElement(element);

      expect(resource.protocolInfo, equals('sonos.com-spotify:*:audio/x-spotify.*'));
    });

    test('converts to XML element', () {
      final resource = DidlResource(
        uri: 'http://example.com/music.mp3',
        protocolInfo: 'http-get:*:audio/mpeg:*',
        duration: '0:03:45',
        size: 1024000,
      );

      final element = resource.toElement();

      expect(element.name.local, equals('res'));
      expect(element.getAttribute('protocolInfo'), equals('http-get:*:audio/mpeg:*'));
      expect(element.getAttribute('duration'), equals('0:03:45'));
      expect(element.getAttribute('size'), equals('1024000'));
      expect(element.innerText, equals('http://example.com/music.mp3'));
    });

    test('toDict returns map with all fields', () {
      final resource = DidlResource(
        uri: 'http://example.com/music.mp3',
        protocolInfo: 'http-get:*:audio/mpeg:*',
        duration: '0:03:45',
      );

      final dict = resource.toDict();

      expect(dict['uri'], equals('http://example.com/music.mp3'));
      expect(dict['protocol_info'], equals('http-get:*:audio/mpeg:*'));
      expect(dict['duration'], equals('0:03:45'));
      expect(dict['size'], isNull);
    });

    test('toDict removes nulls when requested', () {
      final resource = DidlResource(
        uri: 'http://example.com/music.mp3',
        protocolInfo: 'http-get:*:audio/mpeg:*',
      );

      final dict = resource.toDict(removeNones: true);

      expect(dict.containsKey('size'), isFalse);
      expect(dict.containsKey('duration'), isFalse);
      expect(dict['uri'], equals('http://example.com/music.mp3'));
    });

    test('toString returns formatted string', () {
      final resource = DidlResource(
        uri: 'http://example.com/music.mp3',
        protocolInfo: 'http-get:*:audio/mpeg:*',
      );

      expect(resource.toString(), contains('DidlResource'));
      expect(resource.toString(), contains('http://example.com/music.mp3'));
    });
  });

  group('DidlObject', () {
    test('creates object with required fields', () {
      final obj = DidlObject(
        title: 'Test Track',
        parentId: '0',
        itemId: 'Q:0/1',
      );

      expect(obj.title, equals('Test Track'));
      expect(obj.parentId, equals('0'));
      expect(obj.itemId, equals('Q:0/1'));
      expect(obj.restricted, isTrue);
      expect(obj.resources, isEmpty);
      expect(obj.tag, equals('item'));
    });

    test('creates object with optional fields', () {
      final resource = DidlResource(
        uri: 'http://example.com/music.mp3',
        protocolInfo: 'http-get:*:audio/mpeg:*',
      );

      final obj = DidlObject(
        title: 'Test Track',
        parentId: '0',
        itemId: 'Q:0/1',
        restricted: false,
        resources: [resource],
        desc: 'Custom Desc',
        metadata: {'creator': 'Test Artist'},
      );

      expect(obj.restricted, isFalse);
      expect(obj.resources, hasLength(1));
      expect(obj.desc, equals('Custom Desc'));
      expect(obj['creator'], equals('Test Artist'));
    });

    test('supports metadata access via operator[]', () {
      final obj = DidlObject(
        title: 'Test',
        parentId: '0',
        itemId: '1',
      );

      obj['album'] = 'Test Album';
      obj['artist'] = 'Test Artist';

      expect(obj['album'], equals('Test Album'));
      expect(obj['artist'], equals('Test Artist'));
      expect(obj['nonexistent'], isNull);
    });

    test('toString returns formatted string', () {
      final obj = DidlObject(
        title: 'Test Track',
        parentId: '0',
        itemId: 'Q:0/1',
      );

      expect(obj.toString(), contains('DidlObject'));
      expect(obj.toString(), contains('Test Track'));
    });

    test('toDidlString includes resources in output', () {
      final resource = DidlResource(
        uri: 'http://example.com/track.mp3',
        protocolInfo: 'http-get:*:audio/mpeg:*',
        duration: '0:03:45',
      );

      final track = DidlMusicTrack(
        title: 'Track With Resource',
        parentId: '0',
        itemId: 'Q:0/1',
        resources: [resource],
      );

      final result = toDidlString([track]);

      expect(result, contains('<res'));
      expect(result, contains('http://example.com/track.mp3'));
      expect(result, contains('protocolInfo'));
    });

    test('toDidlString includes translated metadata', () {
      final track = DidlMusicTrack(
        title: 'Track With Creator',
        parentId: '0',
        itemId: 'Q:0/1',
        metadata: {'creator': 'Test Artist'},
      );

      final result = toDidlString([track]);

      // The dc:creator element is rendered with full namespace URI
      expect(result, contains('creator'));
      expect(result, contains('Test Artist'));
    });
  });

  group('DidlItem subclasses', () {
    test('DidlItem has correct itemClass', () {
      expect(DidlItem.itemClass, equals('object.item'));
    });

    test('DidlAudioItem has correct itemClass', () {
      expect(DidlAudioItem.itemClass, equals('object.item.audioItem'));
    });

    test('DidlMusicTrack has correct itemClass', () {
      expect(DidlMusicTrack.itemClass, equals('object.item.audioItem.musicTrack'));
    });

    test('DidlAudioBook has correct itemClass', () {
      expect(DidlAudioBook.itemClass, equals('object.item.audioItem.audioBook'));
    });

    test('DidlAudioBroadcast has correct itemClass', () {
      expect(DidlAudioBroadcast.itemClass, equals('object.item.audioItem.audioBroadcast'));
    });

    test('DidlAudioLineIn has correct itemClass', () {
      expect(DidlAudioLineIn.itemClass, equals('object.item.audioItem.linein'));
    });

    test('DidlMusicTrack can be created', () {
      final track = DidlMusicTrack(
        title: 'Bohemian Rhapsody',
        parentId: 'A:ALBUM/Test',
        itemId: 'A:ALBUM/Test/1',
        metadata: {'creator': 'Queen'},
      );

      expect(track.title, equals('Bohemian Rhapsody'));
      expect(track['creator'], equals('Queen'));
    });
  });

  group('DidlContainer subclasses', () {
    test('DidlContainer has correct itemClass and tag', () {
      final container = DidlContainer(
        title: 'Test Container',
        parentId: '0',
        itemId: 'C:1',
      );

      expect(DidlContainer.itemClass, equals('object.container'));
      expect(container.tag, equals('container'));
    });

    test('DidlAlbum has correct itemClass', () {
      expect(DidlAlbum.itemClass, equals('object.container.album'));
    });

    test('DidlMusicAlbum has correct itemClass', () {
      expect(DidlMusicAlbum.itemClass, equals('object.container.musicAlbum'));
    });

    test('DidlPerson has correct itemClass', () {
      expect(DidlPerson.itemClass, equals('object.container.person'));
    });

    test('DidlComposer has correct itemClass', () {
      expect(DidlComposer.itemClass, equals('object.container.person.composer'));
    });

    test('DidlMusicArtist has correct itemClass', () {
      expect(DidlMusicArtist.itemClass, equals('object.container.person.musicArtist'));
    });

    test('DidlPlaylistContainer has correct itemClass', () {
      expect(DidlPlaylistContainer.itemClass, equals('object.container.playlistContainer'));
    });

    test('DidlGenre has correct itemClass', () {
      expect(DidlGenre.itemClass, equals('object.container.genre'));
    });

    test('DidlMusicGenre has correct itemClass', () {
      expect(DidlMusicGenre.itemClass, equals('object.container.genre.musicGenre'));
    });

    test('DidlMusicArtist can be created', () {
      final artist = DidlMusicArtist(
        title: 'The Beatles',
        parentId: 'A:ARTIST',
        itemId: 'A:ARTIST/The%20Beatles',
      );

      expect(artist.title, equals('The Beatles'));
      expect(artist.tag, equals('container'));
    });
  });

  group('SearchResult', () {
    test('creates search result with items', () {
      final items = [
        DidlMusicTrack(
          title: 'Track 1',
          parentId: '0',
          itemId: '1',
        ),
        DidlMusicTrack(
          title: 'Track 2',
          parentId: '0',
          itemId: '2',
        ),
      ];

      final result = SearchResult(
        items,
        'tracks',
        2,
        100,
        42,
      );

      expect(result.items, hasLength(2));
      expect(result.searchType, equals('tracks'));
      expect(result.numberReturned, equals(2));
      expect(result.totalMatches, equals(100));
      expect(result.updateId, equals(42));
    });

    test('toString returns formatted string', () {
      final result = SearchResult(
        [],
        'albums',
        0,
        50,
        null,
      );

      expect(result.toString(), contains('SearchResult'));
      expect(result.toString(), contains('albums'));
    });
  });

  group('toDidlString', () {
    test('converts single object to DIDL-Lite string', () {
      final track = DidlMusicTrack(
        title: 'Test Track',
        parentId: '0',
        itemId: 'Q:0/1',
      );

      final result = toDidlString([track]);

      expect(result, contains('DIDL-Lite'));
      expect(result, contains('Test Track'));
      expect(result, contains('item'));
    });

    test('converts multiple objects to DIDL-Lite string', () {
      final track1 = DidlMusicTrack(
        title: 'Track 1',
        parentId: '0',
        itemId: '1',
      );
      final track2 = DidlMusicTrack(
        title: 'Track 2',
        parentId: '0',
        itemId: '2',
      );

      final result = toDidlString([track1, track2]);

      expect(result, contains('Track 1'));
      expect(result, contains('Track 2'));
    });

    test('includes namespace declarations', () {
      final track = DidlMusicTrack(
        title: 'Test',
        parentId: '0',
        itemId: '1',
      );

      final result = toDidlString([track]);

      expect(result, contains('xmlns'));
      expect(result, contains('urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/'));
    });
  });

  group('initializeDidlClasses', () {
    test('registers all DIDL classes', () {
      initializeDidlClasses();

      // Verify some key mappings work
      expect(didlClassToSoCoClass('object'), equals(DidlObject));
      expect(
        didlClassToSoCoClass('object.item.audioItem.musicTrack'),
        equals(DidlMusicTrack),
      );
      expect(
        didlClassToSoCoClass('object.container.person.musicArtist'),
        equals(DidlMusicArtist),
      );
    });
  });
}
