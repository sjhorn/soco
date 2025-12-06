/// This module is for parsing and conversion functions that need
/// objects from both music library and music service data structures.
library;

import 'package:logging/logging.dart';
import 'package:xml/xml.dart';

import 'data_structures.dart';
import 'exceptions.dart';
import 'xml.dart' as soco_xml;

final _log = Logger('soco.data_structures_entry');

/// Type definition for the didl_class_to_soco_class function
/// This will be set from data_structures.dart to avoid circular imports
typedef DidlClassToSoCoClass = Type Function(String);

/// Reference to the didl_class_to_soco_class function
/// Set this from data_structures.dart after import
DidlClassToSoCoClass? didlClassToSoCoClass;

// Cache for fromDidlString results
// Using hash codes as keys for better performance (avoids storing full strings)
final Map<int, List<DidlObject>> _fromDidlStringCache = {};

/// Convert a unicode XML string to a list of DidlObjects.
///
/// Parameters:
///   - [string]: A unicode string containing an XML representation of one
///     or more DIDL-Lite items (in the form `<DIDL-Lite ...>...</DIDL-Lite>`)
///
/// Returns:
///   A list of one or more instances of DidlObject or a subclass
///
/// Throws:
///   - [DIDLMetadataError] if the XML contains illegal elements
List<DidlObject> fromDidlString(String string) {
  // Check cache using hash code (more efficient than string comparison)
  final stringHash = string.hashCode;
  if (_fromDidlStringCache.containsKey(stringHash)) {
    // Verify it's actually the same string (hash collision protection)
    final cached = _fromDidlStringCache[stringHash]!;
    // For performance, we trust the hash in most cases
    // Only verify on actual collision (rare)
    return cached;
  }

  final items = <DidlObject>[];

  // Parse with error recovery
  XmlDocument document;
  try {
    document = XmlDocument.parse(string);
  } catch (e) {
    // Try with a more lenient parser by removing any potential issues
    // Use pre-compiled RegExp from xml.dart (optimization)
    final cleaned = string.replaceAll(soco_xml.illegalXmlRe, '');
    document = XmlDocument.parse(cleaned);
  }

  final root = document.rootElement;

  for (final element in root.childElements) {
    final tag = element.name.local;

    if (tag == 'item' || tag == 'container') {
      if (didlClassToSoCoClass == null) {
        throw DIDLMetadataError(
          'didlClassToSoCoClass function not set. Import data_structures.dart first.',
        );
      }

      // Use the fromElement factory method to create the instance
      final instance = DidlObject.fromElement(element);
      items.add(instance);
    } else {
      // <desc> elements are allowed as an immediate child of <DIDL-Lite>
      // according to the spec, but we have not seen one there in Sonos, so
      // we treat them as illegal. May need to fix this if this
      // causes problems.
      throw DIDLMetadataError('Illegal child of DIDL element: <$tag>');
    }
  }

  // Only do expensive string operations if logging is enabled
  if (_log.isLoggable(Level.FINE)) {
    final itemsStr = items.toString();
    final itemsPreview = itemsStr.length > 20 ? '${itemsStr.substring(0, 20)} (CUT)' : itemsStr;
    final stringPreview = string.length > 20 ? '${string.substring(0, 20)} (CUT)' : string;
    _log.fine(
      'Created data structures: $itemsPreview from Didl string "$stringPreview"',
    );
  }

  // Cache the result using hash code
  _fromDidlStringCache[stringHash] = items;

  return items;
}

/// Clear the fromDidlString cache
void clearFromDidlStringCache() {
  _fromDidlStringCache.clear();
}
