import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:dbus/dbus.dart';
import 'package:dbus/src/dbus_dart_type.dart';

/// Command that generates a DBusObject class from an introspection XML file.
class GenerateObjectCommand extends Command {
  @override
  final name = 'generate-object';

  @override
  final description = 'Generates a DBusObject to register on the D-Bus.';

  GenerateObjectCommand() {
    argParser.addOption('output',
        abbr: 'o', valueHelp: 'filename', help: 'Dart file to write to');
    argParser.addOption('class-name',
        valueHelp: 'ClassName', help: 'Class name to use');
  }

  @override
  void run() async {
    if (argResults?.rest.length != 1) {
      usageException(
          '$name requires a single D-Bus interface file to be provided.');
    }
    var filename = argResults!.rest[0];
    generateModule(name, argResults?['class-name'], generateObjectClass,
        filename, argResults?['output']);
  }
}

/// Command that generates a DBusRemoteObject class from an introspection XML file.
class GenerateRemoteObjectCommand extends Command {
  @override
  final name = 'generate-remote-object';

  @override
  final description =
      'Generates a DBusRemoteObject to access an object on the D-Bus.';

  GenerateRemoteObjectCommand() {
    argParser.addOption('output',
        abbr: 'o', valueHelp: 'filename', help: 'Dart file to write to');
    argParser.addOption('class-name',
        valueHelp: 'ClassName', help: 'Class name to use');
  }

  @override
  void run() async {
    if (argResults?.rest.length != 1) {
      usageException(
          '$name requires a single D-Bus interface file to be provided.');
    }
    var filename = argResults!.rest[0];
    generateModule(name, argResults?['class-name'], generateRemoteObjectClass,
        filename, argResults?['output']);
  }
}

void main(List<String> args) async {
  var runner = CommandRunner('dart-dbus',
      'A tool to generate Dart classes from D-Bus interface defintions.');
  runner.addCommand(GenerateObjectCommand());
  runner.addCommand(GenerateRemoteObjectCommand());
  await runner.run(args).catchError((error) {
    if (error is! UsageException) {
      throw error;
    }
    print(error);
    exit(1);
  });
}

/// Generates Dart source from the given interface in [filename] and writes it to [outputFilename].
void generateModule(
    String command,
    String? className,
    String? Function(DBusIntrospectNode, String) generateClassFunction,
    String interfaceFilename,
    String? outputFilename) async {
  var xml = await File(interfaceFilename).readAsString();
  var node = parseDBusIntrospectXml(xml);

  if (className == null) {
    className = nodeToClassName(node);
    if (className == null) {
      return;
    }
  }

  var source = '';
  source +=
      '// This file was generated using the following command and may be overwritten.\n';
  source += '// dart-dbus $command $interfaceFilename\n';
  source += '\n';
  source += "import 'package:dbus/dbus.dart';\n";
  source += '\n';
  var classSource = generateClassFunction(node, className);
  if (classSource != null) {
    source += classSource;
  }

  if (outputFilename == null || outputFilename == '-') {
    print(source);
  } else {
    await File(outputFilename).writeAsString(source);
    print('Wrote to $outputFilename');
  }
}

/// Ensure [name] isn't in [memberNames], and return a modified version that is unique.
String getUniqueMethodName(List<String> memberNames, String name) {
  while (memberNames.contains(name)) {
    name += '_';
  }
  memberNames.add(name);
  return name;
}

/// Generates a DBusObject class for the given introspection node.
String? generateObjectClass(DBusIntrospectNode node, String className) {
  var methods = <String>[];
  // Method names provided in this class, initially populated with DBusObject methods.
  // Needs to be kept in sync with the DBusObject class.
  var memberNames = [
    'emitInterfacesAdded',
    'emitInterfacesRemoved',
    'emitPropertiesChangedSignal',
    'emitSignal',
    'getAllProperties',
    'getProperty',
    'setProperty'
  ];
  var getMethodNames = <String, String>{};
  var setMethodNames = <String, String>{};

  /// Make a constructor.
  methods.add(generateConstructor(node, className));

  // Generate all the methods for this object.
  for (var interface in node.interfaces) {
    for (var property in interface.properties) {
      methods.addAll(generatePropertyImplementationMethods(
          memberNames, getMethodNames, setMethodNames, interface, property));
    }
    for (var method in interface.methods) {
      methods.add(generateMethodImplementation(memberNames, interface, method));
    }
    for (var signal in interface.signals) {
      methods.add(generateSignalEmitMethod(memberNames, interface, signal));
    }
  }
  methods.add(generateIntrospectMethod(node));
  methods.add(generateHandleMethodCall(node));
  methods.add(generateGetProperty(getMethodNames, node));
  methods.add(generateSetProperty(setMethodNames, node));
  methods.add(generateGetAllProperties(node));

  var source = '';
  source += 'class $className extends DBusObject {\n';
  source += methods.join('\n');
  source += '}\n';

  return source;
}

/// Generates a constructor for a DBusObject.
String generateConstructor(DBusIntrospectNode node, String className) {
  var source = '';
  source += '  /// Creates a new object to expose on [path].\n';
  source +=
      "  $className({DBusObjectPath path = const DBusObjectPath.unchecked('${node.name ?? '/'}')}) : super(path);\n";

  return source;
}

/// Generates a stub implementation of [property].
List<String> generatePropertyImplementationMethods(
    List<String> memberNames,
    Map<String, String> getMethodNames,
    Map<String, String> setMethodNames,
    DBusIntrospectInterface interface,
    DBusIntrospectProperty property) {
  var methods = <String>[];

  var type = getDartType(property.type);

  if (property.access == DBusPropertyAccess.readwrite ||
      property.access == DBusPropertyAccess.read) {
    var methodName = getUniqueMethodName(memberNames, 'get${property.name}');
    getMethodNames['${interface.name}.${property.name}'] = methodName;

    var source = '';
    source +=
        '  /// Gets value of property ${interface.name}.${property.name}\n';
    source += '  Future<DBusMethodResponse> $methodName() async {\n';
    source +=
        "    return DBusMethodErrorResponse.failed('Get ${interface.name}.${property.name} not implemented');\n";
    source += '  }\n';
    methods.add(source);
  }
  if (property.access == DBusPropertyAccess.readwrite ||
      property.access == DBusPropertyAccess.write) {
    var methodName = getUniqueMethodName(memberNames, 'set${property.name}');
    setMethodNames['${interface.name}.${property.name}'] = methodName;

    var source = '';
    source += '  /// Sets property ${interface.name}.${property.name}\n';
    source +=
        '  Future<DBusMethodResponse> $methodName(${type.nativeType} value) async {\n';
    source +=
        "    return DBusMethodErrorResponse.failed('Set ${interface.name}.${property.name} not implemented');\n";
    source += '  }\n';
    methods.add(source);
  }

  return methods;
}

/// Generates a stub implementation of [method].
String generateMethodImplementation(List<String> memberNames,
    DBusIntrospectInterface interface, DBusIntrospectMethod method) {
  var argValues = <String>[];
  var argsList = <String>[];
  var index = 0;
  for (var arg in method.args) {
    if (arg.direction == DBusArgumentDirection.in_) {
      var type = getDartType(arg.type);
      var argName = arg.name ?? 'arg_$index';
      var convertedValue = type.nativeToDBus(argName);
      argsList.add('${type.nativeType} $argName');
      argValues.add(convertedValue);
    }
    index++;
  }

  var returnTypes = <String>[];
  var returnValues = <String>[];
  index = 0;
  for (var arg in method.args) {
    if (arg.direction == DBusArgumentDirection.out) {
      var type = getDartType(arg.type);
      var returnValue = 'result[${returnTypes.length}]';
      returnTypes.add(type.nativeType);
      var convertedValue = type.dbusToNative(returnValue);
      returnValues.add(convertedValue);
    }
    index++;
  }

  var methodName = getUniqueMethodName(memberNames, 'do${method.name}');

  var source = '';
  source += '  /// Implementation of ${interface.name}.${method.name}()\n';
  source +=
      '  Future<DBusMethodResponse> $methodName(${argsList.join(', ')}) async {\n';
  source +=
      "    return DBusMethodErrorResponse.failed('${interface.name}.${method.name}() not implemented');\n";
  source += '  }\n';

  return source;
}

/// Generates a method to emit a signal.
String generateSignalEmitMethod(List<String> memberNames,
    DBusIntrospectInterface interface, DBusIntrospectSignal signal) {
  var argNames = [
    // Dart keywords that aren't allowed.
    'assert',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'do',
    'else',
    'enum',
    'extends',
    'false',
    'final',
    'finally',
    'for',
    'get',
    'if',
    'in',
    'is',
    'new',
    'null',
    'rethrow',
    'return',
    'super',
    'switch',
    'this',
    'throw',
    'true',
    'try',
    'var',
    'void',
    'while',
    'with'
  ];

  var argValues = <String>[];
  var argsList = <String>[];
  var index = 0;
  for (var arg in signal.args) {
    var type = getDartType(arg.type);
    var argName = arg.name ?? 'arg_$index';
    while (argNames.contains(argName)) {
      argName += '_';
    }
    argNames.add(argName);
    argsList.add('${type.nativeType} $argName');
    var convertedValue = type.nativeToDBus(argName);
    argValues.add(convertedValue);
    index++;
  }

  var methodName = getUniqueMethodName(memberNames, 'emit${signal.name}');

  var source = '';
  source += '  /// Emits signal ${interface.name}.${signal.name}\n';
  source += '  void $methodName(${argsList.join(', ')}) {\n';
  source +=
      "     emitSignal('${interface.name}', '${signal.name}', [ ${argValues.join(', ')} ]);\n";
  source += '  }\n';

  return source;
}

// Generates a method that overrides DBusObject.introspect().
String generateIntrospectMethod(DBusIntrospectNode node) {
  var interfaceNodes = <String>[];
  for (var interface in node.interfaces) {
    var args = <String>[];
    args.add("'${interface.name}'");

    String makeIntrospectObject(String name, Iterable<String> args) {
      return '$name(${args.join(', ')})';
    }

    String makeArg(DBusIntrospectArgument arg) {
      var direction = 'DBusArgumentDirection.out';
      if (arg.direction == DBusArgumentDirection.in_) {
        direction = 'DBusArgumentDirection.in_';
      }
      return makeIntrospectObject('DBusIntrospectArgument',
          ["'${arg.name}'", "DBusSignature('${arg.type.value}')", direction]);
    }

    String makeArgs(Iterable<DBusIntrospectArgument> args) {
      return args.map((a) => makeArg(a)).join(', ');
    }

    String makeMethod(DBusIntrospectMethod method) {
      var args = ["'${method.name}'"];
      if (method.args.isNotEmpty) {
        args.add('args: [${makeArgs(method.args)}]');
      }
      return makeIntrospectObject('DBusIntrospectMethod', args);
    }

    String makeSignal(DBusIntrospectSignal signal) {
      var args = ["'${signal.name}'"];
      if (signal.args.isNotEmpty) {
        args.add('args: [${makeArgs(signal.args)}]');
      }
      return makeIntrospectObject('DBusIntrospectSignal', args);
    }

    String makeProperty(DBusIntrospectProperty property) {
      var args = [
        "'${property.name}'",
        "DBusSignature('${property.type.value}')"
      ];
      if (property.access == DBusPropertyAccess.readwrite) {
        args.add('access: DBusPropertyAccess.readwrite');
      } else if (property.access == DBusPropertyAccess.read) {
        args.add('access: DBusPropertyAccess.read');
      } else if (property.access == DBusPropertyAccess.write) {
        args.add('access: DBusPropertyAccess.write');
      }
      return makeIntrospectObject('DBusIntrospectProperty', args);
    }

    var methodArgs = interface.methods.map((m) => makeMethod(m));
    if (methodArgs.isNotEmpty) {
      args.add('methods: [${methodArgs.join(', ')}]');
    }
    var signalArgs = interface.signals.map((m) => makeSignal(m));
    if (signalArgs.isNotEmpty) {
      args.add('signals: [${signalArgs.join(', ')}]');
    }
    var propertyArgs = interface.properties.map((m) => makeProperty(m));
    if (propertyArgs.isNotEmpty) {
      args.add('properties: [${propertyArgs.join(', ')}]');
    }

    interfaceNodes.add(makeIntrospectObject('DBusIntrospectInterface', args));
  }

  var source = '';
  source += '  @override\n';
  source += '  List<DBusIntrospectInterface> introspect() {\n';
  source += '    return [${interfaceNodes.join(', ')}];\n';
  source += '  }\n';

  return source;
}

// Generates a method that overrides DBusObject.handleMethodCall().
String generateHandleMethodCall(DBusIntrospectNode node) {
  var interfaceBranches = <SwitchBranch>[];
  for (var interface in node.interfaces) {
    var methodBranches = <SwitchBranch>[];
    for (var method in interface.methods) {
      var argValues = <String>[];
      var inputArgs = method.args
          .where((arg) => arg.direction == DBusArgumentDirection.in_);
      String argCheck;
      if (inputArgs.isEmpty) {
        argCheck = 'methodCall.values.isNotEmpty';
      } else {
        argCheck =
            "methodCall.signature != DBusSignature('${method.inputSignature.value}')";
      }
      for (var arg in inputArgs) {
        var argName = 'methodCall.values[${argValues.length}]';
        var type = getDartType(arg.type);
        var convertedValue = type.dbusToNative(argName);
        argValues.add(convertedValue);
      }

      var source = '';
      source += 'if ($argCheck) {\n';
      source += '  return DBusMethodErrorResponse.invalidArgs();\n';
      source += '}\n';
      source += 'return do${method.name}(${argValues.join(', ')});\n';
      methodBranches
          .add(SwitchBranch("methodCall.name == '${method.name}'", source));
    }
    var source = makeSwitch(
        methodBranches, 'return DBusMethodErrorResponse.unknownMethod();\n');
    interfaceBranches.add(
        SwitchBranch("methodCall.interface == '${interface.name}'", source));
  }

  var source = '';
  source += '  @override\n';
  source +=
      '  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {\n';
  source += indentSource(
      2,
      makeSwitch(interfaceBranches,
          'return DBusMethodErrorResponse.unknownInterface();\n'));
  source += '  }\n';

  return source;
}

// Generates a method that overrides DBusObject.getProperty().
String generateGetProperty(
    Map<String, String> getMethodNames, DBusIntrospectNode node) {
  // Override DBusObject.getProperty().
  var interfaceBranches = <SwitchBranch>[];
  for (var interface in node.interfaces) {
    var propertyBranches = <SwitchBranch>[];
    for (var property in interface.properties) {
      var source = '';
      if (property.access == DBusPropertyAccess.readwrite ||
          property.access == DBusPropertyAccess.read) {
        var methodName = getMethodNames['${interface.name}.${property.name}'];
        source += 'return $methodName();\n';
      } else {
        source = 'return DBusMethodErrorResponse.propertyWriteOnly()\n';
      }
      propertyBranches.add(SwitchBranch("name == '${property.name}'", source));
    }
    var source = makeSwitch(propertyBranches,
        'return DBusMethodErrorResponse.unknownProperty();\n');
    interfaceBranches
        .add(SwitchBranch("interface == '${interface.name}'", source));
  }

  var source = '';
  source += '  @override\n';
  source +=
      '  Future<DBusMethodResponse> getProperty(String interface, String name) async {\n';
  source += indentSource(
      2,
      makeSwitch(interfaceBranches,
          'return DBusMethodErrorResponse.unknownInterface();\n'));
  source += '  }\n';

  return source;
}

// Generates a method that overrides DBusObject.setProperty().
String generateSetProperty(
    Map<String, String> setMethodNames, DBusIntrospectNode node) {
  var interfaceBranches = <SwitchBranch>[];
  for (var interface in node.interfaces) {
    var propertyBranches = <SwitchBranch>[];
    for (var property in interface.properties) {
      var type = getDartType(property.type);

      var source = '';
      source +=
          "if (value.signature != DBusSignature('${property.type.value}')) {\n";
      source += '  return DBusMethodErrorResponse.invalidArgs();\n';
      source += '}\n';
      if (property.access == DBusPropertyAccess.readwrite ||
          property.access == DBusPropertyAccess.write) {
        var convertedValue = type.dbusToNative('value');
        var methodName = setMethodNames['${interface.name}.${property.name}'];
        source += 'return $methodName($convertedValue);\n';
      } else {
        source = 'return DBusMethodErrorResponse.propertyReadOnly()\n';
      }
      propertyBranches.add(SwitchBranch("name == '${property.name}'", source));
    }
    var source = makeSwitch(propertyBranches,
        'return DBusMethodErrorResponse.unknownProperty();\n');
    interfaceBranches
        .add(SwitchBranch("interface == '${interface.name}'", source));
  }

  var source = '';
  source += '  @override\n';
  source +=
      '  Future<DBusMethodResponse> setProperty(String interface, String name, DBusValue value) async {\n';
  source += indentSource(
      2,
      makeSwitch(interfaceBranches,
          'return DBusMethodErrorResponse.unknownInterface();\n'));
  source += '  }\n';

  return source;
}

// Generates a method that overrides DBusObject.getAllProperties().
String generateGetAllProperties(DBusIntrospectNode node) {
  var interfaceBranches = <SwitchBranch>[];
  for (var interface in node.interfaces) {
    var source = '';
    for (var property in interface.properties) {
      if (property.access == DBusPropertyAccess.readwrite ||
          property.access == DBusPropertyAccess.read) {
        var convertedValue = '(await get${property.name}()).returnValues[0]';
        source +=
            "properties[DBusString('${property.name}')] = $convertedValue;\n";
      }
    }
    if (source != '') {
      interfaceBranches
          .add(SwitchBranch("interface == '${interface.name}'", source));
    }
  }

  var source = '';
  source += '  @override\n';
  source +=
      '  Future<DBusMethodResponse> getAllProperties(String interface) async {\n';
  source += '    var properties = <DBusValue, DBusValue>{};\n';
  source += indentSource(2, makeSwitch(interfaceBranches));
  source +=
      "    return DBusMethodSuccessResponse([DBusDict(DBusSignature('s'), DBusSignature('v'), properties)]);\n";
  source += '  }\n';

  return source;
}

/// Generates a DBusRemoteObject class for the given introspection node.
String? generateRemoteObjectClass(DBusIntrospectNode node, String className) {
  var classes = <String>[];
  var variables = <String>[];
  var methods = <String>[];
  var variableConstructors = <String>[];
  // Method names provided in this class, initially populated with DBusRemoteObject methods.
  // Needs to be kept in sync with the DBusRemoteObject class.
  var memberNames = [
    'callMethod',
    'getAllProperties',
    'getProperty',
    'setProperty'
  ];

  for (var interface in node.interfaces) {
    for (var signal in interface.signals) {
      classes.add(generateRemoteSignalClass(className, interface, signal));
      var lowerCaseName =
          signal.name[0].toLowerCase() + signal.name.substring(1);
      var variableName = getUniqueMethodName(memberNames, lowerCaseName);
      variables.add(generateRemoteSignalVariable(
          variableName, className, interface, signal));
      variableConstructors.add(generateRemoteSignalConstructor(
          variableName, className, interface, signal));
    }

    for (var property in interface.properties) {
      methods.addAll(
          generateRemotePropertyMethods(memberNames, interface, property));
    }

    for (var method in interface.methods) {
      methods.add(generateRemoteMethodCall(memberNames, interface, method));
    }
  }

  String pathArg;
  if (node.name != null) {
    pathArg =
        "{DBusObjectPath path = const DBusObjectPath.unchecked('${node.name}')}";
  } else {
    pathArg = 'DBusObjectPath path';
  }

  var constructor =
      '  $className(DBusClient client, String destination, $pathArg) : super(client, destination, path)';
  if (variableConstructors.isEmpty) {
    constructor += ';\n';
  } else {
    constructor += ' {\n';
    constructor += variableConstructors.join('\n');
    constructor += '}\n';
  }

  var members = <String>[];
  members.addAll(variables);
  members.add(constructor);
  members.addAll(methods);

  var source = '';
  source += 'class $className extends DBusRemoteObject {\n';
  source += members.join('\n');
  source += '}\n';
  classes.add(source);

  return classes.join('\n');
}

/// Generate methods for the remote [property].
List<String> generateRemotePropertyMethods(List<String> memberNames,
    DBusIntrospectInterface interface, DBusIntrospectProperty property) {
  var methods = <String>[];

  var type = getDartType(property.type);

  if (property.access == DBusPropertyAccess.readwrite ||
      property.access == DBusPropertyAccess.read) {
    var methodName = getUniqueMethodName(memberNames, 'get${property.name}');

    var convertedValue = type.dbusToNative('value');
    var source = '';
    source += '  /// Gets ${interface.name}.${property.name}\n';
    source += '  Future<${type.nativeType}> $methodName() async {\n';
    source +=
        "    var value = await getProperty('${interface.name}', '${property.name}');\n";
    source += '    return $convertedValue;\n';
    source += '  }\n';
    methods.add(source);
  }

  if (property.access == DBusPropertyAccess.readwrite ||
      property.access == DBusPropertyAccess.write) {
    var methodName = getUniqueMethodName(memberNames, 'set${property.name}');

    var convertedValue = type.nativeToDBus('value');
    var source = '';
    source += '  /// Sets ${interface.name}.${property.name}\n';
    source += '  Future<void> $methodName (${type.nativeType} value) async {\n';
    source +=
        "    await setProperty('${interface.name}', '${property.name}', $convertedValue);\n";
    source += '  }\n';
    methods.add(source);
  }

  return methods;
}

/// Generates a method for a remote D-Bus method call.
String generateRemoteMethodCall(List<String> memberNames,
    DBusIntrospectInterface interface, DBusIntrospectMethod method) {
  var inputArgs =
      method.args.where((arg) => arg.direction == DBusArgumentDirection.in_);
  var outputArgs =
      method.args.where((arg) => arg.direction == DBusArgumentDirection.out);

  var argValues = <String>[];
  var argsList = <String>[];
  var index = 0;
  for (var arg in inputArgs) {
    var type = getDartType(arg.type);
    var argName = arg.name ?? 'arg_$index';
    var convertedValue = type.nativeToDBus(argName);
    argsList.add('${type.nativeType} $argName');
    argValues.add(convertedValue);
    index++;
  }

  String returnType;
  if (outputArgs.isEmpty) {
    returnType = 'Future<void>';
  } else if (outputArgs.length == 1) {
    var type = getDartType(outputArgs.first.type);
    returnType = 'Future<${type.nativeType}>';
  } else {
    returnType = 'Future<List<DBusValue>>';
  }

  var methodCall =
      "await callMethod('${interface.name}', '${method.name}', [${argValues.join(', ')}], replySignature: DBusSignature('method.outputSignature.value'));";

  var methodName = getUniqueMethodName(memberNames, 'call${method.name}');

  var source = '';
  source += '  /// Invokes ${interface.name}.${method.name}()\n';
  source += '  $returnType $methodName(${argsList.join(', ')}) async {\n';
  if (outputArgs.isEmpty) {
    source += '    $methodCall\n';
  } else if (outputArgs.length == 1) {
    var type = getDartType(outputArgs.first.type);
    var convertedValue = type.dbusToNative('result.returnValues[0]');
    source += '    var result = $methodCall\n';
    source += '    return $convertedValue;\n';
  } else if (outputArgs.length > 1) {
    source += '    var result = $methodCall\n';
    source += '    return result.returnValues;\n';
  }
  source += '  }\n';

  return source;
}

/// Generates a class to contain a signal response.
String generateRemoteSignalClass(String classPrefix,
    DBusIntrospectInterface interface, DBusIntrospectSignal signal) {
  var argNames = [
    // Members of the DBusSignal class. Needs to be kept up to date.
    'interface',
    'name',
    'path',
    'sender',
    'values',
    // Dart keywords that aren't allowed.
    'assert',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'do',
    'else',
    'enum',
    'extends',
    'false',
    'final',
    'finally',
    'for',
    'get',
    'if',
    'in',
    'is',
    'new',
    'null',
    'rethrow',
    'return',
    'super',
    'switch',
    'this',
    'throw',
    'true',
    'try',
    'var',
    'void',
    'while',
    'with'
  ];

  var properties = <String>[];
  var params = <String>[];
  var index = 0;
  for (var arg in signal.args) {
    var type = getDartType(arg.type);

    // Modify the arg name if it collides.
    var argName = arg.name ?? 'arg_$index';
    while (argNames.contains(argName)) {
      argName += '_';
    }
    argNames.add(argName);

    var valueName = 'values[$index]';
    var convertedValue = type.dbusToNative(valueName);
    properties.add('  ${type.nativeType} get $argName => $convertedValue;\n');
    params.add('this.$argName');
    index++;
  }

  var signalClassName = '$classPrefix${signal.name}';

  var source = '';
  source += '/// Signal data for ${interface.name}.${signal.name}.\n';
  source += 'class $classPrefix${signal.name} extends DBusSignal{\n';
  source += properties.join();
  source += '\n';
  source +=
      '  $signalClassName(DBusSignal signal) : super(signal.sender, signal.path, signal.interface, signal.name, signal.values);\n';
  source += '}\n';

  return source;
}

/// Generates a variable for a signal stream.
String generateRemoteSignalVariable(String variableName, String classPrefix,
    DBusIntrospectInterface interface, DBusIntrospectSignal signal) {
  var signalClassName = '$classPrefix${signal.name}';

  var source = '';
  source += '  /// Stream of ${interface.name}.${signal.name} signals.\n';
  source += '  late final Stream<$signalClassName> $variableName;\n';

  return source;
}

/// Generates a constructor for a signal stream.
String generateRemoteSignalConstructor(String variableName, String classPrefix,
    DBusIntrospectInterface interface, DBusIntrospectSignal signal) {
  String valueCheck;
  if (signal.args.isEmpty) {
    valueCheck = 'signal.values.isEmpty';
  } else {
    valueCheck =
        "signal.signature == DBusSignature('${signal.signature.value}')";
  }

  var signalClassName = '$classPrefix${signal.name}';

  var source = '';
  source +=
      "    $variableName = DBusRemoteObjectSignalStream(this, '${interface.name}', '${signal.name}').map((signal) {\n";
  source += '      if ($valueCheck) {\n';
  source += '        return $signalClassName(signal);\n';
  source += '      } else {\n';
  source +=
      "        throw '${interface.name}.${signal.name} contains invalid values \${signal.values}';\n";
  source += '      }\n';
  source += '    });\n';

  return source;
}

/// Converts a introspection node to a Dart class name using the object path or interface name.
/// e.g.
/// If a path is available: '/org/freedesktop/Notifications' -> 'OrgFreedesktopNotifications'.
/// If no path, use the first interface name: 'org.freedesktop.Notifications' -> 'OrgFreedesktopNotifications'.
String? nodeToClassName(DBusIntrospectNode node) {
  var name = node.name;
  var divider = '/';
  if (name == null || name == '' || node.name == '/') {
    if (node.interfaces.isEmpty) {
      return null;
    }
    name = node.interfaces.first.name;
    divider = '.';
  }

  var className = '';
  for (var element in name.split(divider)) {
    if (element == '') {
      continue;
    }

    var camelName = element[0].toUpperCase() + element.substring(1);
    className += camelName;
  }
  return className.isNotEmpty ? className : null;
}

/// Branch in a switch (if/else) statement.
class SwitchBranch {
  final String condition;
  final String source;

  SwitchBranch(this.condition, this.source);
}

/// Make switch (if/else) statement.
String makeSwitch(Iterable<SwitchBranch> branches, [String? defaultBranch]) {
  if (branches.isEmpty) {
    return defaultBranch ?? '';
  }

  var source = '';
  var isFirst = true;
  for (var branch in branches) {
    var statement = isFirst ? 'if' : '} else if';
    source += '$statement (${branch.condition}) {\n';
    source += indentSource(1, branch.source);
    isFirst = false;
  }

  if (defaultBranch != null) {
    source += '} else {\n';
    source += indentSource(1, defaultBranch);
  }
  source += '}\n';

  return source;
}

/// Indent the given lines of source code.
String indentSource(int indent, String source) {
  var indentedLines = <String>[];
  for (var line in source.split('\n')) {
    if (line == '') {
      indentedLines.add('');
    } else {
      indentedLines.add('  ' * indent + line);
    }
  }
  return indentedLines.join('\n');
}
