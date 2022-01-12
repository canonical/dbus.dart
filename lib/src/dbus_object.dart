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

  /// True if this object exposes the org.freedesktop.DBus.ObjectManager interface.
  final bool isObjectManager;

  /// Creates a new object to export on the bus at [path].
  DBusObject(this.path, {this.isObjectManager = false});

  /// Interfaces and properties of this object.
  /// This only requires overriding if using this object with the org.freedesktop.DBus.ObjectManager interface.
  Map<String, Map<String, DBusValue>> get interfacesAndProperties => {};

  /// Called to get introspection information about this object.
  List<DBusIntrospectInterface> introspect() {
    return [];
  }

  /// Called when a method call is received on this object.
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    return DBusMethodErrorResponse.unknownInterface();
  }

  /// Called when a property is requested on this object. On success, return [DBusGetPropertyResponse].
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    return DBusMethodErrorResponse.unknownProperty();
  }

  /// Called when a property is set on this object. On success, return [DBusMethodSuccessResponse].
  Future<DBusMethodResponse> setProperty(
      String interface, String name, DBusValue value) async {
    return DBusMethodErrorResponse.unknownProperty();
  }

  /// Called when all properties are requested on this object. On success, return [DBusGetAllPropertiesResponse].
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    return DBusGetAllPropertiesResponse({});
  }

  /// Emits a signal on this object.
  Future<void> emitSignal(String interface, String name,
      [Iterable<DBusValue> values = const []]) async {
    await client?.emitSignal(
        path: path, interface: interface, name: name, values: values);
  }

  /// Emits org.freedesktop.DBus.Properties.PropertiesChanged on this object.
  Future<void> emitPropertiesChanged(String interface,
      {Map<String, DBusValue> changedProperties = const {},
      List<String> invalidatedProperties = const []}) async {
    await emitSignal('org.freedesktop.DBus.Properties', 'PropertiesChanged', [
      DBusString(interface),
      DBusDict.stringVariant(changedProperties),
      DBusArray(DBusSignature('s'),
          invalidatedProperties.map((name) => DBusString(name)))
    ]);
  }

  /// Emits org.freedesktop.DBus.ObjectManager.InterfacesAdded on this object.
  /// [path] is the path to the object that has been added or changed.
  /// [interfacesAndProperties] is the interfaces added to the object at [path] and the properties this object has.
  Future<void> emitInterfacesAdded(DBusObjectPath path,
      Map<String, Map<String, DBusValue>> interfacesAndProperties) async {
    DBusValue encodeProperties(Map<String, DBusValue> properties) =>
        DBusDict.stringVariant(properties);
    DBusValue encodeInterfacesAndProperties(
            Map<String, Map<String, DBusValue>> interfacesAndProperties) =>
        DBusDict(
            DBusSignature('s'),
            DBusSignature('a{sv}'),
            interfacesAndProperties.map<DBusValue, DBusValue>(
                (name, properties) =>
                    MapEntry(DBusString(name), encodeProperties(properties))));
    await emitSignal('org.freedesktop.DBus.ObjectManager', 'InterfacesAdded',
        [path, encodeInterfacesAndProperties(interfacesAndProperties)]);
  }

  /// Emits org.freedesktop.DBus.ObjectManager.InterfacesRemoved on this object.
  /// [path] is the path to the object is being removed or changed.
  /// [interfaces] is the names of the interfaces being removed from the object at [path].
  Future<void> emitInterfacesRemoved(
      DBusObjectPath path, Iterable<String> interfaces) async {
    await emitSignal(
        'org.freedesktop.DBus.ObjectManager', 'InterfacesRemoved', [
      path,
      DBusArray(DBusSignature('s'),
          interfaces.map((interface) => DBusString(interface)))
    ]);
  }
}
