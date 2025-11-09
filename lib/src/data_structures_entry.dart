/// This module is for parsing and conversion functions that need
/// objects from both music library and music service data structures.
library;

import 'package:logging/logging.dart';
import 'package:xml/xml.dart';

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
final Map<String, List<dynamic>> _fromDidlStringCache = {};

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
List<dynamic> fromDidlString(String string) {
  // Check cache
  if (_fromDidlStringCache.containsKey(string)) {
    return _fromDidlStringCache[string]!;
  }

  final items = <dynamic>[];

  // Parse with error recovery
  XmlDocument document;
  try {
    document = XmlDocument.parse(string);
  } catch (e) {
    // Try with a more lenient parser by removing any potential issues
    final cleaned = string.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'),
      '',
    );
    document = XmlDocument.parse(cleaned);
  }

  final root = document.rootElement;

  for (final element in root.childElements) {
    final tag = element.name.local;

    if (tag == 'item' || tag == 'container') {
      // Find the upnp:class element
      final itemClassElement = element
          .findElements(soco_xml.nsTag('upnp', 'class'))
          .firstOrNull;

      if (itemClassElement == null) {
        throw DIDLMetadataError('Missing upnp:class element');
      }

      final itemClass = itemClassElement.innerText;

      if (didlClassToSoCoClass == null) {
        throw DIDLMetadataError(
          'didlClassToSoCoClass function not set. Import data_structures.dart first.',
        );
      }

      // Get the appropriate class and create instance from element
      final cls = didlClassToSoCoClass!(itemClass);

      // This would require fromElement static method on the class
      // For now, we'll just store the class type
      // TODO: Implement fromElement factory methods in data structures
      items.add({'class': cls, 'element': element});
    } else {
      // <desc> elements are allowed as an immediate child of <DIDL-Lite>
      // according to the spec, but we have not seen one there in Sonos, so
      // we treat them as illegal. May need to fix this if this
      // causes problems.
      throw DIDLMetadataError('Illegal child of DIDL element: <$tag>');
    }
  }

  _log.fine(
    'Created data structures: ${items.toString().substring(0, 20)} (CUT) from Didl string "${string.substring(0, 20)}" (CUT)',
  );

  // Cache the result
  _fromDidlStringCache[string] = items;

  return items;
}

/// Clear the fromDidlString cache
void clearFromDidlStringCache() {
  _fromDidlStringCache.clear();
}
