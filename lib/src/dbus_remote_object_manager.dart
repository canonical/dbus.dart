import 'dart:async';

import 'dbus_client.dart';
import 'dbus_remote_object.dart';
import 'dbus_signal.dart';
import 'dbus_value.dart';

/// Signal received when interfaces are added.
class DBusObjectManagerInterfacesAddedSignal extends DBusSignal {
  /// Path of the object that has interfaces added to.
  DBusObjectPath get changedPath => values[0] as DBusObjectPath;

  /// The properties and interfaces that were added.
  Map<String, Map<String, DBusValue>> get interfacesAndProperties =>
      _decodeInterfacesAndProperties(values[1]);

  DBusObjectManagerInterfacesAddedSignal(DBusSignal signal)
      : super(
            sender: signal.sender,
            path: signal.path,
            interface: signal.interface,
            name: signal.name,
            values: signal.values);
}

/// Signal received when interfaces are removed.
class DBusObjectManagerInterfacesRemovedSignal extends DBusSignal {
  /// Path of the object that has interfaces removed from.
  DBusObjectPath get changedPath => values[0] as DBusObjectPath;

  /// The interfaces that were removed.
  List<String> get interfaces => (values[1] as DBusArray).mapString().toList();

  DBusObjectManagerInterfacesRemovedSignal(DBusSignal signal)
      : super(
            sender: signal.sender,
            path: signal.path,
            interface: signal.interface,
            name: signal.name,
            values: signal.values);
}

/// An object to simplify access to a D-Bus object manager.
class DBusRemoteObjectManager extends DBusRemoteObject {
  /// Signals received from objects controlled by this object manager.
  /// The manager object will send [DBusObjectManagerInterfacesAddedSignal] and [DBusObjectManagerInterfacesRemovedSignal] to indicate when objects are added, removed or have interfaces modified.
  /// The stream will contain [DBusPropertiesChangedSignal] and [DBusSignal] for all other signals on these objects.
  late final Stream<DBusSignal> signals;

  /// Creates an object that access accesses a remote D-Bus object manager using bus [name] with [path].
  /// Requires the remote object to implement the org.freedesktop.DBus.ObjectManager interface.
  DBusRemoteObjectManager(DBusClient client,
      {required String name, required DBusObjectPath path})
      : super(client, name: name, path: path) {
    var rawSignals =
        DBusSignalStream(client, sender: name, pathNamespace: path);
    signals = rawSignals.map((signal) {
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
          signal.signature == DBusSignature('sa{sv}as')) {
        return DBusPropertiesChangedSignal(signal);
      } else {
        return signal;
      }
    });
  }

  /// Gets all the sub-tree of objects, interfaces and properties of this object.
  /// Requires the remote object to implement the org.freedesktop.DBus.ObjectManager interface.
  Future<Map<DBusObjectPath, Map<String, Map<String, DBusValue>>>>
      getManagedObjects() async {
    var result = await client.callMethod(
        destination: name,
        path: path,
        interface: 'org.freedesktop.DBus.ObjectManager',
        name: 'GetManagedObjects',
        replySignature: DBusSignature('a{oa{sa{sv}}}'));

    Map<DBusObjectPath, Map<String, Map<String, DBusValue>>> decodeObjects(
        DBusValue objects) {
      return (objects as DBusDict).children.map((key, value) => MapEntry(
          key as DBusObjectPath, _decodeInterfacesAndProperties(value)));
    }

    return decodeObjects(result.returnValues[0]);
  }

  @override
  String toString() {
    return "DBusRemoteObjectManager(name: '$name', path: '${path.value}')";
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
  return (object as DBusDict).mapStringVariant();
}
