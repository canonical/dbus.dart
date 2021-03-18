import 'dbus_message.dart';
import 'dbus_value.dart';

/// Exception thrown for invalid match rules.
class DBusMatchRuleException implements Exception {
  final String message;

  DBusMatchRuleException(this.message);
}

/// A Rule to match D-Bus messages.
class DBusMatchRule {
  /// Matches messages with this type.
  final DBusMessageType? type;

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

  /// Creates a match rule from the string [rule] which is in the format used by D-Bus messages.
  factory DBusMatchRule.fromDBusString(String rule) {
    var values = <String, String>{};
    var offset = 0;
    while (offset < rule.length) {
      var keyStart = offset;
      while (offset < rule.length && rule[offset] != '=') {
        offset++;
      }
      var key = rule.substring(keyStart, offset);
      if (offset >= rule.length) {
        throw DBusMatchRuleException(
            'Invalid D-Bus rule, key $key missing value');
      }
      offset++;

      var value = '';
      var inQuotes = false;
      while (offset < rule.length) {
        if (rule[offset] == "'") {
          inQuotes = !inQuotes;
          offset++;
          continue;
        } else if (rule[offset] == '\\') {
          if (!inQuotes) {
            if (offset + 1 < rule.length && rule[offset + 1] == "'") {
              offset++;
            }
          }
        } else if (rule[offset] == ',' && !inQuotes) {
          break;
        }
        value += rule[offset];
        offset++;
      }

      values[key] = value;

      if (offset < rule.length) {
        if (rule[offset] != ',') {
          throw DBusMatchRuleException(
              'Invalid D-Bus rule, missing trailing comma after $key value');
        }
        offset++;
      }
    }

    return DBusMatchRule(
      type: {
        'method_call': DBusMessageType.methodCall,
        'method_return': DBusMessageType.methodReturn,
        'error': DBusMessageType.error,
        'signal': DBusMessageType.signal
      }[values['type']],
      sender: values['sender'],
      interface: values['interface'],
      member: values['member'],
      path: values['path'] != null ? DBusObjectPath(values['path']!) : null,
      pathNamespace: values['pathNamespace'] != null
          ? DBusObjectPath(values['pathNamespace']!)
          : null,
    );
  }

  /// Converts the match rule to the string format used by D-Bus messages.
  String toDBusString() {
    var matches = <String, String>{};
    if (type != null) {
      matches['type'] = {
            DBusMessageType.methodCall: 'method_call',
            DBusMessageType.methodReturn: 'method_return',
            DBusMessageType.error: 'error',
            DBusMessageType.signal: 'signal'
          }[type] ??
          '';
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
      {DBusMessageType? type,
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
  bool operator ==(other) =>
      other is DBusMatchRule &&
      other.type == type &&
      other.sender == sender &&
      other.interface == interface &&
      other.member == member &&
      other.path == path &&
      other.pathNamespace == pathNamespace;

  @override
  String toString() {
    var parameters = <String, String?>{
      'type': type?.toString(),
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
