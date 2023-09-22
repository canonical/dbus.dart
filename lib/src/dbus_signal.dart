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
  final String name;

  /// Values associated with the signal.
  final List<DBusValue> values;

  /// Signature of [values].
  DBusSignature get signature => values
      .map((value) => value.signature)
      .fold(DBusSignature(''), (a, b) => a + b);

  const DBusSignal(
      {required this.sender,
      required this.path,
      required this.interface,
      required this.name,
      this.values = const []});

  @override
  bool operator ==(other) =>
      other is DBusSignal &&
      other.sender == sender &&
      other.path == path &&
      other.interface == interface &&
      other.name == name &&
      _listsEqual(other.values, values);

  @override
  int get hashCode => Object.hash(sender, path, interface, name, values);

  @override
  String toString() =>
      "$runtimeType(sender: '$sender', path: $path, interface: '$interface', name: '$name', values: $values)";
}

bool _listsEqual<T>(List<T> a, List<T> b) {
  if (a.length != b.length) {
    return false;
  }

  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }

  return true;
}
