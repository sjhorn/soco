/// This module contains XML related utility functions.
library;

/// Commonly used namespaces, and abbreviations, used by [nsTag].
const Map<String, String> namespaces = {
  'dc': 'http://purl.org/dc/elements/1.1/',
  'upnp': 'urn:schemas-upnp-org:metadata-1-0/upnp/',
  '': 'urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/',
  'ms': 'http://www.sonos.com/Services/1.1',
  'r': 'urn:schemas-rinconnetworks-com:metadata-1-0/',
};

/// Regular expression for filtering invalid XML characters.
///
/// This pattern matches characters that are illegal in XML according to
/// the XML specification.
final RegExp illegalXmlRe = RegExp(
  r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x84\x86-\x9F'
  r'\uD800-\uDFFF\uFDD0-\uFDDF\uFFFE\uFFFF]',
  // Note: Dart strings use UTF-16, so we can't directly represent
  // code points above 0xFFFF in a character class. For now, we cover
  // the Basic Multilingual Plane (BMP).
);

/// Return a namespace/tag item.
///
/// The [nsId] is translated to a full namespace via the [namespaces]
/// constant.
///
/// Parameters:
///   - [nsId]: A namespace id, e.g., "dc" (see [namespaces])
///   - [tag]: An XML tag, e.g., "author"
///
/// Returns:
///   A fully qualified tag.
///
/// Example:
/// ```dart
/// nsTag('dc', 'author')
/// // Returns: '{http://purl.org/dc/elements/1.1/}author'
/// ```
// Pre-computed namespace tags for common cases (optimization)
const Map<String, Map<String, String>> _precomputedNsTags = {
  'dc': {
    'title': '{http://purl.org/dc/elements/1.1/}title',
    'creator': '{http://purl.org/dc/elements/1.1/}creator',
  },
  'upnp': {
    'class': '{urn:schemas-upnp-org:metadata-1-0/upnp/}class',
    'artist': '{urn:schemas-upnp-org:metadata-1-0/upnp/}artist',
    'album': '{urn:schemas-upnp-org:metadata-1-0/upnp/}album',
  },
};

/// Return a namespace/tag item.
///
/// The [nsId] is translated to a full namespace via the [namespaces]
/// constant.
///
/// Parameters:
///   - [nsId]: A namespace id, e.g., "dc" (see [namespaces])
///   - [tag]: An XML tag, e.g., "author"
///
/// Returns:
///   A fully qualified tag.
///
/// Example:
/// ```dart
/// nsTag('dc', 'author')
/// // Returns: '{http://purl.org/dc/elements/1.1/}author'
/// ```
String nsTag(String nsId, String tag) {
  // Check pre-computed cache first (common cases)
  final precomputed = _precomputedNsTags[nsId]?[tag];
  if (precomputed != null) {
    return precomputed;
  }

  final namespace = namespaces[nsId];
  if (namespace == null) {
    throw ArgumentError('Unknown namespace ID: $nsId');
  }
  return '{$namespace}$tag';
}

/// Remove illegal XML characters from a string.
///
/// Parameters:
///   - [text]: The string to filter
///
/// Returns:
///   The filtered string with illegal XML characters removed.
String filterIllegalXmlChars(String text) {
  return text.replaceAll(illegalXmlRe, '');
}
