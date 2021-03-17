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

  /// Signature of [values].
  DBusSignature get signature => values
      .map((value) => value.signature)
      .fold(DBusSignature(''), (a, b) => a + b);

  const DBusSignal(
      this.sender, this.path, this.interface, this.name, this.values);

  @override
  String toString() =>
      "DBusSignal(sender: '$sender', path: $path, interface: '$interface', name: '$name', values: $values)";
}
