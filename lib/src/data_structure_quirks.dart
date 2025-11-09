/// This module implements 'quirks' for the DIDL-Lite data structures.
///
/// A quirk, in this context, means that a specific music service does not follow
/// a specific part of the DIDL-Lite specification. In order not to clutter the
/// primary implementation of DIDL-Lite for SoCo (in data_structures.dart)
/// up with all these service specific exceptions, they are implemented separately
/// in this module. Besides from keeping the main implementation clean and
/// following the specification, this has the added advantage of making it easier
/// to track how many quirks are out there.
///
/// The implementation of the quirks at this point is just a single function which
/// applies quirks to the DIDL-Lite resources, with the option of adding one that
/// applies them to DIDL-Lite objects.
library;

import 'package:logging/logging.dart';
import 'package:xml/xml.dart';

final _log = Logger('soco.data_structure_quirks');

/// Apply DIDL-Lite resource quirks.
///
/// At least two music services (Spotify Direct and Amazon in conjunction
/// with Alexa) have been known not to supply the mandatory protocolInfo, so
/// if it is missing, supply a dummy one.
///
/// Parameters:
///   - [resource]: The XML resource element to apply quirks to
///
/// Returns:
///   The resource element with quirks applied
XmlElement applyResourceQuirks(XmlElement resource) {
  // Check if protocolInfo attribute is missing
  final protocolInfoAttr = resource.getAttribute('protocolInfo');

  if (protocolInfoAttr == null) {
    var protocolInfo = 'DUMMY_ADDED_BY_QUIRK';

    // For Spotify direct we have a better idea what it should be, since it
    // is included in the main element text
    final text = resource.innerText;
    if (text.isNotEmpty && text.startsWith('x-sonos-spotify')) {
      protocolInfo = 'sonos.com-spotify:*:audio/x-spotify.*';
    }

    _log.fine(
      "Resource quirk applied for missing protocolInfo, setting to '$protocolInfo'",
    );

    resource.setAttribute('protocolInfo', protocolInfo);

    // Ensure the resource has text content
    if (resource.innerText.isEmpty) {
      // Add empty text if needed (in Dart, innerText will be empty string by default)
    }
  }

  return resource;
}
