/// This module implements token stores for the music services.
///
/// A user can provide their own token store depending on how that person
/// wishes to save the tokens, or use the builtin token store (the default)
/// which saves the tokens in a config file.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Token store base class
abstract class TokenStoreBase {
  /// The name of the token collection to use.
  ///
  /// This may be used to store different token collections for different
  /// client programs.
  final String tokenCollection;

  /// Instantiate instance variables
  ///
  /// Parameters:
  ///   - [tokenCollection]: The name of the token collection to use.
  TokenStoreBase({this.tokenCollection = 'default'});

  /// Save a token value pair (token, key) which is a 2 item sequence
  Future<void> saveTokenPair(
    String musicServiceId,
    String householdId,
    List<String> tokenPair,
  );

  /// Load a token pair (token, key) which is a 2 item sequence
  Future<List<String>?> loadTokenPair(
    String musicServiceId,
    String householdId,
  );

  /// Return true if a token is stored for the music service and household ID
  Future<bool> hasToken(String musicServiceId, String householdId);
}

/// Implementation of a token store around a JSON file
class JsonFileTokenStore extends TokenStoreBase {
  /// The filepath where tokens are stored
  final String filepath;

  /// Internal token store data
  Map<String, dynamic> _tokenStore = {};

  /// Instantiate instance variables
  ///
  /// Parameters:
  ///   - [filepath]: Path to the JSON file
  ///   - [tokenCollection]: The name of the token collection to use.
  JsonFileTokenStore(this.filepath, {super.tokenCollection}) {
    _loadFromFile();
  }

  /// Load from file in config directory location
  ///
  /// Parameters:
  ///   - [tokenCollection]: The name of the token collection to use.
  static Future<JsonFileTokenStore> fromConfigFile({
    String tokenCollection = 'default',
  }) async {
    final configDir = await getApplicationSupportDirectory();
    final socoDir = p.join(configDir.path, 'SoCo', 'SoCoGroup');
    final configFile = p.join(socoDir, 'token_store.json');
    return JsonFileTokenStore(configFile, tokenCollection: tokenCollection);
  }

  /// Load the token store from the file
  void _loadFromFile() {
    try {
      final file = File(filepath);
      if (file.existsSync()) {
        final contents = file.readAsStringSync();
        _tokenStore = json.decode(contents) as Map<String, dynamic>;
      }
    } catch (e) {
      _tokenStore = {};
    }
  }

  /// Save the collection to a config file
  Future<void> saveCollection() async {
    final file = File(filepath);
    final folder = file.parent;
    if (!folder.existsSync()) {
      await folder.create(recursive: true);
    }
    await file.writeAsString(
      const JsonEncoder.withIndent('    ').convert(_tokenStore),
    );
  }

  @override
  Future<void> saveTokenPair(
    String musicServiceId,
    String householdId,
    List<String> tokenPair,
  ) async {
    if (!_tokenStore.containsKey(tokenCollection)) {
      _tokenStore[tokenCollection] = <String, dynamic>{};
    }
    final collection = _tokenStore[tokenCollection] as Map<String, dynamic>;
    collection[_createJsonableKey(musicServiceId, householdId)] = tokenPair;
    await saveCollection();
  }

  @override
  Future<List<String>?> loadTokenPair(
    String musicServiceId,
    String householdId,
  ) async {
    final collection = _tokenStore[tokenCollection] as Map<String, dynamic>?;
    if (collection == null) return null;
    final key = _createJsonableKey(musicServiceId, householdId);
    final value = collection[key];
    if (value == null) return null;
    return List<String>.from(value as List);
  }

  @override
  Future<bool> hasToken(String musicServiceId, String householdId) async {
    final collection = _tokenStore[tokenCollection] as Map<String, dynamic>?;
    if (collection == null) return false;
    return collection.containsKey(
      _createJsonableKey(musicServiceId, householdId),
    );
  }

  /// Return a JSON-able dictionary key created from musicServiceId and
  /// householdId
  static String _createJsonableKey(String musicServiceId, String householdId) {
    return '$musicServiceId#$householdId';
  }
}
