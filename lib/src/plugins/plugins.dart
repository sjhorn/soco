/// This module contains the base class for all plugins.
library;

import 'package:logging/logging.dart';

final _log = Logger('soco.plugins');

/// The base class for SoCo plugins.
///
/// Plugins extend the functionality of SoCo by providing integrations
/// with specific music services or features.
abstract class SoCoPlugin {
  /// The SoCo instance this plugin is associated with
  final dynamic soco;

  /// Initialize the plugin
  ///
  /// Parameters:
  ///   - [soco]: The SoCo instance to use
  SoCoPlugin(this.soco) {
    final cls = runtimeType.toString();
    _log.info('Initializing SoCo plugin $cls');
  }

  /// Human-readable name of the plugin
  String get name;
}
