import "dart:convert";

import "dbus_read_buffer.dart";
import "dbus_write_buffer.dart";

/// Base class for D-Bus values.
abstract class DBusValue {
  /// Creates a new D-Bus value from the given [signature].
  static DBusValue fromSignature(DBusSignature signature) {
    var s = signature.value;
    if (s == 'y') {
      return DBusByte(0);
    } else if (s == 'b') {
      return DBusBoolean(false);
    } else if (s == 'n') {
      return DBusInt16(0);
    } else if (s == 'q') {
      return DBusUint16(0);
    } else if (s == 'i') {
      return DBusInt32(0);
    } else if (s == 'u') {
      return DBusUint32(0);
    } else if (s == 'x') {
      return DBusInt64(0);
    } else if (s == 't') {
      return DBusUint64(0);
    } else if (s == 'd') {
      return DBusDouble(0);
    } else if (s == 's') {
      return DBusString('');
    } else if (s == 'o') {
      return DBusObjectPath('');
    } else if (s == 'g') {
      return DBusSignature('');
    } else if (s == 'v') {
      return DBusVariant(null);
    } else if (s.startsWith('a{') && s.endsWith('}')) {
      var childSignature = DBusSignature(s.substring(2, s.length - 1));
      var signatures = childSignature.split(); // FIXME: Check two signatures
      return DBusDict(signatures[0], signatures[1]);
    } else if (s.startsWith('a')) {
      return DBusArray(DBusSignature(s.substring(1, s.length)));
    } else if (s.startsWith('(') && s.endsWith(')')) {
      var children = List<DBusValue>();
      for (var i = 1; i < s.length - 1; i++) {
        children.add(DBusValue.fromSignature(DBusSignature(s[i])));
      }
      return DBusStruct(children);
    } else {
      throw "Unknown DBus data type '${s}'";
    }
  }

  DBusSignature signature;
  int alignment;

  marshal(DBusWriteBuffer buffer) {}

  bool unmarshal(DBusReadBuffer buffer) {
    return false;
  }
}

/// D-Bus representation of an unsigned 8 bit value.
class DBusByte extends DBusValue {
  /// A integer in the range [0, 255]
  int value;

  static final _signature = DBusSignature('y');

  /// Creates a new byte with the given [value].
  DBusByte(this.value);

  @override
  DBusSignature get signature {
    return _signature;
  }

  @override
  int get alignment {
    return 1;
  }

  @override
  marshal(DBusWriteBuffer buffer) {
    buffer.writeByte(this.value);
  }

  @override
  bool unmarshal(DBusReadBuffer buffer) {
    if (buffer.remaining < 1) return false;
    value = buffer.readByte();
    return true;
  }

  @override
  String toString() {
    return 'DBusByte(${value})';
  }
}

/// D-Bus representation of a boolean value.
class DBusBoolean extends DBusValue {
  /// A boolean value.
  bool value;

  static final _signature = DBusSignature('b');

  /// Creates a new boolean with the given [value].
  DBusBoolean(this.value);

  @override
  DBusSignature get signature {
    return _signature;
  }

  @override
  int get alignment {
    return 4;
  }

  @override
  marshal(DBusWriteBuffer buffer) {
    buffer.align(this.alignment);
    buffer.writeUint32(value ? 1 : 0);
  }

  @override
  bool unmarshal(DBusReadBuffer buffer) {
    if (!buffer.align(this.alignment)) return false;
    if (buffer.remaining < 4) return false;
    value = buffer.readUint32() != 0;
    return true;
  }

  @override
  String toString() {
    return 'DBusBoolean(${value})';
  }
}

/// D-Bus representation of a signed 16 bit integer.
class DBusInt16 extends DBusValue {
  /// An integer in the range [-32768, 32767]
  int value;

  static final _signature = DBusSignature('n');

  /// Creates a new signed 16 bit integer with the given [value].
  DBusInt16(this.value);

  @override
  DBusSignature get signature {
    return _signature;
  }

  @override
  int get alignment {
    return 2;
  }

  @override
  marshal(DBusWriteBuffer buffer) {
    buffer.align(this.alignment);
    buffer.writeInt16(value);
  }

  @override
  bool unmarshal(DBusReadBuffer buffer) {
    if (!buffer.align(this.alignment)) return false;
    if (buffer.remaining < 2) return false;
    value = buffer.readInt16();
    return true;
  }

  @override
  String toString() {
    return 'DBusInt16(${value})';
  }
}

/// D-Bus representation of an unsigned 16 bit integer.
class DBusUint16 extends DBusValue {
  /// An integer in the range [0, 65535]
  int value;

  static final _signature = DBusSignature('q');

  /// Creates a new unsigned 16 bit integer with the given [value].
  DBusUint16(this.value);

  @override
  DBusSignature get signature {
    return _signature;
  }

  @override
  int get alignment {
    return 2;
  }

  @override
  marshal(DBusWriteBuffer buffer) {
    buffer.align(this.alignment);
    buffer.writeUint16(value);
  }

  @override
  bool unmarshal(DBusReadBuffer buffer) {
    if (!buffer.align(this.alignment)) return false;
    if (buffer.remaining < 2) return false;
    value = buffer.readUint16();
    return true;
  }

  @override
  String toString() {
    return 'DBusUint16(${value})';
  }
}

/// D-Bus representation of a signed 32 bit integer.
class DBusInt32 extends DBusValue {
  /// An integer in the range [-2147483648, 2147483647]
  int value;

  static final _signature = DBusSignature('i');

  /// Creates a new signed 32 bit integer with the given [value].
  DBusInt32(this.value);

  @override
  DBusSignature get signature {
    return _signature;
  }

  @override
  int get alignment {
    return 4;
  }

  @override
  marshal(DBusWriteBuffer buffer) {
    buffer.align(this.alignment);
    buffer.writeInt32(value);
  }

  @override
  bool unmarshal(DBusReadBuffer buffer) {
    if (!buffer.align(this.alignment)) return false;
    if (buffer.remaining < 4) return false;
    value = buffer.readInt32();
    return true;
  }

  @override
  String toString() {
    return 'DBusInt32(${value})';
  }
}

/// D-Bus representation of an unsigned 32 bit integer.
class DBusUint32 extends DBusValue {
  /// An integer in the range [0, 4294967295]
  int value;

  static final _signature = DBusSignature('u');

  /// Creates a new unsigned 32 bit integer with the given [value].
  DBusUint32(this.value);

  @override
  DBusSignature get signature {
    return _signature;
  }

  @override
  int get alignment {
    return 4;
  }

  @override
  marshal(DBusWriteBuffer buffer) {
    buffer.align(this.alignment);
    buffer.writeUint32(value);
  }

  @override
  bool unmarshal(DBusReadBuffer buffer) {
    if (!buffer.align(this.alignment)) return false;
    if (buffer.remaining < 4) return false;
    value = buffer.readUint32();
    return true;
  }

  @override
  String toString() {
    return 'DBusUint32(${value})';
  }
}

/// D-Bus representation of a signed 64 bit integer.
class DBusInt64 extends DBusValue {
  /// An integer in the range [-9223372036854775808, 9223372036854775807]
  int value;

  static final _signature = DBusSignature('x');

  /// Creates a new signed 64 bit integer with the given [value].
  DBusInt64(this.value);

  @override
  DBusSignature get signature {
    return _signature;
  }

  @override
  int get alignment {
    return 8;
  }

  @override
  marshal(DBusWriteBuffer buffer) {
    buffer.align(this.alignment);
    buffer.writeInt64(value);
  }

  @override
  bool unmarshal(DBusReadBuffer buffer) {
    if (!buffer.align(this.alignment)) return false;
    if (buffer.remaining < 8) return false;
    value = buffer.readInt64();
    return true;
  }

  @override
  String toString() {
    return 'DBusInt64(${value})';
  }
}

/// D-Bus representation of an unsigned 64 bit integer.
class DBusUint64 extends DBusValue {
  /// An integer in the range [0, 18446744073709551615]
  int value;

  static final _signature = DBusSignature('t');

  /// Creates a new unsigned 64 bit integer with the given [value].
  DBusUint64(this.value);

  @override
  DBusSignature get signature {
    return _signature;
  }

  @override
  int get alignment {
    return 8;
  }

  @override
  marshal(DBusWriteBuffer buffer) {
    buffer.align(this.alignment);
    buffer.writeUint64(value);
  }

  @override
  bool unmarshal(DBusReadBuffer buffer) {
    if (!buffer.align(this.alignment)) return false;
    if (buffer.remaining < 8) return false;
    value = buffer.readUint64();
    return true;
  }

  @override
  String toString() {
    return 'DBusUint64(${value})';
  }
}

/// D-Bus representation of a 64 bit floating point value.
class DBusDouble extends DBusValue {
  /// A 64 bit floating point number.
  double value;

  static final _signature = DBusSignature('d');

  /// Creates a new 64 bit floating point number the given [value].
  DBusDouble(this.value);

  @override
  DBusSignature get signature {
    return _signature;
  }

  @override
  int get alignment {
    return 8;
  }

  @override
  marshal(DBusWriteBuffer buffer) {
    buffer.align(this.alignment);
    buffer.writeFloat64(value);
  }

  @override
  bool unmarshal(DBusReadBuffer buffer) {
    if (!buffer.align(this.alignment)) return false;
    if (buffer.remaining < 8) return false;
    value = buffer.readFloat64();
    return true;
  }

  @override
  String toString() {
    return 'DBusDouble(${value})';
  }
}

/// D-Bus representation of an Unicode text string.
class DBusString extends DBusValue {
  /// A Unicode text string.
  String value;

  static final _signature = DBusSignature('s');

  /// Creates a new Unicode text string with the given [value].
  DBusString(this.value);

  @override
  DBusSignature get signature {
    return _signature;
  }

  @override
  int get alignment {
    return 4;
  }

  @override
  marshal(DBusWriteBuffer buffer) {
    var data = utf8.encode(value);
    var length = DBusUint32(value.length);
    length.marshal(buffer);
    for (var d in data) buffer.writeByte(d);
    buffer.writeByte(0);
  }

  @override
  bool unmarshal(DBusReadBuffer buffer) {
    var length = DBusUint32(0);
    if (!length.unmarshal(buffer)) return false;
    if (buffer.remaining < (length.value + 1)) return false;
    var values = List<int>();
    for (var i = 0; i < length.value; i++) values.add(buffer.readByte());
    this.value = utf8.decode(values);
    buffer.readByte(); // Trailing nul
    return true;
  }

  @override
  String toString() {
    return "DBusString('${value}')";
  }
}

/// A D-Bus object path.
///
/// An object path is a text string that refers to an object on the D-Bus.
/// The path must begin with `/` and contain the characters `[A-Z][a-z][0-9]_` separated by more `/` dividers.
/// `/org/freedesktop/DBus` is a valid object path.
class DBusObjectPath extends DBusString {
  static final _signature = DBusSignature('o');

  /// Creates a new D-Bus object path with the given [value].
  DBusObjectPath(String value) : super(value);

  @override
  DBusSignature get signature {
    return _signature;
  }

  @override
  String toString() {
    return "DBusObjectPath('${value}')";
  }
}

/// D-Bus value that indicates a D-Bus type.
///
/// The following signatures map to classes:
///
/// * `y` → [DBusByte]
/// * `b` → [DBusBoolean]
/// * `n` → [DBusInt16]
/// * `q` → [DBusUint16]
/// * `i` → [DBusInt32]
/// * `u` → [DBusUint32]
/// * `x` → [DBusInt64]
/// * `t` → [DBusUint64]
/// * `d` → [DBusDouble]
/// * `s` → [DBusString]
/// * `o` → [DBusObjectPath]
/// * `g` → [DBusSignature]
/// * `v` → [DBusVariant]
/// * `(xyz...)` → [DBusStruct] (`x`, `y`, `z` represent the child value signatures).
/// * `av` → [DBusArray] (v represents the array value signature).
/// * `a{kv}` → [DBusDict] (`k` and `v` represent the key and value signatures).
class DBusSignature extends DBusValue {
  /// A D-Bus signature string.
  String value;

  static final _signature = DBusSignature('g');

  /// Create a new D-Bus signature with the given [value].
  DBusSignature(this.value);

  List<DBusSignature> split() {
    var signatures = List<DBusSignature>();
    for (var i = 0; i < value.length; i++) {
      if (value[i] == 'a') {
        if (value[i + 1] == '(') {
          var count = 1;
          var end = i + 2;
          while (count > 0) {
            if (value[end] == '(') count++;
            if (value[end] == ')') count--;
            end++;
          }
          signatures.add(DBusSignature(value.substring(i, end)));
          i += end - i;
        } else if (value[i + 1] == '{') {
          var count = 1;
          var end = i + 2;
          while (count > 0) {
            if (value[end] == '{') count++;
            if (value[end] == '}') count--;
            end++;
          }
          signatures.add(DBusSignature(value.substring(i, end)));
          i += end - i;
        } else {
          signatures.add(DBusSignature(value.substring(i, i + 2)));
          i++;
        }
      } else
        signatures.add(DBusSignature(value[i]));
    }
    return signatures;
  }

  @override
  DBusSignature get signature {
    return _signature;
  }

  @override
  int get alignment {
    return 1;
  }

  @override
  marshal(DBusWriteBuffer buffer) {
    var data = utf8.encode(value);
    buffer.writeByte(value.length);
    for (var d in data) buffer.writeByte(d);
    buffer.writeByte(0);
  }

  @override
  bool unmarshal(DBusReadBuffer buffer) {
    if (buffer.remaining < 1) return false;
    var length = buffer.readByte();
    var values = List<int>();
    if (buffer.remaining < length + 1) return false;
    for (var i = 0; i < length; i++) values.add(buffer.readByte());
    value = utf8.decode(values);
    buffer.readByte(); // Trailing nul
    return true;
  }

  @override
  String toString() {
    return "DBusSignature('${value}')";
  }
}

/// D-Bus value that contains any D-Bus type.
class DBusVariant extends DBusValue {
  /// The value contained in this variant.
  DBusValue value;

  static final _signature = DBusSignature('v');

  /// Creates a new D-Bus variant containing [value].
  DBusVariant(this.value);

  @override
  DBusSignature get signature {
    return _signature;
  }

  @override
  int get alignment {
    return 1;
  }

  @override
  marshal(DBusWriteBuffer buffer) {
    value.signature.marshal(buffer);
    value.marshal(buffer);
  }

  @override
  bool unmarshal(DBusReadBuffer buffer) {
    var signature = DBusSignature('');
    if (!signature.unmarshal(buffer)) return false;
    value = DBusValue.fromSignature(signature);
    return value.unmarshal(buffer);
  }

  @override
  String toString() {
    return 'DBusVariant(${value.toString()})';
  }
}

/// D-Bus value that contains a fixed set of other values.
class DBusStruct extends DBusValue {
  /// Child values in this structure.
  List<DBusValue> children;

  /// Creates a new D-Bus structure containing [children] values.
  DBusStruct(this.children);

  @override
  int get alignment {
    return 8;
  }

  @override
  DBusSignature get signature {
    var signature = '';
    for (var child in children) signature += child.signature.value;
    return DBusSignature('(' + signature + ')');
  }

  @override
  marshal(DBusWriteBuffer buffer) {
    buffer.align(this.alignment);
    for (var child in children) child.marshal(buffer);
  }

  @override
  bool unmarshal(DBusReadBuffer buffer) {
    if (!buffer.align(this.alignment)) return false;
    for (var child in children) {
      if (!child.unmarshal(buffer)) return false;
    }

    return true;
  }

  @override
  String toString() {
    var childrenText = List<String>();
    for (var child in children) childrenText.add(child.toString());
    return "DBusStruct([${childrenText.join(', ')}])";
  }
}

/// D-Bus representation of an ordered list of D-Bus values of the same type.
class DBusArray extends DBusValue {
  /// Signature of the type of children in this array.
  final DBusSignature childSignature;

  /// Ordered list of children in this array.
  var children = List<DBusValue>();

  /// Creates a new empty D-Bus array containing values that match [childSignature].
  DBusArray(this.childSignature);

  /// Adds [value] to the end of the array.
  add(DBusValue value) {
    children.add(value);
  }

  @override
  DBusSignature get signature {
    return DBusSignature('a' + childSignature.value);
  }

  @override
  int get alignment {
    return 4;
  }

  @override
  marshal(DBusWriteBuffer buffer) {
    DBusUint32(0).marshal(buffer);
    var lengthOffset = buffer.data.length - 4;
    if (children.length > 0) buffer.align(children[0].alignment);
    var startOffset = buffer.data.length;
    for (var child in children) child.marshal(buffer);

    // Update the length that was written
    var length = buffer.data.length - startOffset;
    buffer.setByte(lengthOffset + 0, (length >> 0) & 0xFF);
    buffer.setByte(lengthOffset + 1, (length >> 8) & 0xFF);
    buffer.setByte(lengthOffset + 2, (length >> 16) & 0xFF);
    buffer.setByte(lengthOffset + 3, (length >> 24) & 0xFF);
  }

  @override
  bool unmarshal(DBusReadBuffer buffer) {
    var length = DBusUint32(0);
    if (!length.unmarshal(buffer)) return false;
    // FIXME: Align to first element (not in length)
    var end = buffer.readOffset + length.value;
    while (buffer.readOffset < end) {
      var child = DBusValue.fromSignature(childSignature);
      if (!child.unmarshal(buffer)) return false;
      children.add(child);
    }

    return true;
  }

  @override
  String toString() {
    var childrenText = List<String>();
    for (var child in children) childrenText.add(child.toString());
    return "DBusArray([${childrenText.join(', ')}])";
  }
}

/// D-Bus representation of an associative array of D-Bus values.
class DBusDict extends DBusValue {
  /// Signature of the key type in this dictionary.
  final DBusSignature keySignature;

  /// Signature of the value type in this dictionary.
  final DBusSignature valueSignature;

  /// The child values in this dictionary.
  var children = List<DBusStruct>();

  /// Creates a new dictionary with keys of the type [keySignature] and values of the type [valueSignature].
  DBusDict(this.keySignature, this.valueSignature);

  /// Sets the [key] in the dictionary to have [value]. An existing value used by this key is removed.
  add(DBusValue key, DBusValue value) {
    // FIXME: Check if key exists
    children.add(DBusStruct([key, value]));
  }

  /// Gets the value in the dictionary using [key]. If no value exists null is returned.
  DBusValue lookup(DBusValue key) {
    for (var child in children) {
      if (child.children[0] == key) return child;
    }
    return null;
  }

  @override
  DBusSignature get signature {
    return DBusSignature('a{${keySignature.value}${valueSignature.value}}');
  }

  @override
  int get alignment {
    return 4;
  }

  @override
  marshal(DBusWriteBuffer buffer) {
    DBusUint32(0).marshal(buffer);
    var lengthOffset = buffer.data.length - 4;
    if (children.length > 0) buffer.align(children[0].alignment);
    var startOffset = buffer.data.length;
    for (var child in children) child.marshal(buffer);

    // Update the length that was written
    var length = buffer.data.length - startOffset;
    buffer.setByte(lengthOffset + 0, (length >> 0) & 0xFF);
    buffer.setByte(lengthOffset + 1, (length >> 8) & 0xFF);
    buffer.setByte(lengthOffset + 2, (length >> 16) & 0xFF);
    buffer.setByte(lengthOffset + 3, (length >> 24) & 0xFF);
  }

  @override
  bool unmarshal(DBusReadBuffer buffer) {
    var length = DBusUint32(0);
    if (!length.unmarshal(buffer)) return false;
    // FIXME: Align to first element (not in length)
    var end = buffer.readOffset + length.value;
    while (buffer.readOffset < end) {
      var child = DBusStruct([
        DBusValue.fromSignature(keySignature),
        DBusValue.fromSignature(valueSignature)
      ]);
      if (!child.unmarshal(buffer)) return false;
      children.add(child);
    }

    return true;
  }

  @override
  String toString() {
    var childrenText = List<String>();
    for (var child in children) childrenText.add(child.toString());
    return "DBusDict([${childrenText.join(', ')}])";
  }
}
