import "dart:convert";

/// Base class for D-Bus values.
abstract class DBusValue {
  DBusSignature signature;
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
  String toString() {
    return 'DBusByte(${value})';
  }
}

/// D-Bus representation of a boolean value.
class DBusBoolean extends DBusValue {
  // FIXME: extends DBusUint32
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
  DBusSignature get signature {
    var signature = '';
    for (var child in children) signature += child.signature.value;
    return DBusSignature('(' + signature + ')');
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
    for (var child in children) if (child.children[0] == key) return child;
    return null;
  }

  @override
  DBusSignature get signature {
    return DBusSignature('a{${keySignature.value}${valueSignature.value}}');
  }

  @override
  String toString() {
    var childrenText = List<String>();
    for (var child in children) childrenText.add(child.toString());
    return "DBusDict([${childrenText.join(', ')}])";
  }
}
