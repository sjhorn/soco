/// This module contains configuration variables.
///
/// They may be modified during runtime to adjust SoCo behavior.
library;

/// The class type to use when `SoCo` instances are created.
///
/// Specify the actual callable class type here. If `null`,
/// the default SoCo class will be used. Must be set before any instances are
/// created, or it will have unpredictable effects.
///
/// Note: In Dart, this is primarily used for dependency injection and testing.
Type? socoClass;

/// Is the cache enabled?
///
/// If `true` (the default), some caching of network requests will take place.
///
/// See also:
///   The cache module.
bool cacheEnabled = true;

/// The IP on which to advertise to Sonos.
///
/// The default of `null` means that the relevant IP address will be detected
/// automatically.
///
/// See also:
///   The events_base module.
String? eventAdvertiseIp;

/// The IP on which the event listener listens.
///
/// The default of `null` means that the relevant IP address will be detected
/// automatically.
///
/// See also:
///   The events_base module.
String? eventListenerIp;

/// The port on which the event listener listens.
///
/// The default is 1400. You must set this before subscribing to any events.
///
/// See also:
///   The events_base module.
int eventListenerPort = 1400;

/// The timeout (in seconds) to be used when sending commands to a Sonos device.
///
/// A value for [requestTimeout] *must* be set. It can be a double, an int, or null.
/// If set to `null`, calls can potentially wait indefinitely. (The default of 20.0s
/// is a long time for network operations, but it's been determined empirically to
/// be a reasonable upper limit for most circumstances.)
///
/// [requestTimeout] can be set dynamically during program execution to adjust the
/// timeout at runtime. It can also be overridden for specific calls by using the
/// 'timeout' parameter in the relevant calling functions.
double? requestTimeout = 20.0;

/// For large Sonos systems (about 20+ players) the standard method of querying a
/// player for the Sonos Zone Group Topology will fail.
///
/// By default, SoCo will then fall back to using a method based on ZGT events. If
/// you wish to disable this behaviour, set [zgtEventFallback] to `false`. Your
/// code should then be prepared to catch [NotSupportedException] errors when
/// using functions that interrogate system state.
bool zgtEventFallback = true;

/// Reset all configuration values to their defaults.
///
/// This is primarily useful for testing.
void resetConfig() {
  socoClass = null;
  cacheEnabled = true;
  eventAdvertiseIp = null;
  eventListenerIp = null;
  eventListenerPort = 1400;
  requestTimeout = 20.0;
  zgtEventFallback = true;
}
