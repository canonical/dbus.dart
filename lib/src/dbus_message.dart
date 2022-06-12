import 'dbus_bus_name.dart';
import 'dbus_error_name.dart';
import 'dbus_interface_name.dart';
import 'dbus_member_name.dart';
import 'dbus_value.dart';

/// Type of message.
enum DBusMessageType { methodCall, methodReturn, error, signal }

/// Flags attached to message.
enum DBusMessageFlag {
  noReplyExpected,
  noAutoStart,
  allowInteractiveAuthorization
}

/// A message sent to/from the D-Bus server.
class DBusMessage {
  /// Type of the message, e.g. DBusMessageType.methodCall.
  final DBusMessageType type;

  /// Flags associated with this message, e.g. Flags.NoAutoStart.
  final Set<DBusMessageFlag> flags;

  /// Unique serial number for this message.
  final int serial;

  /// Object path this message refers to or null. e.g. '/org/freedesktop/DBus'.
  final DBusObjectPath? path;

  /// Interface this message refers to or null. e.g. 'org.freedesktop.DBus.Properties'.
  final DBusInterfaceName? interface;

  /// Member this message refers to or null. e.g. 'Get'.
  final DBusMemberName? member;

  /// Error name as returned in messages of type DBusMessageType.error or null. e.g. 'org.freedesktop.DBus.Error.UnknownObject'.
  final DBusErrorName? errorName;

  /// Serial number this message is replying to or null.
  final int? replySerial;

  /// Destination this message is being sent to or null. e.g. 'org.freedesktop.DBus'.
  final DBusBusName? destination;

  /// Sender of this message is being sent to or null. e.g. 'com.exaple.Test'.
  final DBusBusName? sender;

  /// Values being sent with this message.
  final List<DBusValue> values;

  /// The signature of the values.
  DBusSignature get signature =>
      DBusSignature(values.map((value) => value.signature.value).join());

  /// Creates a new D-Bus message.
  DBusMessage(this.type,
      {this.flags = const {},
      this.serial = 0,
      this.path,
      this.interface,
      this.member,
      this.errorName,
      this.replySerial,
      this.destination,
      this.sender,
      this.values = const []});

  @override
  String toString() {
    var parameters = <String, String?>{
      'type': type.toString(),
      'flags': flags.isNotEmpty ? flags.toString() : null,
      'serial': serial.toString(),
      'path': path?.toString(),
      'interface': interface?.toString(),
      'member': member?.toString(),
      'errorName': errorName?.toString(),
      'replySerial': replySerial?.toString(),
      'destination': destination?.toString(),
      'sender': sender?.toString(),
      'values': values.isNotEmpty ? values.toString() : null
    };
    var parameterString = parameters.keys
        .where((key) => parameters[key] != null)
        .map((key) => '$key: ${parameters[key]}')
        .join(', ');
    return '$runtimeType($parameterString)';
  }
}
