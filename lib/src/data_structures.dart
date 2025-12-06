/// This module contains classes for handling DIDL-Lite metadata.
///
/// DIDL is the Digital Item Declaration Language, an XML schema which is
/// part of MPEG21. DIDL-Lite is a cut-down version of the schema which is part
/// of the UPnP ContentDirectory specification. It is the XML schema used by Sonos
/// for carrying metadata representing many items such as tracks, playlists,
/// composers, albums, etc.
library;

import 'package:logging/logging.dart';
import 'package:xml/xml.dart';

import 'data_structure_quirks.dart';
import 'data_structures_entry.dart' as entry;
import 'exceptions.dart';
import 'utils.dart';
import 'xml.dart' as soco_xml;

final _log = Logger('soco.data_structures');

// Global mapping of DIDL class strings to Dart classes
final Map<String, Type> _didlClassToClass = {};

// Global mapping of DIDL class strings to factory functions for dynamically created classes
final Map<
  String,
  DidlObject Function({
    required String title,
    required String parentId,
    required String itemId,
    bool? restricted,
    List<DidlResource>? resources,
    Map<String, dynamic>? desc,
    Map<String, dynamic>? metadata,
  })
>
_didlClassToFactory = {};

/// Official DIDL-Lite classes
const Set<String> officialClasses = {
  'object',
  'object.item',
  'object.item.audioItem',
  'object.item.audioItem.musicTrack',
  'object.item.audioItem.audioBroadcast',
  'object.item.audioItem.audioBook',
  'object.item.audioItem.linein',
  'object.container',
  'object.container.person',
  'object.container.person.musicArtist',
  'object.container.playlistContainer',
  'object.container.album',
  'object.container.musicAlbum',
  'object.container.genre',
  'object.container.musicGenre',
};

///////////////////////////////////////////////////////////////////////////////
// MISC HELPER FUNCTIONS                                                     //
///////////////////////////////////////////////////////////////////////////////

/// Convert any number of DidlObjects to a unicode XML string.
///
/// Parameters:
///   - [objects]: One or more DidlObject instances
///
/// Returns:
///   A unicode string representation of DIDL-Lite XML in the form
///   `<DIDL-Lite ...>...</DIDL-Lite>`
String toDidlString(List<DidlObject> objects) {
  final builder = XmlBuilder();
  builder.element(
    'DIDL-Lite',
    namespaces: {
      '': 'urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/',
      'dc': 'http://purl.org/dc/elements/1.1/',
      'upnp': 'urn:schemas-upnp-org:metadata-1-0/upnp/',
      'r': 'urn:schemas-rinconnetworks-com:metadata-1-0/',
    },
    nest: () {
      for (final obj in objects) {
        builder.element(obj.tag, nest: () => obj.toElement(builder));
      }
    },
  );

  return builder.buildDocument().toXmlString();
}

/// Translate a DIDL-Lite class to the corresponding SoCo data structures class.
///
/// For unknown classes, this will create a factory function that returns
/// instances of the appropriate base class with the DIDL class name stored.
Type didlClassToSoCoClass(String didlClass) {
  // Certain music services have been observed to sub-class via a .# or # syntax.
  // We simply remove these subclasses.
  for (final separator in ['.#', '#']) {
    if (didlClass.contains(separator)) {
      didlClass = didlClass.substring(0, didlClass.indexOf(separator));
    }
  }

  if (_didlClassToClass.containsKey(didlClass)) {
    return _didlClassToClass[didlClass]!;
  }

  // Unknown class - create a factory function dynamically
  // Find the base class by removing the last component
  final parts = didlClass.split('.');
  if (parts.length < 2) {
    _log.warning('Unknown DIDL class: $didlClass, returning DidlObject');
    return DidlObject;
  }

  // Get the base class (everything except the last component)
  final baseClassParts = parts.sublist(0, parts.length - 1);
  final baseClassString = baseClassParts.join('.');
  final baseClass = didlClassToSoCoClass(baseClassString);

  // Create a factory function for this unknown class
  // Use a helper function to create the instance with the correct type
  _didlClassToFactory[didlClass] =
      ({
        required String title,
        required String parentId,
        required String itemId,
        bool? restricted,
        List<DidlResource>? resources,
        Map<String, dynamic>? desc,
        Map<String, dynamic>? metadata,
      }) {
        // Create instance of the base class with the DIDL class override
        // We need to handle all possible base classes
        final descString =
            desc?['RINCON_AssociatedZPUDN'] ?? 'RINCON_AssociatedZPUDN';

        // Check if baseClass is a container type
        if (baseClass == DidlContainer ||
            baseClass == DidlAlbum ||
            baseClass == DidlMusicAlbum ||
            baseClass == DidlPerson ||
            baseClass == DidlComposer ||
            baseClass == DidlMusicArtist ||
            baseClass == DidlPlaylistContainer ||
            baseClass == DidlGenre ||
            baseClass == DidlMusicGenre) {
          // Use the most specific container constructor available
          if (baseClass == DidlAlbum) {
            return DidlAlbum(
              title: title,
              parentId: parentId,
              itemId: itemId,
              restricted: restricted ?? true,
              resources: resources,
              desc: descString,
              metadata: metadata,
              itemClassOverride: didlClass,
            );
          } else if (baseClass == DidlMusicAlbum) {
            return DidlMusicAlbum(
              title: title,
              parentId: parentId,
              itemId: itemId,
              restricted: restricted ?? true,
              resources: resources,
              desc: descString,
              metadata: metadata,
              itemClassOverride: didlClass,
            );
          } else if (baseClass == DidlPerson) {
            return DidlPerson(
              title: title,
              parentId: parentId,
              itemId: itemId,
              restricted: restricted ?? true,
              resources: resources,
              desc: descString,
              metadata: metadata,
              itemClassOverride: didlClass,
            );
          } else if (baseClass == DidlComposer) {
            return DidlComposer(
              title: title,
              parentId: parentId,
              itemId: itemId,
              restricted: restricted ?? true,
              resources: resources,
              desc: descString,
              metadata: metadata,
              itemClassOverride: didlClass,
            );
          } else if (baseClass == DidlMusicArtist) {
            return DidlMusicArtist(
              title: title,
              parentId: parentId,
              itemId: itemId,
              restricted: restricted ?? true,
              resources: resources,
              desc: descString,
              metadata: metadata,
              itemClassOverride: didlClass,
            );
          } else if (baseClass == DidlPlaylistContainer) {
            return DidlPlaylistContainer(
              title: title,
              parentId: parentId,
              itemId: itemId,
              restricted: restricted ?? true,
              resources: resources,
              desc: descString,
              metadata: metadata,
              itemClassOverride: didlClass,
            );
          } else if (baseClass == DidlGenre) {
            return DidlGenre(
              title: title,
              parentId: parentId,
              itemId: itemId,
              restricted: restricted ?? true,
              resources: resources,
              desc: descString,
              metadata: metadata,
              itemClassOverride: didlClass,
            );
          } else if (baseClass == DidlMusicGenre) {
            return DidlMusicGenre(
              title: title,
              parentId: parentId,
              itemId: itemId,
              restricted: restricted ?? true,
              resources: resources,
              desc: descString,
              metadata: metadata,
              itemClassOverride: didlClass,
            );
          } else {
            // Default container
            return DidlContainer(
              title: title,
              parentId: parentId,
              itemId: itemId,
              restricted: restricted ?? true,
              resources: resources,
              desc: descString,
              metadata: metadata,
              itemClassOverride: didlClass,
            );
          }
        } else if (baseClass == DidlAudioItem ||
            baseClass == DidlMusicTrack ||
            baseClass == DidlAudioBook ||
            baseClass == DidlAudioBroadcast ||
            baseClass == DidlAudioLineIn) {
          // Use the most specific audio item constructor
          if (baseClass == DidlMusicTrack) {
            return DidlMusicTrack(
              title: title,
              parentId: parentId,
              itemId: itemId,
              restricted: restricted ?? true,
              resources: resources,
              desc: descString,
              metadata: metadata,
              itemClassOverride: didlClass,
            );
          } else if (baseClass == DidlAudioBook) {
            return DidlAudioBook(
              title: title,
              parentId: parentId,
              itemId: itemId,
              restricted: restricted ?? true,
              resources: resources,
              desc: descString,
              metadata: metadata,
              itemClassOverride: didlClass,
            );
          } else if (baseClass == DidlAudioBroadcast) {
            return DidlAudioBroadcast(
              title: title,
              parentId: parentId,
              itemId: itemId,
              restricted: restricted ?? true,
              resources: resources,
              desc: descString,
              metadata: metadata,
              itemClassOverride: didlClass,
            );
          } else if (baseClass == DidlAudioLineIn) {
            return DidlAudioLineIn(
              title: title,
              parentId: parentId,
              itemId: itemId,
              restricted: restricted ?? true,
              resources: resources,
              desc: descString,
              metadata: metadata,
              itemClassOverride: didlClass,
            );
          } else {
            return DidlAudioItem(
              title: title,
              parentId: parentId,
              itemId: itemId,
              restricted: restricted ?? true,
              resources: resources,
              desc: descString,
              metadata: metadata,
              itemClassOverride: didlClass,
            );
          }
        } else if (baseClass == DidlItem) {
          return DidlItem(
            title: title,
            parentId: parentId,
            itemId: itemId,
            restricted: restricted ?? true,
            resources: resources,
            desc: descString,
            metadata: metadata,
            itemClassOverride: didlClass,
          );
        } else {
          // Default to DidlObject
          return DidlObject(
            title: title,
            parentId: parentId,
            itemId: itemId,
            restricted: restricted ?? true,
            resources: resources,
            desc: descString,
            metadata: metadata,
            itemClassOverride: didlClass,
          );
        }
      };

  // Register the factory and return the base class type
  // Note: We can't return a new Type, so we return the base class
  // but the factory function will create instances with the correct itemClass
  _log.fine(
    'Created dynamic factory for unknown DIDL class: $didlClass (base: $baseClass)',
  );
  return baseClass;
}

/// Get a factory function for creating instances of a DIDL class.
///
/// Returns a factory function if the class was dynamically created,
/// or null if it's a standard class.
DidlObject Function({
  required String title,
  required String parentId,
  required String itemId,
  bool? restricted,
  List<DidlResource>? resources,
  Map<String, dynamic>? desc,
  Map<String, dynamic>? metadata,
})?
getDidlClassFactory(String didlClass) {
  // Clean up the class name
  for (final separator in ['.#', '#']) {
    if (didlClass.contains(separator)) {
      didlClass = didlClass.substring(0, didlClass.indexOf(separator));
    }
  }
  return _didlClassToFactory[didlClass];
}

/// Return an improvised name for vendor extended classes.
String formName(String didlClass) {
  if (!didlClass.startsWith('object.')) {
    throw DIDLMetadataError('Unknown UPnP class: $didlClass');
  }

  final parts = didlClass.split('.');

  // If it is a Sonos favorite, form the name as the class component
  // before with "Favorite" added
  if (parts.last == 'sonos-favorite' && parts.length >= 2) {
    return 'Didl${firstCap(parts[parts.length - 2])}Favorite';
  }

  // For any other class, form the name as the concatenation of all
  // the class components that are not UPnP core classes
  var searchParts = List<String>.from(parts);
  final newParts = <String>[];

  // Strip the components one by one and check whether the base is known
  while (searchParts.isNotEmpty) {
    newParts.add(searchParts.last);
    searchParts.removeLast();
    final searchClass = searchParts.join('.');
    if (officialClasses.contains(searchClass)) {
      break;
    }
  }

  // For class path last parts that contain the word list, capitalize it
  if (newParts[0].endsWith('list')) {
    newParts[0] = newParts[0].replaceAll('list', 'List');
  }

  return 'Didl${newParts.reversed.map(firstCap).join()}';
}

///////////////////////////////////////////////////////////////////////////////
// DIDL RESOURCE                                                             //
///////////////////////////////////////////////////////////////////////////////

/// Identifies a resource, typically some type of binary asset, such as a song.
///
/// It is represented in XML by a `<res>` element, which contains a URI that
/// identifies the resource.
class DidlResource {
  /// A percent encoded URI
  final String uri;

  /// Protocol information (format: a:b:c:d)
  final String protocolInfo;

  /// URI locator for resource update
  final String? importUri;

  /// Size in bytes
  final int? size;

  /// Duration of the playback (H*:MM:SS:F* or H*:MM:SS:F0/F1)
  final String? duration;

  /// Bitrate in bytes/second
  final int? bitrate;

  /// Sample frequency in Hz
  final int? sampleFrequency;

  /// Bits per sample
  final int? bitsPerSample;

  /// Number of audio channels
  final int? nrAudioChannels;

  /// Resolution of the resource (X*Y)
  final String? resolution;

  /// Color depth in bits
  final int? colorDepth;

  /// Statement of protection type
  final String? protection;

  /// Creates a DIDL resource.
  const DidlResource({
    required this.uri,
    required this.protocolInfo,
    this.importUri,
    this.size,
    this.duration,
    this.bitrate,
    this.sampleFrequency,
    this.bitsPerSample,
    this.nrAudioChannels,
    this.resolution,
    this.colorDepth,
    this.protection,
  });

  /// Create a DidlResource from an XML element.
  factory DidlResource.fromElement(XmlElement element) {
    // Helper to convert attribute to int
    int? intHelper(String name) {
      final value = element.getAttribute(name);
      if (value != null) {
        try {
          return int.parse(value);
        } catch (e) {
          throw DIDLMetadataError('Could not convert $name to an integer');
        }
      }
      return null;
    }

    // Apply quirks
    final fixed = applyResourceQuirks(element);

    // Required
    final protocolInfo = fixed.getAttribute('protocolInfo');
    if (protocolInfo == null) {
      throw DIDLMetadataError(
        'Could not create Resource from Element: protocolInfo not found (required).',
      );
    }

    return DidlResource(
      uri: fixed.innerText,
      protocolInfo: protocolInfo,
      importUri: fixed.getAttribute('importUri'),
      size: intHelper('size'),
      duration: fixed.getAttribute('duration'),
      bitrate: intHelper('bitrate'),
      sampleFrequency: intHelper('sampleFrequency'),
      bitsPerSample: intHelper('bitsPerSample'),
      nrAudioChannels: intHelper('nrAudioChannels'),
      resolution: fixed.getAttribute('resolution'),
      colorDepth: intHelper('colorDepth'),
      protection: fixed.getAttribute('protection'),
    );
  }

  /// Build this resource directly into an XmlBuilder (more efficient).
  ///
  /// This method is more efficient than [toElement] when building XML
  /// as it avoids creating intermediate XmlElement objects.
  void toElementInBuilder(XmlBuilder builder) {
    builder.element(
      'res',
      nest: () {
        // Required
        builder.attribute('protocolInfo', protocolInfo);

        // Optional
        if (importUri != null) builder.attribute('importUri', importUri!);
        // Optimize: cache toString() results for integers
        if (size != null) builder.attribute('size', size.toString());
        if (duration != null) builder.attribute('duration', duration!);
        if (bitrate != null) builder.attribute('bitrate', bitrate.toString());
        if (sampleFrequency != null) {
          builder.attribute('sampleFrequency', sampleFrequency.toString());
        }
        if (bitsPerSample != null) {
          builder.attribute('bitsPerSample', bitsPerSample.toString());
        }
        if (nrAudioChannels != null) {
          builder.attribute('nrAudioChannels', nrAudioChannels.toString());
        }
        if (resolution != null) builder.attribute('resolution', resolution!);
        if (colorDepth != null) {
          builder.attribute('colorDepth', colorDepth.toString());
        }
        if (protection != null) builder.attribute('protection', protection!);

        builder.text(uri);
      },
    );
  }

  /// Return an XML Element based on this resource.
  ///
  /// For better performance when building XML, use [toElementInBuilder] instead.
  XmlElement toElement() {
    final builder = XmlBuilder();
    toElementInBuilder(builder);
    final fragment = builder.buildFragment();
    return fragment.children.whereType<XmlElement>().first;
  }

  /// Return a dict representation of the DidlResource.
  Map<String, dynamic> toDict({bool removeNones = false}) {
    final content = {
      'uri': uri,
      'protocol_info': protocolInfo,
      'import_uri': importUri,
      'size': size,
      'duration': duration,
      'bitrate': bitrate,
      'sample_frequency': sampleFrequency,
      'bits_per_sample': bitsPerSample,
      'nr_audio_channels': nrAudioChannels,
      'resolution': resolution,
      'color_depth': colorDepth,
      'protection': protection,
    };

    if (removeNones) {
      content.removeWhere((key, value) => value == null);
    }

    return content;
  }

  @override
  String toString() => "<DidlResource '$uri' at ${hashCode.toRadixString(16)}>";
}

///////////////////////////////////////////////////////////////////////////////
// DIDL OBJECT                                                               //
///////////////////////////////////////////////////////////////////////////////

/// Abstract base class for all DIDL-Lite items.
///
/// You should not need to instantiate this directly.
class DidlObject {
  /// The DIDL Lite class for this object
  static const String itemClass = 'object';

  /// Instance-level override for itemClass (used for dynamically created classes)
  final String? _itemClassOverride;

  /// Get the item class for this instance (uses override if present, otherwise static constant)
  /// Subclasses should override this to return their static itemClass when no override is set
  String get effectiveItemClass => _itemClassOverride ?? itemClass;

  /// The XML element tag name used for this instance
  String tag = 'item';

  /// The title for the item
  final String title;

  /// The parent ID for the item
  final String parentId;

  /// The ID for the item
  final String itemId;

  /// Whether the item can be modified
  final bool restricted;

  /// A list of resources for this object
  final List<DidlResource> resources;

  /// A DIDL descriptor
  final String desc;

  /// Extra metadata
  final Map<String, dynamic> _metadata;

  /// Translation between attribute names and XML tags/namespaces
  static const Map<String, List<String>> translation = {
    'creator': ['dc', 'creator'],
    'write_status': ['upnp', 'writeStatus'],
  };

  /// Pre-computed lookup keys for translation entries (optimization)
  /// Maps metadata key -> 'namespaceUri:localName' for fast element lookup
  static final Map<String, String> _translationLookupKeys =
      _buildTranslationLookupKeys();

  static Map<String, String> _buildTranslationLookupKeys() {
    final keys = <String, String>{};
    for (final entry in translation.entries) {
      final tagInfo = entry.value;
      final namespaceUri = soco_xml.namespaces[tagInfo[0]];
      keys[entry.key] = '$namespaceUri:${tagInfo[1]}';
    }
    return keys;
  }

  /// Creates a DIDL object.
  DidlObject({
    required this.title,
    required this.parentId,
    required this.itemId,
    this.restricted = true,
    List<DidlResource>? resources,
    this.desc = 'RINCON_AssociatedZPUDN',
    Map<String, dynamic>? metadata,
    String? itemClassOverride,
  }) : resources = resources ?? [],
       _metadata = metadata ?? {},
       _itemClassOverride = itemClassOverride;

  /// Get metadata value.
  dynamic operator [](String key) => _metadata[key];

  /// Set metadata value.
  void operator []=(String key, dynamic value) => _metadata[key] = value;

  /// Create an instance of this class from an XML Element.
  ///
  /// An alternative constructor. The element must be a DIDL-Lite <item> or
  /// <container> element, and must be properly namespaced.
  ///
  /// Parameters:
  ///   - [element]: An XmlElement object representing a DIDL-Lite item or container
  ///
  /// Returns:
  ///   An instance of DidlObject or a subclass
  ///
  /// Throws:
  ///   - [DIDLMetadataError] if the XML is invalid or missing required elements
  static DidlObject fromElement(XmlElement element) {
    // Check that it's an item or container
    final tag = element.name.local;
    if (tag != 'item' && tag != 'container') {
      throw DIDLMetadataError(
        'Wrong element. Expected <item> or <container>, got <$tag>',
      );
    }

    // Find the upnp:class element
    final itemClassElement = element
        .findElements('class', namespace: soco_xml.namespaces['upnp'])
        .firstOrNull;

    if (itemClassElement == null) {
      throw DIDLMetadataError('Missing upnp:class element');
    }

    var itemClass = itemClassElement.innerText;

    // Strip subclass syntax (.# or #)
    for (final separator in ['.#', '#']) {
      if (itemClass.contains(separator)) {
        itemClass = itemClass.substring(0, itemClass.indexOf(separator));
      }
    }

    // Get the appropriate class type
    final cls = didlClassToSoCoClass(itemClass);

    // Check if we have a factory for this class (dynamic class)
    final factory = getDidlClassFactory(itemClass);
    if (factory != null) {
      // Use the factory to create the instance
      return _createFromElementUsingFactory(element, factory, itemClass);
    }

    // Otherwise, create instance based on class type
    return _createFromElementByType(element, cls, itemClass);
  }

  /// Helper to create instance using a factory function.
  static DidlObject _createFromElementUsingFactory(
    XmlElement element,
    DidlObject Function({
      required String title,
      required String parentId,
      required String itemId,
      bool? restricted,
      List<DidlResource>? resources,
      Map<String, dynamic>? desc,
      Map<String, dynamic>? metadata,
    })
    factory,
    String itemClass,
  ) {
    final (title, parentId, itemId, restricted, resources, desc, metadata) =
        _parseElementAttributes(element);

    return factory(
      title: title,
      parentId: parentId,
      itemId: itemId,
      restricted: restricted,
      resources: resources,
      desc: desc,
      metadata: metadata,
    );
  }

  /// Helper to create instance based on class type.
  static DidlObject _createFromElementByType(
    XmlElement element,
    Type cls,
    String itemClass,
  ) {
    final (title, parentId, itemId, restricted, resources, desc, metadata) =
        _parseElementAttributes(element);

    // Create instance based on class type
    if (cls == DidlMusicTrack) {
      return DidlMusicTrack(
        title: title,
        parentId: parentId,
        itemId: itemId,
        restricted: restricted,
        resources: resources,
        desc: desc?['RINCON_AssociatedZPUDN'] ?? 'RINCON_AssociatedZPUDN',
        metadata: metadata,
      );
    } else if (cls == DidlAudioBook) {
      return DidlAudioBook(
        title: title,
        parentId: parentId,
        itemId: itemId,
        restricted: restricted,
        resources: resources,
        desc: desc?['RINCON_AssociatedZPUDN'] ?? 'RINCON_AssociatedZPUDN',
        metadata: metadata,
      );
    } else if (cls == DidlAudioBroadcast) {
      return DidlAudioBroadcast(
        title: title,
        parentId: parentId,
        itemId: itemId,
        restricted: restricted,
        resources: resources,
        desc: desc?['RINCON_AssociatedZPUDN'] ?? 'RINCON_AssociatedZPUDN',
        metadata: metadata,
      );
    } else if (cls == DidlAudioLineIn) {
      return DidlAudioLineIn(
        title: title,
        parentId: parentId,
        itemId: itemId,
        restricted: restricted,
        resources: resources,
        desc: desc?['RINCON_AssociatedZPUDN'] ?? 'RINCON_AssociatedZPUDN',
        metadata: metadata,
      );
    } else if (cls == DidlAudioItem) {
      return DidlAudioItem(
        title: title,
        parentId: parentId,
        itemId: itemId,
        restricted: restricted,
        resources: resources,
        desc: desc?['RINCON_AssociatedZPUDN'] ?? 'RINCON_AssociatedZPUDN',
        metadata: metadata,
      );
    } else if (cls == DidlItem) {
      return DidlItem(
        title: title,
        parentId: parentId,
        itemId: itemId,
        restricted: restricted,
        resources: resources,
        desc: desc?['RINCON_AssociatedZPUDN'] ?? 'RINCON_AssociatedZPUDN',
        metadata: metadata,
      );
    } else if (cls == DidlMusicAlbum) {
      return DidlMusicAlbum(
        title: title,
        parentId: parentId,
        itemId: itemId,
        restricted: restricted,
        resources: resources,
        desc: desc?['RINCON_AssociatedZPUDN'] ?? 'RINCON_AssociatedZPUDN',
        metadata: metadata,
      );
    } else if (cls == DidlAlbum) {
      return DidlAlbum(
        title: title,
        parentId: parentId,
        itemId: itemId,
        restricted: restricted,
        resources: resources,
        desc: desc?['RINCON_AssociatedZPUDN'] ?? 'RINCON_AssociatedZPUDN',
        metadata: metadata,
      );
    } else if (cls == DidlComposer) {
      return DidlComposer(
        title: title,
        parentId: parentId,
        itemId: itemId,
        restricted: restricted,
        resources: resources,
        desc: desc?['RINCON_AssociatedZPUDN'] ?? 'RINCON_AssociatedZPUDN',
        metadata: metadata,
      );
    } else if (cls == DidlMusicArtist) {
      return DidlMusicArtist(
        title: title,
        parentId: parentId,
        itemId: itemId,
        restricted: restricted,
        resources: resources,
        desc: desc?['RINCON_AssociatedZPUDN'] ?? 'RINCON_AssociatedZPUDN',
        metadata: metadata,
      );
    } else if (cls == DidlPerson) {
      return DidlPerson(
        title: title,
        parentId: parentId,
        itemId: itemId,
        restricted: restricted,
        resources: resources,
        desc: desc?['RINCON_AssociatedZPUDN'] ?? 'RINCON_AssociatedZPUDN',
        metadata: metadata,
      );
    } else if (cls == DidlPlaylistContainer) {
      return DidlPlaylistContainer(
        title: title,
        parentId: parentId,
        itemId: itemId,
        restricted: restricted,
        resources: resources,
        desc: desc?['RINCON_AssociatedZPUDN'] ?? 'RINCON_AssociatedZPUDN',
        metadata: metadata,
      );
    } else if (cls == DidlMusicGenre) {
      return DidlMusicGenre(
        title: title,
        parentId: parentId,
        itemId: itemId,
        restricted: restricted,
        resources: resources,
        desc: desc?['RINCON_AssociatedZPUDN'] ?? 'RINCON_AssociatedZPUDN',
        metadata: metadata,
      );
    } else if (cls == DidlGenre) {
      return DidlGenre(
        title: title,
        parentId: parentId,
        itemId: itemId,
        restricted: restricted,
        resources: resources,
        desc: desc?['RINCON_AssociatedZPUDN'] ?? 'RINCON_AssociatedZPUDN',
        metadata: metadata,
      );
    } else if (cls == DidlContainer) {
      return DidlContainer(
        title: title,
        parentId: parentId,
        itemId: itemId,
        restricted: restricted,
        resources: resources,
        desc: desc?['RINCON_AssociatedZPUDN'] ?? 'RINCON_AssociatedZPUDN',
        metadata: metadata,
      );
    } else {
      // Default to DidlObject
      return DidlObject(
        title: title,
        parentId: parentId,
        itemId: itemId,
        restricted: restricted,
        resources: resources,
        desc: desc?['RINCON_AssociatedZPUDN'] ?? 'RINCON_AssociatedZPUDN',
        metadata: metadata,
      );
    }
  }

  /// Parse common attributes and child elements from an XML element.
  static (
    String title,
    String parentId,
    String itemId,
    bool restricted,
    List<DidlResource> resources,
    Map<String, dynamic>? desc,
    Map<String, dynamic> metadata,
  )
  _parseElementAttributes(XmlElement element) {
    // Extract attributes
    final itemId = element.getAttribute('id');
    if (itemId == null || itemId.isEmpty) {
      throw DIDLMetadataError('Missing id attribute');
    }

    final parentId = element.getAttribute('parentID');
    if (parentId == null || parentId.isEmpty) {
      throw DIDLMetadataError('Missing parentID attribute');
    }

    // CAUTION: This implementation deviates from the spec.
    // Elements are normally required to have a `restricted` tag, but
    // Spotify Direct violates this. To make it work, a missing restricted
    // tag is interpreted as `restricted = true`.
    final restrictedAttr = element.getAttribute('restricted');
    final restricted =
        restrictedAttr == null ||
        restrictedAttr == '' ||
        (restrictedAttr != '0' && restrictedAttr.toLowerCase() != 'false');

    // Optimize: collect child elements once for multiple lookups
    // Only build map if we have translation entries to process
    final needsMetadataLookup = translation.isNotEmpty;
    final childElements = needsMetadataLookup ? <String, XmlElement>{} : null;
    XmlElement? titleEl;
    XmlElement? descEl;
    final resElements = <XmlElement>[];

    for (final child in element.childElements) {
      final localName = child.name.local;
      final namespaceUri = child.name.namespaceUri;

      // Track specific elements we need
      if (localName == 'title' && namespaceUri == soco_xml.namespaces['dc']) {
        titleEl = child;
      } else if (localName == 'desc') {
        descEl = child;
      } else if (localName == 'res') {
        resElements.add(child);
      }

      // Store for metadata lookup if needed
      if (needsMetadataLookup) {
        final key = '$namespaceUri:$localName';
        if (!childElements!.containsKey(key)) {
          childElements[key] = child;
        }
      }
    }

    // Extract title (dc:title)
    final title = titleEl?.innerText ?? '';

    // Extract resources
    final resources = <DidlResource>[];
    for (final resEl in resElements) {
      final protocolInfo = resEl.getAttribute('protocolInfo');
      if (protocolInfo == null || protocolInfo.isEmpty) {
        // Skip resources without protocolInfo (some favorites don't have it)
        continue;
      }
      final uri = resEl.innerText.trim();
      if (uri.isEmpty) {
        continue;
      }

      resources.add(DidlResource.fromElement(resEl));
    }

    // Extract desc element (There is only one in Sonos)
    // The desc is typically a string like 'RINCON_AssociatedZPUDN'
    // but we store it as a map for compatibility with factory functions
    Map<String, dynamic>? desc;
    if (descEl != null && descEl.innerText.isNotEmpty) {
      desc = {'RINCON_AssociatedZPUDN': descEl.innerText};
    }

    // Extract translated metadata elements
    // Use optimized lookup: map if available, otherwise direct findElements
    final metadata = <String, dynamic>{};
    if (needsMetadataLookup && childElements != null) {
      // Fast path: use pre-built map with pre-computed lookup keys
      for (final entry in translation.entries) {
        final lookupKey = _translationLookupKeys[entry.key];
        if (lookupKey == null) continue;
        final valueEl = childElements[lookupKey];
        if (valueEl != null) {
          final value = valueEl.innerText;
          if (value.isNotEmpty) {
            // Convert original_track_number to int if present
            if (entry.key == 'original_track_number') {
              metadata[entry.key] = int.tryParse(value) ?? value;
            } else {
              metadata[entry.key] = value;
            }
          }
        }
      }
    } else if (needsMetadataLookup) {
      // Fallback: direct lookup (shouldn't happen, but safe)
      for (final entry in translation.entries) {
        final tagInfo = entry.value;
        final valueEl = element
            .findElements(
              tagInfo[1],
              namespace: soco_xml.namespaces[tagInfo[0]],
            )
            .firstOrNull;
        if (valueEl != null) {
          final value = valueEl.innerText;
          if (value.isNotEmpty) {
            if (entry.key == 'original_track_number') {
              metadata[entry.key] = int.tryParse(value) ?? value;
            } else {
              metadata[entry.key] = value;
            }
          }
        }
      }
    }

    return (title, parentId, itemId, restricted, resources, desc, metadata);
  }

  /// Build XML element content.
  void toElement(XmlBuilder builder) {
    // Add attributes
    builder.attribute('id', itemId);
    builder.attribute('parentID', parentId);
    // Optimize: use const strings instead of toString()
    builder.attribute('restricted', restricted ? 'true' : 'false');

    // Title - use pre-computed nsTag
    builder.element(
      soco_xml.nsTag('dc', 'title'),
      nest: () {
        builder.text(title);
      },
    );

    // Class - use pre-computed nsTag
    builder.element(
      soco_xml.nsTag('upnp', 'class'),
      nest: () {
        builder.text(effectiveItemClass);
      },
    );

    // Resources - build directly instead of parse/serialize
    for (final resource in resources) {
      resource.toElementInBuilder(builder);
    }

    // Desc
    if (desc.isNotEmpty) {
      builder.element(
        'desc',
        attributes: {
          'id': 'cdudn',
          'nameSpace': 'urn:schemas-rinconnetworks-com:metadata-1-0/',
        },
        nest: () {
          builder.text(desc);
        },
      );
    }

    // Add extra metadata
    for (final entry in _metadata.entries) {
      if (translation.containsKey(entry.key)) {
        final tagInfo = translation[entry.key]!;
        builder.element(
          soco_xml.nsTag(tagInfo[0], tagInfo[1]),
          nest: () {
            builder.text(entry.value.toString());
          },
        );
      }
    }
  }

  @override
  String toString() {
    return '<${runtimeType.toString()} \'$title\' at ${hashCode.toRadixString(16)}>';
  }
}

///////////////////////////////////////////////////////////////////////////////
// DIDL ITEM SUBCLASSES                                                      //
///////////////////////////////////////////////////////////////////////////////

/// A basic DIDL item.
class DidlItem extends DidlObject {
  static const String itemClass = 'object.item';

  DidlItem({
    required super.title,
    required super.parentId,
    required super.itemId,
    super.restricted,
    super.resources,
    super.desc,
    super.metadata,
    super.itemClassOverride,
  });

  @override
  String get effectiveItemClass => _itemClassOverride ?? itemClass;
}

/// An audio item.
class DidlAudioItem extends DidlItem {
  static const String itemClass = 'object.item.audioItem';

  DidlAudioItem({
    required super.title,
    required super.parentId,
    required super.itemId,
    super.restricted,
    super.resources,
    super.desc,
    super.metadata,
    super.itemClassOverride,
  });

  @override
  String get effectiveItemClass => _itemClassOverride ?? itemClass;
}

/// A music track.
class DidlMusicTrack extends DidlAudioItem {
  static const String itemClass = 'object.item.audioItem.musicTrack';

  DidlMusicTrack({
    required super.title,
    required super.parentId,
    required super.itemId,
    super.restricted,
    super.resources,
    super.desc,
    super.metadata,
    super.itemClassOverride,
  });

  @override
  String get effectiveItemClass => _itemClassOverride ?? itemClass;
}

/// An audio book.
class DidlAudioBook extends DidlAudioItem {
  static const String itemClass = 'object.item.audioItem.audioBook';

  DidlAudioBook({
    required super.title,
    required super.parentId,
    required super.itemId,
    super.restricted,
    super.resources,
    super.desc,
    super.metadata,
    super.itemClassOverride,
  });

  @override
  String get effectiveItemClass => _itemClassOverride ?? itemClass;
}

/// An audio broadcast (radio).
class DidlAudioBroadcast extends DidlAudioItem {
  static const String itemClass = 'object.item.audioItem.audioBroadcast';

  DidlAudioBroadcast({
    required super.title,
    required super.parentId,
    required super.itemId,
    super.restricted,
    super.resources,
    super.desc,
    super.metadata,
    super.itemClassOverride,
  });

  @override
  String get effectiveItemClass => _itemClassOverride ?? itemClass;
}

/// Line-in audio source.
class DidlAudioLineIn extends DidlAudioItem {
  static const String itemClass = 'object.item.audioItem.linein';

  DidlAudioLineIn({
    required super.title,
    required super.parentId,
    required super.itemId,
    super.restricted,
    super.resources,
    super.desc,
    super.metadata,
    super.itemClassOverride,
  });

  @override
  String get effectiveItemClass => _itemClassOverride ?? itemClass;
}

///////////////////////////////////////////////////////////////////////////////
// DIDL CONTAINER SUBCLASSES                                                //
///////////////////////////////////////////////////////////////////////////////

/// A basic DIDL container.
class DidlContainer extends DidlObject {
  static const String itemClass = 'object.container';

  DidlContainer({
    required super.title,
    required super.parentId,
    required super.itemId,
    super.restricted,
    super.resources,
    super.desc,
    super.metadata,
    super.itemClassOverride,
  }) {
    tag = 'container';
  }

  @override
  String get effectiveItemClass => _itemClassOverride ?? itemClass;
}

/// An album container.
class DidlAlbum extends DidlContainer {
  static const String itemClass = 'object.container.album';

  DidlAlbum({
    required super.title,
    required super.parentId,
    required super.itemId,
    super.restricted,
    super.resources,
    super.desc,
    super.metadata,
    super.itemClassOverride,
  });

  @override
  String get effectiveItemClass => _itemClassOverride ?? itemClass;
}

/// A music album.
class DidlMusicAlbum extends DidlAlbum {
  static const String itemClass = 'object.container.musicAlbum';

  DidlMusicAlbum({
    required super.title,
    required super.parentId,
    required super.itemId,
    super.restricted,
    super.resources,
    super.desc,
    super.metadata,
    super.itemClassOverride,
  });

  @override
  String get effectiveItemClass => _itemClassOverride ?? itemClass;
}

/// A person container (artist, composer, etc).
class DidlPerson extends DidlContainer {
  static const String itemClass = 'object.container.person';

  DidlPerson({
    required super.title,
    required super.parentId,
    required super.itemId,
    super.restricted,
    super.resources,
    super.desc,
    super.metadata,
    super.itemClassOverride,
  });

  @override
  String get effectiveItemClass => _itemClassOverride ?? itemClass;
}

/// A composer.
class DidlComposer extends DidlPerson {
  static const String itemClass = 'object.container.person.composer';

  DidlComposer({
    required super.title,
    required super.parentId,
    required super.itemId,
    super.restricted,
    super.resources,
    super.desc,
    super.metadata,
    super.itemClassOverride,
  });

  @override
  String get effectiveItemClass => _itemClassOverride ?? itemClass;
}

/// A music artist.
class DidlMusicArtist extends DidlPerson {
  static const String itemClass = 'object.container.person.musicArtist';

  DidlMusicArtist({
    required super.title,
    required super.parentId,
    required super.itemId,
    super.restricted,
    super.resources,
    super.desc,
    super.metadata,
    super.itemClassOverride,
  });

  @override
  String get effectiveItemClass => _itemClassOverride ?? itemClass;
}

/// A playlist container.
class DidlPlaylistContainer extends DidlContainer {
  static const String itemClass = 'object.container.playlistContainer';

  DidlPlaylistContainer({
    required super.title,
    required super.parentId,
    required super.itemId,
    super.restricted,
    super.resources,
    super.desc,
    super.metadata,
    super.itemClassOverride,
  });

  @override
  String get effectiveItemClass => _itemClassOverride ?? itemClass;
}

/// A genre container.
class DidlGenre extends DidlContainer {
  static const String itemClass = 'object.container.genre';

  DidlGenre({
    required super.title,
    required super.parentId,
    required super.itemId,
    super.restricted,
    super.resources,
    super.desc,
    super.metadata,
    super.itemClassOverride,
  });

  @override
  String get effectiveItemClass => _itemClassOverride ?? itemClass;
}

/// A music genre.
class DidlMusicGenre extends DidlGenre {
  static const String itemClass = 'object.container.genre.musicGenre';

  DidlMusicGenre({
    required super.title,
    required super.parentId,
    required super.itemId,
    super.restricted,
    super.resources,
    super.desc,
    super.metadata,
    super.itemClassOverride,
  });

  @override
  String get effectiveItemClass => _itemClassOverride ?? itemClass;
}

///////////////////////////////////////////////////////////////////////////////
// SPECIAL LISTS                                                            //
///////////////////////////////////////////////////////////////////////////////

/// Container class for a list of music information items.
///
/// Instances of this class are returned from queries into the music library
/// or to music services. The attributes [totalMatches] and [numberReturned]
/// are used to ascertain whether paging is required in order to retrieve all
/// elements of the query.
class SearchResult {
  /// The list of items returned
  final List<DidlObject> items;

  /// The search type (e.g., 'artists', 'albums')
  final String searchType;

  /// The number of items actually returned
  final int numberReturned;

  /// The total number of matches for the query
  final int totalMatches;

  /// Update ID for the content directory
  final int? updateId;

  /// Creates a SearchResult.
  SearchResult(
    this.items,
    this.searchType,
    this.numberReturned,
    this.totalMatches,
    this.updateId,
  );

  @override
  String toString() =>
      'SearchResult(items: ${items.length}, searchType: \'$searchType\')';
}

/// Container class that represents a queue.
///
/// Similar to [SearchResult] but without a search type.
class QueueResult {
  /// The list of items in the queue
  final List<DidlObject> items;

  /// The number of items actually returned
  final int numberReturned;

  /// The total number of matches for the query
  final int totalMatches;

  /// Update ID for the content directory
  final int? updateId;

  /// Creates a QueueResult.
  QueueResult({
    required this.items,
    required this.numberReturned,
    required this.totalMatches,
    this.updateId,
  });

  @override
  String toString() =>
      'QueueResult(items: ${items.length}, numberReturned: $numberReturned, totalMatches: $totalMatches)';
}

// Initialize the class mapping and circular reference
/// Initializes the DIDL class mappings.
///
/// This is called automatically when the library is imported, but can be
/// called manually if needed for testing.
void initializeDidlClasses() {
  // Register all classes
  _didlClassToClass['object'] = DidlObject;
  _didlClassToClass['object.item'] = DidlItem;
  _didlClassToClass['object.item.audioItem'] = DidlAudioItem;
  _didlClassToClass['object.item.audioItem.musicTrack'] = DidlMusicTrack;
  _didlClassToClass['object.item.audioItem.audioBook'] = DidlAudioBook;
  _didlClassToClass['object.item.audioItem.audioBroadcast'] =
      DidlAudioBroadcast;
  _didlClassToClass['object.item.audioItem.linein'] = DidlAudioLineIn;
  _didlClassToClass['object.container'] = DidlContainer;
  _didlClassToClass['object.container.album'] = DidlAlbum;
  _didlClassToClass['object.container.musicAlbum'] = DidlMusicAlbum;
  _didlClassToClass['object.container.person'] = DidlPerson;
  _didlClassToClass['object.container.person.composer'] = DidlComposer;
  _didlClassToClass['object.container.person.musicArtist'] = DidlMusicArtist;
  _didlClassToClass['object.container.playlistContainer'] =
      DidlPlaylistContainer;
  _didlClassToClass['object.container.genre'] = DidlGenre;
  _didlClassToClass['object.container.genre.musicGenre'] = DidlMusicGenre;

  // Set the circular reference for data_structures_entry
  entry.didlClassToSoCoClass = didlClassToSoCoClass;
}

// Auto-initialize when module loads
// ignore: unused_element
final _autoInit = (() {
  initializeDidlClasses();
})();
