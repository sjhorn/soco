/// Example demonstrating music library browsing with the Dart SoCo library.
///
/// This example shows how to:
/// - Search the music library
/// - Browse artists, albums, tracks, playlists
/// - Get search results with paging
/// - Use convenience methods for library access
library;

import 'package:soco/soco.dart';

Future<void> main() async {
  print('=== Sonos Music Library Example ===\n');

  // Discover a Sonos device
  print('Discovering Sonos devices...');
  final device = await anySoco();

  if (device == null) {
    print('No Sonos devices found!');
    return;
  }

  print('Connected to: ${await device.playerName}\n');

  // Get the music library instance
  final library = device.musicLibrary;

  // Example 1: Get all artists
  print('--- Artists in Library ---');
  try {
    final artists = await library.getArtists();
    print(
      'Found ${artists.totalMatches} artists (showing first ${artists.numberReturned}):',
    );

    for (final item in artists.items.take(10)) {
      print('  - ${item['title'] ?? 'Unknown'}');
    }
  } catch (e) {
    print('Error getting artists: $e');
  }

  // Example 2: Search for specific tracks
  print('\n--- Search for Tracks ---');
  try {
    final results = await library.getTracks(searchTerm: 'love', maxItems: 5);
    print('Search for "love" found ${results.totalMatches} tracks:');

    for (final item in results.items) {
      print('  - ${item.title}');
      final creator = item['creator'];
      if (creator != null) {
        print('    by $creator');
      }
    }
  } catch (e) {
    print('Error searching: $e');
  }

  // Example 3: Browse albums
  print('\n--- Albums in Library ---');
  try {
    final albums = await library.getAlbums(maxItems: 10);
    print(
      'Found ${albums.totalMatches} albums (showing first ${albums.numberReturned}):',
    );

    for (final item in albums.items) {
      print('  - ${item.title}');
      final creator = item['creator'];
      if (creator != null) {
        print('    by $creator');
      }
    }
  } catch (e) {
    print('Error getting albums: $e');
  }

  // Example 4: Get playlists
  print('\n--- Playlists ---');
  try {
    final playlists = await library.getPlaylists();
    print('Found ${playlists.totalMatches} playlists:');

    for (final item in playlists.items.take(10)) {
      print('  - ${item['title'] ?? 'Unknown'}');
    }
  } catch (e) {
    print('Error getting playlists: $e');
  }

  // Example 5: Browse by genre
  print('\n--- Genres ---');
  try {
    final genres = await library.getGenres(maxItems: 10);
    print('Found ${genres.totalMatches} genres:');

    for (final item in genres.items) {
      print('  - ${item['title'] ?? 'Unknown'}');
    }
  } catch (e) {
    print('Error getting genres: $e');
  }

  // Example 6: Get tracks
  print('\n--- Tracks in Library ---');
  try {
    final tracks = await library.getTracks(maxItems: 10);
    print('Found ${tracks.totalMatches} tracks (showing first 10):');

    for (final item in tracks.items) {
      print('  - ${item.title}');
      final creator = item['creator'];
      if (creator != null) {
        print('    by $creator');
      }
    }
  } catch (e) {
    print('Error getting tracks: $e');
  }

  // Example 7: Advanced search with paging
  print('\n--- Advanced Search with Paging ---');
  try {
    // Get first page
    final page1 = await library.getTracks(
      searchTerm: 'love',
      start: 0,
      maxItems: 5,
    );
    print('Search for "love" found ${page1.totalMatches} tracks');
    print('\nPage 1 (items 1-5):');

    for (var i = 0; i < page1.items.length; i++) {
      print('  ${i + 1}. ${page1.items[i].title}');
    }

    // Get second page
    if (page1.totalMatches > 5) {
      final page2 = await library.getTracks(
        searchTerm: 'love',
        start: 5,
        maxItems: 5,
      );
      print('\nPage 2 (items 6-10):');

      for (var i = 0; i < page2.items.length; i++) {
        print('  ${i + 6}. ${page2.items[i].title}');
      }
    }
  } catch (e) {
    print('Error with paged search: $e');
  }

  // Example 8: Get composers
  print('\n--- Composers ---');
  try {
    final composers = await library.getComposers(maxItems: 10);
    print('Found ${composers.totalMatches} composers:');

    for (final item in composers.items) {
      print('  - ${item['title'] ?? 'Unknown'}');
    }
  } catch (e) {
    print('Error getting composers: $e');
  }

  // Example 9: Browse specific category
  print('\n--- Browse by Music Category ---');
  try {
    final result = await library.browseByIdstring(
      'A:ARTIST',
      'artists',
      start: 0,
      maxItems: 5,
    );
    print('Browsing artists category:');
    for (final item in result.items) {
      print('  - ${item['title'] ?? 'Unknown'}');
    }
  } catch (e) {
    print('Error browsing category: $e');
  }

  // Example 10: Get album art URI
  print('\n--- Album Art ---');
  try {
    final albums = await library.getAlbums(maxItems: 1, fullAlbumArtUri: true);
    if (albums.items.isNotEmpty) {
      final album = albums.items.first;
      print('Album: ${album.title}');

      final artUri = album['album_art_uri'];
      if (artUri != null) {
        print('Album art URL: $artUri');
      }
    }
  } catch (e) {
    print('Error getting album art: $e');
  }

  print('\n=== Example Complete ===');
  print(
    '\nNote: The amount of data available depends on your local music library.',
  );
  print(
    'If you see limited results, try adding more music to your Sonos library.',
  );
}
