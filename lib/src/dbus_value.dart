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
  DBusByte(this.value) {
    if (value.isNegative || value > 255) {
      throw ArgumentError.value(
          value, 'value', 'Byte must be in range [0, 255]');
    }
  }

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
  String toString() => 'DBusByte($value)';
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
  String toString() => 'DBusBoolean($value)';
}

/// D-Bus representation of a signed 16 bit integer.
class DBusInt16 extends DBusValue {
  /// An integer in the range [-32768, 32767]
  final int value;

  /// Creates a new signed 16 bit integer with the given [value].
  DBusInt16(this.value) {
    if (value < -32768 || value > 32767) {
      throw ArgumentError.value(
          value, 'value', 'Int16 must be in range [-32768, 32767]');
    }
  }

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
  String toString() => 'DBusInt16($value)';
}

/// D-Bus representation of an unsigned 16 bit integer.
class DBusUint16 extends DBusValue {
  /// An integer in the range [0, 65535]
  final int value;

  /// Creates a new unsigned 16 bit integer with the given [value].
  DBusUint16(this.value) {
    if (value.isNegative || value > 65535) {
      throw ArgumentError.value(
          value, 'value', 'Uint16 must be in range [0, 65535]');
    }
  }

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
  String toString() => 'DBusUint16($value)';
}

/// D-Bus representation of a signed 32 bit integer.
class DBusInt32 extends DBusValue {
  /// An integer in the range [-2147483648, 2147483647]
  final int value;

  /// Creates a new signed 32 bit integer with the given [value].
  DBusInt32(this.value) {
    if (value < -2147483648 || value > 2147483647) {
      throw ArgumentError.value(
          value, 'value', 'Int32 must be in range [-2147483648, 2147483647]');
    }
  }

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
  String toString() => 'DBusInt32($value)';
}

/// D-Bus representation of an unsigned 32 bit integer.
class DBusUint32 extends DBusValue {
  /// An integer in the range [0, 4294967295]
  final int value;

  /// Creates a new unsigned 32 bit integer with the given [value].
  DBusUint32(this.value) {
    if (value.isNegative || value > 4294967295) {
      throw ArgumentError.value(
          value, 'value', 'Uint32 must be in range [0, 4294967295]');
    }
  }

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
  String toString() => 'DBusUint32($value)';
}

/// D-Bus representation of a signed 64 bit integer.
class DBusInt64 extends DBusValue {
  /// An integer in the range [-9223372036854775808, 9223372036854775807]
  final int value;

  /// Creates a new signed 64 bit integer with the given [value].
  DBusInt64(this.value) {
    if (value < -(1 << 63) || value > (1 << 63) - 1) {
      throw ArgumentError.value(value, 'value',
          'Uint64 must be in range [-9223372036854775808, 9223372036854775807]');
    }
  }

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
  String toString() => 'DBusInt64($value)';
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
  String toString() => 'DBusUint64($value)';
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
  String toString() => 'DBusDouble($value)';
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
  String toString() => "DBusString('$value')";
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
          value.contains('//') ||
          !value.startsWith('/') ||
          value.endsWith('/')) {
        throw ArgumentError.value(value, 'value', 'Invalid object path');
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
  String toString() => "DBusObjectPath('$value')";
}

/// D-Bus value that indicates a set of D-Bus types.
///
/// A signature may be empty (''), contain a single type (e.g. 's'), or contain multiple types (e.g. 'asbo').
///
/// The following patterns map to classes:
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
/// * `m` → [DBusMaybe]
/// * `(xyz...)` → [DBusStruct] (`x`, `y`, `z` represent the child value signatures).
/// * `av` → [DBusArray] (v represents the array value signature).
/// * `a{kv}` → [DBusDict] (`k` and `v` represent the key and value signatures).
///
/// There is also a Unix file descriptor `h` which may be in a signature, but is not supported in Dart.
class DBusSignature extends DBusValue {
  /// A D-Bus signature string.
  final String value;

  /// True if this signature is for a basic type (byte, boolean, int16, uint16, int32, uint32, int64, uint64, double, unix_fd).
  bool get isBasic => value.length == 1 && 'ybnqiuxtdhsog'.contains(value);

  /// True if this signature is for a single complete type, i.e. represents a single dbus value.
  /// If False, then use [split] to get the types this signature contains.
  bool get isSingleCompleteType =>
      value.isNotEmpty && _findChildSignatureEnd(value, 0) == value.length - 1;

  /// Create a new D-Bus signature with the given [value].
  DBusSignature(this.value) {
    if (value.length > 255) {
      throw ArgumentError.value(
          value, 'value', 'Signature maximum length is 255 characters');
    }
    var index = 0;
    while (index < value.length) {
      index = _validate(value, index) + 1;
    }
  }

  /// Splits this signature into a list of signatures with single complete types, e.g. 'asbo' -> ['as', 'b', 'o']
  List<DBusSignature> split() {
    var signatures = <DBusSignature>[];

    var index = 0;
    while (index < value.length) {
      var end = _findChildSignatureEnd(value, index);
      if (end < 0) {
        throw FormatException('Unable to split invalid signature');
      }
      signatures.add(DBusSignature(value.substring(index, end + 1)));
      index = end + 1;
    }

    return signatures;
  }

  /// Check [value] contains a valid signature and return the index of the end of the current child signature.
  int _validate(String value, int index) {
    if (value.startsWith('(', index)) {
      // Struct.
      var end = _findClosing(value, index, '(', ')');
      if (end < 0) {
        throw ArgumentError.value(
            value, 'value', 'Struct missing closing parenthesis');
      }
      var childIndex = index + 1;
      while (childIndex < end) {
        childIndex = _validate(value, childIndex) + 1;
      }
      return end;
    } else if (value.startsWith('a{', index)) {
      // Dict.
      var end = _findClosing(value, index, '{', '}');
      if (end < 0) {
        throw ArgumentError.value(value, 'value', 'Dict missing closing brace');
      }
      var childIndex = index + 2;
      var childCount = 0;
      while (childIndex < end) {
        childIndex = _validate(value, childIndex) + 1;
        childCount++;
      }
      if (childCount != 2) {
        throw ArgumentError.value(value, 'value',
            "Dict doesn't have correct number of child signatures");
      }
      return end;
    } else if (value.startsWith('a', index)) {
      // Array.
      if (index >= value.length - 1) {
        throw ArgumentError.value(value, 'value', 'Array missing child type');
      }
      return _validate(value, index + 1);
    } else if (value.startsWith('m', index)) {
      // Maybe.
      if (index >= value.length - 1) {
        throw ArgumentError.value(value, 'value', 'Maybe missing child type');
      }
      return _validate(value, index + 1);
    } else if ('ybnqiuxtdsogvha'.contains(value[index])) {
      return index;
    } else {
      throw ArgumentError.value(
          value, 'value', 'Signature contains unknown characters');
    }
  }

  /// Find the index where the current child signature ends.
  int _findChildSignatureEnd(String value, int index) {
    if (index >= value.length) {
      return -1;
    } else if (value.startsWith('(', index)) {
      return _findClosing(value, index, '(', ')');
    } else if (value.startsWith('a{', index)) {
      return _findClosing(value, index, '{', '}');
    } else if (value.startsWith('a', index)) {
      return _findChildSignatureEnd(value, index + 1);
    } else if (value.startsWith('m', index)) {
      return _findChildSignatureEnd(value, index + 1);
    } else {
      return index;
    }
  }

  /// Find the index int [value] where there is a [closeChar] that matches [openChar].
  /// These characters nest.
  int _findClosing(String value, int index, String openChar, String closeChar) {
    var depth = 0;
    for (var i = index; i < value.length; i++) {
      if (value[i] == openChar) {
        depth++;
      } else if (value[i] == closeChar) {
        depth--;
        if (depth == 0) {
          return i;
        }
      }
    }
    return -1;
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
  String toString() => "DBusSignature('$value')";
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
  String toString() => 'DBusVariant(${value.toString()})';
}

/// D-Bus value that contains a D-Bus type or null.
/// This type is reserved for future use, and is not currently able to be sent or received using D-Bus.
class DBusMaybe extends DBusValue {
  /// Signature of the value this maybe contains.
  final DBusSignature valueSignature;

  /// The value contained in this maybe.
  final DBusValue? value;

  /// Creates a new D-Bus maybe containing [value].
  DBusMaybe(this.valueSignature, this.value) {
    if (!valueSignature.isSingleCompleteType) {
      throw ArgumentError.value(valueSignature, 'valueSignature',
          'Maybe value type must be a single complete type');
    }

    if (value != null && value!.signature.value != valueSignature.value) {
      throw ArgumentError.value(
          value, 'value', "Value doesn't match signature $valueSignature");
    }
  }

  @override
  DBusSignature get signature {
    return DBusSignature('m' + valueSignature.value);
  }

  @override
  dynamic toNative() {
    return value?.toNative();
  }

  @override
  bool operator ==(other) =>
      other is DBusMaybe &&
      other.valueSignature == valueSignature &&
      other.value == value;

  @override
  int get hashCode => valueSignature.hashCode | value.hashCode;

  @override
  String toString() => 'DBusMaybe($valueSignature, ${value?.toString()})';
}

/// D-Bus value that contains a fixed set of other values.
class DBusStruct extends DBusValue {
  /// Child values in this structure.
  final List<DBusValue> children;

  /// Creates a new D-Bus structure containing [children] values.
  DBusStruct(Iterable<DBusValue> children) : children = children.toList();

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
      other is DBusStruct && _listsEqual(other.children, children);

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
  final List<DBusValue> children;

  /// Creates a new empty D-Bus array containing [children].
  ///
  /// [childSignature] must contain a single type.
  /// An exception will be thrown if a DBusValue in [children] doesn't have a signature matching [childSignature].
  DBusArray(this.childSignature, [Iterable<DBusValue> children = const []])
      : children = children.toList() {
    if (!childSignature.isSingleCompleteType) {
      throw ArgumentError.value(childSignature, 'childSignature',
          'Array value type must be a single complete type');
    }

    for (var child in children) {
      if (child.signature.value != childSignature.value) {
        throw ArgumentError.value(children, 'children',
            "Provided children don't match array signature ${childSignature.value}");
      }
    }
  }

  /// Creates a new empty D-Bus array containing [children].
  ///
  /// No checking is performed on the validity of [children].
  /// This function is useful when you need a constant value (e.g. for a
  /// parameter default value). In all other cases use the standard constructor.
  DBusArray.unchecked(this.childSignature,
      [Iterable<DBusValue> children = const []])
      : children = children.toList();

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
      _listsEqual(other.children, children);

  @override
  int get hashCode => children.hashCode;

  @override
  String toString() {
    switch (childSignature.value) {
      case 'y':
        return 'DBusArray.byte([' +
            children.map((child) => (child as DBusByte).value).join(', ') +
            '])';
      case 'n':
        return 'DBusArray.int16([' +
            children.map((child) => (child as DBusInt16).value).join(', ') +
            '])';
      case 'q':
        return 'DBusArray.uint16([' +
            children.map((child) => (child as DBusUint16).value).join(', ') +
            '])';
      case 'i':
        return 'DBusArray.int32([' +
            children.map((child) => (child as DBusInt32).value).join(', ') +
            '])';
      case 'u':
        return 'DBusArray.uint32([' +
            children.map((child) => (child as DBusUint32).value).join(', ') +
            '])';
      case 'x':
        return 'DBusArray.int64([' +
            children.map((child) => (child as DBusInt64).value).join(', ') +
            '])';
      case 't':
        return 'DBusArray.uint64([' +
            children.map((child) => (child as DBusUint64).value).join(', ') +
            '])';
      case 'd':
        return 'DBusArray.double([' +
            children.map((child) => (child as DBusDouble).value).join(', ') +
            '])';
      case 's':
        return 'DBusArray.string([' +
            children
                .map((child) => "'" + (child as DBusString).value + "'")
                .join(', ') +
            '])';
      case 'o':
        return 'DBusArray.objectPath([' +
            children
                .map((child) => (child as DBusObjectPath).value)
                .join(', ') +
            '])';
      case 'v':
        return 'DBusArray.variant([' +
            children.map((child) => (child as DBusVariant).value).join(', ') +
            '])';
      default:
        var childrenText = <String>[];
        for (var child in children) {
          childrenText.add(child.toString());
        }
        return "DBusArray($childSignature, [${childrenText.join(', ')}])";
    }
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
  /// [keySignature] and [valueSignature] must a single type.
  /// D-Bus doesn't allow sending and receiving dicts with keys that not basic types, i.e. byte, boolean, int16, uint16, int32, uint32, int64, uint64, double or unix_fd.
  /// An exception will be thrown when sending a message containing dicts using other types for keys.
  ///
  /// An exception will be thrown if the DBusValues in [children] don't have signatures matching [keySignature] and [valueSignature].
  DBusDict(this.keySignature, this.valueSignature, [this.children = const {}]) {
    if (!keySignature.isSingleCompleteType) {
      throw ArgumentError.value(keySignature, 'keySignature',
          'Dict key type must be a single complete type');
    }
    if (!valueSignature.isSingleCompleteType) {
      throw ArgumentError.value(valueSignature, 'valueSignature',
          'Dict value type must be a single complete type');
    }

    children.forEach((key, value) {
      if (key.signature.value != keySignature.value) {
        throw ArgumentError.value(key, 'children',
            "Provided key doesn't match signature ${keySignature.value}");
      }
      if (value.signature.value != valueSignature.value) {
        throw ArgumentError.value(value, 'children',
            "Provided value doesn't match signature ${valueSignature.value}");
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
    if (keySignature.value == 's' && valueSignature.value == 'v') {
      return 'DBusDict.stringVariant({' +
          children.entries
              .map((entry) =>
                  "'${(entry.key as DBusString).value}': ${(entry.value as DBusVariant).value.toString()}")
              .join(', ') +
          '})';
    } else {
      var childrenText = <String>[];
      children.forEach((key, value) {
        childrenText.add('${key.toString()}: ${value.toString()}');
      });
      return 'DBusDict($keySignature, $valueSignature, {' +
          children.entries
              .map((entry) =>
                  '${entry.key.toString()}: ${entry.value.toString()}')
              .join(', ') +
          '})';
    }
  }
}
