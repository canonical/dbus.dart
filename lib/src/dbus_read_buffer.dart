import 'dart:convert';
import 'dart:typed_data';

import 'dbus_buffer.dart';
import 'dbus_message.dart';
import 'dbus_value.dart';

/// Decodes DBus messages from binary data.
class DBusReadBuffer extends DBusBuffer {
  /// Data in the buffer.
  final _data = <int>[];

  /// Read position.
  int readOffset = 0;

  /// Number of bytes remaining in the buffer.
  int get remaining {
    return _data.length - readOffset;
  }

  /// Add bytes to the buffer.
  void writeBytes(Iterable<int> value) {
    _data.addAll(value);
  }

  /// Read a single byte from the buffer.
  int readByte() {
    readOffset++;
    return _data[readOffset - 1];
  }

  /// Reads [length] bytes from the buffer.
  ByteBuffer readBytes(int length) {
    var bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = readByte();
    }
    return bytes.buffer;
  }

  /// Reads a single line of UTF-8 text (terminated with CR LF) from the buffer.
  /// Retutns null if no line available.
  String? readLine() {
    for (var i = readOffset; i < _data.length - 1; i++) {
      if (_data[i] == 13 /* '\r' */ && _data[i + 1] == 10 /* '\n' */) {
        var bytes = List<int>.filled(i - readOffset, 0);
        for (var j = readOffset; j < i; j++) {
          bytes[j] = readByte();
        }
        readOffset = i + 2;
        return utf8.decode(bytes);
      }
    }
    return null;
  }

  /// Reads a D-Bus message from the buffer or returns null if not enough data.
  DBusMessage? readMessage() {
    if (remaining < 12) {
      return null;
    }

    readDBusByte(); // Endianess.
    var type = readDBusByte()!.value;
    var flags = readDBusByte()!.value;
    readDBusByte(); // Protocol version.
    var dataLength = readDBusUint32();
    var serial = readDBusUint32()!.value;
    var headers = readDBusArray(DBusSignature('(yv)'));
    if (headers == null) {
      return null;
    }

    DBusSignature? signature;
    DBusObjectPath? path;
    String? interface;
    String? member;
    String? errorName;
    int? replySerial;
    String? destination;
    String? sender;
    for (var child in headers.children) {
      var header = child as DBusStruct;
      var code = (header.children.elementAt(0) as DBusByte).value;
      var value = (header.children.elementAt(1) as DBusVariant).value;
      if (code == HeaderCode.Path) {
        path = value as DBusObjectPath?;
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
        signature = value as DBusSignature?;
      }
    }
    if (!align(8)) {
      return null;
    }

    if (remaining < dataLength!.value!) {
      return null;
    }

    var values = <DBusValue>[];
    if (signature != null) {
      var signatures = signature.split();
      for (var s in signatures) {
        var value = readDBusValue(s);
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

  /// Reads a 16 bit signed integer from the buffer.
  /// Assumes that there is sufficient data in the buffer.
  int readInt16() {
    return ByteData.view(readBytes(2)).getInt16(0, Endian.little);
  }

  /// Reads a 16 bit unsigned integer from the buffer.
  /// Assumes that there is sufficient data in the buffer.
  int readUint16() {
    return ByteData.view(readBytes(2)).getUint16(0, Endian.little);
  }

  /// Reads a 32 bit signed integer from the buffer.
  /// Assumes that there is sufficient data in the buffer.
  int readInt32() {
    return ByteData.view(readBytes(4)).getInt32(0, Endian.little);
  }

  /// Reads a 32 bit unsigned integer from the buffer.
  /// Assumes that there is sufficient data in the buffer.
  int readUint32() {
    return ByteData.view(readBytes(4)).getUint32(0, Endian.little);
  }

  /// Reads a 64 bit signed integer from the buffer.
  /// Assumes that there is sufficient data in the buffer.
  int readInt64() {
    return ByteData.view(readBytes(8)).getInt64(0, Endian.little);
  }

  /// Reads a 64 bit unsigned integer from the buffer.
  /// Assumes that there is sufficient data in the buffer.
  int readUint64() {
    return ByteData.view(readBytes(8)).getUint64(0, Endian.little);
  }

  /// Reads a 64 bit floating point number from the buffer.
  /// Assumes that there is sufficient data in the buffer.
  double readFloat64() {
    return ByteData.view(readBytes(8)).getFloat64(0, Endian.little);
  }

  /// Reads a [DBusByte] from the buffer or returns null if not enough data.
  DBusByte? readDBusByte() {
    if (remaining < 1) {
      return null;
    }
    return DBusByte(readByte());
  }

  /// Reads a [DBusBoolean] from the buffer or returns null if not enough data.
  DBusBoolean? readDBusBoolean() {
    if (!align(BOOLEAN_ALIGNMENT) || remaining < 4) {
      return null;
    }
    return DBusBoolean(readUint32() != 0);
  }

  /// Reads a [DBusInt16] from the buffer or returns null if not enough data.
  DBusInt16? readDBusInt16() {
    if (!align(INT16_ALIGNMENT) || remaining < 2) {
      return null;
    }
    return DBusInt16(readInt16());
  }

  /// Reads a [DBusUint16] from the buffer or returns null if not enough data.
  DBusUint16? readDBusUint16() {
    if (!align(UINT16_ALIGNMENT) || remaining < 2) {
      return null;
    }
    return DBusUint16(readUint16());
  }

  /// Reads a [DBusInt32] from the buffer or returns null if not enough data.
  DBusInt32? readDBusInt32() {
    if (!align(INT32_ALIGNMENT) || remaining < 4) {
      return null;
    }
    return DBusInt32(readInt32());
  }

  /// Reads a [DBusUint32] from the buffer or returns null if not enough data.
  DBusUint32? readDBusUint32() {
    if (!align(UINT32_ALIGNMENT) || remaining < 4) {
      return null;
    }
    return DBusUint32(readUint32());
  }

  /// Reads a [DBusInt64] from the buffer or returns null if not enough data.
  DBusInt64? readDBusInt64() {
    if (!align(INT64_ALIGNMENT) || remaining < 8) {
      return null;
    }
    return DBusInt64(readInt64());
  }

  /// Reads a [DBusUint64] from the buffer or returns null if not enough data.
  DBusUint64? readDBusUint64() {
    if (!align(UINT64_ALIGNMENT) || remaining < 8) {
      return null;
    }
    return DBusUint64(readUint64());
  }

  /// Reads a [DBusDouble] from the buffer or returns null if not enough data.
  DBusDouble? readDBusDouble() {
    if (!align(DOUBLE_ALIGNMENT) || remaining < 8) {
      return null;
    }
    return DBusDouble(readFloat64());
  }

  /// Reads a [DBusString] from the buffer or returns null if not enough data.
  DBusString? readDBusString() {
    var length = readDBusUint32();
    if (length == null || remaining < (length.value! + 1)) {
      return null;
    }

    var values = <int>[];
    for (var i = 0; i < length.value!; i++) {
      values.add(readByte());
    }
    readByte(); // Trailing nul.

    return DBusString(utf8.decode(values));
  }

  /// Reads a [DBusObjectPath] from the buffer or returns null if not enough data.
  DBusObjectPath? readDBusObjectPath() {
    var value = readDBusString();
    if (value == null) {
      return null;
    }
    return DBusObjectPath(value.value);
  }

  /// Reads a [DBusSignature] from the buffer or returns null if not enough data.
  DBusSignature? readDBusSignature() {
    if (remaining < 1) {
      return null;
    }
    var length = readByte();
    if (remaining < length + 1) {
      return null;
    }

    var values = <int>[];
    for (var i = 0; i < length; i++) {
      values.add(readByte());
    }
    readByte(); // Trailing nul

    return DBusSignature(utf8.decode(values));
  }

  /// Reads a [DBusVariant] from the buffer or returns null if not enough data.
  DBusVariant? readDBusVariant() {
    var signature = readDBusSignature();
    if (signature == null) {
      return null;
    }

    var childValue = readDBusValue(signature);
    if (childValue == null) {
      return null;
    }

    return DBusVariant(childValue);
  }

  /// Reads a [DBusStruct] from the buffer or returns null if not enough data.
  DBusStruct? readDBusStruct(List<DBusSignature> childSignatures) {
    if (!align(STRUCT_ALIGNMENT)) {
      return null;
    }

    var children = <DBusValue>[];
    for (var signature in childSignatures) {
      var child = readDBusValue(signature);
      if (child == null) {
        return null;
      }
      children.add(child);
    }

    return DBusStruct(children);
  }

  /// Reads a [DBusArray] from the buffer or returns null if not enough data.
  DBusArray? readDBusArray(DBusSignature childSignature) {
    var length = readDBusUint32();
    if (length == null || !align(getAlignment(childSignature))) {
      return null;
    }

    var end = readOffset + length.value!;
    var children = <DBusValue>[];
    while (readOffset < end) {
      var child = readDBusValue(childSignature);
      if (child == null) {
        return null;
      }
      children.add(child);
    }

    return DBusArray(childSignature, children);
  }

  DBusDict? readDBusDict(
      DBusSignature keySignature, DBusSignature valueSignature) {
    var length = readDBusUint32();
    if (length == null || !align(DICT_ENTRY_ALIGNMENT)) {
      return null;
    }

    var end = readOffset + length.value!;
    var childSignatures = [keySignature, valueSignature];
    var children = <DBusValue, DBusValue>{};
    while (readOffset < end) {
      var child = readDBusStruct(childSignatures);
      if (child == null) {
        return null;
      }
      var key = child.children.elementAt(0);
      var value = child.children.elementAt(1);
      children[key] = value;
    }

    return DBusDict(keySignature, valueSignature, children);
  }

  /// Reads a [DBusValue] with [signature].
  DBusValue? readDBusValue(DBusSignature signature) {
    var s = signature.value;
    if (s == 'y') {
      return readDBusByte();
    } else if (s == 'b') {
      return readDBusBoolean();
    } else if (s == 'n') {
      return readDBusInt16();
    } else if (s == 'q') {
      return readDBusUint16();
    } else if (s == 'i') {
      return readDBusInt32();
    } else if (s == 'u') {
      return readDBusUint32();
    } else if (s == 'x') {
      return readDBusInt64();
    } else if (s == 't') {
      return readDBusUint64();
    } else if (s == 'd') {
      return readDBusDouble();
    } else if (s == 's') {
      return readDBusString();
    } else if (s == 'o') {
      return readDBusObjectPath();
    } else if (s == 'g') {
      return readDBusSignature();
    } else if (s == 'v') {
      return readDBusVariant();
    } else if (s!.startsWith('a{') && s.endsWith('}')) {
      var childSignature = DBusSignature(s.substring(2, s.length - 1));
      var signatures = childSignature.split(); // FIXME: Check two signatures
      return readDBusDict(signatures[0], signatures[1]);
    } else if (s.startsWith('a')) {
      return readDBusArray(DBusSignature(s.substring(1, s.length)));
    } else if (s.startsWith('(') && s.endsWith(')')) {
      return readDBusStruct(
          DBusSignature(s.substring(1, s.length - 1)).split());
    } else {
      throw "Unknown DBus data type '${s}'";
    }
  }

  /// Skips data from the buffer to align to [boundary].
  bool align(int boundary) {
    while (readOffset % boundary != 0) {
      if (remaining == 0) {
        return false;
      }
      readOffset++;
    }
    return true;
  }

  /// Removes all buffered data.
  void flush() {
    _data.removeRange(0, readOffset);
    readOffset = 0;
  }

  @override
  String toString() {
    var s = '';
    for (var d in _data) {
      if (d >= 33 && d <= 126) {
        s += String.fromCharCode(d);
      } else {
        s += '\\' + d.toRadixString(8);
      }
    }
    return "DBusReadBuffer('${s}')";
  }
}
