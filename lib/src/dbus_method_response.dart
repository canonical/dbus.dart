import 'dbus_value.dart';

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
  String toString() => 'DBusMethodSuccessResponse($values)';
}

/// Exception when error received calling a D-Bus method on a remote object.
class DBusMethodResponseException implements Exception {
  /// The response that generated the exception
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

  /// Creates a new error response indicating access was denied.
  DBusMethodErrorResponse.accessDenied([String? message])
      : this('org.freedesktop.DBus.Error.AccessDenied',
            message != null ? [DBusString(message)] : []);

  @override
  List<DBusValue> get returnValues => throw DBusMethodResponseException(this);

  @override
  String toString() => 'DBusMethodSuccessResponse($errorName, $values)';
}

/// A successful response to [DBusObject.getProperty].
class DBusGetPropertyResponse extends DBusMethodSuccessResponse {
  DBusGetPropertyResponse(DBusValue value) : super([DBusVariant(value)]);

  @override
  String toString() => 'DBusGetPropertyResponse($values[0])';
}

/// A successful response to [DBusObject.getAllProperties].
class DBusGetAllPropertiesResponse extends DBusMethodSuccessResponse {
  DBusGetAllPropertiesResponse(Map<String, DBusValue> values)
      : super([
          DBusDict(
              DBusSignature('s'),
              DBusSignature('v'),
              values.map((key, value) =>
                  MapEntry(DBusString(key), DBusVariant(value))))
        ]);

  @override
  String toString() =>
      'DBusGetAllPropertiesResponse(${(values[0] as DBusDict).children.map((key, value) => MapEntry((key as DBusString).value, (value as DBusVariant).value))})';
}
