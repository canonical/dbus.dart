import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'dbus_buffer.dart';
import 'dbus_bus_name.dart';
import 'dbus_error_name.dart';
import 'dbus_interface_name.dart';
import 'dbus_member_name.dart';
import 'dbus_message.dart';
import 'dbus_value.dart';

/// Decodes DBus messages from binary data.
class DBusReadBuffer extends DBusBuffer {
  /// Data in the buffer.
  var _data = Uint8List(0);

  /// Unix file descriptors available.
  final _resourceHandles = <ResourceHandle>[];

  /// View of the buffer to allow accessing fixed width integers and floats.
  late ByteData _view;

  /// Read position.
  int readOffset = 0;

  /// Number of bytes remaining in the buffer.
  int get remaining {
    return _data.length - readOffset;
  }

  /// Add bytes to the buffer.
  void writeBytes(Uint8List value) {
    var builder = BytesBuilder(copy: false);
    builder.add(_data);
    builder.add(value);
    _data = builder.takeBytes();
    _view = ByteData.view(_data.buffer);
  }

  /// Add received resource handles (file descriptors).
  void addResourceHandles(List<ResourceHandle> handles) {
    _resourceHandles.addAll(handles);
  }

  /// Read a single byte from the buffer.
  int _readByte() {
    readOffset++;
    return _data[readOffset - 1];
  }

  /// Reads a single line of UTF-8 text (terminated with CR LF) from the buffer.
  /// Returns null if no line available.
  String? readLine() {
    for (var i = readOffset; i < _data.length - 1; i++) {
      if (_data[i] == 13 /* '\r' */ && _data[i + 1] == 10 /* '\n' */) {
        var bytes = _data.getRange(readOffset, i);
        readOffset = i + 2;
        return utf8.decode(bytes.toList());
      }
    }
    return null;
  }

  /// Reads a D-Bus message from the buffer or returns null if not enough data.
  DBusMessage? readMessage() {
    if (remaining < 12) {
      return null;
    }

    var endian = {108: Endian.little, 66: Endian.big}[readDBusByte()!.value];
    if (endian == null) {
      throw 'Invalid endian value received';
    }
    var type = {
      1: DBusMessageType.methodCall,
      2: DBusMessageType.methodReturn,
      3: DBusMessageType.error,
      4: DBusMessageType.signal
    }[readDBusByte()!.value];
    if (type == null) {
      throw 'Invalid type received';
    }
    var flags = <DBusMessageFlag>{};
    var flagsValue = readDBusByte()!.value;
    if (flagsValue & 0x01 != 0) {
      flags.add(DBusMessageFlag.noReplyExpected);
    }
    if (flagsValue & 0x02 != 0) {
      flags.add(DBusMessageFlag.noAutoStart);
    }
    if (flagsValue & 0x04 != 0) {
      flags.add(DBusMessageFlag.allowInteractiveAuthorization);
    }
    var protocolVersion = readDBusByte()!.value;
    if (protocolVersion != 1) {
      throw 'Unsupported protocol version';
    }
    var dataLength = readDBusUint32(endian)!.value;
    var serial = readDBusUint32(endian)!.value;
    var headers = readDBusArray(DBusSignature('(yv)'), endian);
    if (headers == null) {
      return null;
    }

    DBusSignature? signature;
    DBusObjectPath? path;
    DBusInterfaceName? interface;
    DBusMemberName? member;
    DBusErrorName? errorName;
    int? replySerial;
    DBusBusName? destination;
    DBusBusName? sender;
    var fdCount = 0;
    for (var child in headers.children) {
      var header = child.asStruct();
      var code = header.elementAt(0).asByte();
      var value = header.elementAt(1).asVariant();
      if (code == 1) {
        if (value.signature != DBusSignature('o')) {
          throw 'Invalid message path header of type ${value.signature}';
        }
        path = value.asObjectPath();
      } else if (code == 2) {
        if (value.signature != DBusSignature('s')) {
          throw 'Invalid message interface header of type ${value.signature}';
        }
        interface = DBusInterfaceName(value.asString());
      } else if (code == 3) {
        if (value.signature != DBusSignature('s')) {
          throw 'Invalid message member name header of type ${value.signature}';
        }
        member = DBusMemberName(value.asString());
      } else if (code == 4) {
        if (value.signature != DBusSignature('s')) {
          throw 'Invalid message error name header of type ${value.signature}';
        }
        errorName = DBusErrorName(value.asString());
      } else if (code == 5) {
        if (value.signature != DBusSignature('u')) {
          throw 'Invalid message reply serial header of type ${value.signature}';
        }
        replySerial = value.asUint32();
      } else if (code == 6) {
        if (value.signature != DBusSignature('s')) {
          throw 'Invalid message destination header of type ${value.signature}';
        }
        destination = DBusBusName(value.asString());
      } else if (code == 7) {
        if (value.signature != DBusSignature('s')) {
          throw 'Invalid message sender header of type ${value.signature}';
        }
        sender = DBusBusName(value.asString());
        if (!(sender.value == 'org.freedesktop.DBus' || sender.isUnique)) {
          throw 'Sender contains non-unique bus name';
        }
      } else if (code == 8) {
        if (value.signature != DBusSignature('g')) {
          throw 'Invalid message signature of type ${value.signature}';
        }
        signature = value.asSignature();
      } else if (code == 9) {
        fdCount = value.asUint32();
      }
    }
    if (!align(8)) {
      return null;
    }

    if (remaining < dataLength) {
      return null;
    }

    var dataEnd = readOffset + dataLength;
    var values = <DBusValue>[];
    if (signature != null) {
      var signatures = signature.split();
      for (var s in signatures) {
        var value = readDBusValue(s, endian, fdCount);
        if (value == null) {
          return null;
        }
        if (readOffset > dataEnd) {
          throw 'Message data of size $dataLength too small to contain ${signature.value}';
        }
        values.add(value);
      }
      if (readOffset != dataEnd) {
        throw 'Message data of size $dataLength too large to contain ${signature.value}';
      }
    } else {
      if (dataLength != 0) {
        throw 'Message has no signature but contains data of length $dataLength';
      }
    }

    // Remove file descriptors that were part of this message.
    // Note: This could remove descriptors added after the end of the message.
    if (_resourceHandles.length < fdCount) {
      throw 'Insufficient file descriptors received';
    }
    _resourceHandles.removeRange(0, fdCount);

    return DBusMessage(type,
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
  int readInt16([Endian endian = Endian.little]) {
    var value = _view.getInt16(readOffset, endian);
    readOffset += 2;
    return value;
  }

  /// Reads a 16 bit unsigned integer from the buffer.
  /// Assumes that there is sufficient data in the buffer.
  int readUint16([Endian endian = Endian.little]) {
    var value = _view.getUint16(readOffset, endian);
    readOffset += 2;
    return value;
  }

  /// Reads a 32 bit signed integer from the buffer.
  /// Assumes that there is sufficient data in the buffer.
  int readInt32([Endian endian = Endian.little]) {
    var value = _view.getInt32(readOffset, endian);
    readOffset += 4;
    return value;
  }

  /// Reads a 32 bit unsigned integer from the buffer.
  /// Assumes that there is sufficient data in the buffer.
  int readUint32([Endian endian = Endian.little]) {
    var value = _view.getUint32(readOffset, endian);
    readOffset += 4;
    return value;
  }

  /// Reads a 64 bit signed integer from the buffer.
  /// Assumes that there is sufficient data in the buffer.
  int readInt64([Endian endian = Endian.little]) {
    var value = _view.getInt64(readOffset, endian);
    readOffset += 8;
    return value;
  }

  /// Reads a 64 bit unsigned integer from the buffer.
  /// Assumes that there is sufficient data in the buffer.
  int readUint64([Endian endian = Endian.little]) {
    var value = _view.getUint64(readOffset, endian);
    readOffset += 8;
    return value;
  }

  /// Reads a 64 bit floating point number from the buffer.
  /// Assumes that there is sufficient data in the buffer.
  double readFloat64([Endian endian = Endian.little]) {
    var value = _view.getFloat64(readOffset, endian);
    readOffset += 8;
    return value;
  }

  /// Reads a [DBusByte] from the buffer or returns null if not enough data.
  DBusByte? readDBusByte() {
    if (remaining < 1) {
      return null;
    }
    return DBusByte(_readByte());
  }

  /// Reads a [DBusBoolean] from the buffer or returns null if not enough data.
  DBusBoolean? readDBusBoolean([Endian endian = Endian.little]) {
    if (!align(booleanAlignment) || remaining < 4) {
      return null;
    }
    return DBusBoolean(readUint32(endian) != 0);
  }

  /// Reads a [DBusInt16] from the buffer or returns null if not enough data.
  DBusInt16? readDBusInt16([Endian endian = Endian.little]) {
    if (!align(int16Alignment) || remaining < 2) {
      return null;
    }
    return DBusInt16(readInt16(endian));
  }

  /// Reads a [DBusUint16] from the buffer or returns null if not enough data.
  DBusUint16? readDBusUint16([Endian endian = Endian.little]) {
    if (!align(uint16Alignment) || remaining < 2) {
      return null;
    }
    return DBusUint16(readUint16(endian));
  }

  /// Reads a [DBusInt32] from the buffer or returns null if not enough data.
  DBusInt32? readDBusInt32([Endian endian = Endian.little]) {
    if (!align(int32Alignment) || remaining < 4) {
      return null;
    }
    return DBusInt32(readInt32(endian));
  }

  /// Reads a [DBusUint32] from the buffer or returns null if not enough data.
  DBusUint32? readDBusUint32([Endian endian = Endian.little]) {
    if (!align(uint32Alignment) || remaining < 4) {
      return null;
    }
    return DBusUint32(readUint32(endian));
  }

  /// Reads a [DBusInt64] from the buffer or returns null if not enough data.
  DBusInt64? readDBusInt64([Endian endian = Endian.little]) {
    if (!align(int64Alignment) || remaining < 8) {
      return null;
    }
    return DBusInt64(readInt64(endian));
  }

  /// Reads a [DBusUint64] from the buffer or returns null if not enough data.
  DBusUint64? readDBusUint64([Endian endian = Endian.little]) {
    if (!align(uint64Alignment) || remaining < 8) {
      return null;
    }
    return DBusUint64(readUint64(endian));
  }

  /// Reads a [DBusDouble] from the buffer or returns null if not enough data.
  DBusDouble? readDBusDouble([Endian endian = Endian.little]) {
    if (!align(doubleAlignment) || remaining < 8) {
      return null;
    }
    return DBusDouble(readFloat64(endian));
  }

  /// Reads a [DBusString] from the buffer or returns null if not enough data.
  DBusString? readDBusString([Endian endian = Endian.little]) {
    var length = readDBusUint32(endian);
    if (length == null || remaining < (length.value + 1)) {
      return null;
    }

    var values = _data.getRange(readOffset, readOffset + length.value);
    readOffset += length.value;
    if (_readByte() != 0) {
      throw 'String missing trailing nul';
    }

    return DBusString(utf8.decode(values.toList()));
  }

  /// Reads a [DBusObjectPath] from the buffer or returns null if not enough data.
  DBusObjectPath? readDBusObjectPath([Endian endian = Endian.little]) {
    var value = readDBusString(endian);
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
    var length = _readByte();
    if (remaining < length + 1) {
      return null;
    }

    var values = _data.getRange(readOffset, readOffset + length);
    readOffset += length;
    if (_readByte() != 0) {
      throw 'Signature missing trailing nul';
    }

    var signatureText = utf8.decode(values.toList());
    if (signatureText.contains('m')) {
      throw 'Signature contains reserved maybe type';
    }
    return DBusSignature(signatureText);
  }

  /// Reads a [DBusVariant] from the buffer or returns null if not enough data.
  DBusVariant? readDBusVariant(
      [Endian endian = Endian.little, int fdCount = 0]) {
    var signature = readDBusSignature();
    if (signature == null) {
      return null;
    }

    var childValue = readDBusValue(signature, endian, fdCount);
    if (childValue == null) {
      return null;
    }

    return DBusVariant(childValue);
  }

  /// Reads a [DBusUnixFd] from the buffer or returns null if not enough data.
  DBusUnixFd? readDBusUnixFd(int fdCount, [Endian endian = Endian.little]) {
    var index = readDBusUint32(endian)?.value;
    if (index == null) {
      return null;
    }
    if (index > fdCount) {
      throw 'Unix fd index out of bounds';
    }
    if (index > _resourceHandles.length) {
      throw 'Unix fd $index not yet received';
    }
    return DBusUnixFd(_resourceHandles[index]);
  }

  /// Reads a [DBusStruct] from the buffer or returns null if not enough data.
  DBusStruct? readDBusStruct(Iterable<DBusSignature> childSignatures,
      [Endian endian = Endian.little, int fdCount = 0]) {
    if (!align(structAlignment)) {
      return null;
    }

    var children = <DBusValue>[];
    for (var signature in childSignatures) {
      var child = readDBusValue(signature, endian, fdCount);
      if (child == null) {
        return null;
      }
      children.add(child);
    }

    return DBusStruct(children);
  }

  /// Reads a [DBusArray] from the buffer or returns null if not enough data.
  DBusArray? readDBusArray(DBusSignature childSignature,
      [Endian endian = Endian.little, int fdCount = 0]) {
    var length = readDBusUint32(endian);
    if (length == null || !align(getAlignment(childSignature))) {
      return null;
    }

    var end = readOffset + length.value;
    var children = <DBusValue>[];
    while (readOffset < end) {
      var child = readDBusValue(childSignature, endian, fdCount);
      if (child == null) {
        return null;
      }
      children.add(child);
    }

    return DBusArray(childSignature, children);
  }

  DBusDict? readDBusDict(
      DBusSignature keySignature, DBusSignature valueSignature,
      [Endian endian = Endian.little, int fdCount = 0]) {
    var length = readDBusUint32(endian);
    if (length == null || !align(dictEntryAlignment)) {
      return null;
    }

    var end = readOffset + length.value;
    var childSignatures = [keySignature, valueSignature];
    var children = <DBusValue, DBusValue>{};
    while (readOffset < end) {
      var child = readDBusStruct(childSignatures, endian, fdCount);
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
  DBusValue? readDBusValue(DBusSignature signature,
      [Endian endian = Endian.little, int fdCount = 0]) {
    var s = signature.value;
    if (s == 'y') {
      return readDBusByte();
    } else if (s == 'b') {
      return readDBusBoolean(endian);
    } else if (s == 'n') {
      return readDBusInt16(endian);
    } else if (s == 'q') {
      return readDBusUint16(endian);
    } else if (s == 'i') {
      return readDBusInt32(endian);
    } else if (s == 'u') {
      return readDBusUint32(endian);
    } else if (s == 'x') {
      return readDBusInt64(endian);
    } else if (s == 't') {
      return readDBusUint64(endian);
    } else if (s == 'd') {
      return readDBusDouble(endian);
    } else if (s == 's') {
      return readDBusString(endian);
    } else if (s == 'o') {
      return readDBusObjectPath(endian);
    } else if (s == 'g') {
      return readDBusSignature();
    } else if (s == 'v') {
      return readDBusVariant(endian, fdCount);
    } else if (s == 'm') {
      throw 'D-Bus reserved maybe type not valid';
    } else if (s == 'h') {
      return readDBusUnixFd(fdCount, endian);
    } else if (s.startsWith('a{') && s.endsWith('}')) {
      var childSignature = DBusSignature(s.substring(2, s.length - 1));
      var signatures = childSignature.split();
      if (signatures.length != 2) {
        throw 'Invalid dict signature ${childSignature.value}';
      }
      var keySignature = signatures[0];
      var valueSignature = signatures[1];
      if (!keySignature.isBasic) {
        throw 'Invalid dict key signature ${keySignature.value}';
      }
      return readDBusDict(keySignature, valueSignature, endian, fdCount);
    } else if (s.startsWith('a')) {
      return readDBusArray(
          DBusSignature(s.substring(1, s.length)), endian, fdCount);
    } else if (s.startsWith('(') && s.endsWith(')')) {
      return readDBusStruct(
          DBusSignature(s.substring(1, s.length - 1)).split(), endian, fdCount);
    } else {
      throw "Unknown D-Bus data type '$s'";
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
    _data = _data.sublist(readOffset);
    _view = ByteData.view(_data.buffer);
    readOffset = 0;
  }

  @override
  String toString() {
    var s = '';
    for (var d in _data) {
      if (d >= 33 && d <= 126) {
        s += String.fromCharCode(d);
      } else {
        s += '\\${d.toRadixString(8)}';
      }
    }
    return "$runtimeType('$s')";
  }
}
