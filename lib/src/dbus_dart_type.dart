import 'package:dbus/dbus.dart';

/// Gets an object that indicates how to generate Dart code for a given D-Bus type.
DBusDartType getDartType(DBusSignature signature) {
  var value = signature.value;
  if (value == 'y') {
    return DBusByteType();
  } else if (value == 'n') {
    return DBusInt16Type();
  } else if (value == 'q') {
    return DBusUint16Type();
  } else if (value == 'i') {
    return DBusInt32Type();
  } else if (value == 'u') {
    return DBusUint32Type();
  } else if (value == 'x') {
    return DBusInt64Type();
  } else if (value == 't') {
    return DBusUint64Type();
  } else if (value == 'b') {
    return DBusBoolType();
  } else if (value == 'd') {
    return DBusDoubleType();
  } else if (value == 's') {
    return DBusStringType();
  } else if (value == 'o') {
    return DBusObjectPathType();
  } else if (value == 'v') {
    return DBusVariantType();
  } else if (value.startsWith('a{') && value.endsWith('}')) {
    var signatures =
        DBusSignature(value.substring(2, value.length - 1)).split();
    if (signatures.length != 2) {
      return DBusComplexType();
    }
    return DBusDictType(signatures[0], signatures[1]);
  } else if (value.startsWith('a')) {
    var childSignature = DBusSignature(signature.value.substring(1));
    return DBusArrayType(childSignature);
  } else {
    return DBusComplexType();
  }
}

/// Class that generates Dart code for a D-Bus data type.
abstract class DBusDartType {
  // Native Dart type for the API user to interact with, e.g. 'int', 'String'.
  String nativeType;

  // Dart type to pass to dbus.dart, e.g. 'DBusUint32', 'DBusString'.
  String dbusType;

  // Converts a native Dart variable to a D-Bus data type. e.g. 'foo' -> 'DBusInteger(foo)'.
  String nativeToDBus(String name);

  // Converts a DBusValue object to a native type. e.g. 'foo' -> '(foo as DBusInteger).value'.
  String dbusToNative(String name);
}

/// Generates Dart code for the boolean D-Bus type.
class DBusBoolType extends DBusDartType {
  @override
  String get nativeType {
    return 'bool';
  }

  @override
  String get dbusType {
    return 'DBusBoolean';
  }

  @override
  String nativeToDBus(String name) {
    return 'DBusBoolean(${name})';
  }

  @override
  String dbusToNative(String name) {
    return '(${name} as DBusBoolean).value';
  }
}

/// Generates Dart code for D-Bus integer types.
abstract class DBusIntegerType extends DBusDartType {
  @override
  String get nativeType {
    return 'int';
  }
}

class DBusByteType extends DBusIntegerType {
  @override
  String get dbusType {
    return 'DBusByte';
  }

  @override
  String nativeToDBus(String name) {
    return 'DBusByte(${name})';
  }

  @override
  String dbusToNative(String name) {
    return '(${name} as DBusByte).value';
  }
}

/// Generates Dart code for the signed 16 bit integer D-Bus type.
class DBusInt16Type extends DBusIntegerType {
  @override
  String get dbusType {
    return 'DBusInt16';
  }

  @override
  String nativeToDBus(String name) {
    return 'DBusInt16(${name})';
  }

  @override
  String dbusToNative(String name) {
    return '(${name} as DBusInt16).value';
  }
}

/// Generates Dart code for the unsigned 16 bit integer D-Bus type.
class DBusUint16Type extends DBusIntegerType {
  @override
  String get dbusType {
    return 'DBusUint16';
  }

  @override
  String nativeToDBus(String name) {
    return 'DBusUint16(${name})';
  }

  @override
  String dbusToNative(String name) {
    return '(${name} as DBusUint16).value';
  }
}

/// Generates Dart code for the signed 32 bit integer D-Bus type.
class DBusInt32Type extends DBusIntegerType {
  @override
  String get dbusType {
    return 'DBusInt32';
  }

  @override
  String nativeToDBus(String name) {
    return 'DBusInt32(${name})';
  }

  @override
  String dbusToNative(String name) {
    return '(${name} as DBusInt32).value';
  }
}

/// Generates Dart code for the unsigned 32 bit integer D-Bus type.
class DBusUint32Type extends DBusIntegerType {
  @override
  String get dbusType {
    return 'DBusUint32';
  }

  @override
  String nativeToDBus(String name) {
    return 'DBusUint32(${name})';
  }

  @override
  String dbusToNative(String name) {
    return '(${name} as DBusUint32).value';
  }
}

/// Generates Dart code for the signed 64 bit integer D-Bus type.
class DBusInt64Type extends DBusIntegerType {
  @override
  String get dbusType {
    return 'DBusInt64';
  }

  @override
  String nativeToDBus(String name) {
    return 'DBusInt64(${name})';
  }

  @override
  String dbusToNative(String name) {
    return '(${name} as DBusInt64).value';
  }
}

/// Generates Dart code for the unsigned 64 bit integer D-Bus type.
class DBusUint64Type extends DBusIntegerType {
  @override
  String get dbusType {
    return 'DBusUint64';
  }

  @override
  String nativeToDBus(String name) {
    return 'DBusUint64(${name})';
  }

  @override
  String dbusToNative(String name) {
    return '(${name} as DBusUint64).value';
  }
}

/// Generates Dart code for the double D-Bus type.
class DBusDoubleType extends DBusDartType {
  @override
  String get nativeType {
    return 'double';
  }

  @override
  String get dbusType {
    return 'DBusDouble';
  }

  @override
  String nativeToDBus(String name) {
    return 'DBusDouble(${name})';
  }

  @override
  String dbusToNative(String name) {
    return '(${name} as DBusDouble).value';
  }
}

/// Generates Dart code for the string D-Bus type.
class DBusStringType extends DBusDartType {
  @override
  String get nativeType {
    return 'String';
  }

  @override
  String get dbusType {
    return 'DBusString';
  }

  @override
  String nativeToDBus(String name) {
    return 'DBusString(${name})';
  }

  @override
  String dbusToNative(String name) {
    return '(${name} as DBusString).value';
  }
}

/// Generates Dart code for the object path D-Bus type.
class DBusObjectPathType extends DBusStringType {
  @override
  String get dbusType {
    return 'DBusObjectPath';
  }

  @override
  String nativeToDBus(String name) {
    return 'DBusObjectPath(${name})';
  }

  @override
  String dbusToNative(String name) {
    return '(${name} as DBusObjectPath).value';
  }
}

/// Generates Dart code for the variant D-Bus type.
class DBusVariantType extends DBusDartType {
  @override
  String get nativeType {
    return 'DBusValue';
  }

  @override
  String get dbusType {
    return 'DBusVariant';
  }

  @override
  String nativeToDBus(String name) {
    return 'DBusVariant(${name})';
  }

  @override
  String dbusToNative(String name) {
    return '(${name} as DBusVariant).value';
  }
}

/// Generates Dart code for the array D-Bus type.
class DBusArrayType extends DBusDartType {
  final DBusSignature childSignature;

  DBusArrayType(this.childSignature);

  @override
  String get nativeType {
    var childType = getDartType(childSignature);
    return 'List<${childType.nativeType}>';
  }

  @override
  String get dbusType {
    return 'DBusArray';
  }

  @override
  String nativeToDBus(String name) {
    var childType = getDartType(childSignature);
    var convertedValue = childType.nativeToDBus('child');
    return "DBusArray(DBusSignature('${childSignature.value}'), ${name}.map((child) => ${convertedValue}))";
  }

  @override
  String dbusToNative(String name) {
    var childType = getDartType(childSignature);
    var convertedValue = childType.dbusToNative('child');
    return '(${name} as DBusArray).children.map((child) => ${convertedValue}).toList()';
  }
}

/// Generates Dart code for the dict D-Bus type.
class DBusDictType extends DBusDartType {
  final DBusSignature keySignature;
  final DBusSignature valueSignature;

  DBusDictType(this.keySignature, this.valueSignature);

  @override
  String get nativeType {
    var keyType = getDartType(keySignature);
    var valueType = getDartType(valueSignature);
    return 'Map<${keyType.nativeType}, ${valueType.nativeType}>';
  }

  @override
  String get dbusType {
    return 'DBusDict';
  }

  @override
  String nativeToDBus(String name) {
    var keyType = getDartType(keySignature);
    var convertedKey = keyType.nativeToDBus('key');
    var valueType = getDartType(valueSignature);
    var convertedValue = valueType.nativeToDBus('value');
    return "DBusDict(DBusSignature('${keySignature.value}'), DBusSignature('${valueSignature.value}'), ${name}.map((key, value) => MapEntry(${convertedKey}, ${convertedValue})))";
  }

  @override
  String dbusToNative(String name) {
    var keyType = getDartType(keySignature);
    var convertedKey = keyType.dbusToNative('key');
    var valueType = getDartType(valueSignature);
    var convertedValue = valueType.dbusToNative('value');
    return '(${name} as DBusDict).children.map((key, value) => MapEntry(${convertedKey}, ${convertedValue}))';
  }
}

/// Generates Dart code for the D-Bus types that can't be represented with native Dart types.
class DBusComplexType extends DBusDartType {
  @override
  String get nativeType {
    return 'DBusValue';
  }

  @override
  String get dbusType {
    return 'DBusValue';
  }

  @override
  String nativeToDBus(String name) {
    return name;
  }

  @override
  String dbusToNative(String name) {
    return name;
  }
}
