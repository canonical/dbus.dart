import 'dbus_client.dart';
import 'dbus_introspect.dart';
import 'dbus_method_response.dart';
import 'dbus_value.dart';

/// An object that is exported on the bus.
class DBusObject {
  /// The client this object is being exported by.
  DBusClient? client;

  /// The path this object is registered on.
  DBusObjectPath get path {
    return DBusObjectPath('/');
  }

  /// Called to get introspection information about this object.
  List<DBusIntrospectInterface> introspect() {
    return [];
  }

  /// Called when a method call is received on this object.
  Future<DBusMethodResponse> handleMethodCall(String? sender, String? interface,
      String? member, List<DBusValue>? values) async {
    return DBusMethodErrorResponse.unknownInterface();
  }

  /// Called when a property is requested on this object. On success, return [DBusGetPropertyResponse].
  Future<DBusMethodResponse> getProperty(
      String? interface, String? member) async {
    return DBusMethodErrorResponse.unknownProperty();
  }

  /// Called when a property is set on this object.
  Future<DBusMethodResponse> setProperty(
      String? interface, String? member, DBusValue? value) async {
    return DBusMethodErrorResponse.unknownProperty();
  }

  /// Called when all properties are requested on this object. On success, return [DBusGetAllPropertiesResponse].
  Future<DBusMethodResponse> getAllProperties(String? interface) async {
    return DBusMethodSuccessResponse(
        [DBusDict(DBusSignature('s'), DBusSignature('v'), {})]);
  }

  /// Emits a signal on this object.
  void emitSignal(String interface, String member,
      [List<DBusValue> values = const []]) {
    client!.emitSignal(
        path: path, interface: interface, member: member, values: values);
  }
}
