/// Tests for the soap module.
library;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';
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

  group('SoapMessage.call()', () {
    test(
      'parses successful response and returns body element',
      () async {
        final mockClient = MockClient((request) async {
          expect(
            request.url.toString(),
            equals('http://192.168.1.100:1400/test'),
          );
          expect(
            request.headers['Content-Type'],
            equals('text/xml; charset="utf-8"'),
          );
          expect(request.headers['SOAPACTION'], equals('"TestAction"'));
          return http.Response(dummyValidResponse, 200);
        });

        final soap = SoapMessage(
          endpoint: 'http://192.168.1.100:1400/test',
          method: 'GetLEDState',
          soapAction: 'TestAction',
          httpClient: mockClient,
        );

        final result = await soap.call();

        expect(result.localName, equals('GetLEDStateResponse'));
        // Access child elements by filtering by name
        final currentLedState = result.childElements
            .where((e) => e.localName == 'CurrentLEDState')
            .first;
        expect(currentLedState.innerText, equals('On'));

        final unicode = result.childElements
            .where((e) => e.localName == 'Unicode')
            .first;
        expect(unicode.innerText, equals('data'));
      },
      timeout: Timeout(Duration(seconds: 5)),
    );

    test(
      'throws SoapFault on 500 response with SOAP fault',
      () async {
        const faultResponse = '''<?xml version="1.0"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
                    s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <s:Fault>
              <faultcode>s:Client</faultcode>
              <faultstring>UPnPError</faultstring>
              <detail>
                <UPnPError xmlns="urn:schemas-upnp-org:control-1-0">
                  <errorCode>402</errorCode>
                  <errorDescription>Invalid Args</errorDescription>
                </UPnPError>
              </detail>
            </s:Fault>
          </s:Body>
        </s:Envelope>''';

        final mockClient = MockClient((request) async {
          return http.Response(faultResponse, 500);
        });

        final soap = SoapMessage(
          endpoint: 'http://192.168.1.100:1400/test',
          method: 'TestMethod',
          httpClient: mockClient,
        );

        expect(
          () => soap.call(),
          throwsA(
            isA<SoapFault>()
                .having((f) => f.faultcode, 'faultcode', 's:Client')
                .having((f) => f.faultstring, 'faultstring', 'UPnPError'),
          ),
        );
      },
      timeout: Timeout(Duration(seconds: 5)),
    );

    test(
      'throws SoapFault on 200 response containing fault',
      () async {
        const faultIn200Response = '''<?xml version="1.0"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
                    s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <s:Fault xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
              <faultcode>s:Server</faultcode>
              <faultstring>Server Error</faultstring>
            </s:Fault>
          </s:Body>
        </s:Envelope>''';

        final mockClient = MockClient((request) async {
          return http.Response(faultIn200Response, 200);
        });

        final soap = SoapMessage(
          endpoint: 'http://192.168.1.100:1400/test',
          method: 'TestMethod',
          httpClient: mockClient,
        );

        expect(
          () => soap.call(),
          throwsA(
            isA<SoapFault>()
                .having((f) => f.faultcode, 'faultcode', 's:Server')
                .having((f) => f.faultstring, 'faultstring', 'Server Error'),
          ),
        );
      },
      timeout: Timeout(Duration(seconds: 5)),
    );

    test(
      'throws XmlParserException on 500 response with invalid XML',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final soap = SoapMessage(
          endpoint: 'http://192.168.1.100:1400/test',
          method: 'TestMethod',
          httpClient: mockClient,
        );

        // The code tries to parse XML even on 500 response, so invalid XML throws XmlParserException
        expect(() => soap.call(), throwsA(isA<Exception>()));
      },
      timeout: Timeout(Duration(seconds: 5)),
    );

    test(
      'throws ClientException on non-200/500 response',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        final soap = SoapMessage(
          endpoint: 'http://192.168.1.100:1400/test',
          method: 'TestMethod',
          httpClient: mockClient,
        );

        expect(() => soap.call(), throwsA(isA<http.ClientException>()));
      },
      timeout: Timeout(Duration(seconds: 5)),
    );

    test(
      'sends parameters correctly in request body',
      () async {
        String? capturedBody;

        final mockClient = MockClient((request) async {
          capturedBody = request.body;
          return http.Response(dummyValidResponse, 200);
        });

        final soap = SoapMessage(
          endpoint: 'http://192.168.1.100:1400/test',
          method: 'SetVolume',
          parameters: [
            const MapEntry('InstanceID', '0'),
            const MapEntry('Channel', 'Master'),
            const MapEntry('DesiredVolume', '50'),
          ],
          namespace: 'urn:schemas-upnp-org:service:RenderingControl:1',
          httpClient: mockClient,
        );

        await soap.call();

        expect(capturedBody, contains('<SetVolume'));
        expect(capturedBody, contains('<InstanceID>0</InstanceID>'));
        expect(capturedBody, contains('<Channel>Master</Channel>'));
        expect(capturedBody, contains('<DesiredVolume>50</DesiredVolume>'));
        expect(
          capturedBody,
          contains('xmlns="urn:schemas-upnp-org:service:RenderingControl:1"'),
        );
      },
      timeout: Timeout(Duration(seconds: 5)),
    );

    test('includes SOAP header when provided', () async {
      String? capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(dummyValidResponse, 200);
      });

      final soap = SoapMessage(
        endpoint: 'http://192.168.1.100:1400/test',
        method: 'TestMethod',
        soapHeader: '<credentials><token>abc123</token></credentials>',
        httpClient: mockClient,
      );

      await soap.call();

      expect(capturedBody, contains('<s:Header>'));
      expect(capturedBody, contains('<credentials>'));
      expect(capturedBody, contains('<token>abc123</token>'));
      expect(capturedBody, contains('</s:Header>'));
    }, timeout: Timeout(Duration(seconds: 5)));

    test('uses custom timeout when provided', () async {
      final mockClient = MockClient((request) async {
        // Simulate a fast response
        return http.Response(dummyValidResponse, 200);
      });

      final soap = SoapMessage(
        endpoint: 'http://192.168.1.100:1400/test',
        method: 'TestMethod',
        timeout: const Duration(seconds: 5),
        httpClient: mockClient,
      );

      // Should complete without timing out
      final result = await soap.call();
      expect(result, isNotNull);
    }, timeout: Timeout(Duration(seconds: 5)));

    test(
      'throws ClientException on non-SOAP error response',
      () async {
        // Return 400 Bad Request with a non-SOAP body (not a fault envelope)
        final mockClient = MockClient((request) async {
          return http.Response(
            'Bad Request - not a SOAP response',
            400,
            reasonPhrase: 'Bad Request',
          );
        });

        final soap = SoapMessage(
          endpoint: 'http://192.168.1.100:1400/test',
          method: 'TestMethod',
          httpClient: mockClient,
        );

        expect(() => soap.call(), throwsA(isA<http.ClientException>()));
      },
      timeout: Timeout(Duration(seconds: 5)),
    );
  });
}
