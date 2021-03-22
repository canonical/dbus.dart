import 'dbus_value.dart';

/// Optional flags used when making method calls.
/// * [noReplyExpected] indicates the service should not respond to this call.
/// * [noAutoStart] stops the requested service from starting from this call.
/// * [allowInteractiveAuthorization] tells the service that is providing the method it can prompt the user for authorization to complete the call.
///   This may cause the call to take a long time to complete.yes
enum DBusMethodCallFlag {
  noReplyExpected,
  noAutoStart,
  allowInteractiveAuthorization
}

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

  /// Flags passed by caller.
  final Set<DBusMethodCallFlag> flags;

  /// Signature of [values].
  DBusSignature get signature => values
      .map((value) => value.signature)
      .fold(DBusSignature(''), (a, b) => a + b);

  const DBusMethodCall(
      this.sender, this.interface, this.name, this.values, this.flags);

  @override
  String toString() =>
      "DBusMethodCall(sender: '$sender', interface: '$interface', name: '$name', values: $values, flags: $flags)";
}
