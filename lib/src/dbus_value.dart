bool _listsEqual<T>(List<T> a, List<T> b) {
  if (a.length != b.length) {
    return false;
  }

  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }

  return true;
}

bool _mapsEqual<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) {
    return false;
  }

  for (var key in a.keys) {
    if (a[key] != b[key]) {
      return false;
    }
  }

  return true;
}

/// Base class for D-Bus values.
abstract class DBusValue {
  /// Gets the signature for this value.
  DBusSignature get signature;

  const DBusValue();

  /// Converts this value to a native Dart representation.
  dynamic toNative();
}

/// D-Bus representation of an unsigned 8 bit value.
class DBusByte extends DBusValue {
  /// A integer in the range [0, 255]
  final int value;

  /// Creates a new byte with the given [value].
  const DBusByte(this.value);

  @override
  DBusSignature get signature {
    return DBusSignature('y');
  }

  @override
  dynamic toNative() {
    return value;
  }

  @override
  bool operator ==(other) => other is DBusByte && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'DBusByte($value)';
  }
}

/// D-Bus representation of a boolean value.
class DBusBoolean extends DBusValue {
  /// A boolean value.
  final bool value;

  /// Creates a new boolean with the given [value].
  const DBusBoolean(this.value);

  @override
  DBusSignature get signature {
    return DBusSignature('b');
  }

  @override
  dynamic toNative() {
    return value;
  }

  @override
  bool operator ==(other) => other is DBusBoolean && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'DBusBoolean($value)';
  }
}

/// D-Bus representation of a signed 16 bit integer.
class DBusInt16 extends DBusValue {
  /// An integer in the range [-32768, 32767]
  final int value;

  /// Creates a new signed 16 bit integer with the given [value].
  const DBusInt16(this.value);

  @override
  DBusSignature get signature {
    return DBusSignature('n');
  }

  @override
  dynamic toNative() {
    return value;
  }

  @override
  bool operator ==(other) => other is DBusInt16 && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'DBusInt16($value)';
  }
}

/// D-Bus representation of an unsigned 16 bit integer.
class DBusUint16 extends DBusValue {
  /// An integer in the range [0, 65535]
  final int value;

  /// Creates a new unsigned 16 bit integer with the given [value].
  const DBusUint16(this.value);

  @override
  DBusSignature get signature {
    return DBusSignature('q');
  }

  @override
  dynamic toNative() {
    return value;
  }

  @override
  bool operator ==(other) => other is DBusUint16 && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'DBusUint16($value)';
  }
}

/// D-Bus representation of a signed 32 bit integer.
class DBusInt32 extends DBusValue {
  /// An integer in the range [-2147483648, 2147483647]
  final int value;

  /// Creates a new signed 32 bit integer with the given [value].
  const DBusInt32(this.value);

  @override
  DBusSignature get signature {
    return DBusSignature('i');
  }

  @override
  dynamic toNative() {
    return value;
  }

  @override
  bool operator ==(other) => other is DBusInt32 && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'DBusInt32($value)';
  }
}

/// D-Bus representation of an unsigned 32 bit integer.
class DBusUint32 extends DBusValue {
  /// An integer in the range [0, 4294967295]
  final int value;

  /// Creates a new unsigned 32 bit integer with the given [value].
  const DBusUint32(this.value);

  @override
  DBusSignature get signature {
    return DBusSignature('u');
  }

  @override
  dynamic toNative() {
    return value;
  }

  @override
  bool operator ==(other) => other is DBusUint32 && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'DBusUint32($value)';
  }
}

/// D-Bus representation of a signed 64 bit integer.
class DBusInt64 extends DBusValue {
  /// An integer in the range [-9223372036854775808, 9223372036854775807]
  final int value;

  /// Creates a new signed 64 bit integer with the given [value].
  const DBusInt64(this.value);

  @override
  DBusSignature get signature {
    return DBusSignature('x');
  }

  @override
  dynamic toNative() {
    return value;
  }

  @override
  bool operator ==(other) => other is DBusInt64 && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'DBusInt64($value)';
  }
}

/// D-Bus representation of an unsigned 64 bit integer.
class DBusUint64 extends DBusValue {
  /// An integer in the range [0, 18446744073709551615]
  final int value;

  /// Creates a new unsigned 64 bit integer with the given [value].
  const DBusUint64(this.value);

  @override
  DBusSignature get signature {
    return DBusSignature('t');
  }

  @override
  dynamic toNative() {
    return value;
  }

  @override
  bool operator ==(other) => other is DBusUint64 && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'DBusUint64($value)';
  }
}

/// D-Bus representation of a 64 bit floating point value.
class DBusDouble extends DBusValue {
  /// A 64 bit floating point number.
  final double value;

  /// Creates a new 64 bit floating point number the given [value].
  const DBusDouble(this.value);

  @override
  DBusSignature get signature {
    return DBusSignature('d');
  }

  @override
  dynamic toNative() {
    return value;
  }

  @override
  bool operator ==(other) => other is DBusDouble && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'DBusDouble($value)';
  }
}

/// D-Bus representation of an Unicode text string.
class DBusString extends DBusValue {
  /// A Unicode text string.
  final String value;

  /// Creates a new Unicode text string with the given [value].
  const DBusString(this.value);

  @override
  DBusSignature get signature {
    return DBusSignature('s');
  }

  @override
  dynamic toNative() {
    return value;
  }

  @override
  bool operator ==(other) => other is DBusString && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return "DBusString('$value')";
  }
}

/// A D-Bus object path.
///
/// An object path is a text string that refers to an object on the D-Bus.
/// The path must begin with `/` and contain the characters `[A-Z][a-z][0-9]_` separated by more `/` dividers.
/// `/org/freedesktop/DBus` is a valid object path.
class DBusObjectPath extends DBusString {
  /// Creates a new D-Bus object path with the given [value].
  ///
  /// An exception is shown if [value] is not a valid object path.
  DBusObjectPath(String value) : super(value) {
    if (value != '/') {
      if (value.contains(RegExp('[^a-zA-Z0-9_/]')) ||
          !value.startsWith('/') ||
          value.endsWith('/')) {
        throw 'Invalid object path: $value';
      }
    }
  }

  /// Creates a new D-Bus object path with the given [value].
  ///
  /// No checking is performed on the validity of [value].
  /// This function is useful when you need a constant value (e.g. for a
  /// parameter default value). In all other cases use the standard constructor.
  const DBusObjectPath.unchecked(String value) : super(value);

  /// Splits an object path into separate elements, e.g. '/org/freedesktop/DBus' -> [ 'org', 'freedesktop', 'DBus' ].
  List<String> split() {
    if (value == '/') {
      return [];
    } else {
      return value.substring(1).split('/');
    }
  }

  /// Returns true if this object path is under [namespace]. e.g. '/org/freedesktop/DBus' is under '/org/freedesktop'.
  bool isInNamespace(DBusObjectPath namespace) {
    return namespace.value == '/' ||
        value == namespace.value ||
        value.startsWith(namespace.value + '/');
  }

  @override
  DBusSignature get signature {
    return DBusSignature('o');
  }

  @override
  dynamic toNative() {
    return this;
  }

  @override
  bool operator ==(other) => other is DBusObjectPath && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return "DBusObjectPath('$value')";
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
  final String value;

  /// Create a new D-Bus signature with the given [value].
  const DBusSignature(this.value);

  /// Splits this signature into a list of signatures, e.g. 'asbo' -> ['as', 'b', 'o']
  List<DBusSignature> split() {
    var signatures = <DBusSignature>[];

    var start = 0;
    while (start < value.length) {
      var end = _findChildEnd(start);
      signatures.add(DBusSignature(value.substring(start, end)));
      start = end;
    }

    return signatures;
  }

  /// Gets the end of the child signature starting at [offset].
  int _findChildEnd(int offset) {
    /// Dicts and structs have the child type following.
    if (value[offset] == 'a') {
      return _findChildEnd(offset + 1);
    }

    // Structs and dict entries are multiple characters, everything else is a single character.
    if (value[offset] == '(') {
      return _findClosing(offset, ')');
    } else if (value[offset] == '{') {
      return _findClosing(offset, '}');
    } else {
      return offset + 1;
    }
  }

  // Find the closing parenthesis/brace.
  int _findClosing(int start, String closeChar) {
    var openChar = value[start];
    var count = 0;
    var end = start;
    while (end < value.length) {
      if (value[end] == openChar) {
        count++;
      } else if (value[end] == closeChar) {
        count--;
        if (count == 0) {
          return end + 1;
        }
      }
      end++;
    }

    throw 'Unable to find closing $closeChar in signature: $value';
  }

  @override
  DBusSignature get signature {
    return DBusSignature('g');
  }

  @override
  dynamic toNative() {
    return this;
  }

  @override
  bool operator ==(other) => other is DBusSignature && other.value == value;

  DBusSignature operator +(DBusSignature other) =>
      DBusSignature(value + other.value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return "DBusSignature('$value')";
  }
}

/// D-Bus value that contains any D-Bus type.
class DBusVariant extends DBusValue {
  /// The value contained in this variant.
  final DBusValue value;

  /// Creates a new D-Bus variant containing [value].
  const DBusVariant(this.value);

  @override
  DBusSignature get signature {
    return DBusSignature('v');
  }

  @override
  dynamic toNative() {
    return value.toNative();
  }

  @override
  bool operator ==(other) => other is DBusVariant && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'DBusVariant(${value.toString()})';
  }
}

/// D-Bus value that contains a fixed set of other values.
class DBusStruct extends DBusValue {
  /// Child values in this structure.
  final Iterable<DBusValue> children;

  /// Creates a new D-Bus structure containing [children] values.
  const DBusStruct(this.children);

  @override
  DBusSignature get signature {
    var signature = '';
    for (var child in children) {
      signature += child.signature.value;
    }
    return DBusSignature('(' + signature + ')');
  }

  @override
  dynamic toNative() {
    return children.map((value) => value.toNative());
  }

  @override
  bool operator ==(other) =>
      other is DBusStruct &&
      _listsEqual(other.children.toList(), children.toList());

  @override
  int get hashCode => children.hashCode;

  @override
  String toString() {
    var childrenText = <String>[];
    for (var child in children) {
      childrenText.add(child.toString());
    }
    return "DBusStruct([${childrenText.join(', ')}])";
  }
}

/// D-Bus representation of an ordered list of D-Bus values of the same type.
class DBusArray extends DBusValue {
  /// Signature of the type of children in this array.
  final DBusSignature childSignature;

  /// Ordered list of children in this array.
  final Iterable<DBusValue> children;

  /// Creates a new empty D-Bus array containing [children].
  ///
  /// An exception will be thrown if a DBusValue in [children] doesn't have a signature matching [childSignature].
  DBusArray(this.childSignature, [this.children = const []]) {
    for (var child in children) {
      if (child.signature.value != childSignature.value) {
        throw "Provided children don't match array signature";
      }
    }
  }

  /// Creates a new empty D-Bus array containing [children].
  ///
  /// No checking is performed on the validity of [children].
  /// This function is useful when you need a constant value (e.g. for a
  /// parameter default value). In all other cases use the standard constructor.
  const DBusArray.unchecked(this.childSignature, [this.children = const []]);

  /// Creates a new array of unsigned 8 bit values.
  factory DBusArray.byte(Iterable<int> values) {
    return DBusArray(
        DBusSignature('y'), values.map((value) => DBusByte(value)));
  }

  /// Creates a new array of signed 16 bit values.
  factory DBusArray.int16(Iterable<int> values) {
    return DBusArray(
        DBusSignature('n'), values.map((value) => DBusInt16(value)));
  }

  /// Creates a new array of unsigned 16 bit values.
  factory DBusArray.uint16(Iterable<int> values) {
    return DBusArray(
        DBusSignature('q'), values.map((value) => DBusUint16(value)));
  }

  /// Creates a new array of signed 32 bit values.
  factory DBusArray.int32(Iterable<int> values) {
    return DBusArray(
        DBusSignature('i'), values.map((value) => DBusInt32(value)));
  }

  /// Creates a new array of unsigned 32 bit values.
  factory DBusArray.uint32(Iterable<int> values) {
    return DBusArray(
        DBusSignature('u'), values.map((value) => DBusUint32(value)));
  }

  /// Creates a new array of signed 64 bit values.
  factory DBusArray.int64(Iterable<int> values) {
    return DBusArray(
        DBusSignature('x'), values.map((value) => DBusInt64(value)));
  }

  /// Creates a new array of unsigned 64 bit values.
  factory DBusArray.uint64(Iterable<int> values) {
    return DBusArray(
        DBusSignature('t'), values.map((value) => DBusUint64(value)));
  }

  /// Creates a new array of 64 bit floating point values.
  factory DBusArray.double(Iterable<double> values) {
    return DBusArray(
        DBusSignature('d'), values.map((value) => DBusDouble(value)));
  }

  /// Creates a new array of Unicode text strings.
  factory DBusArray.string(Iterable<String> values) {
    return DBusArray(
        DBusSignature('s'), values.map((value) => DBusString(value)));
  }

  /// Creates a new array of D-Bus object paths.
  factory DBusArray.objectPath(Iterable<DBusObjectPath> values) {
    return DBusArray(DBusSignature('o'), values);
  }

  /// Creates a new array of D-Bus variants.
  factory DBusArray.variant(Iterable<DBusValue> values) {
    return DBusArray(
        DBusSignature('v'), values.map((value) => DBusVariant(value)));
  }

  @override
  DBusSignature get signature {
    return DBusSignature('a' + childSignature.value);
  }

  @override
  dynamic toNative() {
    return children.map((value) => value.toNative());
  }

  @override
  bool operator ==(other) =>
      other is DBusArray &&
      other.childSignature == childSignature &&
      _listsEqual(other.children.toList(), children.toList());

  @override
  int get hashCode => children.hashCode;

  @override
  String toString() {
    var childrenText = <String>[];
    for (var child in children) {
      childrenText.add(child.toString());
    }
    return "DBusArray($childSignature, [${childrenText.join(', ')}])";
  }
}

/// D-Bus representation of an associative array of D-Bus values.
class DBusDict extends DBusValue {
  /// Signature of the key type in this dictionary.
  final DBusSignature keySignature;

  /// Signature of the value type in this dictionary.
  final DBusSignature valueSignature;

  /// The child values in this dictionary.
  final Map<DBusValue, DBusValue> children;

  /// Creates a new dictionary with keys of the type [keySignature] and values of the type [valueSignature].
  ///
  /// An exception will be thrown if the DBusValues in [children] don't have signatures matching [keySignature] and [valueSignature].
  DBusDict(this.keySignature, this.valueSignature, [this.children = const {}]) {
    children.forEach((key, value) {
      if (key.signature.value != keySignature.value) {
        throw "Provided key doesn't match signature";
      }
      if (value.signature.value != valueSignature.value) {
        throw "Provided value doesn't match signature";
      }
    });
  }

  /// Creates a new dictionary with keys of the type [keySignature] and values of the type [valueSignature].
  ///
  /// No checking is performed on the validity of [children].
  /// This function is useful when you need a constant value (e.g. for a
  /// parameter default value). In all other cases use the standard constructor.
  const DBusDict.unchecked(this.keySignature, this.valueSignature,
      [this.children = const {}]);

  /// Creates a new dictionary of string keys mapping to variant values.
  factory DBusDict.stringVariant(Map<String, DBusValue> children) {
    return DBusDict(
        DBusSignature('s'),
        DBusSignature('v'),
        children.map(
            (key, value) => MapEntry(DBusString(key), DBusVariant(value))));
  }

  @override
  DBusSignature get signature {
    return DBusSignature('a{${keySignature.value}${valueSignature.value}}');
  }

  @override
  dynamic toNative() {
    return children
        .map((key, value) => MapEntry(key.toNative(), value.toNative()));
  }

  @override
  bool operator ==(other) =>
      other is DBusDict &&
      other.keySignature == keySignature &&
      other.valueSignature == valueSignature &&
      _mapsEqual(other.children, children);

  @override
  int get hashCode => children.hashCode;

  @override
  String toString() {
    var childrenText = <String>[];
    children.forEach((key, value) {
      childrenText.add('${key.toString()}: ${value.toString()}');
    });
    return "DBusDict($keySignature, $valueSignature, {${childrenText.join(', ')}})";
  }
}
