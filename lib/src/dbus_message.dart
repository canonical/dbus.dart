import 'dbus_value.dart';
import 'dbus_read_buffer.dart';
import 'dbus_write_buffer.dart';

const ProtocolVersion = 1;

class Endianess {
  static const Little = 108; // ASCII 'l'
  static const Big = 66; // ASCII 'B'
}

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

class MessageType {
  static const Invalid = 0;
  static const MethodCall = 1;
  static const MethodReturn = 2;
  static const Error = 3;
  static const Signal = 4;
}

class Flags {
  static const NoReplyExpected = 0x01;
  static const NoAutoStart = 0x02;
  static const AllowInteractiveAuthorization = 0x04;
}

class DBusMessage {
  int type;
  int flags;
  int serial;
  String path;
  String interface;
  String member;
  String errorName;
  int replySerial;
  String destination;
  String sender;
  var values = List<DBusValue>();

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

  marshal(DBusWriteBuffer buffer) {
    var valueBuffer = DBusWriteBuffer();
    for (var value in values) value.marshal(valueBuffer);

    // FIXME(robert-ancell): Handle endianess - currently hard-coded to little
    DBusByte(Endianess.Little).marshal(buffer);
    DBusByte(type).marshal(buffer);
    DBusByte(flags).marshal(buffer);
    DBusByte(ProtocolVersion).marshal(buffer);
    DBusUint32(valueBuffer.data.length).marshal(buffer);
    DBusUint32(serial).marshal(buffer);
    var headerArray = DBusArray(DBusSignature('(yv)'));
    if (this.path != null)
      headerArray.add(_makeHeader(HeaderCode.Path, DBusObjectPath(this.path)));
    if (this.interface != null)
      headerArray
          .add(_makeHeader(HeaderCode.Interface, DBusString(this.interface)));
    if (this.member != null)
      headerArray.add(_makeHeader(HeaderCode.Member, DBusString(this.member)));
    if (this.errorName != null)
      headerArray
          .add(_makeHeader(HeaderCode.ErrorName, DBusString(this.errorName)));
    if (this.replySerial != null)
      headerArray.add(
          _makeHeader(HeaderCode.ReplySerial, DBusUint32(this.replySerial)));
    if (this.destination != null)
      headerArray.add(
          _makeHeader(HeaderCode.Destination, DBusString(this.destination)));
    if (this.sender != null)
      headerArray.add(_makeHeader(HeaderCode.Sender, DBusString(this.sender)));
    if (this.values.length > 0) {
      String signature = '';
      for (var value in values) signature += value.signature.value;
      headerArray
          .add(_makeHeader(HeaderCode.Signature, DBusSignature(signature)));
    }
    headerArray.marshal(buffer);
    buffer.align(8);
    buffer.writeBytes(valueBuffer.data);
  }

  DBusStruct _makeHeader(int code, DBusValue value) {
    return DBusStruct([DBusByte(code), DBusVariant(value)]);
  }

  bool unmarshal(DBusReadBuffer buffer) {
    if (buffer.remaining < 12) return false;

    var endianess = DBusByte(0);
    endianess.unmarshal(buffer);
    var type = DBusByte(0);
    type.unmarshal(buffer);
    this.type = type.value;
    var flags = DBusByte(0);
    flags.unmarshal(buffer);
    this.flags = flags.value;
    var protocolVersion = DBusByte(0);
    protocolVersion.unmarshal(buffer);
    var dataLength = DBusUint32(0);
    dataLength.unmarshal(buffer);
    var serial = DBusUint32(0);
    serial.unmarshal(buffer);
    this.serial = serial.value;
    var headers = DBusArray(DBusSignature('(yv)'));
    if (!headers.unmarshal(buffer)) return false;

    DBusSignature signature;
    for (var child in headers.children) {
      var header = child as DBusStruct;
      var code = (header.children[0] as DBusByte).value;
      var value = (header.children[1] as DBusVariant).value;
      if (code == HeaderCode.Path)
        this.path = (value as DBusObjectPath).value;
      else if (code == HeaderCode.Interface)
        this.interface = (value as DBusString).value;
      else if (code == HeaderCode.Member)
        this.member = (value as DBusString).value;
      else if (code == HeaderCode.ErrorName)
        this.errorName = (value as DBusString).value;
      else if (code == HeaderCode.ReplySerial)
        this.replySerial = (value as DBusUint32).value;
      else if (code == HeaderCode.Destination)
        this.destination = (value as DBusString).value;
      else if (code == HeaderCode.Sender)
        this.sender = (value as DBusString).value;
      else if (code == HeaderCode.Signature) signature = value as DBusSignature;
    }
    if (!buffer.align(8)) return false;

    this.values = List<DBusValue>();
    if (signature != null) {
      var signatures = signature.split();
      for (var s in signatures) {
        var value = DBusValue.fromSignature(s);
        if (!value.unmarshal(buffer)) return false;
        values.add(value);
      }
    }

    return true;
  }

  @override
  String toString() {
    var text = 'DBusMessage(type=';
    if (type == MessageType.MethodCall)
      text += 'MessageType.MethodCall';
    else if (type == MessageType.MethodReturn)
      text += 'MessageType.MethodReturn';
    else if (type == MessageType.Error)
      text += 'MessageType.Error';
    else if (type == MessageType.Signal)
      text += 'MessageType.Signal';
    else
      text += '${type}';
    if (flags != 0) {
      var flagNames = List<String>();
      if (flags & Flags.NoReplyExpected != 0)
        flagNames.add('Flags.NoReplyExpected');
      if (flags & Flags.NoAutoStart != 0) flagNames.add('Flags.NoAutoStart');
      if (flags & Flags.AllowInteractiveAuthorization != 0)
        flagNames.add('Flags.AllowInteractiveAuthorization');
      if (flags & 0xF8 != 0)
        flagNames.add((flags & 0xF8).toRadixString(16).padLeft(2));
      text += ' flags=${flagNames.join('|')}';
    }
    text += ' serial=${serial}';
    if (path != null) text += ", path='${path}'";
    if (interface != null) text += ", interface='${interface}'";
    if (member != null) text += ", member='${member}'";
    if (errorName != null) text += ", errorName='${errorName}'";
    if (replySerial != null) text += ', replySerial=${replySerial}';
    if (destination != null) text += ", destination='${destination}'";
    if (sender != null) text += ", sender='${sender}'";
    if (values.length > 0) {
      var valueText = List<String>();
      for (var value in values) valueText.add(value.toString());
      text += ", values=[${valueText.join(', ')}]";
    }
    text += ')';
    return text;
  }
}
