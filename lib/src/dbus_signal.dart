import 'dbus_value.dart';

/// A D-Bus signal.
class DBusSignal {
  /// Client that sent the signal.
  final String sender;

  /// Path of the object emitting the signal.
  final DBusObjectPath path;

  /// Interface emitting the signal.
  final String interface;

  /// Signal name;
  final String name;

  /// Values associated with the signal.
  final List<DBusValue> values;

  const DBusSignal(
      this.sender, this.path, this.interface, this.name, this.values);

  @override
  String toString() =>
      "DBusSignal(sender: '$sender', path: $path, interface: '$interface', name: '$name', values: $values)";
}
