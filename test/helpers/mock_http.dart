/// Mock HTTP client infrastructure for testing.
///
/// This module provides utilities for mocking HTTP responses in tests.
library;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Create a mock HTTP client that returns predefined responses.
///
/// Parameters:
///   - [responses]: A map of URL patterns to response data.
///     Each entry maps a URL substring to a (statusCode, body) tuple.
///
/// Returns:
///   A [MockClient] that can be used in tests.
MockClient createMockClient(
  Map<String, (int, String)> responses, {
  (int, String)? defaultResponse,
}) {
  return MockClient((request) async {
    // Find a matching response
    for (final entry in responses.entries) {
      if (request.url.toString().contains(entry.key)) {
        return http.Response(
          entry.value.$2,
          entry.value.$1,
          headers: {'content-type': 'text/xml; charset=utf-8'},
        );
      }
    }

    // Return default or 404
    if (defaultResponse != null) {
      return http.Response(
        defaultResponse.$2,
        defaultResponse.$1,
        headers: {'content-type': 'text/xml; charset=utf-8'},
      );
    }

    return http.Response('Not Found', 404);
  });
}

/// Create a SOAP response envelope.
///
/// Parameters:
///   - [body]: The XML content to wrap in a SOAP envelope body.
///
/// Returns:
///   A complete SOAP envelope XML string.
String soapEnvelope(String body) {
  return '''<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
            s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>$body</s:Body>
</s:Envelope>''';
}

/// Create a SOAP fault response.
///
/// Parameters:
///   - [faultcode]: The fault code (e.g., 's:Client')
///   - [faultstring]: Human-readable fault description
///   - [errorCode]: Optional UPnP error code
///   - [errorDescription]: Optional UPnP error description
///
/// Returns:
///   A complete SOAP fault envelope XML string.
String soapFault({
  required String faultcode,
  required String faultstring,
  String? errorCode,
  String? errorDescription,
}) {
  final detail = errorCode != null
      ? '''
    <detail>
      <UPnPError xmlns="urn:schemas-upnp-org:control-1-0">
        <errorCode>$errorCode</errorCode>
        <errorDescription>${errorDescription ?? ''}</errorDescription>
      </UPnPError>
    </detail>'''
      : '';

  return '''<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
            s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <s:Fault>
      <faultcode>$faultcode</faultcode>
      <faultstring>$faultstring</faultstring>
      $detail
    </s:Fault>
  </s:Body>
</s:Envelope>''';
}

/// Common SOAP response templates for Sonos services.
class SonosResponses {
  /// GetVolume response
  static String getVolume(int volume) {
    return soapEnvelope('''
    <u:GetVolumeResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
      <CurrentVolume>$volume</CurrentVolume>
    </u:GetVolumeResponse>''');
  }

  /// SetVolume response (empty success)
  static String setVolume() {
    return soapEnvelope('''
    <u:SetVolumeResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
    </u:SetVolumeResponse>''');
  }

  /// GetMute response
  static String getMute(bool muted) {
    return soapEnvelope('''
    <u:GetMuteResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
      <CurrentMute>${muted ? 1 : 0}</CurrentMute>
    </u:GetMuteResponse>''');
  }

  /// GetTransportInfo response
  static String getTransportInfo(String state) {
    return soapEnvelope('''
    <u:GetTransportInfoResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <CurrentTransportState>$state</CurrentTransportState>
      <CurrentTransportStatus>OK</CurrentTransportStatus>
      <CurrentSpeed>1</CurrentSpeed>
    </u:GetTransportInfoResponse>''');
  }

  /// Play response (empty success)
  static String play() {
    return soapEnvelope('''
    <u:PlayResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
    </u:PlayResponse>''');
  }

  /// Pause response (empty success)
  static String pause() {
    return soapEnvelope('''
    <u:PauseResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
    </u:PauseResponse>''');
  }

  /// Stop response (empty success)
  static String stop() {
    return soapEnvelope('''
    <u:StopResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
    </u:StopResponse>''');
  }

  /// GetPositionInfo response
  static String getPositionInfo({
    int track = 1,
    String trackDuration = '0:03:45',
    String trackMetaData = '',
    String trackUri = '',
    String relTime = '0:01:30',
    String absTime = '0:01:30',
    int relCount = 90,
    int absCount = 90,
  }) {
    return soapEnvelope('''
    <u:GetPositionInfoResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <Track>$track</Track>
      <TrackDuration>$trackDuration</TrackDuration>
      <TrackMetaData>$trackMetaData</TrackMetaData>
      <TrackURI>$trackUri</TrackURI>
      <RelTime>$relTime</RelTime>
      <AbsTime>$absTime</AbsTime>
      <RelCount>$relCount</RelCount>
      <AbsCount>$absCount</AbsCount>
    </u:GetPositionInfoResponse>''');
  }

  /// GetZoneGroupState response
  static String getZoneGroupState(String zoneGroupStateXml) {
    final escaped = _escapeXml(zoneGroupStateXml);
    return soapEnvelope('''
    <u:GetZoneGroupStateResponse xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1">
      <ZoneGroupState>$escaped</ZoneGroupState>
    </u:GetZoneGroupStateResponse>''');
  }

  /// Browse response (ContentDirectory)
  static String browse({
    required String result,
    int numberReturned = 1,
    int totalMatches = 1,
    int updateId = 1,
  }) {
    final escaped = _escapeXml(result);
    return soapEnvelope('''
    <u:BrowseResponse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1">
      <Result>$escaped</Result>
      <NumberReturned>$numberReturned</NumberReturned>
      <TotalMatches>$totalMatches</TotalMatches>
      <UpdateID>$updateId</UpdateID>
    </u:BrowseResponse>''');
  }

  /// GetMediaInfo response
  static String getMediaInfo({
    int nrTracks = 10,
    String mediaDuration = '0:35:00',
    String currentUri = 'x-rincon-queue:RINCON_XXX#0',
    String currentUriMetaData = '',
    String nextUri = '',
    String nextUriMetaData = '',
    String playMedium = 'NETWORK',
    String recordMedium = 'NOT_IMPLEMENTED',
    String writeStatus = 'NOT_IMPLEMENTED',
  }) {
    return soapEnvelope('''
    <u:GetMediaInfoResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <NrTracks>$nrTracks</NrTracks>
      <MediaDuration>$mediaDuration</MediaDuration>
      <CurrentURI>$currentUri</CurrentURI>
      <CurrentURIMetaData>$currentUriMetaData</CurrentURIMetaData>
      <NextURI>$nextUri</NextURI>
      <NextURIMetaData>$nextUriMetaData</NextURIMetaData>
      <PlayMedium>$playMedium</PlayMedium>
      <RecordMedium>$recordMedium</RecordMedium>
      <WriteStatus>$writeStatus</WriteStatus>
    </u:GetMediaInfoResponse>''');
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

/// Sample zone group state XML for testing.
const sampleZoneGroupState = '''
<ZoneGroupState>
  <ZoneGroups>
    <ZoneGroup Coordinator="RINCON_TEST001" ID="RINCON_TEST001:0">
      <ZoneGroupMember UUID="RINCON_TEST001"
        Location="http://192.168.1.100:1400/xml/device_description.xml"
        ZoneName="Living Room"
        BootSeq="123"
        Configuration="1"/>
    </ZoneGroup>
  </ZoneGroups>
</ZoneGroupState>
''';

/// Wimp/Tidal music service SOAP response templates.
class WimpResponses {
  static const _msNs = 'http://www.sonos.com/Services/1.1';

  /// Search response with tracks
  static String searchTracks({
    required List<Map<String, String>> tracks,
    int index = 0,
    int? total,
  }) {
    final count = tracks.length;
    total ??= count;

    final trackXml = tracks
        .map(
          (t) =>
              '''
      <mediaMetadata xmlns="$_msNs">
        <id>${t['id'] ?? 'trackid_123'}</id>
        <itemType>track</itemType>
        <title>${t['title'] ?? 'Unknown Track'}</title>
        <mimeType>${t['mimeType'] ?? 'audio/aac'}</mimeType>
        <trackMetadata>
          <artistId>${t['artistId'] ?? 'artistid_1'}</artistId>
          <artist>${t['artist'] ?? 'Unknown Artist'}</artist>
          <albumId>${t['albumId'] ?? 'albumid_1'}</albumId>
          <album>${t['album'] ?? 'Unknown Album'}</album>
          <duration>${t['duration'] ?? '180'}</duration>
          <canPlay>${t['canPlay'] ?? 'true'}</canPlay>
        </trackMetadata>
      </mediaMetadata>
    ''',
        )
        .join('\n');

    return '''<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
  <s:Body>
    <searchResponse xmlns="$_msNs">
      <searchResult>
        <index>$index</index>
        <count>$count</count>
        <total>$total</total>
        $trackXml
      </searchResult>
    </searchResponse>
  </s:Body>
</s:Envelope>''';
  }

  /// Search response with albums
  static String searchAlbums({
    required List<Map<String, String>> albums,
    int index = 0,
    int? total,
  }) {
    final count = albums.length;
    total ??= count;

    final albumXml = albums
        .map(
          (a) =>
              '''
      <mediaCollection xmlns="$_msNs">
        <id>${a['id'] ?? 'albumid_123'}</id>
        <itemType>album</itemType>
        <title>${a['title'] ?? 'Unknown Album'}</title>
        <artistId>${a['artistId'] ?? 'artistid_1'}</artistId>
        <artist>${a['artist'] ?? 'Unknown Artist'}</artist>
        <canPlay>${a['canPlay'] ?? 'true'}</canPlay>
      </mediaCollection>
    ''',
        )
        .join('\n');

    return '''<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
  <s:Body>
    <searchResponse xmlns="$_msNs">
      <searchResult>
        <index>$index</index>
        <count>$count</count>
        <total>$total</total>
        $albumXml
      </searchResult>
    </searchResponse>
  </s:Body>
</s:Envelope>''';
  }

  /// Search response with artists
  static String searchArtists({
    required List<Map<String, String>> artists,
    int index = 0,
    int? total,
  }) {
    final count = artists.length;
    total ??= count;

    final artistXml = artists
        .map(
          (a) =>
              '''
      <mediaCollection xmlns="$_msNs">
        <id>${a['id'] ?? 'artistid_123'}</id>
        <itemType>artist</itemType>
        <title>${a['title'] ?? 'Unknown Artist'}</title>
        <canPlay>${a['canPlay'] ?? 'false'}</canPlay>
      </mediaCollection>
    ''',
        )
        .join('\n');

    return '''<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
  <s:Body>
    <searchResponse xmlns="$_msNs">
      <searchResult>
        <index>$index</index>
        <count>$count</count>
        <total>$total</total>
        $artistXml
      </searchResult>
    </searchResponse>
  </s:Body>
</s:Envelope>''';
  }

  /// Browse root response
  static String browseRoot({
    required List<Map<String, String>> collections,
    int index = 0,
    int? total,
  }) {
    final count = collections.length;
    total ??= count;

    final collectionXml = collections
        .map(
          (c) =>
              '''
      <mediaCollection xmlns="$_msNs">
        <id>${c['id'] ?? 'collection_123'}</id>
        <itemType>${c['itemType'] ?? 'collection'}</itemType>
        <title>${c['title'] ?? 'Unknown Collection'}</title>
        <canPlay>${c['canPlay'] ?? 'false'}</canPlay>
      </mediaCollection>
    ''',
        )
        .join('\n');

    return '''<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
  <s:Body>
    <getMetadataResponse xmlns="$_msNs">
      <getMetadataResult>
        <index>$index</index>
        <count>$count</count>
        <total>$total</total>
        $collectionXml
      </getMetadataResult>
    </getMetadataResponse>
  </s:Body>
</s:Envelope>''';
  }

  /// Error response (SOAP Fault)
  static String error({
    String faultstring = 'ItemNotFound',
    String faultcode = 's:Client',
  }) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
  <s:Body>
    <Fault>
      <faultcode>$faultcode</faultcode>
      <faultstring>$faultstring</faultstring>
    </Fault>
  </s:Body>
</s:Envelope>''';
  }

  /// GetSessionId response
  static String getSessionId(String sessionId) {
    return soapEnvelope('''
    <u:GetSessionIdResponse xmlns:u="urn:schemas-upnp-org:service:MusicServices:1">
      <SessionId>$sessionId</SessionId>
    </u:GetSessionIdResponse>''');
  }

  /// GetSpeakerInfo response
  static String getSpeakerInfo({
    String serialNumber = 'XX-XX-XX-XX-XX-XX',
    String softwareVersion = '12.0',
    String displaySoftwareVersion = 'S2 12.0',
    String hardwareVersion = '1.0',
    String modelName = 'Sonos One',
    String modelNumber = 'S13',
    String macAddress = 'XX:XX:XX:XX:XX:XX',
  }) {
    return soapEnvelope('''
    <u:GetZoneInfoResponse xmlns:u="urn:schemas-upnp-org:service:DeviceProperties:1">
      <SerialNumber>$serialNumber</SerialNumber>
      <SoftwareVersion>$softwareVersion</SoftwareVersion>
      <DisplaySoftwareVersion>$displaySoftwareVersion</DisplaySoftwareVersion>
      <HardwareVersion>$hardwareVersion</HardwareVersion>
      <IPAddress>192.168.1.100</IPAddress>
      <MACAddress>$macAddress</MACAddress>
      <CopyrightInfo>© 2004-2022 Sonos, Inc. All Rights Reserved.</CopyrightInfo>
      <ExtraInfo></ExtraInfo>
      <HTAudioIn>0</HTAudioIn>
      <Flags>0</Flags>
    </u:GetZoneInfoResponse>''');
  }
}

/// Sample device description XML for testing.
const sampleDeviceDescription = '''<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <specVersion>
    <major>1</major>
    <minor>0</minor>
  </specVersion>
  <device>
    <deviceType>urn:schemas-upnp-org:device:ZonePlayer:1</deviceType>
    <friendlyName>Living Room</friendlyName>
    <manufacturer>Sonos, Inc.</manufacturer>
    <modelNumber>S1</modelNumber>
    <modelName>Sonos One</modelName>
    <serialNum>XX-XX-XX-XX-XX-XX:X</serialNum>
    <UDN>uuid:RINCON_TEST001</UDN>
    <roomName>Living Room</roomName>
    <displayName>Living Room</displayName>
  </device>
</root>
''';
