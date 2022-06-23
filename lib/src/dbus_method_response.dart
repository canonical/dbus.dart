import 'dbus_value.dart';

// Namespace used for standard D-Bus errors.
const _dbusErrorNamespacePrefix = 'org.freedesktop.DBus.Error.';

/// A response to a method call.
abstract class DBusMethodResponse {
  /// Gets the value returned from this method or throws a [DBusMethodResponseException] if an error received.
  List<DBusValue> get returnValues;

  /// Gets the signature of the [returnValues].
  DBusSignature get signature => returnValues
      .map((value) => value.signature)
      .fold(DBusSignature(''), (a, b) => a + b);
}

/// A success response to a method call.
class DBusMethodSuccessResponse extends DBusMethodResponse {
  /// Values returned from the method.
  List<DBusValue> values;

  /// Creates a new success response to a method call returning [values].
  DBusMethodSuccessResponse([this.values = const []]);

  @override
  List<DBusValue> get returnValues => values;

  @override
  String toString() => '$runtimeType($values)';
}

/// Exception when error received calling a D-Bus method on a remote object.
class DBusMethodResponseException implements Exception {
  /// Name of the error.
  String get errorName => response.errorName;

  /// The response that generated the exception.
  final DBusMethodErrorResponse response;

  DBusMethodResponseException(this.response);

  @override
  String toString() {
    if (response.values.isEmpty) {
      return response.errorName;
    } else if (response.values.length == 1) {
      return '${response.errorName}: ${response.values.first.toNative()}';
    } else {
      return '${response.errorName}: ${response.values.map((value) => value.toNative())}';
    }
  }
}

/// Standard D-Bus exception in the org.freedesktop.DBus.Error namespace.
class DBusErrorException extends DBusMethodResponseException {
  /// Message passed with exception.
  String get message {
    if (response.values.isNotEmpty && response.values.first is DBusString) {
      return response.values.first.asString();
    }
    return '';
  }

  DBusErrorException(DBusMethodErrorResponse response) : super(response) {
    assert(response.errorName.startsWith(_dbusErrorNamespacePrefix));
  }
}

/// Exception when a general failure occurs.
class DBusFailedException extends DBusErrorException {
  DBusFailedException(DBusMethodErrorResponse response) : super(response);
}

/// Exception when there is no service providing the requested bus name.
class DBusServiceUnknownException extends DBusErrorException {
  DBusServiceUnknownException(DBusMethodErrorResponse response)
      : super(response);
}

/// Exception when an unknown object was requested.
class DBusUnknownObjectException extends DBusErrorException {
  DBusUnknownObjectException(DBusMethodErrorResponse response)
      : super(response);
}

/// Exception when an unknown interface was requested.
class DBusUnknownInterfaceException extends DBusErrorException {
  DBusUnknownInterfaceException(DBusMethodErrorResponse response)
      : super(response);
}

/// Exception when an unknown method was requested.
class DBusUnknownMethodException extends DBusErrorException {
  DBusUnknownMethodException(DBusMethodErrorResponse response)
      : super(response);
}

/// Exception when a request times out.
class DBusTimeoutException extends DBusErrorException {
  DBusTimeoutException(DBusMethodErrorResponse response) : super(response);
}

/// Exception when a request times out.
class DBusTimedOutException extends DBusErrorException {
  DBusTimedOutException(DBusMethodErrorResponse response) : super(response);
}

/// Exception when invalid arguments were provided to a method call.
class DBusInvalidArgsException extends DBusErrorException {
  DBusInvalidArgsException(DBusMethodErrorResponse response) : super(response);
}

/// Exception when an unknown property was requested.
class DBusUnknownPropertyException extends DBusErrorException {
  DBusUnknownPropertyException(DBusMethodErrorResponse response)
      : super(response);
}

/// Exception when a read-only property was written to.
class DBusPropertyReadOnlyException extends DBusErrorException {
  DBusPropertyReadOnlyException(DBusMethodErrorResponse response)
      : super(response);
}

/// Exception when a write-only property was read from.
class DBusPropertyWriteOnlyException extends DBusErrorException {
  DBusPropertyWriteOnlyException(DBusMethodErrorResponse response)
      : super(response);
}

/// Exception when accessing a feature that is not supported.
class DBusNotSupportedException extends DBusErrorException {
  DBusNotSupportedException(DBusMethodErrorResponse response) : super(response);
}

/// Exception when access was denied to the requested resource.
class DBusAccessDeniedException extends DBusErrorException {
  DBusAccessDeniedException(DBusMethodErrorResponse response) : super(response);
}

/// Exception when authentication failed accessing the requested resource.
class DBusAuthFailedException extends DBusErrorException {
  DBusAuthFailedException(DBusMethodErrorResponse response) : super(response);
}

/// An error response to a method call.
class DBusMethodErrorResponse extends DBusMethodResponse {
  /// The name of the error that occurred.
  String errorName;

  /// Additional values passed with the error.
  List<DBusValue> values;

  /// Creates a new error response to a method call with the error [errorName] and optional [values].
  DBusMethodErrorResponse(this.errorName, [this.values = const []]);

  /// Creates a new error response indicating the request failed.
  DBusMethodErrorResponse.failed([String? message])
      : this('org.freedesktop.DBus.Error.Failed',
            message != null ? [DBusString(message)] : []);

  /// Creates a new error response indicating an unknown object.
  DBusMethodErrorResponse.unknownObject([String? message])
      : this('org.freedesktop.DBus.Error.UnknownObject',
            message != null ? [DBusString(message)] : []);

  /// Creates a new error response indicating an unknown interface.
  DBusMethodErrorResponse.unknownInterface([String? message])
      : this('org.freedesktop.DBus.Error.UnknownInterface',
            message != null ? [DBusString(message)] : []);

  /// Creates a new error response indicating an unknown method.
  DBusMethodErrorResponse.unknownMethod([String? message])
      : this('org.freedesktop.DBus.Error.UnknownMethod',
            message != null ? [DBusString(message)] : []);

  /// Creates a new error response indicating the request timed out.
  DBusMethodErrorResponse.timeout([String? message])
      : this('org.freedesktop.DBus.Error.Timeout',
            message != null ? [DBusString(message)] : []);

  /// Creates a new error response indicating the request timed out.
  DBusMethodErrorResponse.timedOut([String? message])
      : this('org.freedesktop.DBus.Error.TimedOut',
            message != null ? [DBusString(message)] : []);

  /// Creates a new error response indicating the arguments passed were invalid.
  DBusMethodErrorResponse.invalidArgs([String? message])
      : this('org.freedesktop.DBus.Error.InvalidArgs',
            message != null ? [DBusString(message)] : []);

  /// Creates a new error response indicating an unknown property.
  DBusMethodErrorResponse.unknownProperty([String? message])
      : this('org.freedesktop.DBus.Error.UnknownProperty',
            message != null ? [DBusString(message)] : []);

  /// Creates a new error response when attempting to write to a read-only property.
  DBusMethodErrorResponse.propertyReadOnly([String? message])
      : this('org.freedesktop.DBus.Error.PropertyReadOnly',
            message != null ? [DBusString(message)] : []);

  /// Creates a new error response when attempting to read to a write-only property.
  DBusMethodErrorResponse.propertyWriteOnly([String? message])
      : this('org.freedesktop.DBus.Error.PropertyWriteOnly',
            message != null ? [DBusString(message)] : []);

  /// Creates a new error response when accessing an unsupported feature.
  DBusMethodErrorResponse.notSupported([String? message])
      : this('org.freedesktop.DBus.Error.NotSupported',
            message != null ? [DBusString(message)] : []);

  /// Creates a new error response indicating access was denied.
  DBusMethodErrorResponse.accessDenied([String? message])
      : this('org.freedesktop.DBus.Error.AccessDenied',
            message != null ? [DBusString(message)] : []);

  /// Creates a new error response indicating authentication failed.
  DBusMethodErrorResponse.authFailed([String? message])
      : this('org.freedesktop.DBus.Error.AuthFailed',
            message != null ? [DBusString(message)] : []);

  @override
  List<DBusValue> get returnValues => throw DBusMethodResponseException(this);

  @override
  String toString() => '$runtimeType($errorName, $values)';
}

/// A successful response to [DBusObject.getProperty].
class DBusGetPropertyResponse extends DBusMethodSuccessResponse {
  DBusGetPropertyResponse(DBusValue value) : super([DBusVariant(value)]);

  @override
  String toString() => '$runtimeType($values[0])';
}

/// A successful response to [DBusObject.getAllProperties].
class DBusGetAllPropertiesResponse extends DBusMethodSuccessResponse {
  DBusGetAllPropertiesResponse(Map<String, DBusValue> values)
      : super([DBusDict.stringVariant(values)]);

  @override
  String toString() => '$runtimeType(${values[0].asStringVariantDict()})';
}
