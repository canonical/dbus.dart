import 'dbus_client.dart';
import 'dbus_introspect.dart';
import 'dbus_method_call.dart';
import 'dbus_method_response.dart';
import 'dbus_signal.dart';
import 'dbus_value.dart';

/// Signal received when properties are changed.
class DBusPropertiesChangedSignal extends DBusSignal {
  /// The interface the properties are on.
  String get propertiesInterface => (values[0] as DBusString).value;

  /// Properties that have changed and their new values.
  Map<String, DBusValue> get changedProperties =>
      (values[1] as DBusDict).children.map((name, value) =>
          MapEntry((name as DBusString).value, (value as DBusVariant).value));

  /// Properties that have changed but require their values to be requested.
  List<String> get invalidatedProperties => (values[2] as DBusArray)
      .children
      .map((value) => (value as DBusString).value)
      .toList();

  DBusPropertiesChangedSignal(DBusSignal signal)
      : super(signal.sender, signal.path, signal.interface, signal.name,
            signal.values);
}

/// Signal received when interfaces are added.
class DBusObjectManagerInterfacesAddedSignal extends DBusSignal {
  /// Path of the object that has interfaces added to.
  DBusObjectPath get changedPath => values[0] as DBusObjectPath;

  /// The properties and interfaces that were added.
  Map<String, Map<String, DBusValue>> get interfacesAndProperties =>
      _decodeInterfacesAndProperties(values[1]);

  DBusObjectManagerInterfacesAddedSignal(DBusSignal signal)
      : super(signal.sender, signal.path, signal.interface, signal.name,
            signal.values);
}

/// Signal received when interfaces are removed.
class DBusObjectManagerInterfacesRemovedSignal extends DBusSignal {
  /// Path of the object that has interfaces removed from.
  DBusObjectPath get changedPath => values[0] as DBusObjectPath;

  /// The interfaces that were removed.
  List<String> get interfaces => (values[1] as DBusArray)
      .children
      .map((value) => (value as DBusString).value)
      .toList();

  DBusObjectManagerInterfacesRemovedSignal(DBusSignal signal)
      : super(signal.sender, signal.path, signal.interface, signal.name,
            signal.values);
}

/// An object to simplify access to a D-Bus object.
class DBusRemoteObject {
  final DBusClient client;
  final String destination;
  final DBusObjectPath path;

  /// Creates an object that access accesses a remote D-Bus object at [destination], [path].
  DBusRemoteObject(this.client, this.destination, this.path);

  /// Gets the introspection data for this object.
  Future<DBusIntrospectNode> introspect() async {
    var result = await client.callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Introspectable',
        member: 'Introspect');
    if (result.signature != DBusSignature('s')) {
      throw 'org.freedesktop.DBus.Introspectable.Introspect returned invalid result: ${result.returnValues}';
    }
    var xml = (result.returnValues[0] as DBusString).value;
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
    if (result.signature != DBusSignature('v')) {
      throw 'org.freedesktop.DBus.Properties.Get returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusVariant).value;
  }

  /// Gets the values of all the properties on this object.
  Future<Map<String, DBusValue>> getAllProperties(String interface) async {
    var result = await client.callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Properties',
        member: 'GetAll',
        values: [DBusString(interface)]);
    if (result.signature != DBusSignature('a{sv}')) {
      throw 'org.freedesktop.DBus.Properties.GetAll returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusDict).children.map((key, value) =>
        MapEntry((key as DBusString).value, (value as DBusVariant).value));
  }

  /// Sets a property on this object.
  Future<void> setProperty(
      String interface, String name, DBusValue value) async {
    var result = await client.callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Properties',
        member: 'Set',
        values: [DBusString(interface), DBusString(name), DBusVariant(value)]);
    if (result.returnValues.isNotEmpty) {
      throw 'org.freedesktop.DBus.Properties.set returned invalid result: ${result.returnValues}';
    }
  }

  /// Subscribes to property changes.
  Stream<DBusPropertiesChangedSignal> subscribePropertiesChanged() {
    var signals =
        subscribeSignal('org.freedesktop.DBus.Properties', 'PropertiesChanged');
    return signals.map((signal) {
      if (signal.signature != DBusSignature('sa{sv}as')) {
        return DBusPropertiesChangedSignal(signal);
      } else {
        throw 'org.freedesktop.DBus.Properties.PropertiesChanged contains invalid values ${signal.values}';
      }
    });
  }

  /// Invokes a method on this object.
  Future<DBusMethodResponse> callMethod(
      String? interface, String member, Iterable<DBusValue> values,
      {Set<DBusMethodCallFlag> flags = const {}}) async {
    return client.callMethod(
        destination: destination,
        path: path,
        interface: interface,
        member: member,
        values: values,
        flags: flags);
  }

  /// Subscribes to signals [interface].[member] from this object.
  Stream<DBusSignal> subscribeSignal(String interface, String member) {
    return client.subscribeSignals(
        sender: destination, path: path, interface: interface, member: member);
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
    if (result.signature != DBusSignature('a{oa{sa{sv}}}')) {
      throw 'GetManagedObjects returned invalid result: ${result.returnValues}';
    }

    Map<DBusObjectPath, Map<String, Map<String, DBusValue>>> decodeObjects(
        DBusValue objects) {
      return (objects as DBusDict).children.map((key, value) => MapEntry(
          key as DBusObjectPath, _decodeInterfacesAndProperties(value)));
    }

    return decodeObjects(result.returnValues[0]);
  }

  /// Subscribes to signals using object manager.
  /// The stream will contain [DBusPropertiesChangedSignal], [DBusObjectManagerInterfacesAddedSignal], [DBusObjectManagerInterfacesRemovedSignal] and [DBusSignal] for all other signals on these objects.
  /// Requires the remote object to implement the org.freedesktop.DBus.ObjectManager interface.
  Stream<DBusSignal> subscribeObjectManagerSignals() {
    var signals =
        client.subscribeSignals(sender: destination, pathNamespace: path);
    return signals.map((signal) {
      if (signal.interface == 'org.freedesktop.DBus.ObjectManager' &&
          signal.name == 'InterfacesAdded' &&
          signal.signature == DBusSignature('oa{sa{sv}}')) {
        return DBusObjectManagerInterfacesAddedSignal(signal);
      } else if (signal.interface == 'org.freedesktop.DBus.ObjectManager' &&
          signal.name == 'InterfacesRemoved' &&
          signal.signature == DBusSignature('oas')) {
        return DBusObjectManagerInterfacesRemovedSignal(signal);
      } else if (signal.interface == 'org.freedesktop.DBus.Properties' &&
          signal.name == 'PropertiesChanged' &&
          signal.signature == DBusSignature('aa{sv}as')) {
        return DBusPropertiesChangedSignal(signal);
      } else {
        return signal;
      }
    });
  }

  @override
  String toString() {
    return "DBusRemoteObject(destination: '$destination', path: '${path.value}')";
  }
}

/// Decodes a value with signature 'a{sa{sv}}'.
Map<String, Map<String, DBusValue>> _decodeInterfacesAndProperties(
    DBusValue object) {
  return (object as DBusDict).children.map((key, value) =>
      MapEntry((key as DBusString).value, _decodeProperties(value)));
}

/// Decodes a value with signature 'a{sv}'.
Map<String, DBusValue> _decodeProperties(DBusValue object) {
  return (object as DBusDict).children.map((key, value) =>
      MapEntry((key as DBusString).value, (value as DBusVariant).value));
}
