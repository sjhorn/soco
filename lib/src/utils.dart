/// This module contains utility functions used internally by SoCo.
library;

import 'package:xml/xml.dart' as xml_pkg;

/// Regular expressions for camel case conversion
final _firstCapRe = RegExp(r'(.)([A-Z][a-z]+)');
final _allCapRe = RegExp(r'([a-z0-9])([A-Z])');

/// Convert camelCase to lowercase_and_underscore.
///
/// Recipe from http://stackoverflow.com/a/1176023
///
/// Parameters:
///   - [input]: The string to convert
///
/// Returns:
///   The converted string
///
/// Example:
/// ```dart
/// camelToUnderscore('MyClassName')
/// // Returns: 'my_class_name'
/// ```
String camelToUnderscore(String input) {
  var result = input.replaceAllMapped(_firstCapRe, (match) {
    return '${match.group(1)}_${match.group(2)}';
  });
  result = result.replaceAllMapped(_allCapRe, (match) {
    return '${match.group(1)}_${match.group(2)}';
  });
  return result.toLowerCase();
}

/// Convert underscore_case to camelCase.
///
/// Parameters:
///   - [input]: The string to convert
///   - [capitalizeFirst]: Whether to capitalize the first letter (default: false)
///
/// Returns:
///   The converted string
///
/// Example:
/// ```dart
/// underscoreToCamel('my_class_name')
/// // Returns: 'myClassName'
/// underscoreToCamel('my_class_name', capitalizeFirst: true)
/// // Returns: 'MyClassName'
/// ```
String underscoreToCamel(String input, {bool capitalizeFirst = false}) {
  final parts = input.split('_');
  if (parts.isEmpty) return input;

  final buffer = StringBuffer();
  buffer.write(capitalizeFirst ? firstCap(parts[0]) : parts[0]);

  for (var i = 1; i < parts.length; i++) {
    if (parts[i].isNotEmpty) {
      buffer.write(firstCap(parts[i]));
    }
  }

  return buffer.toString();
}

/// Return a pretty-printed version of an XML string.
///
/// Useful for debugging.
///
/// Parameters:
///   - [xmlText]: A text representation of XML
///
/// Returns:
///   A pretty-printed version of the input
String prettify(String xmlText) {
  try {
    final document = xml_pkg.XmlDocument.parse(xmlText);
    return document.toXmlString(pretty: true, indent: '  ');
  } catch (e) {
    // If parsing fails, return the original text
    return xmlText;
  }
}

/// Pretty print an XML document or element.
///
/// Parameters:
///   - [xmlNode]: The XML node to pretty print
///
/// Note:
///   This is a convenience function used during development. It
///   is not used anywhere in the main code base.
void showXml(xml_pkg.XmlNode xmlNode) {
  print(prettify(xmlNode.toXmlString()));
}

/// URL-escape a string value for a URL request path.
///
/// Parameters:
///   - [path]: The path to escape
///
/// Returns:
///   The escaped path
///
/// Example:
/// ```dart
/// urlEscapePath("Foo, bar & baz / the hackers")
/// // Returns: 'Foo%2C%20bar%20%26%20baz%20%2F%20the%20hackers'
/// ```
String urlEscapePath(String path) {
  // Uri.encodeComponent handles most characters, but we need to also
  // escape forward slashes
  return Uri.encodeComponent(path).replaceAll('/', '%2F');
}

/// Return string with first character upper cased.
///
/// Parameters:
///   - [input]: The string to process
///
/// Returns:
///   The string with first character capitalized
String firstCap(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1);
}

/// Convert a camelCase or underscore_case string to Title Case.
///
/// Parameters:
///   - [input]: The string to convert
///
/// Returns:
///   The string in Title Case
String toTitleCase(String input) {
  if (input.isEmpty) return input;

  // Handle camelCase by inserting spaces
  var spaced = input.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );

  // Handle underscore_case
  spaced = spaced.replaceAll('_', ' ');

  // Capitalize first letter of each word
  return spaced
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}

/// A custom deprecation annotation for SoCo.
///
/// Use this to mark deprecated functions, classes, or fields.
///
/// Example:
/// ```dart
/// @SoCoDeprecated(
///   'Use newFunction instead',
///   since: '0.7',
///   willBeRemovedIn: '1.0',
/// )
/// void oldFunction() {
///   // ...
/// }
/// ```
class SoCoDeprecated {
  /// The message to display
  final String message;

  /// The version in which the item was deprecated
  final String since;

  /// The version in which the item will be removed
  final String? willBeRemovedIn;

  /// Creates a deprecation annotation.
  const SoCoDeprecated(
    this.message, {
    required this.since,
    this.willBeRemovedIn,
  });
}
