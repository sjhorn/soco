/// Helper class for loading test data files.
library;

import 'dart:io';
import 'dart:convert';

/// Loads XML and JSON test data files from the test/data directory.
class DataLoader {
  final String subdirectory;

  DataLoader(this.subdirectory);

  /// Get the base path for test data files.
  String get basePath => 'test/data/$subdirectory';

  /// Load an XML file and return its contents as a string.
  String loadXml(String filename) {
    final file = File('$basePath/$filename');
    if (!file.existsSync()) {
      throw FileSystemException('Test data file not found', file.path);
    }
    return file.readAsStringSync();
  }

  /// Load a JSON file and return its parsed contents.
  Map<String, dynamic> loadJson(String filename) {
    final file = File('$basePath/$filename');
    if (!file.existsSync()) {
      throw FileSystemException('Test data file not found', file.path);
    }
    final jsonString = file.readAsStringSync();
    return json.decode(jsonString) as Map<String, dynamic>;
  }

  /// Load both XML and JSON files with the same base name.
  ///
  /// For example, loadXmlAndJson('track') will load 'track.xml' and 'track.json'
  /// and return them as a tuple (xmlString, jsonData).
  (String, Map<String, dynamic>) loadXmlAndJson(String baseName) {
    final xmlContent = loadXml('$baseName.xml');
    final jsonData = loadJson('$baseName.json');
    return (xmlContent, jsonData);
  }
}
