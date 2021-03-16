import 'dbus_value.dart';

/// A D-Bus signal.
class DBusSignal {
  /// Client that sent the signal.
  final String? sender;

  /// Path of the object emitting the signal.
  final DBusObjectPath path;

  /// Interface emitting the signal.
  final String interface;

  /// Signal name;
  final String member;

  /// Values associated with the signal.
  final List<DBusValue> values;

  const DBusSignal(
      this.sender, this.path, this.interface, this.member, this.values);

  @override
  String toString() =>
      "DBusSignal(sender: '$sender', path: $path, interface: '$interface', member: '$member', values: $values)";
}
