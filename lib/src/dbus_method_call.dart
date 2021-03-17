import 'dbus_value.dart';

/// A D-Bus method call.
class DBusMethodCall {
  /// Client that called the method.
  final String sender;

  /// Interface method is on.
  final String? interface;

  /// Method name;
  final String name;

  /// Arguments passed by caller.
  final List<DBusValue> values;

  /// Signature of [values].
  DBusSignature get signature => values
      .map((value) => value.signature)
      .fold(DBusSignature(''), (a, b) => a + b);

  const DBusMethodCall(this.sender, this.interface, this.name, this.values);

  @override
  String toString() =>
      "DBusMethodCall(sender: '$sender', interface: '$interface', name: '$name', values: $values)";
}
