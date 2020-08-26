import 'dbus_value.dart';
import 'dbus_read_buffer.dart';
import 'dbus_write_buffer.dart';

/// Supported protocol version.
const ProtocolVersion = 1;

/// Endianess of a D-Bus message.
class Endianess {
  static const Little = 108; // ASCII 'l'
  static const Big = 66; // ASCII 'B'
}

/// Types of headers.
class HeaderCode {
  static const Invalid = 0;
  static const Path = 1;
  static const Interface = 2;
  static const Member = 3;
  static const ErrorName = 4;
  static const ReplySerial = 5;
  static const Destination = 6;
  static const Sender = 7;
  static const Signature = 8;
  static const UnixFds = 9;
}

/// Type of message.
class MessageType {
  static const Invalid = 0;
  static const MethodCall = 1;
  static const MethodReturn = 2;
  static const Error = 3;
  static const Signal = 4;
}

/// Flags attached to message.
class Flags {
  static const NoReplyExpected = 0x01;
  static const NoAutoStart = 0x02;
  static const AllowInteractiveAuthorization = 0x04;
}

/// A message sent to/from the D-Bus server.
class DBusMessage {
  /// Type of the message, e.g. MessageType.MethodCall.
  final int type;

  /// Flags associated with this message, e.g. Flags.NoAutoStart.
  final int flags;

  /// Unique serial number for this message.
  final int serial;

  /// Object path this message refers to or null. e.g. '/org/freedesktop/DBus'.
  final DBusObjectPath path;

  /// Interface this message refers to or null. e.g. 'org.freedesktop.DBus.Properties'.
  final String interface;

  /// Member this message refers to or null. e.g. 'Get'.
  final String member;

  /// Error name as returned in messages of type MessageType.Error or null. e.g. 'org.freedesktop.DBus.Error.UnknownObject'.
  final String errorName;

  /// Serial number this message is replying to or null.
  final int replySerial;

  /// Destination this message is being sent to or null. e.g. 'org.freedesktop.DBus'.
  final String destination;

  /// Sender of this message is being sent to or null. e.g. 'com.exaple.Test'.
  final String sender;

  /// Values being sent with this message.
  final List<DBusValue> values;

  /// Creates a new D-Bus message.
  DBusMessage(
      {this.type = MessageType.Invalid,
      this.flags = 0,
      this.serial = 0,
      this.path,
      this.interface,
      this.member,
      this.errorName,
      this.replySerial,
      this.destination,
      this.sender,
      this.values});

  /// Creates a message by reading from [buffer].
  /// Returns null if not enough data to read a message.
  factory DBusMessage.fromBuffer(DBusReadBuffer buffer) {
    if (buffer.remaining < 12) {
      return null;
    }

    buffer.readDBusByte(); // Endianess.
    var type = buffer.readDBusByte().value;
    var flags = buffer.readDBusByte().value;
    buffer.readDBusByte(); // Protocol version.
    var dataLength = buffer.readDBusUint32();
    var serial = buffer.readDBusUint32().value;
    var headers = buffer.readDBusArray(DBusSignature('(yv)'));
    if (headers == null) {
      return null;
    }

    DBusSignature signature;
    DBusObjectPath path;
    String interface;
    String member;
    String errorName;
    int replySerial;
    String destination;
    String sender;
    for (var child in headers.children) {
      var header = child as DBusStruct;
      var code = (header.children.elementAt(0) as DBusByte).value;
      var value = (header.children.elementAt(1) as DBusVariant).value;
      if (code == HeaderCode.Path) {
        path = value as DBusObjectPath;
      } else if (code == HeaderCode.Interface) {
        interface = (value as DBusString).value;
      } else if (code == HeaderCode.Member) {
        member = (value as DBusString).value;
      } else if (code == HeaderCode.ErrorName) {
        errorName = (value as DBusString).value;
      } else if (code == HeaderCode.ReplySerial) {
        replySerial = (value as DBusUint32).value;
      } else if (code == HeaderCode.Destination) {
        destination = (value as DBusString).value;
      } else if (code == HeaderCode.Sender) {
        sender = (value as DBusString).value;
      } else if (code == HeaderCode.Signature) {
        signature = value as DBusSignature;
      }
    }
    if (!buffer.align(8)) {
      return null;
    }

    if (buffer.remaining < dataLength.value) {
      return null;
    }

    var values = <DBusValue>[];
    if (signature != null) {
      var signatures = signature.split();
      for (var s in signatures) {
        var value = buffer.readDBusValue(s);
        if (value == null) {
          return null;
        }
        values.add(value);
      }
    }

    return DBusMessage(
        type: type,
        flags: flags,
        serial: serial,
        path: path,
        interface: interface,
        member: member,
        errorName: errorName,
        replySerial: replySerial,
        destination: destination,
        sender: sender,
        values: values);
  }

  /// Write this message to [buffer].
  void toBuffer(DBusWriteBuffer buffer) {
    var valueBuffer = DBusWriteBuffer();
    for (var value in values) {
      valueBuffer.writeValue(value);
    }

    // FIXME(robert-ancell): Handle endianess - currently hard-coded to little
    buffer.writeValue(DBusByte(Endianess.Little));
    buffer.writeValue(DBusByte(type));
    buffer.writeValue(DBusByte(flags));
    buffer.writeValue(DBusByte(ProtocolVersion));
    buffer.writeValue(DBusUint32(valueBuffer.data.length));
    buffer.writeValue(DBusUint32(serial));
    var headers = <DBusValue>[];
    if (path != null) {
      headers.add(_makeHeader(HeaderCode.Path, path));
    }
    if (interface != null) {
      headers.add(_makeHeader(HeaderCode.Interface, DBusString(interface)));
    }
    if (member != null) {
      headers.add(_makeHeader(HeaderCode.Member, DBusString(member)));
    }
    if (errorName != null) {
      headers.add(_makeHeader(HeaderCode.ErrorName, DBusString(errorName)));
    }
    if (replySerial != null) {
      headers.add(_makeHeader(HeaderCode.ReplySerial, DBusUint32(replySerial)));
    }
    if (destination != null) {
      headers.add(_makeHeader(HeaderCode.Destination, DBusString(destination)));
    }
    if (sender != null) {
      headers.add(_makeHeader(HeaderCode.Sender, DBusString(sender)));
    }
    if (values.isNotEmpty) {
      var signature = '';
      for (var value in values) {
        signature += value.signature.value;
      }
      headers.add(_makeHeader(HeaderCode.Signature, DBusSignature(signature)));
    }
    buffer.writeValue(DBusArray(DBusSignature('(yv)'), headers));
    buffer.align(8);
    buffer.writeBytes(valueBuffer.data);
  }

  /// Makes a new message header.
  DBusStruct _makeHeader(int code, DBusValue value) {
    return DBusStruct([DBusByte(code), DBusVariant(value)]);
  }

  @override
  String toString() {
    var text = 'DBusMessage(type=';
    if (type == MessageType.MethodCall) {
      text += 'MessageType.MethodCall';
    } else if (type == MessageType.MethodReturn) {
      text += 'MessageType.MethodReturn';
    } else if (type == MessageType.Error) {
      text += 'MessageType.Error';
    } else if (type == MessageType.Signal) {
      text += 'MessageType.Signal';
    } else {
      text += '${type}';
    }
    if (flags != 0) {
      var flagNames = <String>[];
      if (flags & Flags.NoReplyExpected != 0) {
        flagNames.add('Flags.NoReplyExpected');
      }
      if (flags & Flags.NoAutoStart != 0) {
        flagNames.add('Flags.NoAutoStart');
      }
      if (flags & Flags.AllowInteractiveAuthorization != 0) {
        flagNames.add('Flags.AllowInteractiveAuthorization');
      }
      if (flags & 0xF8 != 0) {
        flagNames.add((flags & 0xF8).toRadixString(16).padLeft(2));
      }
      text += ' flags=${flagNames.join('|')}';
    }
    text += ' serial=${serial}';
    if (path != null) {
      text += ", path='${path}'";
    }
    if (interface != null) {
      text += ", interface='${interface}'";
    }
    if (member != null) {
      text += ", member='${member}'";
    }
    if (errorName != null) {
      text += ", errorName='${errorName}'";
    }
    if (replySerial != null) {
      text += ', replySerial=${replySerial}';
    }
    if (destination != null) {
      text += ", destination='${destination}'";
    }
    if (sender != null) {
      text += ", sender='${sender}'";
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
