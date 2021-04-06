import 'dbus_client.dart';
import 'dbus_introspect.dart';
import 'dbus_method_call.dart';
import 'dbus_method_response.dart';
import 'dbus_value.dart';

/// An object that is exported on the bus.
class DBusObject {
  /// The path this object is registered on.
  final DBusObjectPath path;

  /// The client this object is being exported by.
  DBusClient? client;

  /// Creates a new object to export on the bus at [path].
  DBusObject(this.path);

  /// Called to get introspection information about this object.
  List<DBusIntrospectInterface> introspect() {
    return [];
  }

  /// Called when a method call is received on this object.
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    return DBusMethodErrorResponse.unknownInterface();
  }

  /// Called when a property is requested on this object. On success, return [DBusGetPropertyResponse].
  Future<DBusMethodResponse> getProperty(
      String interface, String member) async {
    return DBusMethodErrorResponse.unknownProperty();
  }

  /// Called when a property is set on this object. On success, return [DBusMethodSuccessResponse].
  Future<DBusMethodResponse> setProperty(
      String interface, String member, DBusValue value) async {
    return DBusMethodErrorResponse.unknownProperty();
  }

  /// Called when all properties are requested on this object. On success, return [DBusGetAllPropertiesResponse].
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    return DBusGetAllPropertiesResponse({});
  }

  /// Emits a signal on this object.
  void emitSignal(String interface, String member,
      [Iterable<DBusValue> values = const []]) {
    client?.emitSignal(
        path: path, interface: interface, member: member, values: values);
  }

  /// Emits org.freedesktop.DBus.Properties.PropertiesChanged on this object.
  void emitPropertiesChanged(String interface,
      {Map<String, DBusValue> changedProperties = const {},
      List<String> invalidatedProperties = const []}) {
    emitSignal('org.freedesktop.DBus.Properties', 'PropertiesChanged', [
      DBusString(interface),
      DBusDict(
          DBusSignature('s'),
          DBusSignature('v'),
          changedProperties.map(
              (name, value) => MapEntry(DBusString(name), DBusVariant(value)))),
      DBusArray(DBusSignature('s'),
          invalidatedProperties.map((name) => DBusString(name)))
    ]);
  }
}
