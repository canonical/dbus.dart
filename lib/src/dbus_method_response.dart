import 'dbus_value.dart';

/// A response to a method call.
abstract class DBusMethodResponse {
  /// Gets the value returned from this method or throws an exception if an error received.
  List<DBusValue> get returnValues;
}

/// A success response to a method call.
class DBusMethodSuccessResponse extends DBusMethodResponse {
  /// Values returned from the method.
  List<DBusValue> values;

  /// Creates a new success response to a method call returning [values].
  DBusMethodSuccessResponse([this.values = const []]);

  @override
  List<DBusValue> get returnValues => values;
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
  DBusMethodErrorResponse.failed(String message)
      : this('org.freedesktop.DBus.Error.Failed', [DBusString(message)]);

  /// Creates a new error response indicating an unknown object.
  DBusMethodErrorResponse.unknownObject()
      : this('org.freedesktop.DBus.Error.UnknownObject',
            [DBusString('Unknown object')]);

  /// Creates a new error response indicating an unknown interface.
  DBusMethodErrorResponse.unknownInterface()
      : this('org.freedesktop.DBus.Error.UnknownInterface',
            [DBusString('Object does not implement the interface')]);

  /// Creates a new error response indicating an unknown method.
  DBusMethodErrorResponse.unknownMethod()
      : this('org.freedesktop.DBus.Error.UnknownMethod',
            [DBusString('Unknown / invalid message')]);

  /// Creates a new error response indicating the arguments passed were invalid.
  DBusMethodErrorResponse.invalidArgs()
      : this('org.freedesktop.DBus.Error.InvalidArgs',
            [DBusString('Invalid type / number of args')]);

  /// Creates a new error response indicating an unknown property.
  DBusMethodErrorResponse.unknownProperty()
      : this('org.freedesktop.DBus.Error.UnknownProperty',
            [DBusString('Unknown property')]);

  /// Creates a new error response when attempting to write to a read-only property.
  DBusMethodErrorResponse.propertyReadOnly()
      : this('org.freedesktop.DBus.Error.PropertyReadOnly',
            [DBusString('Property is read-only')]);

  @override
  List<DBusValue> get returnValues => throw 'Error: ${errorName}';
}

/// A successful response to [DBusObject.getProperty].
class DBusGetPropertyResponse extends DBusMethodSuccessResponse {
  DBusGetPropertyResponse(DBusValue value) : super([DBusVariant(value)]);
}

/// A successful response to [DBusObject.getAllProperties].
class DBusGetAllPropertiesResponse extends DBusMethodSuccessResponse {
  DBusGetAllPropertiesResponse(Map<String, DBusValue> values)
      : super([
          DBusDict(
              DBusSignature('s'),
              DBusSignature('v'),
              Map.fromIterables(values.keys.map((k) => DBusString(k)),
                  values.values.map((v) => DBusVariant(v))))
        ]);
}
