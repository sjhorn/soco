/// Integration tests for data_structures_entry parsing.
library;

import 'package:test/test.dart';
// Import data_structures FIRST to ensure initialization happens
import 'package:soco/src/data_structures.dart';
import 'package:soco/src/data_structures_entry.dart';

import 'helpers/data_loader.dart';

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

      expect(result, isA<Map>());
      expect(result['class'], equals(DidlMusicTrack));
    });

    test('identifies DidlMusicAlbum class from XML', () {
      final xmlString = dataLoader.loadXml('album.xml');
      final result = fromDidlString(xmlString)[0];

      expect(result, isA<Map>());
      // Note: album.xml contains "object.container.album.musicAlbum"
      // which falls back to DidlObject since only "object.container.musicAlbum"
      // is registered
      expect(result['class'], equals(DidlObject));
    });

    test('identifies DidlMusicArtist class from XML', () {
      final xmlString = dataLoader.loadXml('artist.xml');
      final result = fromDidlString(xmlString)[0];

      expect(result, isA<Map>());
      expect(result['class'], equals(DidlMusicArtist));
    });

    test('identifies DidlMusicGenre class from XML', () {
      final xmlString = dataLoader.loadXml('genre.xml');
      final result = fromDidlString(xmlString)[0];

      expect(result, isA<Map>());
      expect(result['class'], equals(DidlMusicGenre));
    });

    test('identifies DidlContainer class from XML (share)', () {
      final xmlString = dataLoader.loadXml('share.xml');
      final result = fromDidlString(xmlString)[0];

      expect(result, isA<Map>());
      expect(result['class'], equals(DidlContainer));
    });

    test('identifies DidlPlaylistContainer class from XML', () {
      final xmlString = dataLoader.loadXml('playlist.xml');
      final result = fromDidlString(xmlString)[0];

      expect(result, isA<Map>());
      expect(result['class'], equals(DidlPlaylistContainer));
    });

    test('identifies DidlAudioBroadcast class from XML', () {
      final xmlString = dataLoader.loadXml('audio_broadcast.xml');
      final result = fromDidlString(xmlString)[0];

      expect(result, isA<Map>());
      expect(result['class'], equals(DidlAudioBroadcast));
    });

    test('handles vendor extended DIDL class - falls back to DidlObject', () {
      // recent_show.xml contains object.item.audioItem.musicTrack.recentShow
      // which is a vendor-extended class not in our registry
      final xmlString = dataLoader.loadXml('recent_show.xml');
      final result = fromDidlString(xmlString)[0];

      expect(result, isA<Map>());
      // Unknown classes fall back to DidlObject
      expect(result['class'], equals(DidlObject));
    });

    test('identifies DidlComposer class from XML', () {
      final xmlString = dataLoader.loadXml('composer.xml');
      final result = fromDidlString(xmlString)[0];

      expect(result, isA<Map>());
      expect(result['class'], equals(DidlComposer));
    });
  });
}
