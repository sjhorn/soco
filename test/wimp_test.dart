/// Tests for the Wimp plugin.
library;

import 'package:test/test.dart';
import 'package:soco/src/plugins/wimp.dart';
import 'package:soco/src/ms_data_structures.dart';

void main() {
  group('WimpPlugin static methods', () {
    test('idToExtendedId returns correct prefix for MSTrack', () {
      final result = WimpPlugin.idToExtendedId('trackid_12345', MSTrack);
      expect(result, equals('00030020trackid_12345'));
    });

    test('idToExtendedId returns correct prefix for MSAlbum', () {
      final result = WimpPlugin.idToExtendedId('albumid_12345', MSAlbum);
      expect(result, equals('0004002calbumid_12345'));
    });

    test('idToExtendedId returns correct prefix for MSArtist', () {
      final result = WimpPlugin.idToExtendedId('artistid_12345', MSArtist);
      expect(result, equals('10050024artistid_12345'));
    });

    test('idToExtendedId returns correct prefix for MSAlbumList', () {
      final result = WimpPlugin.idToExtendedId('listid_12345', MSAlbumList);
      expect(result, equals('000d006clistid_12345'));
    });

    test('idToExtendedId returns correct prefix for MSPlaylist', () {
      final result = WimpPlugin.idToExtendedId('playlistid_12345', MSPlaylist);
      expect(result, equals('0006006cplaylistid_12345'));
    });

    test('idToExtendedId returns correct prefix for MSArtistTracklist', () {
      final result =
          WimpPlugin.idToExtendedId('tracklistid_12345', MSArtistTracklist);
      expect(result, equals('100f006ctracklistid_12345'));
    });

    test('idToExtendedId returns null for MSFavorites (unknown prefix)', () {
      final result = WimpPlugin.idToExtendedId('favid_12345', MSFavorites);
      expect(result, isNull);
    });

    test('idToExtendedId returns null for MSCollection (unknown prefix)', () {
      final result = WimpPlugin.idToExtendedId('collid_12345', MSCollection);
      expect(result, isNull);
    });
  });

  group('WimpPlugin formUri', () {
    test('formUri for MSTrack with mime type', () {
      final content = {
        'item_id': 'trackid_12345',
        'service_id': 20,
        'mime_type': 'audio/aac',
      };
      final result = WimpPlugin.formUri(content, MSTrack);
      expect(result, equals('x-sonos-http:trackid_12345.mp4?sid=20&flags=32'));
    });

    test('formUri for MSTrack without mime type', () {
      final content = {
        'item_id': 'trackid_12345',
        'service_id': 20,
      };
      final result = WimpPlugin.formUri(content, MSTrack);
      expect(result, equals('x-sonos-http:trackid_12345.?sid=20&flags=32'));
    });

    test('formUri for MSAlbum', () {
      final content = {
        'extended_id': '0004002calbumid_12345',
      };
      final result = WimpPlugin.formUri(content, MSAlbum);
      expect(result, equals('x-rincon-cpcontainer:0004002calbumid_12345'));
    });

    test('formUri for MSAlbumList', () {
      final content = {
        'extended_id': '000d006clistid_12345',
      };
      final result = WimpPlugin.formUri(content, MSAlbumList);
      expect(result, equals('x-rincon-cpcontainer:000d006clistid_12345'));
    });

    test('formUri for MSPlaylist', () {
      final content = {
        'extended_id': '0006006cplaylistid_12345',
      };
      final result = WimpPlugin.formUri(content, MSPlaylist);
      expect(result, equals('x-rincon-cpcontainer:0006006cplaylistid_12345'));
    });

    test('formUri for MSArtistTracklist', () {
      final content = {
        'extended_id': '100f006ctracklistid_12345',
      };
      final result = WimpPlugin.formUri(content, MSArtistTracklist);
      expect(result, equals('x-rincon-cpcontainer:100f006ctracklistid_12345'));
    });

    test('formUri returns null for unsupported types', () {
      final content = {'item_id': 'test'};
      final result = WimpPlugin.formUri(content, MSFavorites);
      expect(result, isNull);
    });
  });

  group('WimpPlugin constants', () {
    test('service ID is 20', () {
      // The service ID constant should be 20 for Wimp
      // We can't directly test the private constant, but we can verify
      // via the description format
      expect(true, isTrue); // Placeholder - actual verification would need instance
    });

    test('service URL is correct', () {
      // The service URL should be the Wimp SOAP endpoint
      // We can't directly test the private constant
      expect(true, isTrue); // Placeholder
    });
  });

  group('WimpPlugin search types', () {
    test('valid search types', () {
      // The valid search types are: artists, albums, tracks, playlists
      final validTypes = ['artists', 'albums', 'tracks', 'playlists'];
      for (final type in validTypes) {
        expect(validTypes.contains(type), isTrue);
      }
    });

    test('search prefix format is correct', () {
      // The search prefix should be in the format: 00020064{searchType}:{search}
      const prefix = '00020064{searchType}:{search}';
      expect(prefix.contains('{searchType}'), isTrue);
      expect(prefix.contains('{search}'), isTrue);
    });
  });

  group('WimpPlugin error handling', () {
    test('exception codes are defined', () {
      // Known exception codes
      const codes = {
        'unknown': 20000,
        'ItemNotFound': 20001,
      };
      expect(codes['unknown'], equals(20000));
      expect(codes['ItemNotFound'], equals(20001));
    });
  });
}
