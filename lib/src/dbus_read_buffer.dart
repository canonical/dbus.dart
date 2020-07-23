import "dart:convert";
import "dart:typed_data";

class DBusReadBuffer {
  var data = List<int>();
  int readOffset = 0;

  int get remaining {
    return data.length - readOffset;
  }

  writeBytes(Iterable<int> value) {
    data.addAll(value);
  }

  int readByte() {
    readOffset++;
    return data[readOffset - 1];
  }

  ByteBuffer readBytes(int length) {
    var bytes = Uint8List(length);
    for (var i = 0; i < length; i++) bytes[i] = readByte();
    return bytes.buffer;
  }

  String readLine() {
    for (var i = readOffset; i < data.length - 1; i++) {
      if (data[i] == 13 /* '\r' */ && data[i + 1] == 10 /* '\n' */) {
        var bytes = List<int>(i - readOffset);
        for (var j = readOffset; j < i; j++) bytes[j] = readByte();
        readOffset = i + 2;
        return utf8.decode(bytes);
      }
    }
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

  bool align(int boundary) {
    while (readOffset % boundary != 0) {
      if (remaining == 0) return false;
      readOffset++;
    }
    return true;
  }

  flush() {
    data.removeRange(0, readOffset);
    readOffset = 0;
  }

  @override
  toString() {
    var s = '';
    for (var d in data) {
      if (d >= 33 && d <= 126)
        s += String.fromCharCode(d);
      else
        s += '\\' + d.toRadixString(8);
    }
    return "DBusReadBuffer('${s}')";
  }
}
