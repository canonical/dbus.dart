import "dart:typed_data";

class DBusWriteBuffer {
  var data = List<int>();

  writeByte(int value) {
    data.add(value);
  }

  writeBytes(Iterable<int> value) {
    data.addAll(value);
  }

  writeInt16(int value) {
    var bytes = Uint8List(2).buffer;
    ByteData.view(bytes).setInt16(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  writeUint16(int value) {
    var bytes = Uint8List(2).buffer;
    ByteData.view(bytes).setUint16(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  writeInt32(int value) {
    var bytes = Uint8List(4).buffer;
    ByteData.view(bytes).setInt32(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  writeUint32(int value) {
    var bytes = Uint8List(4).buffer;
    ByteData.view(bytes).setUint32(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  writeInt64(int value) {
    var bytes = Uint8List(8).buffer;
    ByteData.view(bytes).setInt64(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  writeUint64(int value) {
    var bytes = Uint8List(8).buffer;
    ByteData.view(bytes).setUint64(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  writeFloat64(double value) {
    var bytes = Uint8List(8).buffer;
    ByteData.view(bytes).setFloat64(0, value, Endian.little);
    writeBytes(bytes.asUint8List());
  }

  setByte(int offset, int value) {
    data[offset] = value;
  }

  align(int boundary) {
    while (data.length % boundary != 0) writeByte(0);
  }
}
