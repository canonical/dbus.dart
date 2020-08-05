import 'dart:convert';
import 'dart:typed_data';

import 'dbus_buffer.dart';
import 'dbus_value.dart';

class DBusWriteBuffer extends DBusBuffer {
  var data = <int>[];

  void writeByte(int value) {
    data.add(value);
  }

  void writeBytes(Iterable<int> value) {
    data.addAll(value);
  }

  void writeInt16(int value) {
    var bytes = Uint8List(2).buffer;
    ByteData.view(bytes).setInt16(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  void writeUint16(int value) {
    var bytes = Uint8List(2).buffer;
    ByteData.view(bytes).setUint16(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  void writeInt32(int value) {
    var bytes = Uint8List(4).buffer;
    ByteData.view(bytes).setInt32(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  void writeUint32(int value) {
    var bytes = Uint8List(4).buffer;
    ByteData.view(bytes).setUint32(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  void writeInt64(int value) {
    var bytes = Uint8List(8).buffer;
    ByteData.view(bytes).setInt64(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  void writeUint64(int value) {
    var bytes = Uint8List(8).buffer;
    ByteData.view(bytes).setUint64(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  void writeFloat64(double value) {
    var bytes = Uint8List(8).buffer;
    ByteData.view(bytes).setFloat64(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  void setByte(int offset, int value) {
    data[offset] = value;
  }

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

      var children = value.children;
      if (children.isNotEmpty) align(getAlignment(children[0]));
      var startOffset = data.length;
      for (var child in children) {
        writeValue(child);
      }

      // Update the length that was written
      var length = data.length - startOffset;
      setByte(lengthOffset + 0, (length >> 0) & 0xFF);
      setByte(lengthOffset + 1, (length >> 8) & 0xFF);
      setByte(lengthOffset + 2, (length >> 16) & 0xFF);
      setByte(lengthOffset + 3, (length >> 24) & 0xFF);
    } else if (value is DBusDict) {
      // Length will be overwritten later.
      writeValue(DBusUint32(0));
      var lengthOffset = data.length - 4;

      var children = value.children;
      if (children.isNotEmpty) align(getAlignment(children[0]));
      var startOffset = data.length;
      children.forEach((key, value) {
        writeValue(DBusStruct([key, value]));
      });

      // Update the length that was written
      var length = data.length - startOffset;
      setByte(lengthOffset + 0, (length >> 0) & 0xFF);
      setByte(lengthOffset + 1, (length >> 8) & 0xFF);
      setByte(lengthOffset + 2, (length >> 16) & 0xFF);
      setByte(lengthOffset + 3, (length >> 24) & 0xFF);
    }
  }

  int getAlignment(DBusValue value) {
    if (value is DBusByte) {
      return BYTE_ALIGNMENT;
    } else if (value is DBusBoolean) {
      return BOOLEAN_ALIGNMENT;
    } else if (value is DBusInt16) {
      return INT16_ALIGNMENT;
    } else if (value is DBusUint16) {
      return UINT16_ALIGNMENT;
    } else if (value is DBusInt32) {
      return INT32_ALIGNMENT;
    } else if (value is DBusUint32) {
      return UINT32_ALIGNMENT;
    } else if (value is DBusInt64) {
      return INT64_ALIGNMENT;
    } else if (value is DBusUint64) {
      return UINT64_ALIGNMENT;
    } else if (value is DBusDouble) {
      return DOUBLE_ALIGNMENT;
    } else if (value is DBusString) {
      return STRING_ALIGNMENT;
    } else if (value is DBusSignature) {
      return SIGNATURE_ALIGNMENT;
    } else if (value is DBusVariant) {
      return VARIANT_ALIGNMENT;
    } else if (value is DBusStruct) {
      return STRUCT_ALIGNMENT;
    } else if (value is DBusArray) {
      return ARRAY_ALIGNMENT;
    } else if (value is DBusDict) {
      return DICT_ALIGNMENT;
    } else {
      return 0;
    }
  }

  void align(int boundary) {
    while (data.length % boundary != 0) {
      writeByte(0);
    }
  }
}
