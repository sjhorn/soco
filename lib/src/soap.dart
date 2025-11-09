/// Classes for handling SoCo's basic SOAP requirements.
///
/// This module does not handle the full SOAP Specification, but is enough
/// for SoCo's needs. Sonos uses SOAP for UPnP communications, and for
/// communication with third party music services.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:xml/xml.dart' as xml;

import 'config.dart' as config;
import 'exceptions.dart';
import 'utils.dart';

final _log = Logger('soco.soap');

/// An exception encapsulating a SOAP Fault.
class SoapFault extends SoCoException {
  /// The SOAP faultcode
  final String faultcode;

  /// The SOAP faultstring
  final String faultstring;

  /// The SOAP fault detail, as an XML element
  final xml.XmlElement? detail;

  /// String representation of the detail
  late final String detailString;

  /// Creates a SOAP fault exception.
  ///
  /// Parameters:
  ///   - [faultcode]: The SOAP faultcode
  ///   - [faultstring]: The SOAP faultstring
  ///   - [detail]: The SOAP fault detail as an XML element (optional)
  SoapFault({required this.faultcode, required this.faultstring, this.detail})
    : super('$faultcode: $faultstring') {
    detailString = detail?.toXmlString() ?? '';
  }

  @override
  String toString() => '$faultcode: $faultstring';
}

/// A SOAP Message representing a remote procedure call.
///
/// Uses the `http` package for communication with a SOAP server.
class SoapMessage {
  /// The SOAP endpoint URL for this client
  final String endpoint;

  /// The name of the method to call
  final String method;

  /// A list of (name, value) pairs containing the parameters to pass
  final List<MapEntry<String, dynamic>> parameters;

  /// HTTP headers to use for the http request
  final Map<String, String>? httpHeaders;

  /// The value of the SOAPACTION header
  final String? soapAction;

  /// A string representation of the XML to be used for the SOAP Header
  final String? soapHeader;

  /// The namespace URI to use for the method and parameters
  final String? namespace;

  /// Optional timeout for the HTTP request
  final Duration? timeout;

  /// Creates a SOAP message.
  ///
  /// Parameters:
  ///   - [endpoint]: The SOAP endpoint URL for this client
  ///   - [method]: The name of the method to call
  ///   - [parameters]: A list of (name, value) pairs containing the parameters.
  ///     Default is empty list.
  ///   - [httpHeaders]: HTTP headers to use. Content-type and SOAPACTION
  ///     headers will be created automatically, so do not include them here.
  ///   - [soapAction]: The value of the SOAPACTION header. Default null.
  ///   - [soapHeader]: A string representation of the XML to be used for the
  ///     SOAP Header. Default null.
  ///   - [namespace]: The namespace URI to use for the method and parameters.
  ///     Default null.
  ///   - [timeout]: Timeout for the HTTP request. If not specified, uses
  ///     [config.requestTimeout].
  SoapMessage({
    required this.endpoint,
    required this.method,
    this.parameters = const [],
    this.httpHeaders,
    this.soapAction,
    this.soapHeader,
    this.namespace,
    this.timeout,
  });

  /// Prepare the http headers for sending.
  ///
  /// Add the SOAPACTION header to the others.
  ///
  /// Parameters:
  ///   - [httpHeaders]: HTTP headers to use
  ///   - [soapAction]: The value of the SOAPACTION header
  ///
  /// Returns:
  ///   Headers including the SOAPACTION header
  Map<String, String> prepareHeaders(
    Map<String, String>? httpHeaders,
    String? soapAction,
  ) {
    final headers = <String, String>{
      'Content-Type': 'text/xml; charset="utf-8"',
    };

    if (soapAction != null) {
      headers['SOAPACTION'] = '"$soapAction"';
    }

    if (httpHeaders != null) {
      headers.addAll(httpHeaders);
    }

    return headers;
  }

  /// Prepare the SOAP header for sending.
  ///
  /// Wraps the soap header in appropriate tags.
  ///
  /// Parameters:
  ///   - [soapHeader]: A string representation of the XML to be used
  ///     for the SOAP Header
  ///
  /// Returns:
  ///   The soap header wrapped in appropriate tags
  String prepareSoapHeader(String? soapHeader) {
    if (soapHeader != null) {
      return '<s:Header>$soapHeader</s:Header>';
    } else {
      return '';
    }
  }

  /// Prepare the SOAP message body for sending.
  ///
  /// Parameters:
  ///   - [method]: The name of the method to call
  ///   - [parameters]: A list of (name, value) pairs containing the parameters
  ///   - [namespace]: The XML namespace to use for the method
  ///
  /// Returns:
  ///   A properly formatted SOAP Body
  String prepareSoapBody(
    String method,
    List<MapEntry<String, dynamic>> parameters,
    String? namespace,
  ) {
    final tags = <String>[];
    for (final param in parameters) {
      final name = param.key;
      final value = param.value;
      // Escape XML special characters
      final escapedValue = _escapeXml(value.toString());
      tags.add('<$name>$escapedValue</$name>');
    }

    final wrappedParams = tags.join();

    // Prepare the SOAP Body
    if (namespace != null) {
      return '<$method xmlns="$namespace">$wrappedParams</$method>';
    } else {
      return '<$method>$wrappedParams</$method>';
    }
  }

  /// Prepare the SOAP Envelope for sending.
  ///
  /// Parameters:
  ///   - [preparedSoapHeader]: A SOAP Header prepared by [prepareSoapHeader]
  ///   - [preparedSoapBody]: A SOAP Body prepared by [prepareSoapBody]
  ///
  /// Returns:
  ///   A prepared SOAP Envelope
  String prepareSoapEnvelope(
    String preparedSoapHeader,
    String preparedSoapBody,
  ) {
    return '<?xml version="1.0"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"'
        ' s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '$preparedSoapHeader'
        '<s:Body>'
        '$preparedSoapBody'
        '</s:Body>'
        '</s:Envelope>';
  }

  /// Prepare the SOAP message for sending to the server.
  ///
  /// Returns:
  ///   A record containing (headers, data) ready to send
  (Map<String, String>, String) prepare() {
    final headers = prepareHeaders(httpHeaders, soapAction);
    final soapHeaderData = prepareSoapHeader(soapHeader);
    final soapBody = prepareSoapBody(method, parameters, namespace);
    final data = prepareSoapEnvelope(soapHeaderData, soapBody);
    return (headers, data);
  }

  /// Call the SOAP method on the server.
  ///
  /// Returns:
  ///   The decapsulated SOAP response from the server as an XML element.
  ///
  /// Throws:
  ///   - [SoapFault] if a SOAP error occurs
  ///   - [http.ClientException] if an http error occurs
  ///   - [XmlParserException] if the response cannot be parsed as XML
  Future<xml.XmlElement> call() async {
    final (headers, data) = prepare();

    // Check log level before logging XML, since prettifying it is expensive
    if (_log.level <= Level.FINE) {
      _log.fine('Sending $headers, ${prettify(data)}');
    }

    final effectiveTimeout =
        timeout ??
        (config.requestTimeout != null
            ? Duration(seconds: config.requestTimeout!.toInt())
            : null);

    final response = await http
        .post(Uri.parse(endpoint), headers: headers, body: utf8.encode(data))
        .timeout(effectiveTimeout ?? const Duration(seconds: 20));

    _log.fine('Received ${response.headers}, ${response.body}');

    final status = response.statusCode;

    if (status == 200) {
      // The response is good. Extract the Body
      final document = xml.XmlDocument.parse(response.body);

      // Check for faults in the content
      final fault = document
          .findAllElements(
            'Fault',
            namespace: 'http://schemas.xmlsoap.org/soap/envelope/',
          )
          .firstOrNull;

      if (fault != null) {
        final faultcode = fault.findElements('faultcode').first.innerText;
        final faultstring = fault.findElements('faultstring').first.innerText;
        final faultdetail = fault.findElements('detail').firstOrNull;
        throw SoapFault(
          faultcode: faultcode,
          faultstring: faultstring,
          detail: faultdetail,
        );
      }

      // Get the first child of the <Body> tag
      final body = document
          .findAllElements(
            'Body',
            namespace: 'http://schemas.xmlsoap.org/soap/envelope/',
          )
          .first
          .children
          .whereType<xml.XmlElement>()
          .first;

      return body;
    } else if (status == 500) {
      // We probably have a SOAP Fault
      final document = xml.XmlDocument.parse(response.body);
      final fault = document
          .findAllElements(
            'Fault',
            namespace: 'http://schemas.xmlsoap.org/soap/envelope/',
          )
          .firstOrNull;

      if (fault == null) {
        // Not a SOAP fault. Must be something else.
        throw http.ClientException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          Uri.parse(endpoint),
        );
      }

      final faultcode = fault.findElements('faultcode').first.innerText;
      final faultstring = fault.findElements('faultstring').first.innerText;
      final faultdetail = fault.findElements('detail').firstOrNull;

      throw SoapFault(
        faultcode: faultcode,
        faultstring: faultstring,
        detail: faultdetail,
      );
    } else {
      // Something else has gone wrong. Probably a network error.
      throw http.ClientException(
        'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        Uri.parse(endpoint),
      );
    }
  }
}

/// Escape XML special characters.
///
/// Parameters:
///   - [text]: The text to escape
///
/// Returns:
///   The escaped text
String _escapeXml(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
