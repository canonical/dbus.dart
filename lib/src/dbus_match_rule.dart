import 'dbus_value.dart';

/// A Rule to match D-Bus messages.
class DBusMatchRule {
  /// Matches messages with this type.
  final String? type;

  /// Matches messages from this sender.
  final String? sender;

  /// Matches messages on this interface.
  final String? interface;

  /// Matches messages with this member.
  final String? member;

  /// Matches messages on this path.
  final DBusObjectPath? path;

  /// Matches messages on a path in this namespace.
  final DBusObjectPath? pathNamespace;

  /// Creates a new D-Bus rule to match messages.
  const DBusMatchRule(
      {this.type,
      this.sender,
      this.interface,
      this.member,
      this.path,
      this.pathNamespace});

  /// Converts the match rule to the string format used by D-Bus messages.
  String toDBusString() {
    var matches = <String, String>{};
    if (type != null) {
      matches['type'] = type!;
    }
    if (sender != null) {
      matches['sender'] = sender!;
    }
    if (interface != null) {
      matches['interface'] = interface!;
    }
    if (member != null) {
      matches['member'] = member!;
    }
    if (path != null) {
      matches['path'] = path!.value;
    }
    if (pathNamespace != null) {
      matches['path_namespace'] = pathNamespace!.value;
    }
    return matches.keys
        .map((key) => '$key=${_escapeString(matches[key]!)}')
        .join(',');
  }

  /// Escapes a string value.
  String _escapeString(String value) {
    // Replace quotes with: End quotes, escaped quote, start quotes again.
    return "'" + value.replaceAll("'", "'\\''") + "'";
  }

  /// True if the rule matches the supplied values.
  bool match(
      {String? type,
      String? sender,
      String? interface,
      String? member,
      DBusObjectPath? path}) {
    if (this.type != null && this.type != type) {
      return false;
    }
    if (this.sender != null && this.sender != sender) {
      return false;
    }
    if (this.interface != null && this.interface != interface) {
      return false;
    }
    if (this.member != null && this.member != member) {
      return false;
    }
    if (this.path != null && this.path != path) {
      return false;
    }
    if (pathNamespace != null &&
        path != null &&
        !path.isInNamespace(pathNamespace!)) {
      return false;
    }

    return true;
  }

  @override
  String toString() {
    var parameters = <String, String?>{
      'type': type,
      'sender': sender,
      'interface': interface,
      'member': member,
      'path': path?.toString(),
      'pathNamespace': pathNamespace?.toString()
    };
    return 'DBusMatchRule(' +
        parameters.keys
            .where((key) => parameters[key] != null)
            .map((key) => '$key=${parameters[key]}')
            .join(', ') +
        ')';
  }
}
