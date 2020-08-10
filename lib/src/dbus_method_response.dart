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

  @override
  List<DBusValue> get returnValues => throw 'Error: ${errorName}';
}
