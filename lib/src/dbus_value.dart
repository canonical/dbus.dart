import 'dart:io';

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

  /// Converts this value to the native Dart representation of a byte. Only works if [signature] is 'y'.
  int asByte() => (this as DBusByte).value;

  /// Converts this value to the native Dart representation of a boolean. Only works if [signature] is 'b'.
  bool asBoolean() => (this as DBusBoolean).value;

  /// Converts this value to the native Dart representation of a 16 bit signed integer. Only works if [signature] is 'n'.
  int asInt16() => (this as DBusInt16).value;

  /// Converts this value to the native Dart representation of a 16 bit unsigned integer. Only works if [signature] is 'q'.
  int asUint16() => (this as DBusUint16).value;

  /// Converts this value to the native Dart representation of a 32 bit signed integer. Only works if [signature] is 'i'.
  int asInt32() => (this as DBusInt32).value;

  /// Converts this value to the native Dart representation of a 32 bit unsigned integer. Only works if [signature] is 'u'.
  int asUint32() => (this as DBusUint32).value;

  /// Converts this value to the native Dart representation of a 64 bit signed integer. Only works if [signature] is 'x'.
  int asInt64() => (this as DBusInt64).value;

  /// Converts this value to the native Dart representation of a 64 bit unsigned integer. Only works if [signature] is 't'.
  int asUint64() => (this as DBusUint64).value;

  /// Converts this value to the native Dart representation of a 64 bit floating point number. Only works if [signature] is 'd'.
  double asDouble() => (this as DBusDouble).value;

  /// Converts this value to the native Dart representation of a string. Only works if [signature] is 's'.
  String asString() => (this as DBusString).value;

  /// Extracts the object path inside this value. Only works if [signature] is 'o'.
  DBusObjectPath asObjectPath() => this as DBusObjectPath;

  /// Extracts the signature inside this value. Only works if [signature] is 'g'.
  DBusSignature asSignature() => this as DBusSignature;

  /// Extracts the value stored inside this variant. Only works if [signature] is 'v'.
  DBusValue asVariant() => (this as DBusVariant).value;

  /// Extracts the maybe type inside this value. Only works if [signature] is a maybe type, e.g. 'mi'.
  DBusValue? asMaybe() => (this as DBusMaybe).value;

  /// Extracts the [ResourceHandle] inside this unix file descriptor D-Bus value. Only works if [signature] is 'h'.
  ResourceHandle asUnixFd() => (this as DBusUnixFd).handle;

  /// Extracts this child values inside this struct. Only works if [signature] is a struct type, e.g '(si)'.
  List<DBusValue> asStruct() => (this as DBusStruct).children;

  /// Extracts the array inside this value. Only works if [signature] is an array type, e.g 'as'.
  List<DBusValue> asArray() => (this as DBusArray).children;

  /// Extracts the bytes inside this array. Only works if [signature] is 'ay'.
  Iterable<int> asByteArray() => (this as DBusArray).mapByte();

  /// Extracts the boolean values inside this array. Only works if [signature] is 'ab'.
  Iterable<bool> asBooleanArray() => (this as DBusArray).mapBoolean();

  /// Extracts the 16 bit signed integers inside this array. Only works if [signature] is 'an'.
  Iterable<int> asInt16Array() => (this as DBusArray).mapInt16();

  /// Extracts the 16 bit unsigned integers inside this array. Only works if [signature] is 'aq'.
  Iterable<int> asUint16Array() => (this as DBusArray).mapUint16();

  /// Extracts the 32 bit signed integers inside this array. Only works if [signature] is 'ai'.
  Iterable<int> asInt32Array() => (this as DBusArray).mapInt32();

  /// Extracts the 32 bit unsigned integers inside this array. Only works if [signature] is 'au'.
  Iterable<int> asUint32Array() => (this as DBusArray).mapUint32();

  /// Extracts the 64 bit signed integers inside this array. Only works if [signature] is 'ax'.
  Iterable<int> asInt64Array() => (this as DBusArray).mapInt64();

  /// Extracts the 64 bit unsigned integers inside this array. Only works if [signature] is 'at'.
  Iterable<int> asUint64Array() => (this as DBusArray).mapUint64();

  /// Extracts the 64 bit floating point numbers inside this array. Only works if [signature] is 'ad'.
  Iterable<double> asDoubleArray() => (this as DBusArray).mapDouble();

  /// Extracts the strings inside this array. Only works if [signature] is 'as'.
  Iterable<String> asStringArray() => (this as DBusArray).mapString();

  /// Extracts the object paths inside this array. Only works if [signature] is 'ao'.
  Iterable<DBusObjectPath> asObjectPathArray() =>
      (this as DBusArray).mapObjectPath();

  /// Extracts the signatures inside this array. Only works if [signature] is 'ag'.
  Iterable<DBusSignature> asSignatureArray() =>
      (this as DBusArray).mapSignature();

  /// Extracts the values inside this variant array. Only works if [signature] is 'av'.
  Iterable<DBusValue> asVariantArray() => (this as DBusArray).mapVariant();

  /// Extracts the resource handles inside this array of unix file descriptors. Only works if [signature] is 'ah'.
  Iterable<ResourceHandle> asUnixFdArray() => (this as DBusArray).mapUnixFd();

  /// Extracts the dictionary inside this vlaue. Only works if [signature] is a dictionary type, e.g 'a{os}'.
  Map<DBusValue, DBusValue> asDict() => (this as DBusDict).children;

  /// Extracts the string to variant dictionary inside this value. Only works if [signature] is 'a{sv}'.
  Map<String, DBusValue> asStringVariantDict() =>
      (this as DBusDict).mapStringVariant();
}

/// D-Bus representation of an unsigned 8 bit value.
class DBusByte extends DBusValue {
  /// A integer in the range [0, 255]
  final int value;

  /// Creates a new byte with the given [value].
  const DBusByte(this.value)
      : assert(value >= 0 && value <= 255, 'Byte must be in range [0, 255]');

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
  String toString() => '$runtimeType($value)';
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
  String toString() => '$runtimeType($value)';
}

/// D-Bus representation of a signed 16 bit integer.
class DBusInt16 extends DBusValue {
  /// An integer in the range [-32768, 32767]
  final int value;

  /// Creates a new signed 16 bit integer with the given [value].
  const DBusInt16(this.value)
      : assert(value >= -32768 && value <= 32767,
            'Int16 must be in range [-32768, 32767]');

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
  String toString() => '$runtimeType($value)';
}

/// D-Bus representation of an unsigned 16 bit integer.
class DBusUint16 extends DBusValue {
  /// An integer in the range [0, 65535]
  final int value;

  /// Creates a new unsigned 16 bit integer with the given [value].
  const DBusUint16(this.value)
      : assert(
            value >= 0 && value <= 65535, 'Uint16 must be in range [0, 65535]');

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
  String toString() => '$runtimeType($value)';
}

/// D-Bus representation of a signed 32 bit integer.
class DBusInt32 extends DBusValue {
  /// An integer in the range [-2147483648, 2147483647]
  final int value;

  /// Creates a new signed 32 bit integer with the given [value].
  const DBusInt32(this.value)
      : assert(value >= -2147483648 && value <= 2147483647,
            'Int32 must be in range [-2147483648, 2147483647]');

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
  String toString() => '$runtimeType($value)';
}

/// D-Bus representation of an unsigned 32 bit integer.
class DBusUint32 extends DBusValue {
  /// An integer in the range [0, 4294967295]
  final int value;

  /// Creates a new unsigned 32 bit integer with the given [value].
  const DBusUint32(this.value)
      : assert(value >= 0 && value <= 4294967295,
            'Uint32 must be in range [0, 4294967295]');

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
  String toString() => '$runtimeType($value)';
}

/// D-Bus representation of a signed 64 bit integer.
class DBusInt64 extends DBusValue {
  /// An integer in the range [-9223372036854775808, 9223372036854775807]
  final int value;

  /// Creates a new signed 64 bit integer with the given [value].
  const DBusInt64(this.value)
      : assert(value >= -(1 << 63) && value <= (1 << 63) - 1,
            'Int64 must be in range [-9223372036854775808, 9223372036854775807]');

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
  String toString() => '$runtimeType($value)';
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
  String toString() => '$runtimeType($value)';
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
  String toString() => '$runtimeType($value)';
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
  String toString() => "$runtimeType('$value')";
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

  /// The root object path ("/").
  static const DBusObjectPath root = DBusObjectPath.unchecked('/');

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
        value.startsWith('${namespace.value}/');
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
  String toString() => "$runtimeType('$value')";
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
/// * 'h' → [DBusUnixFd]
/// * `(xyz...)` → [DBusStruct] (`x`, `y`, `z` represent the child value signatures).
/// * `av` → [DBusArray] (v represents the array value signature).
/// * `a{kv}` → [DBusDict] (`k` and `v` represent the key and value signatures).
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

  /// Create a new D-Bus signature with the given [value].
  ///
  /// No checking is performed on the validity of [value].
  /// This function is useful when you need a constant value (e.g. for a
  /// parameter default value). In all other cases use the standard constructor.
  const DBusSignature.unchecked(this.value);

  /// Empty "void" signature.
  static const empty = DBusSignature.unchecked(''); // void :(

  /// D-Bus signature of an unsigned 8 bit value ([DBusByte]).
  static const byte = DBusSignature.unchecked('y');

  /// D-Bus signature of a boolean value ([DBusBoolean]).
  static const boolean = DBusSignature.unchecked('b');

  /// D-Bus signature of a signed 16 bit integer ([DBusInt16]).
  static const int16 = DBusSignature.unchecked('n');

  /// D-Bus signature of an unsigned 16 bit integer ([DBusUint16]).
  static const uint16 = DBusSignature.unchecked('q');

  /// D-Bus signature of a signed 32 bit integer ([DBusInt32]).
  static const int32 = DBusSignature.unchecked('i');

  /// D-Bus signature of an unsigned 32 bit integer ([DBusUint32]).
  static const uint32 = DBusSignature.unchecked('u');

  /// D-Bus signature of a signed 64 bit integer ([DBusInt64]).
  static const int64 = DBusSignature.unchecked('x');

  /// D-Bus signature of an unsigned 64 bit integer ([DBusUint64]).
  static const uint64 = DBusSignature.unchecked('t');

  /// D-Bus signature of a 64 bit floating point value ([DBusDouble]).
  static const double = DBusSignature.unchecked('d');

  /// D-Bus signature of a Unicode text string ([DBusString]).
  static const string = DBusSignature.unchecked('s');

  /// D-Bus signature of an object path ([DBusObjectPath]).
  static const objectPath = DBusSignature.unchecked('o');

  /// Create a new D-Bus signature of a variant that contains any D-Bus type ([DBusVariant]).
  static const variant = DBusSignature.unchecked('v');

  /// D-Bus signature of a Unix file descriptor ([DBusUnixFd]).
  static const unixFd = DBusSignature.unchecked('h');

  /// Create a new D-Bus signature of an array of the given [type] ([DBusArray]).
  factory DBusSignature.array(DBusSignature type) =>
      DBusSignature('a${type.value}');

  /// Create a new D-Bus signature of a dictionary of the given [key] and [value] types ([DBusDict]).
  factory DBusSignature.dict(DBusSignature key, DBusSignature value) =>
      DBusSignature('a{${key.value}${value.value}}');

  /// Create a new D-Bus signature of a struct of the given [types] ([DBusStruct]).
  factory DBusSignature.struct(Iterable<DBusSignature> types) =>
      DBusSignature('(${types.map((t) => t.value).join()})');

  /// Create a new D-Bus signature of a value that contains a D-Bus type or null ([DBusMaybe]).
  factory DBusSignature.maybe(DBusSignature type) =>
      DBusSignature('m${type.value}');

  /// Splits this signature into a list of signatures with single complete types, e.g. 'asbo' -> ['as', 'b', 'o']
  List<DBusSignature> split() {
    var signatures = <DBusSignature>[];

    var index = 0;
    while (index < value.length) {
      var end = _findChildSignatureEnd(value, index);
      // The signature was validated at creation, so this assertion should never fail.
      assert(end >= 0);
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
  String toString() => "$runtimeType('$value')";
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
  String toString() => '$runtimeType(${value.toString()})';
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
    return DBusSignature('m${valueSignature.value}');
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
  int get hashCode => Object.hash(valueSignature, value);

  @override
  String toString() => '$runtimeType($valueSignature, ${value?.toString()})';
}

/// D-Bus value that contains a Unix file descriptor.
class DBusUnixFd extends DBusValue {
  /// The resource handle containing this file descriptor.
  final ResourceHandle handle;

  /// Creates a new file descriptor containing [handle].
  const DBusUnixFd(this.handle);

  @override
  DBusSignature get signature {
    return DBusSignature('h');
  }

  @override
  dynamic toNative() {
    return this;
  }

  @override
  bool operator ==(other) => other is DBusUnixFd && other.handle == handle;

  @override
  int get hashCode => handle.hashCode;

  @override
  String toString() {
    return '$runtimeType()';
  }
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
    return DBusSignature('($signature)');
  }

  @override
  dynamic toNative() {
    return children.map((value) => value.toNative());
  }

  @override
  bool operator ==(other) =>
      other is DBusStruct && _listsEqual(other.children, children);

  @override
  int get hashCode => Object.hashAll(children);

  @override
  String toString() {
    var childrenText = <String>[];
    for (var child in children) {
      childrenText.add(child.toString());
    }
    return "$runtimeType([${childrenText.join(', ')}])";
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

  /// Creates a new array of boolean values.
  factory DBusArray.boolean(Iterable<bool> values) {
    return DBusArray(
        DBusSignature('b'), values.map((value) => DBusBoolean(value)));
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

  /// Creates a new array of D-Bus signatures.
  factory DBusArray.signature(Iterable<DBusSignature> values) {
    return DBusArray(DBusSignature('g'), values);
  }

  /// Creates a new array of D-Bus variants.
  factory DBusArray.variant(Iterable<DBusValue> values) {
    return DBusArray(
        DBusSignature('v'), values.map((value) => DBusVariant(value)));
  }

  /// Creates a new array of Unix file descriptors.
  factory DBusArray.unixFd(Iterable<ResourceHandle> values) {
    return DBusArray(
        DBusSignature('h'), values.map((value) => DBusUnixFd(value)));
  }

  @override
  DBusSignature get signature {
    return DBusSignature('a${childSignature.value}');
  }

  @override
  dynamic toNative() {
    return children.map((value) => value.toNative());
  }

  /// Maps the contents of this array into native types. Only works if [childSignature] is 'y'.
  Iterable<int> mapByte() => children.map((value) => value.asByte());

  /// Maps the contents of this array into native types. Only works if [childSignature] is 'b'.
  Iterable<bool> mapBoolean() => children.map((value) => value.asBoolean());

  /// Maps the contents of this array into native types. Only works if [childSignature] is 'n'.
  Iterable<int> mapInt16() => children.map((value) => value.asInt16());

  /// Maps the contents of this array into native types. Only works if [childSignature] is 'q'.
  Iterable<int> mapUint16() => children.map((value) => value.asUint16());

  /// Maps the contents of this array into native types. Only works if [childSignature] is 'i'.
  Iterable<int> mapInt32() => children.map((value) => value.asInt32());

  /// Maps the contents of this array into native types. Only works if [childSignature] is 'u'.
  Iterable<int> mapUint32() => children.map((value) => value.asUint32());

  /// Maps the contents of this array into native types. Only works if [childSignature] is 'x'.
  Iterable<int> mapInt64() => children.map((value) => value.asInt64());

  /// Maps the contents of this array into native types. Only works if [childSignature] is 't'.
  Iterable<int> mapUint64() => children.map((value) => value.asUint64());

  /// Maps the contents of this array into native types. Only works if [childSignature] is 'd'.
  Iterable<double> mapDouble() => children.map((value) => value.asDouble());

  /// Maps the contents of this array into native types. Only works if [childSignature] is 's'.
  Iterable<String> mapString() => children.map((value) => value.asString());

  /// Maps the contents of this array into native types. Only works if [childSignature] is 'o'.
  Iterable<DBusObjectPath> mapObjectPath() =>
      children.map((value) => value.asObjectPath());

  /// Maps the contents of this array into native types. Only works if [childSignature] is 'g'.
  Iterable<DBusSignature> mapSignature() =>
      children.map((value) => value.asSignature());

  /// Maps the contents of this array into native types. Only works if [childSignature] is 'v'.
  Iterable<DBusValue> mapVariant() =>
      children.map((value) => value.asVariant());

  /// Maps the contents of this array into native types. Only works if [childSignature] is 'h'.
  Iterable<ResourceHandle> mapUnixFd() =>
      children.map((value) => value.asUnixFd());

  @override
  bool operator ==(other) =>
      other is DBusArray &&
      other.childSignature == childSignature &&
      _listsEqual(other.children, children);

  @override
  int get hashCode => Object.hashAll(children);

  @override
  String toString() {
    switch (childSignature.value) {
      case 'y':
        var values = children.map((child) => child.asByte()).join(', ');
        return 'DBusArray.byte([$values])';
      case 'b':
        var values = children.map((child) => child.asBoolean()).join(', ');
        return 'DBusArray.boolean([$values])';
      case 'n':
        var values = children.map((child) => child.asInt16()).join(', ');
        return 'DBusArray.int16([$values])';
      case 'q':
        var values = children.map((child) => child.asUint16()).join(', ');
        return 'DBusArray.uint16([$values])';
      case 'i':
        var values = children.map((child) => child.asInt32()).join(', ');
        return 'DBusArray.int32([$values])';
      case 'u':
        var values = children.map((child) => child.asUint32()).join(', ');
        return 'DBusArray.uint32([$values])';
      case 'x':
        var values = children.map((child) => child.asInt64()).join(', ');
        return 'DBusArray.int64([$values])';
      case 't':
        var values = children.map((child) => child.asUint64()).join(', ');
        return 'DBusArray.uint64([$values])';
      case 'd':
        var values = children.map((child) => child.asDouble()).join(', ');
        return 'DBusArray.double([$values])';
      case 's':
        var values =
            children.map((child) => "'${child.asString()}'").join(', ');
        return 'DBusArray.string([$values])';
      case 'o':
        var values =
            children.map((child) => child.asObjectPath().toString()).join(', ');
        return 'DBusArray.objectPath([$values])';
      case 'g':
        var values =
            children.map((child) => child.asSignature().toString()).join(', ');
        return 'DBusArray.signature([$values])';
      case 'v':
        var values = children.map((child) => child.asVariant()).join(', ');
        return 'DBusArray.variant([$values])';
      case 'h':
        var values = children.map((child) => child.asUnixFd()).join(', ');
        return 'DBusArray.unixFd([$values])';
      default:
        var childrenText = <String>[];
        for (var child in children) {
          childrenText.add(child.toString());
        }
        return "$runtimeType($childSignature, [${childrenText.join(', ')}])";
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

  /// Maps the contents of this array into native types. Only works if [keySignature] is 's' and [valueSignature] is 'v'.
  Map<String, DBusValue> mapStringVariant() =>
      children.map((key, value) => MapEntry(key.asString(), value.asVariant()));

  @override
  bool operator ==(other) =>
      other is DBusDict &&
      other.keySignature == keySignature &&
      other.valueSignature == valueSignature &&
      _mapsEqual(other.children, children);

  @override
  int get hashCode => Object.hashAll(
      children.entries.map((entry) => Object.hash(entry.key, entry.value)));

  @override
  String toString() {
    if (keySignature.value == 's' && valueSignature.value == 'v') {
      var values = children.entries
          .map((entry) =>
              "'${entry.key.asString()}': ${entry.value.asVariant().toString()}")
          .join(', ');
      return 'DBusDict.stringVariant({$values})';
    } else {
      var childrenText = <String>[];
      children.forEach((key, value) {
        childrenText.add('${key.toString()}: ${value.toString()}');
      });
      var values = children.entries
          .map((entry) => '${entry.key.toString()}: ${entry.value.toString()}')
          .join(', ');
      return '$runtimeType($keySignature, $valueSignature, {$values})';
    }
  }
}
