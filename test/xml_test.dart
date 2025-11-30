/// Tests for the xml module.
library;

import 'package:test/test.dart';
import 'package:soco/src/xml.dart';

void main() {
  group('XML utilities', () {
    test('nsTag function formats namespace tags correctly', () {
      final testCases = [
        {'nsId': 'dc', 'namespace': 'http://purl.org/dc/elements/1.1/'},
        {
          'nsId': 'upnp',
          'namespace': 'urn:schemas-upnp-org:metadata-1-0/upnp/',
        },
        {
          'nsId': '',
          'namespace': 'urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/',
        },
      ];

      for (final testCase in testCases) {
        final nsId = testCase['nsId'] as String;
        final namespace = testCase['namespace'] as String;
        final result = nsTag(nsId, 'testtag');
        final expected = '{$namespace}testtag';

        expect(
          result,
          equals(expected),
          reason: 'nsTag("$nsId", "testtag") should return "$expected"',
        );
      }
    });

    test('nsTag throws ArgumentError for unknown namespace', () {
      expect(() => nsTag('unknown', 'testtag'), throwsArgumentError);
    });

    test('filterIllegalXmlChars removes illegal characters', () {
      // Test with null byte and control characters
      expect(filterIllegalXmlChars('hello\x00world'), equals('helloworld'));
      expect(filterIllegalXmlChars('test\x01\x02\x03text'), equals('testtext'));
      expect(filterIllegalXmlChars('before\x0Bafter'), equals('beforeafter'));
      expect(filterIllegalXmlChars('line\x0Cbreak'), equals('linebreak'));
    });

    test('filterIllegalXmlChars preserves valid characters', () {
      // Valid characters should be preserved
      expect(filterIllegalXmlChars('Hello World!'), equals('Hello World!'));
      expect(filterIllegalXmlChars('<tag>value</tag>'), equals('<tag>value</tag>'));
      expect(filterIllegalXmlChars('tab\there'), equals('tab\there'));
      expect(filterIllegalXmlChars('new\nline'), equals('new\nline'));
      expect(filterIllegalXmlChars('carriage\rreturn'), equals('carriage\rreturn'));
    });

    test('filterIllegalXmlChars handles empty string', () {
      expect(filterIllegalXmlChars(''), equals(''));
    });

    test('filterIllegalXmlChars handles unicode', () {
      // BMP characters are preserved
      expect(filterIllegalXmlChars('日本語テスト'), equals('日本語テスト'));
      expect(filterIllegalXmlChars('Ümläuts äöü'), equals('Ümläuts äöü'));
      // Note: The regex removes surrogate pairs (emoji), which is expected
      // behavior based on the XML spec for some use cases
    });

    test('illegalXmlRe pattern exists', () {
      // Just verify the pattern is accessible and works
      expect(illegalXmlRe.hasMatch('\x00'), isTrue);
      expect(illegalXmlRe.hasMatch('a'), isFalse);
    });
  });
}
