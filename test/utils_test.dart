/// Tests for the utils module.
library;

import 'package:test/test.dart';
import 'package:soco/src/utils.dart';
import 'package:xml/xml.dart';

void main() {
  group('Utils', () {
    group('SoCoDeprecated annotation', () {
      test('creates annotation with required fields', () {
        const deprecated = SoCoDeprecated(
          'Use newFunction instead',
          since: '0.7',
        );

        expect(deprecated.message, equals('Use newFunction instead'));
        expect(deprecated.since, equals('0.7'));
        expect(deprecated.willBeRemovedIn, isNull);
      });

      test('creates annotation with optional willBeRemovedIn field', () {
        const deprecated = SoCoDeprecated(
          'Use betterFunction instead',
          since: '0.8',
          willBeRemovedIn: '0.12',
        );

        expect(deprecated.message, equals('Use betterFunction instead'));
        expect(deprecated.since, equals('0.8'));
        expect(deprecated.willBeRemovedIn, equals('0.12'));
      });
    });

    group('camelToUnderscore', () {
      test('converts camelCase to snake_case', () {
        expect(camelToUnderscore('MyClassName'), equals('my_class_name'));
        expect(camelToUnderscore('camelCase'), equals('camel_case'));
        expect(
          camelToUnderscore('HTTPSConnection'),
          equals('https_connection'),
        );
        expect(
          camelToUnderscore('getHTTPResponseCode'),
          equals('get_http_response_code'),
        );
      });

      test('handles already lowercase strings', () {
        expect(camelToUnderscore('lowercase'), equals('lowercase'));
      });
    });

    group('underscoreToCamel', () {
      test('converts snake_case to camelCase', () {
        expect(underscoreToCamel('my_class_name'), equals('myClassName'));
        expect(underscoreToCamel('snake_case'), equals('snakeCase'));
      });

      test(
        'converts snake_case to PascalCase when capitalizeFirst is true',
        () {
          expect(
            underscoreToCamel('my_class_name', capitalizeFirst: true),
            equals('MyClassName'),
          );
          expect(
            underscoreToCamel('snake_case', capitalizeFirst: true),
            equals('SnakeCase'),
          );
        },
      );

      test('handles already camelCase strings', () {
        expect(underscoreToCamel('camelCase'), equals('camelCase'));
      });
    });

    group('firstCap', () {
      test('capitalizes first character', () {
        expect(firstCap('hello'), equals('Hello'));
        expect(firstCap('world'), equals('World'));
      });

      test('handles already capitalized strings', () {
        expect(firstCap('Hello'), equals('Hello'));
      });

      test('handles empty strings', () {
        expect(firstCap(''), equals(''));
      });

      test('handles single character', () {
        expect(firstCap('a'), equals('A'));
        expect(firstCap('A'), equals('A'));
      });
    });

    group('toTitleCase', () {
      test('converts camelCase to Title Case', () {
        expect(toTitleCase('myClassName'), equals('My Class Name'));
      });

      test('converts snake_case to Title Case', () {
        expect(toTitleCase('my_class_name'), equals('My Class Name'));
      });

      test('handles already Title Case', () {
        expect(toTitleCase('My Class Name'), equals('My Class Name'));
      });

      test('handles empty string', () {
        expect(toTitleCase(''), equals(''));
      });
    });

    group('urlEscapePath', () {
      test('escapes URL path with special characters', () {
        expect(
          urlEscapePath('Foo, bar & baz / the hackers'),
          equals('Foo%2C%20bar%20%26%20baz%20%2F%20the%20hackers'),
        );
      });

      test('escapes forward slashes', () {
        expect(urlEscapePath('path/to/resource'), contains('%2F'));
      });

      test('handles already escaped strings', () {
        final path = 'simple';
        expect(urlEscapePath(path), equals('simple'));
      });
    });

    group('prettify', () {
      test('formats XML with indentation', () {
        final xml = '<root><child>value</child></root>';
        final pretty = prettify(xml);

        expect(pretty, contains('\n'));
        expect(pretty, contains('  ')); // Should have indentation
      });

      test('returns original text if XML is invalid', () {
        final invalidXml = '<root><unclosed>';
        final result = prettify(invalidXml);

        // Should return original since it can't be parsed
        expect(result, equals(invalidXml));
      });
    });

    group('showXml', () {
      test('prints prettified XML to stdout', () {
        final xmlDoc = XmlDocument.parse('<root><child>text</child></root>');
        // This just exercises the function - it prints to stdout
        // We can't easily capture the output but we can verify it doesn't throw
        showXml(xmlDoc);
      });
    });
  });
}
