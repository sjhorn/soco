/// Tests for the exceptions module.
library;

import 'package:test/test.dart';
import 'package:soco/src/exceptions.dart';

void main() {
  group('SoCoException', () {
    test('creates exception with message', () {
      const exception = SoCoException('Test error');
      expect(exception.message, equals('Test error'));
    });

    test('creates exception without message', () {
      const exception = SoCoException();
      expect(exception.message, isNull);
    });

    test('toString returns message', () {
      const exception = SoCoException('Test error');
      expect(exception.toString(), equals('Test error'));
    });

    test('toString returns default when no message', () {
      const exception = SoCoException();
      expect(exception.toString(), equals('SoCoException'));
    });

    test('implements Exception interface', () {
      const exception = SoCoException('Test');
      expect(exception, isA<Exception>());
    });
  });

  group('UnknownSoCoException', () {
    test('creates exception with raw response', () {
      const exception = UnknownSoCoException('Raw XML response');
      expect(exception.rawResponse, equals('Raw XML response'));
      expect(exception.message, equals('Raw XML response'));
    });

    test('toString includes raw response', () {
      const exception = UnknownSoCoException('Raw XML');
      expect(exception.toString(), contains('UnknownSoCoException'));
      expect(exception.toString(), contains('Raw XML'));
    });

    test('extends SoCoException', () {
      const exception = UnknownSoCoException('test');
      expect(exception, isA<SoCoException>());
    });
  });

  group('SoCoUPnPException', () {
    test('creates exception with all fields', () {
      const exception = SoCoUPnPException(
        message: 'Invalid Action',
        errorCode: '401',
        errorXml: '<error>...</error>',
        errorDescription: 'The action is not supported',
      );

      expect(exception.message, equals('Invalid Action'));
      expect(exception.errorCode, equals('401'));
      expect(exception.errorXml, equals('<error>...</error>'));
      expect(exception.errorDescription, equals('The action is not supported'));
    });

    test('errorDescription defaults to empty string', () {
      const exception = SoCoUPnPException(
        message: 'Error',
        errorCode: '500',
        errorXml: '<xml/>',
      );

      expect(exception.errorDescription, equals(''));
    });

    test('toString returns message', () {
      const exception = SoCoUPnPException(
        message: 'Invalid Args',
        errorCode: '402',
        errorXml: '<xml/>',
      );

      expect(exception.toString(), equals('Invalid Args'));
    });

    test('extends SoCoException', () {
      const exception = SoCoUPnPException(
        message: 'test',
        errorCode: '400',
        errorXml: '<xml/>',
      );
      expect(exception, isA<SoCoException>());
    });
  });

  group('DIDLMetadataError', () {
    test('creates error with message', () {
      const error = DIDLMetadataError('Missing title');
      expect(error.message, equals('Missing title'));
    });

    test('creates error without message', () {
      const error = DIDLMetadataError();
      expect(error.message, isNull);
    });

    test('extends SoCoException', () {
      const error = DIDLMetadataError();
      expect(error, isA<SoCoException>());
    });
  });

  group('MusicServiceException', () {
    test('creates exception with message', () {
      const exception = MusicServiceException('Service unavailable');
      expect(exception.message, equals('Service unavailable'));
    });

    test('extends SoCoException', () {
      const exception = MusicServiceException();
      expect(exception, isA<SoCoException>());
    });
  });

  group('MusicServiceAuthException', () {
    test('creates exception with message', () {
      const exception = MusicServiceAuthException('Invalid credentials');
      expect(exception.message, equals('Invalid credentials'));
    });

    test('extends MusicServiceException', () {
      const exception = MusicServiceAuthException();
      expect(exception, isA<MusicServiceException>());
    });

    test('extends SoCoException', () {
      const exception = MusicServiceAuthException();
      expect(exception, isA<SoCoException>());
    });
  });

  group('UnknownXMLStructure', () {
    test('creates exception with message', () {
      const exception = UnknownXMLStructure('Unexpected root element');
      expect(exception.message, equals('Unexpected root element'));
    });

    test('extends SoCoException', () {
      const exception = UnknownXMLStructure();
      expect(exception, isA<SoCoException>());
    });
  });

  group('SoCoSlaveException', () {
    test('creates exception with message', () {
      const exception = SoCoSlaveException('Cannot control slave speaker');
      expect(exception.message, equals('Cannot control slave speaker'));
    });

    test('extends SoCoException', () {
      const exception = SoCoSlaveException();
      expect(exception, isA<SoCoException>());
    });
  });

  group('SoCoNotVisibleException', () {
    test('creates exception with message', () {
      const exception = SoCoNotVisibleException('Speaker is not visible');
      expect(exception.message, equals('Speaker is not visible'));
    });

    test('extends SoCoException', () {
      const exception = SoCoNotVisibleException();
      expect(exception, isA<SoCoException>());
    });
  });

  group('NotSupportedException', () {
    test('creates exception with message', () {
      const exception = NotSupportedException('Feature not supported');
      expect(exception.message, equals('Feature not supported'));
    });

    test('extends SoCoException', () {
      const exception = NotSupportedException();
      expect(exception, isA<SoCoException>());
    });
  });

  group('EventParseException', () {
    test('creates exception with all fields', () {
      final cause = FormatException('Invalid format');
      final exception = EventParseException(
        tag: 'CurrentTrackMetaData',
        metadata: '<invalid>xml',
        cause: cause,
      );

      expect(exception.tag, equals('CurrentTrackMetaData'));
      expect(exception.metadata, equals('<invalid>xml'));
      expect(exception.cause, equals(cause));
      expect(exception.message, contains('CurrentTrackMetaData'));
    });

    test('toString includes tag', () {
      final exception = EventParseException(
        tag: 'LastChange',
        metadata: 'bad data',
        cause: Exception('test'),
      );

      expect(exception.toString(), contains('LastChange'));
    });

    test('extends SoCoException', () {
      final exception = EventParseException(
        tag: 'tag',
        metadata: 'meta',
        cause: Exception(),
      );
      expect(exception, isA<SoCoException>());
    });
  });

  group('SoCoFault', () {
    test('creates fault with exception', () {
      final exception = Exception('Something went wrong');
      final fault = SoCoFault(exception);

      expect(fault.exception, equals(exception));
    });

    test('toString includes exception', () {
      final exception = FormatException('Bad format');
      final fault = SoCoFault(exception);

      expect(fault.toString(), contains('SoCoFault'));
      expect(fault.toString(), contains('Bad format'));
    });

    test('throws exception on property access via noSuchMethod', () {
      final exception = Exception('Test exception');
      final fault = SoCoFault(exception);

      // Accessing any property should throw
      expect(
        () => (fault as dynamic).someProperty,
        throwsA(equals(exception)),
      );
    });

    test('throws exception on method call via noSuchMethod', () {
      final exception = FormatException('Test');
      final fault = SoCoFault(exception);

      // Calling any method should throw
      expect(
        () => (fault as dynamic).someMethod(),
        throwsA(equals(exception)),
      );
    });
  });

  group('Exception hierarchy', () {
    test('all exceptions can be caught as SoCoException', () {
      final exceptions = <SoCoException>[
        const SoCoException('base'),
        const UnknownSoCoException('unknown'),
        const SoCoUPnPException(
          message: 'upnp',
          errorCode: '500',
          errorXml: '<xml/>',
        ),
        const DIDLMetadataError('didl'),
        const MusicServiceException('music'),
        const MusicServiceAuthException('auth'),
        const UnknownXMLStructure('xml'),
        const SoCoSlaveException('slave'),
        const SoCoNotVisibleException('not visible'),
        const NotSupportedException('not supported'),
        EventParseException(
          tag: 'tag',
          metadata: 'meta',
          cause: Exception(),
        ),
      ];

      for (final e in exceptions) {
        expect(e, isA<SoCoException>());
        expect(e, isA<Exception>());
      }
    });
  });
}
