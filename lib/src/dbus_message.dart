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
  final String? interface;

  /// Member this message refers to or null. e.g. 'Get'.
  final String? member;

  /// Error name as returned in messages of type DBusMessageType.error or null. e.g. 'org.freedesktop.DBus.Error.UnknownObject'.
  final String? errorName;

  /// Serial number this message is replying to or null.
  final int? replySerial;

  /// Destination this message is being sent to or null. e.g. 'org.freedesktop.DBus'.
  final String? destination;

  /// Sender of this message is being sent to or null. e.g. 'com.exaple.Test'.
  final String? sender;

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
    var text = 'DBusMessage(type=$type';
    if (flags.isNotEmpty) {
      text += ' flags=$flags';
    }
    text += ' serial=$serial';
    if (path != null) {
      text += ", path='$path'";
    }
    if (interface != null) {
      text += ", interface='$interface'";
    }
    if (member != null) {
      text += ", member='$member'";
    }
    if (errorName != null) {
      text += ", errorName='$errorName'";
    }
    if (replySerial != null) {
      text += ', replySerial=$replySerial';
    }
    if (destination != null) {
      text += ", destination='$destination'";
    }
    if (sender != null) {
      text += ", sender='$sender'";
    }
    if (values.isNotEmpty) {
      var valueText = <String>[];
      for (var value in values) {
        valueText.add(value.toString());
      }
      text += ", values=[${valueText.join(', ')}]";
    }
    text += ')';
    return text;
  }
}
