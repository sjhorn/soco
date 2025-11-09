/// Provides handling for ZoneGroupState information.
///
/// ZoneGroupState XML payloads are received from both:
/// * zoneGroupTopology.GetZoneGroupState()['ZoneGroupState']
/// * zoneGroupTopology subscription event callbacks
///
/// The ZoneGroupState payloads are identical between all speakers in a
/// household, but may be generated with differing orders for contained
/// ZoneGroup or ZoneGroupMember elements and children. To benefit from
/// similar contents, payloads are passed through normalization to allow
/// simple equality comparisons, and to avoid unnecessary reprocessing of
/// identical data.
///
/// Since the payloads are identical between all speakers, we can use a
/// common cache per household.
///
/// As satellites can sometimes deliver outdated payloads when they are
/// directly polled, these requests are instead forwarded to the parent
/// device.
library;

import 'package:logging/logging.dart';
import 'package:xml/xml.dart';

import 'config.dart' as config;
import 'core.dart';
import 'exceptions.dart';
import 'groups.dart';

final _log = Logger('soco.zonegroupstate');

/// Cache timeout for polling in seconds
const pollingCacheTimeout = 5;

/// Never time constant (very old time to indicate no cache)
const neverTime = -1200.0;

/// Mapping from ZGS XML attributes to SoCo private attributes
const Map<String, String> zgsAttribMapping = {
  'BootSeq': '_bootSeqnum',
  'ChannelMapSet': '_channelMap',
  'HTSatChanMapSet': '_htSatChanMap',
  'MicEnabled': '_micEnabled',
  'UUID': '_uid',
  'VoiceConfigState': '_voiceConfigState',
  'ZoneName': '_playerName',
};

/// Handles processing and caching of ZoneGroupState payloads.
///
/// Only one ZoneGroupState instance is created per Sonos household.
class ZoneGroupState {
  /// All zones in this household
  final Set<SoCo> allZones = {};

  /// All groups in this household
  final Set<ZoneGroup> groups = {};

  /// Visible zones only (excludes bridges and satellites)
  final Set<SoCo> visibleZones = {};

  /// Cache expiration timestamp
  double _cacheUntil = neverTime;

  /// Last processed ZGS XML (normalized)
  String? _lastZgs;

  /// Statistics
  int totalRequests = 0;
  int processedCount = 0;

  /// Clear the cache timestamp.
  void clearCache() {
    _cacheUntil = neverTime;
  }

  /// Clear all known group sets.
  void clearZoneGroups() {
    groups.clear();
    allZones.clear();
    visibleZones.clear();
  }

  /// Poll using the provided SoCo instance and process the payload.
  ///
  /// This method will:
  /// 1. Check if cache is still valid and return early if so
  /// 2. Forward to parent if polling a satellite
  /// 3. Call GetZoneGroupState() and process the result
  /// 4. Handle fallback for large systems (if configured)
  Future<void> poll(SoCo soco) async {
    // Check cache validity
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    if (now < _cacheUntil) {
      totalRequests++;
      _log.fine('Cache still active (GetZoneGroupState) during poll for ${soco.ipAddress}');
      return;
    }

    // Forward satellite requests to parent
    var targetSoco = soco;
    if (await soco.isSatellite) {
      final parent = soco.satelliteParent;
      if (parent != null) {
        _log.fine('Poll request on satellite (${soco.ipAddress}), using parent (${parent.ipAddress})');
        targetSoco = parent;
      }
    }

    // On large (about 20+ players) systems, GetZoneGroupState() can cause
    // the target Sonos player to return an HTTP 501 error, raising a
    // SoCoUPnPException.
    try {
      final response = await targetSoco.zoneGroupTopology.sendCommand('GetZoneGroupState');
      final zgs = response['ZoneGroupState'];

      if (zgs != null) {
        await processPayload(
          payload: zgs,
          source: 'poll',
          sourceIp: targetSoco.ipAddress,
        );

        // Extend cache
        final newExpiry = DateTime.now().millisecondsSinceEpoch / 1000.0 + pollingCacheTimeout;
        _cacheUntil = newExpiry;
        _log.fine('Extending ZGS cache by ${pollingCacheTimeout}s');
      }
    } on SoCoUPnPException catch (e) {
      _log.fine('Exception ($e) raised on \'GetZoneGroupState()\'');

      if (!config.zgtEventFallback) {
        _log.fine('ZGT event fallback disabled (config.zgtEventFallback)');
        throw NotSupportedException(
          '\'GetZoneGroupState()\' call fails on large Sonos systems '
          'and event fallback is disabled',
        );
      }

      // Note: Event-based fallback would go here
      // For now, we'll just rethrow since events module isn't ported yet
      _log.warning('ZGT event fallback not yet implemented in Dart port');
      rethrow;
    }
  }

  /// Update using the provided XML payload.
  ///
  /// Parameters:
  ///   - [payload]: The XML payload string
  ///   - [source]: The source of the payload ('poll' or 'event')
  ///   - [sourceIp]: The IP address of the source device
  Future<void> processPayload({
    required String payload,
    required String source,
    required String sourceIp,
  }) async {
    totalRequests++;

    final normalizedZgs = _normalizeZgsXml(payload);

    if (normalizedZgs == _lastZgs) {
      _log.fine('Duplicate ZGS received from $sourceIp ($source), ignoring');
      return;
    }

    processedCount++;
    _log.fine(
      'Updating ZGS with $source payload from $sourceIp ($processedCount/$totalRequests processed)',
    );

    await _updateSocoInstances(normalizedZgs);
    _lastZgs = normalizedZgs;
  }

  /// Parse a ZoneGroupMember or Satellite element from Zone Group State.
  ///
  /// Creates a SoCo instance for the member, sets basic attributes and returns it.
  SoCo _parseZoneGroupMember(XmlElement memberElement) {
    // Create a SoCo instance for each member. Because SoCo instances are
    // singletons, this is cheap if they have already been created
    final memberAttribs = memberElement.attributes;

    // Example Location contents:
    //   http://192.168.1.100:1400/xml/device_description.xml
    final location = memberAttribs.firstWhere((a) => a.name.local == 'Location').value;
    final ipAddr = location.split('//')[1].split(':')[0];

    final zone = SoCo(ipAddr);

    // Set attributes from the mapping
    for (final entry in zgsAttribMapping.entries) {
      final key = entry.key;
      final attrib = entry.value;

      final attribute = memberAttribs.where((a) => a.name.local == key).firstOrNull;
      if (attribute != null) {
        // Use reflection-like approach to set private fields
        // Since we can't directly set private fields in Dart, we'll need
        // to access them through the internal setters in SoCo class
        _setSoCoAttribute(zone, attrib, attribute.value);
      }
    }

    // Handle channel mapping for stereo pairs and home theater
    final channelMap = _getSoCoAttribute(zone, '_channelMap');
    final htSatChanMap = _getSoCoAttribute(zone, '_htSatChanMap');
    final uid = _getSoCoAttribute(zone, '_uid');

    for (final channelMapStr in [channelMap, htSatChanMap]) {
      if (channelMapStr != null && channelMapStr is String && channelMapStr.isNotEmpty) {
        // Example ChannelMapSet (stereo pair):
        //   RINCON_001XXX1400:LF,LF;RINCON_002XXX1400:RF,RF
        // Example HTSatChanMapSet (home theater):
        //   RINCON_001XXX1400:LF,RF;RINCON_002XXX1400:LR;RINCON_003XXX1400:RR
        for (final channel in channelMapStr.split(';')) {
          if (uid != null && channel.startsWith(uid as String)) {
            final channelName = channel.split(':').last;
            _setSoCoAttribute(zone, '_channel', channelName);
          }
        }
      }
    }

    // Add the zone to the set of all members, and to the set of visible
    // members if appropriate
    final invisibleAttr = memberAttribs.where((a) => a.name.local == 'Invisible').firstOrNull;
    if (invisibleAttr == null || invisibleAttr.value != '1') {
      visibleZones.add(zone);
    }
    allZones.add(zone);

    return zone;
  }

  /// Update all SoCo instances with the provided payload.
  Future<void> _updateSocoInstances(String normalizedXml) async {
    clearZoneGroups();

    final document = XmlDocument.parse(normalizedXml);
    final root = document.rootElement;

    // Compatibility fallback for pre-10.1 firmwares
    // where a "ZoneGroups" element is not used
    var zoneGroupsElement = root.findElements('ZoneGroups').firstOrNull;
    zoneGroupsElement ??= root;

    for (final groupElement in zoneGroupsElement.findElements('ZoneGroup')) {
      final coordinatorUid = groupElement.getAttribute('Coordinator')!;
      final groupUid = groupElement.getAttribute('ID')!;
      SoCo? groupCoordinator;
      final members = <SoCo>{};

      for (final memberElement in groupElement.findElements('ZoneGroupMember')) {
        final zone = _parseZoneGroupMember(memberElement);

        // Reset satellite status
        _setSoCoAttribute(zone, '_isSatellite', false);
        _setSoCoAttribute(zone, '_satelliteParent', null);

        final zoneUid = _getSoCoAttribute(zone, '_uid');
        if (zoneUid == coordinatorUid) {
          groupCoordinator = zone;
          _setSoCoAttribute(zone, '_isCoordinator', true);
        } else {
          _setSoCoAttribute(zone, '_isCoordinator', false);
        }

        // is_bridge doesn't change, but set it here just in case
        final isBridgeAttr = memberElement.attributes
            .where((a) => a.name.local == 'IsZoneBridge')
            .firstOrNull;
        _setSoCoAttribute(zone, '_isBridge', isBridgeAttr?.value == '1');

        // Add the zone to the members for this group
        members.add(zone);

        // Loop over Satellite elements if present
        final satelliteElements = memberElement.findElements('Satellite');
        _setSoCoAttribute(zone, '_hasSatellites', satelliteElements.isNotEmpty);

        for (final satelliteElement in satelliteElements) {
          final satellite = _parseZoneGroupMember(satelliteElement);
          _setSoCoAttribute(satellite, '_isSatellite', true);
          _setSoCoAttribute(satellite, '_satelliteParent', zone);
          // Assume a satellite can't be a bridge or coordinator
          members.add(satellite);
        }
      }

      if (groupCoordinator != null) {
        groups.add(ZoneGroup(
          uid: groupUid,
          coordinator: groupCoordinator,
          members: members,
        ));
      }
    }
  }

  /// Normalize the ZoneGroupState XML payload.
  ///
  /// This sorts the XML elements to ensure consistent ordering for
  /// comparison purposes.
  String _normalizeZgsXml(String xml) {
    try {
      final document = XmlDocument.parse(xml);
      final root = document.rootElement;

      // Sort ZoneGroup elements by Coordinator or UUID
      _sortXmlChildren(root);

      return document.toXmlString(pretty: false);
    } catch (e) {
      _log.warning('Failed to normalize ZGS XML: $e');
      return xml; // Return original if normalization fails
    }
  }

  /// Recursively sort XML children by @Coordinator or @UUID attributes.
  void _sortXmlChildren(XmlElement element) {
    final children = element.children.whereType<XmlElement>().toList();

    if (children.isEmpty) return;

    // Sort children
    children.sort((a, b) {
      final aKey = a.getAttribute('Coordinator') ?? a.getAttribute('UUID') ?? '';
      final bKey = b.getAttribute('Coordinator') ?? b.getAttribute('UUID') ?? '';
      return aKey.compareTo(bKey);
    });

    // Remove and re-add children in sorted order
    element.children.removeWhere((node) => node is XmlElement);
    for (final child in children) {
      element.children.add(child);
      _sortXmlChildren(child); // Recursively sort
    }
  }

  /// Helper to set SoCo attributes (works around private field limitations).
  void _setSoCoAttribute(SoCo zone, String attributeName, dynamic value) {
    // In Dart, we can't directly access private fields from another library.
    // The SoCo class would need to provide setters for these fields.
    // For now, we'll store them in the speakerInfo map as a workaround.
    zone.speakerInfo[attributeName] = value;
  }

  /// Helper to get SoCo attributes.
  dynamic _getSoCoAttribute(SoCo zone, String attributeName) {
    return zone.speakerInfo[attributeName];
  }
}
