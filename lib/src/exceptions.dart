/// Exceptions that are used by SoCo.
// ignore_for_file: deprecated_member_use_from_same_package
library;

/// Base class for all SoCo exceptions.
class SoCoException implements Exception {
  /// Message describing the exception
  final String? message;

  /// Creates a SoCo exception with an optional message.
  const SoCoException([this.message]);

  @override
  String toString() => message ?? 'SoCoException';
}

/// An unknown UPnP error.
///
/// The exception object will contain the raw response sent back from
/// the speaker.
class UnknownSoCoException extends SoCoException {
  /// The raw response from the speaker
  final String rawResponse;

  /// Creates an unknown SoCo exception with the raw response.
  const UnknownSoCoException(this.rawResponse) : super(rawResponse);

  @override
  String toString() => 'UnknownSoCoException: $rawResponse';
}

/// A UPnP Fault Code, raised in response to actions sent over the network.
class SoCoUPnPException extends SoCoException {
  /// The UPnP Error Code as a string
  final String errorCode;

  /// The xml containing the error, as a string
  final String errorXml;

  /// A description of the error
  final String errorDescription;

  /// Creates a UPnP exception.
  ///
  /// Parameters:
  ///   - [message]: The message from the server
  ///   - [errorCode]: The UPnP Error Code as a string
  ///   - [errorXml]: The xml containing the error, as a string
  ///   - [errorDescription]: A description of the error (default is empty string)
  const SoCoUPnPException({
    required String message,
    required this.errorCode,
    required this.errorXml,
    this.errorDescription = '',
  }) : super(message);

  @override
  String toString() => message ?? 'SoCoUPnPException';
}

/// Raised if a data container class cannot create the DIDL metadata due to
/// missing information.
///
/// Deprecated: Use [DIDLMetadataError] instead.
@Deprecated('Use DIDLMetadataError instead')
class CannotCreateDIDLMetadata extends SoCoException {
  /// Creates a CannotCreateDIDLMetadata exception.
  const CannotCreateDIDLMetadata([super.message]);
}

/// Raised if a data container class cannot create the DIDL metadata due to
/// missing information.
///
/// For backward compatibility, this is currently a subclass of
/// [CannotCreateDIDLMetadata]. In a future version, it will likely become
/// a direct subclass of [SoCoException].
class DIDLMetadataError extends CannotCreateDIDLMetadata {
  /// Creates a DIDL metadata error.
  const DIDLMetadataError([super.message]);
}

/// An error relating to a third party music service.
class MusicServiceException extends SoCoException {
  /// Creates a music service exception.
  const MusicServiceException([super.message]);
}

/// An error relating to authentication of a third party music service.
class MusicServiceAuthException extends MusicServiceException {
  /// Creates a music service authentication exception.
  const MusicServiceAuthException([super.message]);
}

/// Raised if XML with an unknown or unexpected structure is returned.
class UnknownXMLStructure extends SoCoException {
  /// Creates an unknown XML structure exception.
  const UnknownXMLStructure([super.message]);
}

/// Raised when a master command is called on a slave.
class SoCoSlaveException extends SoCoException {
  /// Creates a SoCo slave exception.
  const SoCoSlaveException([super.message]);
}

/// Raised when a command intended for a visible speaker is called
/// on an invisible one.
class SoCoNotVisibleException extends SoCoException {
  /// Creates a SoCo not visible exception.
  const SoCoNotVisibleException([super.message]);
}

/// Raised when something is not supported by the device.
class NotSupportedException extends SoCoException {
  /// Creates a not supported exception.
  const NotSupportedException([super.message]);
}

/// Raised when a parsing exception occurs during event handling.
class EventParseException extends SoCoException {
  /// The tag for which the exception occurred
  final String tag;

  /// The metadata which failed to parse
  final String metadata;

  /// The original exception that caused this error
  final Exception cause;

  /// Creates an event parse exception.
  ///
  /// Parameters:
  ///   - [tag]: The tag for which the exception occurred
  ///   - [metadata]: The metadata which failed to parse
  ///   - [cause]: The original exception
  EventParseException({
    required this.tag,
    required this.metadata,
    required this.cause,
  }) : super("Invalid metadata for '$tag'");

  @override
  String toString() => "Invalid metadata for '$tag'";
}

/// Class to represent a failed object instantiation.
///
/// It rethrows the exception on common use.
class SoCoFault {
  /// The exception which will be thrown on use
  final Exception exception;

  /// Creates a SoCoFault with the given exception.
  ///
  /// Parameters:
  ///   - [exception]: The exception which should be thrown on use
  const SoCoFault(this.exception);

  /// Throws the stored exception when any property is accessed
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw exception;
  }

  @override
  String toString() => '<SoCoFault: ${exception.toString()}>';
}
