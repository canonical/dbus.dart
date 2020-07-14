import "dbus_client.dart";
import "dbus_value.dart";

/// An object to simplify access to a D-Bus object.
class DBusObjectProxy {
  final DBusClient client;
  final String destination;
  final String path;

  /// Creates a new DBus object proxy to access the object at [destination], [path].
  DBusObjectProxy(this.client, this.destination, this.path);

  /// Gets the introspection data for this object.
  Future<String> introspect() async {
    return client.introspect(destination, path);
  }

  /// Gets a property on this object.
  Future<DBusVariant> getProperty(String interface, String name) {
    return client.getProperty(
        destination: destination, path: path, interface: interface, name: name);
  }

  /// Gets the values of all the properties on this object.
  Future<DBusDict> getAllProperties(String interface) async {
    return client.getAllProperties(
        destination: destination, path: path, interface: interface);
  }

  /// Sets a property on this object.
  setProperty(String interface, String name, DBusVariant value) {
    return client.setProperty(
        destination: destination,
        path: path,
        interface: interface,
        name: name,
        value: value);
  }

  /// Invokes a method on this object.
  Future<List<DBusValue>> callMethod(
      String interface, String member, List<DBusValue> values) async {
    return client.callMethod(
        destination: destination,
        path: path,
        interface: interface,
        member: member,
        values: values);
  }
}
