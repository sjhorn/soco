/// Example implementation of a plugin.
library;

import 'package:logging/logging.dart';
import 'plugins.dart';

final _log = Logger('soco.plugins.example');

/// This file serves as an example of a SoCo plugin.
class ExamplePlugin extends SoCoPlugin {
  /// The username for this plugin instance
  final String username;

  /// Initialize the plugin.
  ///
  /// The plugin can accept any arguments it requires. It should at
  /// least accept a soco instance which it passes on to the base
  /// class when calling super's constructor.
  ///
  /// Parameters:
  ///   - [soco]: The SoCo instance
  ///   - [username]: A username for demonstration
  ExamplePlugin(super.soco, this.username);

  @override
  String get name => 'Example Plugin for $username';

  /// Play some music.
  ///
  /// This is just a reimplementation of the ordinary play function,
  /// to show how we can use the general upnp methods from soco
  Future<void> musicPluginPlay() async {
    _log.info('Hi, $username');
    await soco.avTransport.play([
      MapEntry('InstanceID', 0),
      MapEntry('Speed', 1),
    ]);
  }

  /// Stop the music.
  ///
  /// This methods shows how, if we need it, we can use the soco
  /// functionality from inside the plugins
  Future<void> musicPluginStop() async {
    _log.info('Bye, $username');
    await soco.stop();
  }
}
