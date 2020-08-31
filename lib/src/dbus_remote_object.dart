import 'dbus_client.dart';
import 'dbus_introspect.dart';
import 'dbus_method_response.dart';
import 'dbus_value.dart';

/// Callback for when objects change properties.
typedef PropertiesChangedCallback = void Function(
    String interfaceName,
    Map<String, DBusValue> changedProperties,
    List<String> invalidatedProperties);

typedef ObjectManagerInterfacesAddedCallback = void Function(
    DBusObjectPath objectPath,
    Map<String, Map<String, DBusValue>> interfacesAndProperties);

typedef ObjectManagerInterfacesRemovedCallback = void Function(
    DBusObjectPath objectPath, List<String> interfaces);

typedef ObjectManagerPropertiesChangedCallback = void Function(
    DBusObjectPath objectPath,
    String interfaceName,
    Map<String, DBusValue> changedProperties,
    List<String> invalidatedProperties);

/// An object to simplify access to a D-Bus object.
class DBusRemoteObject {
  final DBusClient client;
  final String destination;
  final DBusObjectPath path;

  /// Creates an object that access accesses a remote D-Bus object at [destination], [path].
  DBusRemoteObject(this.client, this.destination, this.path);

  /// Gets the introspection data for this object.
  Future<List<DBusIntrospectNode>> introspect() async {
    var result = await client.callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Introspectable',
        member: 'Introspect');
    var values = result.returnValues;
    if (values.length != 1 || values[0].signature != DBusSignature('s')) {
      throw 'org.freedesktop.DBus.Introspectable.Introspect returned invalid result: ${values}';
    }
    var xml = await (values[0] as DBusString).value;
    return parseDBusIntrospectXml(xml);
  }

  /// Gets a property on this object.
  Future<DBusValue> getProperty(String interface, String name) async {
    var result = await client.callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Properties',
        member: 'Get',
        values: [DBusString(interface), DBusString(name)]);
    var values = result.returnValues;
    if (values.length != 1 || values[0].signature != DBusSignature('v')) {
      throw 'org.freedesktop.DBus.Properties.Get returned invalid result: ${values}';
    }
    return (values[0] as DBusVariant).value;
  }

  /// Gets the values of all the properties on this object.
  Future<Map<String, DBusValue>> getAllProperties(String interface) async {
    var result = await client.callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Properties',
        member: 'GetAll',
        values: [DBusString(interface)]);
    var values = result.returnValues;
    if (values.length != 1 || values[0].signature != DBusSignature('a{sv}')) {
      throw 'org.freedesktop.DBus.Properties.GetAll returned invalid result: ${values}';
    }
    return (values[0] as DBusDict).children.map((key, value) =>
        MapEntry((key as DBusString).value, (value as DBusVariant).value));
  }

  /// Sets a property on this object.
  void setProperty(String interface, String name, DBusValue value) async {
    var result = await client.callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Properties',
        member: 'Set',
        values: [DBusString(interface), DBusString(name), DBusVariant(value)]);
    var values = result.returnValues;
    if (values.isNotEmpty) {
      throw 'org.freedesktop.DBus.Properties.set returned invalid result: ${values}';
    }
  }

  /// Subscribe to property change signals.
  Future<DBusSignalSubscription> subscribePropertiesChanged(
      PropertiesChangedCallback callback) async {
    return await subscribeSignal(
        'org.freedesktop.DBus.Properties', 'PropertiesChanged', (values) {
      if (values.length != 3 ||
          values[0].signature != DBusSignature('s') ||
          values[1].signature != DBusSignature('a{sv}') ||
          values[2].signature != DBusSignature('as')) {
        return;
      }
      var interfaceName = (values[0] as DBusString).value;
      var changedProperties = (values[1] as DBusDict).children.map((name,
              value) =>
          MapEntry((name as DBusString).value, (value as DBusVariant).value));
      var invalidatedProperties = (values[2] as DBusArray)
          .children
          .map((value) => (value as DBusString).value)
          .toList();
      callback(interfaceName, changedProperties, invalidatedProperties);
    });
  }

  /// Invokes a method on this object.
  Future<DBusMethodResponse> callMethod(
      String interface, String member, List<DBusValue> values) async {
    return client.callMethod(
        destination: destination,
        path: path,
        interface: interface,
        member: member,
        values: values);
  }

  /// Subscribes to the signal [interface].[member] from this object and calls [callback] when received.
  Future<DBusSignalSubscription> subscribeSignal(String interface,
      String member, void Function(List<DBusValue> values) callback) async {
    return await client.subscribeSignals(
        (path, interface, member, values) => callback(values),
        sender: destination,
        path: path,
        interface: interface,
        member: member);
  }

  /// Gets all the sub-tree of objects, interfaces and properties of this object.
  /// Requires the remote object to implement the org.freedesktop.DBus.ObjectManager interface.
  Future<Map<DBusObjectPath, Map<String, Map<String, DBusValue>>>>
      getManagedObjects() async {
    var result = await client.callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.ObjectManager',
        member: 'GetManagedObjects');
    var values = result.returnValues;
    if (values.length != 1 ||
        values[0].signature != DBusSignature('a{oa{sa{sv}}}')) {
      throw 'GetManagedObjects returned invalid result: ${values}';
    }

    Map<DBusObjectPath, Map<String, Map<String, DBusValue>>> decodeObjects(
        DBusValue objects) {
      return (objects as DBusDict).children.map((key, value) => MapEntry(
          key as DBusObjectPath, _decodeInterfacesAndProperties(value)));
    }

    return decodeObjects(values[0]);
  }

  /// Subscribes to when the sub-tree of objects has objects or interfaces added or removed.
  /// [interfacesAddedCallback] is called when objects are added or have interfaces added.
  /// [interfacesRemovedCallback] is called when objects are removed or have interfaces removed.
  /// [propertiesChangedCallback] is called when object properties change.
  /// [signalCallback] is called for all other signals received on these objects.
  /// Requires the remote object to implement the org.freedesktop.DBus.ObjectManager interface.
  Future<DBusSignalSubscription> subscribeObjectManagerSignals(
      {ObjectManagerInterfacesAddedCallback interfacesAddedCallback,
      ObjectManagerInterfacesRemovedCallback interfacesRemovedCallback,
      ObjectManagerPropertiesChangedCallback propertiesChangedCallback,
      SignalCallback signalCallback}) async {
    return await client.subscribeSignals((path, interface, member, values) {
      if (interface == 'org.freedesktop.DBus.ObjectManager' &&
          member == 'InterfacesAdded') {
        if (values.length != 2 ||
            values[0].signature != DBusSignature('o') ||
            values[1].signature != DBusSignature('a{sa{sv}}')) {
          return;
        }
        var objectPath = values[0] as DBusObjectPath;
        var interfacesAndProperties = _decodeInterfacesAndProperties(values[1]);
        if (interfacesAddedCallback != null) {
          interfacesAddedCallback(objectPath, interfacesAndProperties);
        }
      } else if (interface == 'org.freedesktop.DBus.ObjectManager' &&
          member == 'InterfacesRemoved') {
        if (values.length != 2 ||
            values[0].signature != DBusSignature('o') ||
            values[1].signature != DBusSignature('as')) {
          return;
        }
        var objectPath = values[0] as DBusObjectPath;
        var interfaces = (values[1] as DBusArray)
            .children
            .map((value) => (value as DBusString).value)
            .toList();
        if (interfacesRemovedCallback != null) {
          interfacesRemovedCallback(objectPath, interfaces);
        }
      } else if (interface == 'org.freedesktop.DBus.Properties' &&
          member == 'PropertiesChanged') {
        if (values.length != 3 ||
            values[0].signature != DBusSignature('s') ||
            values[1].signature != DBusSignature('a{sv}') ||
            values[2].signature != DBusSignature('as')) {
          return;
        }
        var interfaceName = (values[0] as DBusString).value;
        var changedProperties = (values[1] as DBusDict).children.map((name,
                value) =>
            MapEntry((name as DBusString).value, (value as DBusVariant).value));
        var invalidatedProperties = (values[2] as DBusArray)
            .children
            .map((value) => (value as DBusString).value)
            .toList();
        if (propertiesChangedCallback != null) {
          propertiesChangedCallback(
              path, interfaceName, changedProperties, invalidatedProperties);
        }
      } else {
        if (signalCallback != null) {
          signalCallback(path, interface, member, values);
        }
      }
    }, sender: destination, pathNamespace: path);
  }

  /// Decodes a value with signature 'a{sv}'.
  Map<String, DBusValue> _decodeProperties(DBusValue object) {
    return (object as DBusDict).children.map((key, value) =>
        MapEntry((key as DBusString).value, (value as DBusVariant).value));
  }

  /// Decodes a value with signature 'a{sa{sv}}'.
  Map<String, Map<String, DBusValue>> _decodeInterfacesAndProperties(
      DBusValue object) {
    return (object as DBusDict).children.map((key, value) =>
        MapEntry((key as DBusString).value, _decodeProperties(value)));
  }
}
