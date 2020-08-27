import 'dart:convert';
import 'dart:typed_data';

import 'dbus_buffer.dart';
import 'dbus_message.dart';
import 'dbus_value.dart';

/// Encodes DBus messages to binary data.
class DBusWriteBuffer extends DBusBuffer {
  /// Data generated.
  var data = <int>[];

  /// Writes a [DBusMessage] to the buffer.
  void writeMessage(DBusMessage message) {
    var valueBuffer = DBusWriteBuffer();
    for (var value in message.values) {
      valueBuffer.writeValue(value);
    }

    // FIXME(robert-ancell): Handle endianess - currently hard-coded to little
    writeValue(DBusByte(Endianess.Little));
    writeValue(DBusByte(message.type));
    writeValue(DBusByte(message.flags));
    writeValue(DBusByte(ProtocolVersion));
    writeValue(DBusUint32(valueBuffer.data.length));
    writeValue(DBusUint32(message.serial));
    var headers = <DBusValue>[];
    if (message.path != null) {
      headers.add(_makeHeader(HeaderCode.Path, message.path));
    }
    if (message.interface != null) {
      headers.add(
          _makeHeader(HeaderCode.Interface, DBusString(message.interface)));
    }
    if (message.member != null) {
      headers.add(_makeHeader(HeaderCode.Member, DBusString(message.member)));
    }
    if (message.errorName != null) {
      headers.add(
          _makeHeader(HeaderCode.ErrorName, DBusString(message.errorName)));
    }
    if (message.replySerial != null) {
      headers.add(
          _makeHeader(HeaderCode.ReplySerial, DBusUint32(message.replySerial)));
    }
    if (message.destination != null) {
      headers.add(
          _makeHeader(HeaderCode.Destination, DBusString(message.destination)));
    }
    if (message.sender != null) {
      headers.add(_makeHeader(HeaderCode.Sender, DBusString(message.sender)));
    }
    if (message.values.isNotEmpty) {
      var signature = '';
      for (var value in message.values) {
        signature += value.signature.value;
      }
      headers.add(_makeHeader(HeaderCode.Signature, DBusSignature(signature)));
    }
    writeValue(DBusArray(DBusSignature('(yv)'), headers));
    align(8);
    writeBytes(valueBuffer.data);
  }

  /// Makes a new message header.
  DBusStruct _makeHeader(int code, DBusValue value) {
    return DBusStruct([DBusByte(code), DBusVariant(value)]);
  }

  /// Writes a single byte to the buffer.
  void writeByte(int value) {
    data.add(value);
  }

  /// Writes multiple bytes to the buffer.
  void writeBytes(Iterable<int> value) {
    data.addAll(value);
  }

  /// Writes a 16 bit signed integer to the buffer.
  void writeInt16(int value) {
    var bytes = Uint8List(2).buffer;
    ByteData.view(bytes).setInt16(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  /// Writes a 16 bit unsigned integer to the buffer.
  void writeUint16(int value) {
    var bytes = Uint8List(2).buffer;
    ByteData.view(bytes).setUint16(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  /// Writes a 32 bit signed integer to the buffer.
  void writeInt32(int value) {
    var bytes = Uint8List(4).buffer;
    ByteData.view(bytes).setInt32(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  /// Writes a 32 bit unsigned integer to the buffer.
  void writeUint32(int value) {
    var bytes = Uint8List(4).buffer;
    ByteData.view(bytes).setUint32(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  /// Writes a 64 bit signed integer to the buffer.
  void writeInt64(int value) {
    var bytes = Uint8List(8).buffer;
    ByteData.view(bytes).setInt64(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  /// Writes a 64 bit unsigned integer to the buffer.
  void writeUint64(int value) {
    var bytes = Uint8List(8).buffer;
    ByteData.view(bytes).setUint64(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  /// Writes a 64 bit floating point number to the buffer.
  void writeFloat64(double value) {
    var bytes = Uint8List(8).buffer;
    ByteData.view(bytes).setFloat64(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  /// Writes a [DBusValue] to the buffer.
  void writeValue(DBusValue value) {
    if (value is DBusByte) {
      writeByte(value.value);
    } else if (value is DBusBoolean) {
      align(BOOLEAN_ALIGNMENT);
      writeUint32(value.value ? 1 : 0);
    } else if (value is DBusInt16) {
      align(INT16_ALIGNMENT);
      writeInt16(value.value);
    } else if (value is DBusUint16) {
      align(UINT16_ALIGNMENT);
      writeUint16(value.value);
    } else if (value is DBusInt32) {
      align(INT32_ALIGNMENT);
      writeInt32(value.value);
    } else if (value is DBusUint32) {
      align(UINT32_ALIGNMENT);
      writeUint32(value.value);
    } else if (value is DBusInt64) {
      align(INT64_ALIGNMENT);
      writeInt64(value.value);
    } else if (value is DBusUint64) {
      align(UINT64_ALIGNMENT);
      writeUint64(value.value);
    } else if (value is DBusDouble) {
      align(DOUBLE_ALIGNMENT);
      writeFloat64(value.value);
    } else if (value is DBusString) {
      var data = utf8.encode(value.value);
      writeValue(DBusUint32(data.length));
      for (var d in data) {
        writeByte(d);
      }
      writeByte(0); // Terminating nul.
    } else if (value is DBusSignature) {
      var data = utf8.encode(value.value);
      writeByte(data.length);
      for (var d in data) {
        writeByte(d);
      }
      writeByte(0);
    } else if (value is DBusVariant) {
      var childValue = value.value;
      writeValue(childValue.signature);
      writeValue(childValue);
    } else if (value is DBusStruct) {
      align(STRUCT_ALIGNMENT);
      var children = value.children;
      for (var child in children) {
        writeValue(child);
      }
    } else if (value is DBusArray) {
      // Length will be overwritten later.
      writeValue(DBusUint32(0));
      var lengthOffset = data.length - 4;

      align(getAlignment(value.childSignature));
      var startOffset = data.length;
      for (var child in value.children) {
        writeValue(child);
      }

      // Update the length that was written
      var length = data.length - startOffset;
      data[lengthOffset + 0] = (length >> 0) & 0xFF;
      data[lengthOffset + 1] = (length >> 8) & 0xFF;
      data[lengthOffset + 2] = (length >> 16) & 0xFF;
      data[lengthOffset + 3] = (length >> 24) & 0xFF;
    } else if (value is DBusDict) {
      // Length will be overwritten later.
      writeValue(DBusUint32(0));
      var lengthOffset = data.length - 4;

      align(DICT_ENTRY_ALIGNMENT);
      var startOffset = data.length;
      value.children.forEach((key, value) {
        writeValue(DBusStruct([key, value]));
      });

      // Update the length that was written
      var length = data.length - startOffset;
      data[lengthOffset + 0] = (length >> 0) & 0xFF;
      data[lengthOffset + 1] = (length >> 8) & 0xFF;
      data[lengthOffset + 2] = (length >> 16) & 0xFF;
      data[lengthOffset + 3] = (length >> 24) & 0xFF;
    }
  }

  /// Writes padding bytes to align to [boundary].
  void align(int boundary) {
    while (data.length % boundary != 0) {
      writeByte(0);
    }
  }
}
