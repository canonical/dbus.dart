import 'dbus_bus_name.dart';
import 'dbus_interface_name.dart';
import 'dbus_member_name.dart';
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
  final DBusBusName? sender;

  /// Matches messages on this interface.
  final DBusInterfaceName? interface;

  /// Matches messages with this member.
  final DBusMemberName? member;

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
      // Extract key.
      var keyStart = offset;
      if (rule[offset] == '=' || rule[offset] == ',') {
        throw DBusMatchRuleException('Invalid D-Bus rule, missing key');
      }
      while (
          offset < rule.length && rule[offset] != '=' && rule[offset] != ',') {
        offset++;
      }
      var key = rule.substring(keyStart, offset);
      if (offset >= rule.length || rule[offset] != '=') {
        throw DBusMatchRuleException(
            'Invalid D-Bus rule, key $key missing value');
      }
      offset++;

      // Extract value (may be quoted).
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
          offset++;
          if (offset >= rule.length) {
            throw DBusMatchRuleException(
                'Invalid D-Bus rule, missing key after comma');
          }
          break;
        }
        value += rule[offset];
        offset++;
      }
      if (inQuotes) {
        throw DBusMatchRuleException('Missing closing quote');
      }

      values[key] = value;
    }

    DBusMessageType? type;
    var valueType = values['type'];
    if (valueType != null) {
      type = {
        'method_call': DBusMessageType.methodCall,
        'method_return': DBusMessageType.methodReturn,
        'error': DBusMessageType.error,
        'signal': DBusMessageType.signal
      }[valueType];
      if (type == null) {
        throw DBusMatchRuleException('Invalid message type $valueType');
      }
    }

    if (values['path'] != null && values['path_namespace'] != null) {
      throw DBusMatchRuleException(
          "Match rule can't contain both path and path_namespace");
    }

    return DBusMatchRule(
      type: type,
      sender: values['sender'] != null ? DBusBusName(values['sender']!) : null,
      interface: values['interface'] != null
          ? DBusInterfaceName(values['interface']!)
          : null,
      member:
          values['member'] != null ? DBusMemberName(values['member']!) : null,
      path: values['path'] != null ? DBusObjectPath(values['path']!) : null,
      pathNamespace: values['path_namespace'] != null
          ? DBusObjectPath(values['path_namespace']!)
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
      matches['sender'] = sender!.value;
    }
    if (interface != null) {
      matches['interface'] = interface!.value;
    }
    if (member != null) {
      matches['member'] = member!.value;
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
    var escapedValue = value.replaceAll("'", "'\\''");
    return "'$escapedValue'";
  }

  /// True if the rule matches the supplied values.
  bool match(
      {DBusMessageType? type,
      DBusBusName? sender,
      DBusInterfaceName? interface,
      DBusMemberName? member,
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
  int get hashCode =>
      Object.hash(type, sender, interface, member, path, pathNamespace);

  @override
  String toString() {
    var parameters = <String, String?>{
      'type': type?.toString(),
      'sender': sender?.toString(),
      'interface': interface?.toString(),
      'member': member?.toString(),
      'path': path?.toString(),
      'pathNamespace': pathNamespace?.toString()
    };
    var parameterString = parameters.keys
        .where((key) => parameters[key] != null)
        .map((key) => '$key=${parameters[key]}')
        .join(', ');
    return '$runtimeType($parameterString)';
  }
}
