import 'dart:convert';
import 'dart:typed_data';

import 'dbus_buffer.dart';
import 'dbus_value.dart';

class DBusReadBuffer extends DBusBuffer {
  var data = <int>[];
  int readOffset = 0;

  int get remaining {
    return data.length - readOffset;
  }

  void writeBytes(Iterable<int> value) {
    data.addAll(value);
  }

  int readByte() {
    readOffset++;
    return data[readOffset - 1];
  }

  ByteBuffer readBytes(int length) {
    var bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = readByte();
    }
    return bytes.buffer;
  }

  String readLine() {
    for (var i = readOffset; i < data.length - 1; i++) {
      if (data[i] == 13 /* '\r' */ && data[i + 1] == 10 /* '\n' */) {
        var bytes = List<int>(i - readOffset);
        for (var j = readOffset; j < i; j++) {
          bytes[j] = readByte();
        }
        readOffset = i + 2;
        return utf8.decode(bytes);
      }
    }
    return null;
  }

  int readInt16() {
    return ByteData.view(readBytes(2)).getInt16(0, Endian.little);
  }

  int readUint16() {
    return ByteData.view(readBytes(2)).getUint16(0, Endian.little);
  }

  int readInt32() {
    return ByteData.view(readBytes(4)).getInt32(0, Endian.little);
  }

  int readUint32() {
    return ByteData.view(readBytes(4)).getUint32(0, Endian.little);
  }

  int readInt64() {
    return ByteData.view(readBytes(8)).getInt64(0, Endian.little);
  }

  int readUint64() {
    return ByteData.view(readBytes(8)).getUint64(0, Endian.little);
  }

  double readFloat64() {
    return ByteData.view(readBytes(8)).getFloat64(0, Endian.little);
  }

  DBusByte readDBusByte() {
    if (remaining < 1) return null;
    return DBusByte(readByte());
  }

  DBusBoolean readDBusBoolean() {
    if (!align(BOOLEAN_ALIGNMENT)) return null;
    if (remaining < 4) return null;
    return DBusBoolean(readUint32() != 0);
  }

  DBusInt16 readDBusInt16() {
    if (!align(INT16_ALIGNMENT)) return null;
    if (remaining < 2) return null;
    return DBusInt16(readInt16());
  }

  DBusUint16 readDBusUint16() {
    if (!align(UINT16_ALIGNMENT)) return null;
    if (remaining < 2) return null;
    return DBusUint16(readUint16());
  }

  DBusInt32 readDBusInt32() {
    if (!align(INT32_ALIGNMENT)) return null;
    if (remaining < 4) return null;
    return DBusInt32(readInt32());
  }

  DBusUint32 readDBusUint32() {
    if (!align(UINT32_ALIGNMENT)) return null;
    if (remaining < 4) return null;
    return DBusUint32(readUint32());
  }

  DBusInt64 readDBusInt64() {
    if (!align(INT64_ALIGNMENT)) return null;
    if (remaining < 8) return null;
    return DBusInt64(readInt64());
  }

  DBusUint64 readDBusUint64() {
    if (!align(UINT64_ALIGNMENT)) return null;
    if (remaining < 8) return null;
    return DBusUint64(readUint64());
  }

  DBusDouble readDBusDouble() {
    if (!align(DOUBLE_ALIGNMENT)) return null;
    if (remaining < 8) return null;
    return DBusDouble(readFloat64());
  }

  DBusString readDBusString() {
    var length = readDBusUint32();
    if (length == null) return null;
    if (remaining < (length.value + 1)) return null;
    var values = <int>[];
    for (var i = 0; i < length.value; i++) {
      values.add(readByte());
    }
    readByte(); // Trailing nul
    return DBusString(utf8.decode(values));
  }

  DBusObjectPath readDBusObjectPath() {
    var value = readDBusString();
    if (value == null) return null;
    return DBusObjectPath(value.value);
  }

  DBusSignature readDBusSignature() {
    if (remaining < 1) return null;
    var length = readByte();
    var values = <int>[];
    if (remaining < length + 1) return null;
    for (var i = 0; i < length; i++) {
      values.add(readByte());
    }
    readByte(); // Trailing nul
    return DBusSignature(utf8.decode(values));
  }

  DBusVariant readDBusVariant() {
    var signature = readDBusSignature();
    if (signature == null) return null;
    var childValue = readDBusValue(signature);
    if (childValue == null) return null;
    return DBusVariant(childValue);
  }

  DBusStruct readDBusStruct(List<DBusSignature> childSignatures) {
    if (!align(STRUCT_ALIGNMENT)) return null;
    var children = <DBusValue>[];
    for (var signature in childSignatures) {
      var child = readDBusValue(signature);
      if (child == null) return null;
      children.add(child);
    }

    return DBusStruct(children);
  }

  DBusArray readDBusArray(DBusSignature childSignature) {
    var length = readDBusUint32();
    if (length == null) return null;
    // FIXME: Align to first element (not in length)
    var end = readOffset + length.value;
    var children = <DBusValue>[];
    while (readOffset < end) {
      var child = readDBusValue(childSignature);
      if (child == null) return null;
      children.add(child);
    }

    return DBusArray(childSignature, children);
  }

  DBusDict readDBusDict(
      DBusSignature keySignature, DBusSignature valueSignature) {
    var length = readDBusUint32();
    if (length == null) return null;
    // FIXME: Align to first element (not in length)
    var end = readOffset + length.value;
    var childSignatures = <DBusSignature>[];
    childSignatures.add(keySignature);
    childSignatures.add(valueSignature);
    var children = <DBusValue, DBusValue>{};
    while (readOffset < end) {
      var child = readDBusStruct(childSignatures);
      if (child == null) return null;
      children.update(
          child.children.elementAt(0), (e) => child.children.elementAt(1));
    }

    return DBusDict(keySignature, valueSignature, children);
  }

  DBusValue readDBusValue(DBusSignature signature) {
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
    } else if (s.startsWith('a{') && s.endsWith('}')) {
      var childSignature = DBusSignature(s.substring(2, s.length - 1));
      var signatures = childSignature.split(); // FIXME: Check two signatures
      return readDBusDict(signatures[0], signatures[1]);
    } else if (s.startsWith('a')) {
      return readDBusArray(DBusSignature(s.substring(1, s.length)));
    } else if (s.startsWith('(') && s.endsWith(')')) {
      var childSignatures = <DBusSignature>[];
      for (var i = 1; i < s.length - 1; i++) {
        childSignatures.add(DBusSignature(s[i]));
      }
      return readDBusStruct(childSignatures);
    } else {
      throw "Unknown DBus data type '${s}'";
    }
  }

  bool align(int boundary) {
    while (readOffset % boundary != 0) {
      if (remaining == 0) return false;
      readOffset++;
    }
    return true;
  }

  void flush() {
    data.removeRange(0, readOffset);
    readOffset = 0;
  }

  @override
  String toString() {
    var s = '';
    for (var d in data) {
      if (d >= 33 && d <= 126) {
        s += String.fromCharCode(d);
      } else {
        s += '\\' + d.toRadixString(8);
      }
    }
    return "DBusReadBuffer('${s}')";
  }
}
