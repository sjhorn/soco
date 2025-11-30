/// This module contains all the data structures for music service plugins.
library;

import 'package:xml/xml.dart';

import 'exceptions.dart';
import 'utils.dart';
import 'xml.dart' as soco_xml;

// Global mapping of MS item types to classes
final Map<String, Type> _msTypeToClass = {};

/// Find elements matching a local name within a specific namespace.
///
/// The Dart xml package's findElements uses local names only.
/// This helper finds elements that match both local name and namespace.
Iterable<XmlElement> _findElementsNs(
    XmlElement xml, String nsUri, String localName) {
  return xml.findElements(localName).where(
        (e) => e.name.namespaceUri == nsUri || e.name.namespaceUri == null,
      );
}

/// Return the music service item that corresponds to xml.
///
/// The class is identified by getting the type from the 'itemType' tag.
MusicServiceItem getMsItem(XmlElement xml, dynamic service, String parentId) {
  // Find itemType element - try both namespaced and non-namespaced
  final itemTypeElements = _findElementsNs(
    xml,
    soco_xml.namespaces['ms']!,
    'itemType',
  );

  if (itemTypeElements.isEmpty) {
    throw StateError(
        'No itemType element found in XML. '
        'XML contains: ${xml.childElements.map((e) => e.name.local).toList()}');
  }

  final itemType = itemTypeElements.first.innerText;

  // Create the appropriate music service item based on type
  switch (itemType) {
    case 'track':
      return MSTrack.fromXml(xml, service, parentId);
    case 'album':
      return MSAlbum.fromXml(xml, service, parentId);
    case 'albumList':
      return MSAlbumList.fromXml(xml, service, parentId);
    case 'playlist':
      return MSPlaylist.fromXml(xml, service, parentId);
    case 'artistTrackList':
      return MSArtistTracklist.fromXml(xml, service, parentId);
    case 'artist':
      return MSArtist.fromXml(xml, service, parentId);
    case 'favorites':
      return MSFavorites.fromXml(xml, service, parentId);
    case 'collection':
      return MSCollection.fromXml(xml, service, parentId);
    default:
      throw ArgumentError('Unknown music service item type: $itemType');
  }
}

/// Return a list of tags that contain text retrieved recursively from an XML tree.
List<XmlElement> tagsWithText(XmlElement xml, [List<XmlElement>? tags]) {
  tags ??= [];

  for (final element in xml.childElements) {
    if (element.innerText.isNotEmpty && element.childElements.isEmpty) {
      tags.add(element);
    } else if (element.childElements.isNotEmpty) {
      tagsWithText(element, tags);
    } else {
      throw ArgumentError('Unknown XML structure: $element');
    }
  }

  return tags;
}

/// Base class that represents a music service item.
abstract class MusicServiceItem {
  /// The item class (e.g., 'object.item.audioItem.musicTrack')
  String get itemClass;

  /// Valid fields for this item type
  Set<String> get validFields;

  /// Required fields for this item type
  List<String> get requiredFields;

  /// The content of the item
  final Map<String, dynamic> content;

  /// Creates a music service item.
  MusicServiceItem(this.content);

  /// Create a music service item from XML.
  static T fromXml<T extends MusicServiceItem>(
    XmlElement xml,
    dynamic service,
    String parentId,
    T Function(Map<String, dynamic>) constructor,
    Set<String> validFields,
    List<String> requiredFields,
  ) {
    // Add a few extra pieces of information
    final content = <String, dynamic>{
      'description': service.description,
      'service_id': service.serviceId,
      'parent_id': parentId,
    };

    // Extract values from the XML
    final allTextElements = tagsWithText(xml);
    for (final item in allTextElements) {
      // Strip namespace
      var tag = item.name.local;
      if (item.name.namespaceUri == soco_xml.namespaces['ms']) {
        tag = item.name.local;
      }

      // Convert to underscore notation
      tag = camelToUnderscore(tag);

      if (!validFields.contains(tag)) {
        throw ArgumentError("The info tag '$tag' is not allowed for this item");
      }

      content[tag] = item.innerText;
    }

    // Convert values for known types
    content.forEach((key, value) {
      if (key == 'duration' && value is String) {
        content[key] = int.parse(value);
      }
      if ([
        'can_play',
        'can_skip',
        'can_add_to_favorites',
        'can_enumerate',
      ].contains(key)) {
        content[key] = value == 'true';
      }
    });

    // Rename id to item_id
    if (content.containsKey('id')) {
      content['item_id'] = content.remove('id');
    }

    // Get the extended id (would need service method)
    // content['extended_id'] = service.idToExtendedId(content['item_id'], T);

    // Add URI if there is one for the relevant class (would need service method)
    // final uri = service.formUri(content, T);
    // if (uri != null) {
    //   content['uri'] = uri;
    // }

    // Check for all required values
    for (final key in requiredFields) {
      if (!content.containsKey(key)) {
        throw ArgumentError(
          "An XML field that corresponds to the key '$key' is required.",
        );
      }
    }

    return constructor(content);
  }

  /// Get a content value by key.
  dynamic operator [](String key) => content[key];

  /// Convenience getters for common fields
  String? get itemId => content['item_id'] as String?;
  String? get extendedId => content['extended_id'] as String?;
  String? get title => content['title'] as String?;
  String? get parentId => content['parent_id'] as String?;
  bool get canPlay => content['can_play'] as bool? ?? false;
  String? get uri => content['uri'] as String?;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MusicServiceItem) return false;
    return content.toString() == other.content.toString();
  }

  @override
  int get hashCode => content.toString().hashCode;

  @override
  String toString() {
    final middle = title ?? content.toString();
    final truncated = middle.length > 40
        ? '${middle.substring(0, 40)}...'
        : middle;
    return '<${runtimeType.toString()} \'$truncated\' at ${hashCode.toRadixString(16)}>';
  }

  /// Return a copy of the content dict.
  Map<String, dynamic> toDict() => Map.from(content);

  /// Return the DIDL metadata for this music service item.
  String get didlMetadata {
    // Check if this item is meant to be played
    if (!canPlay) {
      throw DIDLMetadataError(
        'This item is not meant to be played and therefore also not to create its own didl_metadata',
      );
    }

    // Check if we have the attributes to create the didl metadata
    for (final key in ['extended_id', 'title']) {
      if (!content.containsKey(key)) {
        throw DIDLMetadataError(
          "The property '$key' is not present on this item. "
          'This indicates that this item was not meant to create didl_metadata',
        );
      }
    }

    if (!content.containsKey('description')) {
      throw DIDLMetadataError(
        "The item for 'description' is not present in content. "
        'This indicates that this item was not meant to create didl_metadata',
      );
    }

    // Build DIDL-Lite XML
    final builder = XmlBuilder();
    builder.element(
      'DIDL-Lite',
      namespaces: {
        'dc': 'http://purl.org/dc/elements/1.1/',
        'upnp': 'urn:schemas-upnp-org:metadata-1-0/upnp/',
        'r': 'urn:schemas-rinconnetworks-com:metadata-1-0/',
        '': 'urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/',
      },
      nest: () {
        builder.element(
          'item',
          attributes: {
            'id': extendedId!,
            'parentID': parentId!,
            'restricted': 'true',
          },
          nest: () {
            builder.element(
              soco_xml.nsTag('dc', 'title'),
              nest: () {
                builder.text(title!);
              },
            );
            builder.element(
              soco_xml.nsTag('upnp', 'class'),
              nest: () {
                builder.text(itemClass);
              },
            );
            builder.element(
              'desc',
              attributes: {
                'id': 'cdudn',
                'nameSpace': 'urn:schemas-rinconnetworks-com:metadata-1-0/',
              },
              nest: () {
                builder.text(content['description'].toString());
              },
            );
          },
        );
      },
    );

    return builder.buildDocument().toXmlString();
  }
}

///////////////////////////////////////////////////////////////////////////////
// MUSIC SERVICE ITEM SUBCLASSES                                             //
///////////////////////////////////////////////////////////////////////////////

/// A music service track.
class MSTrack extends MusicServiceItem {
  @override
  String get itemClass => 'object.item.audioItem.musicTrack';

  @override
  Set<String> get validFields => {
    'id',
    'item_type',
    'mime_type',
    'title',
    'artist_id',
    'artist',
    'composer_id',
    'composer',
    'album_id',
    'album',
    'album_artist_id',
    'album_artist',
    'duration',
    'album_art_uri',
    'can_play',
    'can_skip',
    'can_add_to_favorites',
  };

  @override
  List<String> get requiredFields => ['item_id', 'title'];

  MSTrack(super.content);

  /// Create from XML.
  static MSTrack fromXml(XmlElement xml, dynamic service, String parentId) {
    return MusicServiceItem.fromXml(
      xml,
      service,
      parentId,
      (content) => MSTrack(content),
      MSTrack._dummy.validFields,
      MSTrack._dummy.requiredFields,
    );
  }

  static final _dummy = MSTrack({});
}

/// A music service album.
class MSAlbum extends MusicServiceItem {
  @override
  String get itemClass => 'object.container.album.musicAlbum';

  @override
  Set<String> get validFields => {
    'id',
    'item_type',
    'title',
    'artist_id',
    'artist',
    'album_art_uri',
    'can_play',
    'can_enumerate',
    'can_cache',
    'can_add_to_favorites',
  };

  @override
  List<String> get requiredFields => ['item_id', 'title'];

  MSAlbum(super.content);

  static MSAlbum fromXml(XmlElement xml, dynamic service, String parentId) {
    return MusicServiceItem.fromXml(
      xml,
      service,
      parentId,
      (content) => MSAlbum(content),
      MSAlbum._dummy.validFields,
      MSAlbum._dummy.requiredFields,
    );
  }

  static final _dummy = MSAlbum({});
}

/// A music service album list.
class MSAlbumList extends MusicServiceItem {
  @override
  String get itemClass => 'object.container.albumlist';

  @override
  Set<String> get validFields => {
    'id',
    'item_type',
    'title',
    'artist',
    'artist_id',
    'album_art_uri',
    'can_play',
    'can_enumerate',
    'can_cache',
    'can_add_to_favorites',
  };

  @override
  List<String> get requiredFields => ['item_id', 'title'];

  MSAlbumList(super.content);

  static MSAlbumList fromXml(XmlElement xml, dynamic service, String parentId) {
    return MusicServiceItem.fromXml(
      xml,
      service,
      parentId,
      (content) => MSAlbumList(content),
      MSAlbumList._dummy.validFields,
      MSAlbumList._dummy.requiredFields,
    );
  }

  static final _dummy = MSAlbumList({});
}

/// A music service playlist.
class MSPlaylist extends MusicServiceItem {
  @override
  String get itemClass => 'object.container.playlistContainer';

  @override
  Set<String> get validFields => {
    'id',
    'item_type',
    'title',
    'album_art_uri',
    'can_play',
    'can_enumerate',
    'can_cache',
  };

  @override
  List<String> get requiredFields => ['item_id', 'title'];

  MSPlaylist(super.content);

  static MSPlaylist fromXml(XmlElement xml, dynamic service, String parentId) {
    return MusicServiceItem.fromXml(
      xml,
      service,
      parentId,
      (content) => MSPlaylist(content),
      MSPlaylist._dummy.validFields,
      MSPlaylist._dummy.requiredFields,
    );
  }

  static final _dummy = MSPlaylist({});
}

/// A music service artist track list.
class MSArtistTracklist extends MusicServiceItem {
  @override
  String get itemClass => 'object.container.playlistContainer';

  @override
  Set<String> get validFields => {
    'id',
    'item_type',
    'title',
    'can_play',
    'can_enumerate',
    'can_cache',
  };

  @override
  List<String> get requiredFields => ['item_id', 'title'];

  MSArtistTracklist(super.content);

  static MSArtistTracklist fromXml(
    XmlElement xml,
    dynamic service,
    String parentId,
  ) {
    return MusicServiceItem.fromXml(
      xml,
      service,
      parentId,
      (content) => MSArtistTracklist(content),
      MSArtistTracklist._dummy.validFields,
      MSArtistTracklist._dummy.requiredFields,
    );
  }

  static final _dummy = MSArtistTracklist({});
}

/// A music service artist.
class MSArtist extends MusicServiceItem {
  @override
  String get itemClass => 'object.container.person.musicArtist';

  @override
  Set<String> get validFields => {
    'id',
    'item_type',
    'title',
    'album_art_uri',
    'can_play',
    'can_enumerate',
    'can_cache',
    'can_add_to_favorites',
  };

  @override
  List<String> get requiredFields => ['item_id', 'title'];

  MSArtist(super.content);

  static MSArtist fromXml(XmlElement xml, dynamic service, String parentId) {
    return MusicServiceItem.fromXml(
      xml,
      service,
      parentId,
      (content) => MSArtist(content),
      MSArtist._dummy.validFields,
      MSArtist._dummy.requiredFields,
    );
  }

  static final _dummy = MSArtist({});
}

/// A music service favorites collection.
class MSFavorites extends MusicServiceItem {
  @override
  String get itemClass => 'object.container.playlistContainer';

  @override
  Set<String> get validFields => {
    'id',
    'item_type',
    'title',
    'album_art_uri',
    'can_play',
    'can_enumerate',
    'can_cache',
  };

  @override
  List<String> get requiredFields => ['item_id', 'title'];

  MSFavorites(super.content);

  static MSFavorites fromXml(XmlElement xml, dynamic service, String parentId) {
    return MusicServiceItem.fromXml(
      xml,
      service,
      parentId,
      (content) => MSFavorites(content),
      MSFavorites._dummy.validFields,
      MSFavorites._dummy.requiredFields,
    );
  }

  static final _dummy = MSFavorites({});
}

/// A music service collection.
class MSCollection extends MusicServiceItem {
  @override
  String get itemClass => 'object.container';

  @override
  Set<String> get validFields => {
    'id',
    'item_type',
    'title',
    'album_art_uri',
    'can_play',
    'can_enumerate',
    'can_cache',
  };

  @override
  List<String> get requiredFields => ['item_id', 'title'];

  MSCollection(super.content);

  static MSCollection fromXml(
    XmlElement xml,
    dynamic service,
    String parentId,
  ) {
    return MusicServiceItem.fromXml(
      xml,
      service,
      parentId,
      (content) => MSCollection(content),
      MSCollection._dummy.validFields,
      MSCollection._dummy.requiredFields,
    );
  }

  static final _dummy = MSCollection({});
}

// Initialize the type mapping
void _initializeMsClasses() {
  _msTypeToClass['track'] = MSTrack;
  _msTypeToClass['album'] = MSAlbum;
  _msTypeToClass['albumList'] = MSAlbumList;
  _msTypeToClass['playlist'] = MSPlaylist;
  _msTypeToClass['artistTrackList'] = MSArtistTracklist;
  _msTypeToClass['artist'] = MSArtist;
  _msTypeToClass['favorites'] = MSFavorites;
  _msTypeToClass['collection'] = MSCollection;
}

// Auto-initialize
// ignore: unused_element
final _msAutoInit = (() {
  _initializeMsClasses();
})();
