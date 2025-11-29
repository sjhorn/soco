/// Tests for the soap module.
library;

import 'package:test/test.dart';
import 'package:soco/src/soap.dart';

const dummyValidResponse =
    '''<?xml version="1.0"?>'''
    '''<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"'''
    ''' s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'''
    '''<s:Body>'''
    '''<u:GetLEDStateResponse '''
    '''xmlns:u="urn:schemas-upnp-org:service:DeviceProperties:1">'''
    '''<CurrentLEDState>On</CurrentLEDState>'''
    '''<Unicode>data</Unicode>'''
    '''</u:GetLEDStateResponse>'''
    '''</s:Body>'''
    '''</s:Envelope>''';

void main() {
  group('SoapMessage', () {
    test('initialization sets all properties correctly', () {
      final s = SoapMessage(
        endpoint: 'http://endpoint_url',
        method: 'a_method',
      );

      expect(s.endpoint, equals('http://endpoint_url'));
      expect(s.method, equals('a_method'));
      expect(s.parameters, isEmpty);
      expect(s.soapAction, isNull);
      expect(s.httpHeaders, isNull);
      expect(s.soapHeader, isNull);
      expect(s.namespace, isNull);
    });

    test('prepareHeaders creates correct headers without SOAP action', () {
      final s = SoapMessage(endpoint: 'endpoint', method: 'method');
      final h = s.prepareHeaders({'test1': 'one', 'test2': 'two'}, null);

      expect(
        h,
        equals({
          'Content-Type': 'text/xml; charset="utf-8"',
          'test1': 'one',
          'test2': 'two',
        }),
      );
    });

    test('prepareHeaders creates correct headers with SOAP action', () {
      final s = SoapMessage(endpoint: 'endpoint', method: 'method');
      final h = s.prepareHeaders({
        'test1': 'one',
        'test2': 'two',
      }, 'soapaction');

      expect(
        h,
        equals({
          'Content-Type': 'text/xml; charset="utf-8"',
          'test1': 'one',
          'test2': 'two',
          'SOAPACTION': '"soapaction"',
        }),
      );
    });

    test('prepareSoapHeader wraps XML in header tags', () {
      final s = SoapMessage(endpoint: 'endpoint', method: 'method');
      final h = s.prepareSoapHeader('<a><b></b></a>');

      expect(h, equals('<s:Header><a><b></b></a></s:Header>'));
    });

    test('prepareSoapHeader returns empty string for null input', () {
      final s = SoapMessage(
        endpoint: 'endpoint',
        method: 'method',
        httpHeaders: {'test1': 'one', 'test2': 'two'},
      );
      final h = s.prepareSoapHeader(null);

      expect(h, equals(''));
    });

    test('prepareSoapBody formats method with no parameters', () {
      final s = SoapMessage(endpoint: 'endpoint', method: 'method');
      final b = s.prepareSoapBody('a_method', [], null);

      expect(b, equals('<a_method></a_method>'));
    });

    test('prepareSoapBody formats method with one parameter', () {
      final s = SoapMessage(endpoint: 'endpoint', method: 'method');
      final b = s.prepareSoapBody('a_method', [
        const MapEntry('one', '1'),
      ], null);

      expect(b, equals('<a_method><one>1</one></a_method>'));
    });

    test('prepareSoapBody formats method with two parameters', () {
      final s = SoapMessage(endpoint: 'endpoint', method: 'method');
      final b = s.prepareSoapBody('a_method', [
        const MapEntry('one', '1'),
        const MapEntry('two', '2'),
      ], null);

      expect(b, equals('<a_method><one>1</one><two>2</two></a_method>'));
    });

    test('prepareSoapBody includes namespace when provided', () {
      final s = SoapMessage(endpoint: 'endpoint', method: 'method');
      final b = s.prepareSoapBody('a_method', [
        const MapEntry('one', '1'),
        const MapEntry('two', '2'),
      ], 'http://a_namespace');

      expect(
        b,
        equals(
          '<a_method xmlns="http://a_namespace"><one>1</one><two>2</two></a_method>',
        ),
      );
    });

    test('prepare creates complete SOAP message', () {
      final s = SoapMessage(
        endpoint: 'endpoint',
        method: 'getData',
        parameters: [const MapEntry('one', '1')],
        httpHeaders: {'timeout': '3'},
        soapAction: 'ACTION',
        soapHeader: '<a_header>data</a_header>',
        namespace: 'http://namespace.com',
      );
      final (headers, data) = s.prepare();

      expect(
        data,
        equals(
          '<?xml version="1.0"?>'
          '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
          's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
          '<s:Header><a_header>data</a_header></s:Header>'
          '<s:Body>'
          '<getData xmlns="http://namespace.com"><one>1</one></getData>'
          '</s:Body>'
          '</s:Envelope>',
        ),
      );

      expect(headers, contains('SOAPACTION'));
      expect(headers['SOAPACTION'], equals('"ACTION"'));
    });

    test('prepareSoapBody escapes XML special characters', () {
      final s = SoapMessage(endpoint: 'endpoint', method: 'method');
      final b = s.prepareSoapBody('a_method', [
        const MapEntry('data', '<tag>"quoted" & \'apostrophe\'</tag>'),
      ], null);

      expect(
        b,
        contains(
          '&lt;tag&gt;&quot;quoted&quot; &amp; &apos;apostrophe&apos;&lt;/tag&gt;',
        ),
      );
    });
  });

  group('SoapFault', () {
    test('creates fault with required parameters', () {
      final fault = SoapFault(
        faultcode: 'Client.Error',
        faultstring: 'Invalid request',
      );

      expect(fault.faultcode, equals('Client.Error'));
      expect(fault.faultstring, equals('Invalid request'));
      expect(fault.detail, isNull);
      expect(fault.detailString, equals(''));
      expect(fault.toString(), equals('Client.Error: Invalid request'));
    });
  });
}
