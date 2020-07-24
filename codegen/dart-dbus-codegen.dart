import 'dart:convert';
import 'dart:io';
import 'package:dbus_client/dbus_client.dart';

// FIXME: Check for method name collisions

main(List<String> args) async {
  if (args.length != 1) {
    print('''Usage: dart-dbus-codegen [interface.xml]

Generates a D-Bus implementation for the given interface file.''');
    return;
  }

  var interfaceFilename = args[0];
  var xml = await File(interfaceFilename).readAsString();
  var nodes = parseDBusIntrospectXml(xml);
  print(generateDartModule(nodes));
}

/// Generates a Dart module for the given introspection data.
String generateDartModule(List<DBusIntrospectNode> nodes) {
  var classes = List<String>();
  for (var node in nodes) {
    classes.add(generateDartClass(node));
  }

  var source = '';
  source += "import 'package:dbus_client/dbus_client.dart';\n";
  source += '\n';
  source += classes.join('\n');

  return source;
}

/// Generates a Dart class for the given introspection node.
String generateDartClass(DBusIntrospectNode node) {
  var className = 'Foo'; // FIXME

  var dartMethods = new List<String>();

  var inputTypes = Set<DBusSignature>();
  var outputTypes = Set<DBusSignature>();

  for (var interface in node.interfaces) {
    for (var property in interface.properties) {
      var type = getDartType(property.type);

      if (property.access == DBusPropertyAccess.readwrite ||
          property.access == DBusPropertyAccess.read) {
        outputTypes.add(property.type);

        var convertedValue = type.convertOutArg('value');
        var method = '';
        method += '  Future<${type.nativeType}> get ${property.name} async {\n';
        method +=
            "    var value = await getProperty('${interface.name}', '${property.name}');\n";
        method += '    return ${convertedValue};\n';
        method += '  }\n';
        dartMethods.add(method);
      }

      if (property.access == DBusPropertyAccess.readwrite ||
          property.access == DBusPropertyAccess.write) {
        inputTypes.add(property.type);

        var convertedValue = type.convertInArg('value');
        var method = '';
        method += '  set ${property.name} (${type.nativeType} value) {\n';
        method +=
            "    setProperty('${interface.name}', '${property.name}', ${convertedValue});\n";
        method += '  }\n';
        dartMethods.add(method);
      }
    }

    for (var method in interface.methods) {
      var argValues = List<String>();
      var argsList = List<String>();
      for (var arg in method.args) {
        if (arg.direction == DBusArgumentDirection.in_) {
          inputTypes.add(arg.type);

          var type = getDartType(arg.type);
          var argName =
              arg.name != null ? arg.name : 'arg_${method.args.indexOf(arg)}';
          var convertedValue = type.convertInArg(argName);
          argsList.add('${type.nativeType} ${argName}');
          argValues.add(convertedValue);
        }
      }

      var returnTypes = List<String>();
      var returnValues = List<String>();
      for (var arg in method.args) {
        if (arg.direction == DBusArgumentDirection.out) {
          outputTypes.add(arg.type);

          var type = getDartType(arg.type);
          var argName =
              arg.name != null ? arg.name : 'arg_${method.args.indexOf(arg)}';
          var returnValue = 'result[${returnTypes.length}]';
          returnTypes.add(type.nativeType);
          var convertedName = '_${argName}';
          var convertedValue = type.convertOutArg(returnValue);
          returnValues.add(convertedValue);
        }
      }

      String returnType;
      if (returnTypes.length == 0) {
        returnType = 'Future';
      } else if (returnTypes.length == 1) {
        returnType = 'Future<${returnTypes[0]}>';
      } else {
        returnType = 'Future<List<DBusValue>>';
      }

      var methodCall =
          "await callMethod('${interface.name}', '${method.name}', [${argValues.join(', ')}]);";

      var dartMethod = '';
      dartMethod +=
          '  ${returnType} ${method.name}(${argsList.join(', ')}) async {\n';
      if (returnTypes.length == 0) {
        dartMethod += '    ${methodCall}\n';
      } else if (returnTypes.length == 1) {
        dartMethod += '    var result = ${methodCall}\n';
        dartMethod += '    return ${returnValues[0]};\n';
      } else {
        dartMethod += '    return ${methodCall};\n';
      }
      dartMethod += '  }\n';
      dartMethods.add(dartMethod);
    }
  }

  // Generate helper methods.
  for (var type in inputTypes) {
    var dartType = getDartType(type);
    var method = dartType.inArgHelperMethod();
    if (method != null) dartMethods.add(method);
  }
  for (var type in outputTypes) {
    var dartType = getDartType(type);
    var method = dartType.outArgHelperMethod();
    if (method != null) dartMethods.add(method);
  }

  var source = '';

  source += "class ${className} extends DBusObjectProxy {\n";
  source +=
      '''  ${className}(DBusClient client, String destination, String path) : super(client, destination, path);\n''';
  source += '\n';
  source += dartMethods.join('\n');
  source += '}\n';

  return source;
}

/// Converts a D-Bus signature to a valid Dart symbol
String signatureToSymbol(DBusSignature signature) {
  var symbol = '';

  for (var c in utf8.encode(signature.value)) {
    if ((c >= 0x41 /* 'A' */ && c <= 0x5a /* 'Z' */) ||
        (c >= 0x61 /* 'a' */ && c <= 0x7a /* 'z' */)) {
      symbol += String.fromCharCode(c);
    } else {
      symbol += '_' + c.toRadixString(16).padLeft(2, '0');
    }
  }

  return symbol;
}

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
    if (signatures.length != 2) return DBusComplexType();
    return DBusDictType(signatures[0], signatures[1]);
  } else if (value.startsWith('a')) {
    var childSignature = DBusSignature(signature.value.substring(1));
    return DBusArrayType(childSignature);
  } else {
    return DBusComplexType();
  }
}

abstract class DBusDartType {
  // Native type for the API user to interact with.
  String nativeType;
  String dbusType;

  // Converts an input argument to a DBusValue.
  String convertInArg(String name);

  // Converts an out arg from a DBusValue.
  String convertOutArg(String name);

  // Helper method required for access in args, or null.
  String inArgHelperMethod() {
    return null;
  }

  // Helper method required for access out args, or null.
  String outArgHelperMethod() {
    return null;
  }
}

class DBusBoolType extends DBusDartType {
  String get nativeType {
    return 'bool';
  }

  String get dbusType {
    return 'DBusBoolean';
  }

  String convertInArg(String name) {
    return 'DBusBoolean(${name})';
  }

  String convertOutArg(String name) {
    return '(${name} as DBusBoolean).value';
  }
}

abstract class DBusIntegerType extends DBusDartType {
  String get nativeType {
    return 'int';
  }
}

class DBusByteType extends DBusIntegerType {
  String get dbusType {
    return 'DBusByte';
  }

  String convertInArg(String name) {
    return 'DBusByte(${name})';
  }

  String convertOutArg(String name) {
    return '(${name} as DBusByte).value';
  }
}

class DBusInt16Type extends DBusIntegerType {
  String get dbusType {
    return 'DBusInt16';
  }

  String convertInArg(String name) {
    return 'DBusInt16(${name})';
  }

  String convertOutArg(String name) {
    return '(${name} as DBusInt16).value';
  }
}

class DBusUint16Type extends DBusIntegerType {
  String get dbusType {
    return 'DBusUint16';
  }

  String convertInArg(String name) {
    return 'DBusUint16(${name})';
  }

  String convertOutArg(String name) {
    return '(${name} as DBusUint16).value';
  }
}

class DBusInt32Type extends DBusIntegerType {
  String get dbusType {
    return 'DBusInt32';
  }

  String convertInArg(String name) {
    return 'DBusInt32(${name})';
  }

  String convertOutArg(String name) {
    return '(${name} as DBusInt32).value';
  }
}

class DBusUint32Type extends DBusIntegerType {
  String get dbusType {
    return 'DBusUint32';
  }

  String convertInArg(String name) {
    return 'DBusUint32(${name})';
  }

  String convertOutArg(String name) {
    return '(${name} as DBusUint32).value';
  }
}

class DBusInt64Type extends DBusIntegerType {
  String get dbusType {
    return 'DBusInt64';
  }

  String convertInArg(String name) {
    return 'DBusInt64(${name})';
  }

  String convertOutArg(String name) {
    return '(${name} as DBusInt64).value';
  }
}

class DBusUint64Type extends DBusIntegerType {
  String get dbusType {
    return 'DBusUint64';
  }

  String convertInArg(String name) {
    return 'DBusUint64(${name})';
  }

  String convertOutArg(String name) {
    return '(${name} as DBusUint64).value';
  }
}

class DBusDoubleType extends DBusDartType {
  String get nativeType {
    return 'double';
  }

  String get dbusType {
    return 'DBusDouble';
  }

  String convertInArg(String name) {
    return 'DBusDouble(${name})';
  }

  String convertOutArg(String name) {
    return '(${name} as DBusDouble).value';
  }
}

class DBusStringType extends DBusDartType {
  String get nativeType {
    return 'String';
  }

  String get dbusType {
    return 'DBusString';
  }

  String convertInArg(String name) {
    return 'DBusString(${name})';
  }

  String convertOutArg(String name) {
    return '(${name} as DBusString).value';
  }
}

class DBusObjectPathType extends DBusStringType {
  String get dbusType {
    return 'DBusObjectPath';
  }

  String convertInArg(String name) {
    return 'DBusObjectPath(${name})';
  }

  String convertOutArg(String name) {
    return '(${name} as DBusObjectPath).value';
  }
}

class DBusVariantType extends DBusDartType {
  String get nativeType {
    return 'DBusValue';
  }

  String get dbusType {
    return 'DBusVariant';
  }

  String convertInArg(String name) {
    return 'DBusVariant(${name})';
  }

  String convertOutArg(String name) {
    return '(${name} as DBusVariant).value';
  }
}

class DBusArrayType extends DBusDartType {
  final DBusSignature childSignature;

  DBusArrayType(this.childSignature);

  String get nativeType {
    var childType = getDartType(childSignature);
    return 'List<${childType.nativeType}>';
  }

  String get dbusType {
    return 'DBusArray';
  }

  String get toDBusArrayMethodName {
    return '_nativeToDBusArray_${signatureToSymbol(childSignature)}';
  }

  String get toNativeMethodName {
    return '_dBusArrayToNative_${signatureToSymbol(childSignature)}';
  }

  String convertInArg(String name) {
    return '${toDBusArrayMethodName}(${name})';
  }

  String convertOutArg(String name) {
    return '${toNativeMethodName}(${name} as DBusArray)';
  }

  String inArgHelperMethod() {
    var childType = getDartType(childSignature);
    var convertedValue = childType.convertInArg('value');
    var method = '';
    method += '  DBusArray ${toDBusArrayMethodName}(${nativeType} values) {\n';
    method += '    var wrappedValues = List<DBusValue>();\n';
    method += '    for (var value in values) {\n';
    method += '      wrappedValues.add(${convertedValue});\n';
    method += '    }\n';
    method +=
        "    return DBusArray(DBusSignature('${childSignature.value}'), wrappedValues);\n";
    method += '  }\n';
    return method;
  }

  String outArgHelperMethod() {
    var childType = getDartType(childSignature);
    var convertedValue = childType.convertOutArg('value');
    var method = '';
    method += '  ${nativeType} ${toNativeMethodName}(DBusArray value) {\n';
    method += '    var nativeValue = ${nativeType}();\n';
    method += '    for (var child in value.children) {\n';
    method += '      nativeValue.add(${convertedValue});\n';
    method += '    }\n';
    method += '    return nativeValue;\n';
    method += '  }\n';
    return method;
  }
}

class DBusDictType extends DBusDartType {
  final DBusSignature keySignature;
  final DBusSignature valueSignature;

  DBusDictType(this.keySignature, this.valueSignature);

  String get nativeType {
    var keyType = getDartType(keySignature);
    var valueType = getDartType(valueSignature);
    return 'Map<${keyType.nativeType}, ${valueType.nativeType}>';
  }

  String get dbusType {
    return 'DBusDict';
  }

  String get toDBusDictMethodName {
    return '_nativeToDBusDict_${signatureToSymbol(keySignature)}__${signatureToSymbol(valueSignature)}';
  }

  String get toNativeMethodName {
    return '_dBusDictToNative_${signatureToSymbol(keySignature)}__${signatureToSymbol(valueSignature)}';
  }

  String convertInArg(String name) {
    return '${toDBusDictMethodName}(${name})';
  }

  String convertOutArg(String name) {
    return '${toNativeMethodName}(${name} as DBusArray)';
  }

  String inArgHelperMethod() {
    var keyType = getDartType(keySignature);
    var convertedKey = keyType.convertInArg('key');
    var valueType = getDartType(valueSignature);
    var convertedValue = valueType.convertInArg('value');
    var method = '';
    method += '  DBusDict ${toDBusDictMethodName}(${nativeType} values) {\n';
    method += '    var wrappedValues = Map<DBusValue, DBusValue>();\n';
    method += '    values.forEach((key, value) {\n';
    method +=
        '      wrappedValues.update(${convertedKey}, (e) => ${convertedValue});\n';
    method += '    });\n';
    method +=
        "    return DBusDict(DBusSignature('${keySignature.value}'), DBusSignature('${valueSignature.value}'), wrappedValues);\n";
    method += '  }\n';
    return method;
  }

  String outArgHelperMethod() {
    var keyType = getDartType(keySignature);
    var convertedKey = keyType.convertOutArg('key');
    var valueType = getDartType(valueSignature);
    var convertedValue = valueType.convertOutArg('value');
    var method = '';
    method += '  ${nativeType} ${toNativeMethodName}(DBusDict value) {\n';
    method += '    var nativeValue = ${nativeType}();\n';
    method += '    value.children.forEach((key, value) {\n';
    method +=
        '      nativeValue.update(${convertedKey}, (e) => ${convertedValue});\n';
    method += '    });\n';
    method += '    return nativeValue;\n';
    method += '  }\n';
    return method;
  }
}

class DBusComplexType extends DBusDartType {
  String get nativeType {
    return 'DBusValue';
  }

  String get dbusType {
    return 'DBusValue';
  }

  String convertInArg(String name) {
    return name;
  }

  String convertOutArg(String name) {
    return name;
  }
}
