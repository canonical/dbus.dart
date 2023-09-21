import 'dbus_value.dart';

/// A D-Bus method call.
class DBusMethodCall {
  /// Client that called the method.
  final String? sender;

  /// Interface method is on.
  final String? interface;

  /// Method name;
  final String name;

  /// Arguments passed by caller.
  final List<DBusValue> values;

  /// True if the client doesn't expect a reply.
  final bool noReplyExpected;

  /// True if this method shouldn't start the service if it's not running.
  final bool noAutoStart;

  /// True if the receiving service can prompt the user to authorize the call.
  final bool allowInteractiveAuthorization;

  /// Signature of [values].
  DBusSignature get signature => values
      .map((value) => value.signature)
      .fold(DBusSignature(''), (a, b) => a + b);

  const DBusMethodCall(
      {required this.sender,
      this.interface,
      required this.name,
      this.values = const [],
      this.noReplyExpected = false,
      this.noAutoStart = false,
      this.allowInteractiveAuthorization = false});

  @override
  String toString() {
    var parameters = <String, String?>{
      'sender': "'$sender'",
      'interface': interface != null ? "'$interface'" : null,
      'name': "'$name'",
      'values': values.isNotEmpty ? values.toString() : null,
      'noReplyExpected': noReplyExpected ? 'true' : null,
      'noAutoStart': noAutoStart ? 'true' : null,
      'allowInteractiveAuthorization':
          allowInteractiveAuthorization ? 'true' : null
    };
    var parameterString = parameters.keys
        .where((key) => parameters[key] != null)
        .map((key) => '$key: ${parameters[key]}')
        .join(', ');
    return '$runtimeType($parameterString)';
  }
}
