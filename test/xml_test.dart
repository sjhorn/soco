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
  });
}
