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

  // Unknown class - would create subclass dynamically in Python
  // In Dart, we'll return the base class type
  // TODO: Implement dynamic class creation if needed
  _log.warning('Unknown DIDL class: $didlClass, returning DidlObject');
  return DidlObject;
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

  /// Return an XML Element based on this resource.
  XmlElement toElement() {
    final builder = XmlBuilder();
    builder.element(
      'res',
      nest: () {
        // Required
        builder.attribute('protocolInfo', protocolInfo);

        // Optional
        if (importUri != null) builder.attribute('importUri', importUri!);
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

  /// Creates a DIDL object.
  DidlObject({
    required this.title,
    required this.parentId,
    required this.itemId,
    this.restricted = true,
    List<DidlResource>? resources,
    this.desc = 'RINCON_AssociatedZPUDN',
    Map<String, dynamic>? metadata,
  }) : resources = resources ?? [],
       _metadata = metadata ?? {};

  /// Get metadata value.
  dynamic operator [](String key) => _metadata[key];

  /// Set metadata value.
  void operator []=(String key, dynamic value) => _metadata[key] = value;

  /// Build XML element content.
  void toElement(XmlBuilder builder) {
    // Add attributes
    builder.attribute('id', itemId);
    builder.attribute('parentID', parentId);
    builder.attribute('restricted', restricted.toString());

    // Title
    builder.element(
      soco_xml.nsTag('dc', 'title'),
      nest: () {
        builder.text(title);
      },
    );

    // Class
    builder.element(
      soco_xml.nsTag('upnp', 'class'),
      nest: () {
        builder.text(itemClass);
      },
    );

    // Resources
    for (final resource in resources) {
      builder.xml(resource.toElement().toXmlString());
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
  });
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
  });
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
  });
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
  });
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
  });
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
  });
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
  }) {
    tag = 'container';
  }
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
  });
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
  });
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
  });
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
  });
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
  });
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
  });
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
  });
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
  });
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
