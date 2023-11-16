import 'package:dbus/dbus.dart';
import 'package:dbus/src/dbus_dart_type.dart';

// Branch in a switch (if/else) statement.
class _SwitchBranch {
  final String condition;
  final String source;

  _SwitchBranch(this.condition, this.source);
}

/// Object to generate Dart code to access D-Bus objects.
class DBusCodeGenerator {
  /// Introspection data used to generate source code.
  final DBusIntrospectNode node;

  /// Class name used in generated code.
  late final String className;

  final String? _comment;

  /// Creates a new object to generate code from [node].
  /// [className] is the name of the generated class, if not provided it will be inferred from [node].
  /// If provided [comment] is added to the top of the source.
  DBusCodeGenerator(this.node, {String? comment, String? className})
      : _comment = comment {
    var className_ = className ?? _nodeToClassName();
    if (className_ == null) {
      throw 'Unable to determine class name';
    }
    this.className = className_;
  }

  /// Generates Dart code for a client to access the given D-Bus interface.
  String generateClientSource() {
    var source = '';

    source += _generateHeader();
    source += "import 'dart:io';\n";
    source += "import 'package:dbus/dbus.dart';\n";
    source += '\n';
    source += _generateRemoteObjectClass();

    return source;
  }

  /// Generates Dart code for a server to expose objects on the given D-Bus interface.
  String generateServerSource() {
    var source = '';

    source += _generateHeader();
    source += "import 'dart:io';\n";
    source += "import 'package:dbus/dbus.dart';\n";
    source += '\n';
    source += _generateObjectClass();

    return source;
  }

  // Generates a header comment for the source.
  String _generateHeader() {
    var source = '';

    if (_comment != null) {
      var escapedComment = _comment!.split('\n').join('\n// ');
      source += '// $escapedComment\n\n';
    }

    return source;
  }

  // Generates a DBusObject class for the given introspection node.
  String _generateObjectClass() {
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

    // Make a constructor.
    methods.add(_generateConstructor(node, className));

    // Generate all the methods for this object.
    for (var interface in node.interfaces) {
      for (var property in interface.properties) {
        methods.addAll(_generatePropertyImplementationMethods(
            memberNames, getMethodNames, setMethodNames, interface, property));
      }
      for (var method in interface.methods) {
        methods
            .add(_generateMethodImplementation(memberNames, interface, method));
      }
      for (var signal in interface.signals) {
        methods.add(_generateSignalEmitMethod(memberNames, interface, signal));
      }
    }
    var code = _generateIntrospectMethod(node);
    if (code != '') {
      methods.add(code);
    }
    code = _generateHandleMethodCall(node);
    if (code != '') {
      methods.add(code);
    }
    code = _generateGetProperty(getMethodNames, node);
    if (code != '') {
      methods.add(code);
    }
    code = _generateSetProperty(setMethodNames, node);
    if (code != '') {
      methods.add(code);
    }
    code = _generateGetAllProperties(node);
    if (code != '') {
      methods.add(code);
    }

    var source = '';
    source += 'class $className extends DBusObject {\n';
    source += methods.join('\n');
    source += '}\n';

    return source;
  }

  // Ensure [name] isn't in [memberNames], and return a modified version that is unique.
  String _getUniqueMethodName(List<String> memberNames, String name) {
    while (memberNames.contains(name)) {
      name += '_';
    }
    memberNames.add(name);
    return name;
  }

  // Generates a constructor for a DBusObject.
  String _generateConstructor(DBusIntrospectNode node, String className) {
    var source = '';
    source += '  /// Creates a new object to expose on [path].\n';
    source +=
        "  $className({DBusObjectPath path = const DBusObjectPath.unchecked('${node.name ?? '/'}')}) : super(path);\n";

    return source;
  }

  // Generates a stub implementation of [property].
  List<String> _generatePropertyImplementationMethods(
      List<String> memberNames,
      Map<String, String> getMethodNames,
      Map<String, String> setMethodNames,
      DBusIntrospectInterface interface,
      DBusIntrospectProperty property) {
    var methods = <String>[];

    var type = getDartType(property.type);

    if (property.access == DBusPropertyAccess.readwrite ||
        property.access == DBusPropertyAccess.read) {
      var methodName = _getUniqueMethodName(memberNames, 'get${property.name}');
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
      var methodName = _getUniqueMethodName(memberNames, 'set${property.name}');
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

  // Generates a stub implementation of [method].
  String _generateMethodImplementation(List<String> memberNames,
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

    var isNoReply = _getBooleanAnnotation(
        method.annotations, 'org.freedesktop.DBus.Method.NoReply');
    var returnType = isNoReply ? 'void' : 'DBusMethodResponse';

    var methodName = _getUniqueMethodName(memberNames, 'do${method.name}');

    var source = '';
    source += '  /// Implementation of ${interface.name}.${method.name}()\n';
    source +=
        '  Future<$returnType> $methodName(${argsList.join(', ')}) async {\n';
    if (!isNoReply) {
      source +=
          "    return DBusMethodErrorResponse.failed('${interface.name}.${method.name}() not implemented');\n";
    }
    source += '  }\n';

    return source;
  }

  // Generates a method to emit a signal.
  String _generateSignalEmitMethod(List<String> memberNames,
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

    var methodName = _getUniqueMethodName(memberNames, 'emit${signal.name}');

    var source = '';
    source += '  /// Emits signal ${interface.name}.${signal.name}\n';
    source += '  Future<void> $methodName(${argsList.join(', ')}) async {\n';
    source +=
        "     await emitSignal('${interface.name}', '${signal.name}', [${argValues.join(', ')}]);\n";
    source += '  }\n';

    return source;
  }

  // Generates a method that overrides DBusObject.introspect().
  String _generateIntrospectMethod(DBusIntrospectNode node) {
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
        var args = ["DBusSignature('${arg.type.value}')", direction];
        if (arg.name != null) {
          args.add("name: '${arg.name}'");
        }
        return makeIntrospectObject('DBusIntrospectArgument', args);
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

    if (interfaceNodes.isEmpty) {
      return '';
    }

    var source = '';
    source += '  @override\n';
    source += '  List<DBusIntrospectInterface> introspect() {\n';
    source += '    return [${interfaceNodes.join(', ')}];\n';
    source += '  }\n';

    return source;
  }

  // Generates a method that overrides DBusObject.handleMethodCall().
  String _generateHandleMethodCall(DBusIntrospectNode node) {
    var interfaceBranches = <_SwitchBranch>[];
    for (var interface in node.interfaces) {
      var methodBranches = <_SwitchBranch>[];
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

        var methodImplementation = 'do${method.name}(${argValues.join(', ')})';
        var isNoReply = _getBooleanAnnotation(
            method.annotations, 'org.freedesktop.DBus.Method.NoReply');

        var source = '';
        source += 'if ($argCheck) {\n';
        source += '  return DBusMethodErrorResponse.invalidArgs();\n';
        source += '}\n';
        if (isNoReply) {
          source += 'await $methodImplementation;\n';
          source += 'return DBusMethodSuccessResponse();\n';
        } else {
          source += 'return $methodImplementation;\n';
        }
        methodBranches
            .add(_SwitchBranch("methodCall.name == '${method.name}'", source));
      }
      var source = _makeSwitch(
          methodBranches, 'return DBusMethodErrorResponse.unknownMethod();\n');
      interfaceBranches.add(
          _SwitchBranch("methodCall.interface == '${interface.name}'", source));
    }

    if (interfaceBranches.isEmpty) {
      return '';
    }

    var source = '';
    source += '  @override\n';
    source +=
        '  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {\n';
    source += _indentSource(
        2,
        _makeSwitch(interfaceBranches,
            'return DBusMethodErrorResponse.unknownInterface();\n'));
    source += '  }\n';

    return source;
  }

  // Generates a method that overrides DBusObject.getProperty().
  String _generateGetProperty(
      Map<String, String> getMethodNames, DBusIntrospectNode node) {
    // Override DBusObject.getProperty().
    var interfaceBranches = <_SwitchBranch>[];
    for (var interface in node.interfaces) {
      var propertyBranches = <_SwitchBranch>[];
      for (var property in interface.properties) {
        var source = '';
        if (property.access == DBusPropertyAccess.readwrite ||
            property.access == DBusPropertyAccess.read) {
          var methodName = getMethodNames['${interface.name}.${property.name}'];
          source += 'return $methodName();\n';
        } else {
          source = 'return DBusMethodErrorResponse.propertyWriteOnly();\n';
        }
        propertyBranches
            .add(_SwitchBranch("name == '${property.name}'", source));
      }
      var source = _makeSwitch(propertyBranches,
          'return DBusMethodErrorResponse.unknownProperty();\n');
      interfaceBranches
          .add(_SwitchBranch("interface == '${interface.name}'", source));
    }

    if (interfaceBranches.isEmpty) {
      return '';
    }

    var source = '';
    source += '  @override\n';
    source +=
        '  Future<DBusMethodResponse> getProperty(String interface, String name) async {\n';
    source += _indentSource(
        2,
        _makeSwitch(interfaceBranches,
            'return DBusMethodErrorResponse.unknownProperty();\n'));
    source += '  }\n';

    return source;
  }

  // Generates a method that overrides DBusObject.setProperty().
  String _generateSetProperty(
      Map<String, String> setMethodNames, DBusIntrospectNode node) {
    var interfaceBranches = <_SwitchBranch>[];
    for (var interface in node.interfaces) {
      var propertyBranches = <_SwitchBranch>[];
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
          source = 'return DBusMethodErrorResponse.propertyReadOnly();\n';
        }
        propertyBranches
            .add(_SwitchBranch("name == '${property.name}'", source));
      }
      var source = _makeSwitch(propertyBranches,
          'return DBusMethodErrorResponse.unknownProperty();\n');
      interfaceBranches
          .add(_SwitchBranch("interface == '${interface.name}'", source));
    }

    if (interfaceBranches.isEmpty) {
      return '';
    }

    var source = '';
    source += '  @override\n';
    source +=
        '  Future<DBusMethodResponse> setProperty(String interface, String name, DBusValue value) async {\n';
    source += _indentSource(
        2,
        _makeSwitch(interfaceBranches,
            'return DBusMethodErrorResponse.unknownProperty();\n'));
    source += '  }\n';

    return source;
  }

  // Generates a method that overrides DBusObject.getAllProperties().
  String _generateGetAllProperties(DBusIntrospectNode node) {
    var interfaceBranches = <_SwitchBranch>[];
    for (var interface in node.interfaces) {
      var source = '';
      for (var property in interface.properties) {
        if (property.access == DBusPropertyAccess.readwrite ||
            property.access == DBusPropertyAccess.read) {
          var convertedValue = '(await get${property.name}()).returnValues[0]';
          source += "properties['${property.name}'] = $convertedValue;\n";
        }
      }
      if (source != '') {
        interfaceBranches
            .add(_SwitchBranch("interface == '${interface.name}'", source));
      }
    }

    if (interfaceBranches.isEmpty) {
      return '';
    }

    var source = '';
    source += '  @override\n';
    source +=
        '  Future<DBusMethodResponse> getAllProperties(String interface) async {\n';
    source += '    var properties = <String, DBusValue>{};\n';
    source += _indentSource(2, _makeSwitch(interfaceBranches));
    source +=
        '    return DBusMethodSuccessResponse([DBusDict.stringVariant(properties)]);\n';
    source += '  }\n';

    return source;
  }

  String _generateRemoteObjectClass() {
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
        classes.add(_generateRemoteSignalClass(className, interface, signal));
        var lowerCaseName =
            signal.name[0].toLowerCase() + signal.name.substring(1);
        var variableName = _getUniqueMethodName(memberNames, lowerCaseName);
        variables.add(_generateRemoteSignalVariable(
            variableName, className, interface, signal));
        variableConstructors.add(_generateRemoteSignalConstructor(
            variableName, className, interface, signal));
      }

      for (var property in interface.properties) {
        methods.addAll(
            _generateRemotePropertyMethods(memberNames, interface, property));
      }

      for (var method in interface.methods) {
        methods.add(_generateRemoteMethodCall(memberNames, interface, method));
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
        '  $className(DBusClient client, String destination, $pathArg) : super(client, name: destination, path: path)';
    if (variableConstructors.isEmpty) {
      constructor += ';\n';
    } else {
      constructor += ' {\n';
      constructor += variableConstructors.join('\n');
      constructor += '  }\n';
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

  // Generate methods for the remote [property].
  List<String> _generateRemotePropertyMethods(List<String> memberNames,
      DBusIntrospectInterface interface, DBusIntrospectProperty property) {
    var methods = <String>[];

    var type = getDartType(property.type);

    if (property.access == DBusPropertyAccess.readwrite ||
        property.access == DBusPropertyAccess.read) {
      var methodName = _getUniqueMethodName(memberNames, 'get${property.name}');

      var convertedValue = type.dbusToNative('value');
      var source = '';
      source += '  /// Gets ${interface.name}.${property.name}\n';
      source += '  Future<${type.nativeType}> $methodName() async {\n';
      source +=
          "    var value = await getProperty('${interface.name}', '${property.name}', signature: DBusSignature('${property.type.value}'));\n";
      source += '    return $convertedValue;\n';
      source += '  }\n';
      methods.add(source);
    }

    if (property.access == DBusPropertyAccess.readwrite ||
        property.access == DBusPropertyAccess.write) {
      var methodName = _getUniqueMethodName(memberNames, 'set${property.name}');

      var convertedValue = type.nativeToDBus('value');
      var source = '';
      source += '  /// Sets ${interface.name}.${property.name}\n';
      source +=
          '  Future<void> $methodName (${type.nativeType} value) async {\n';
      source +=
          "    await setProperty('${interface.name}', '${property.name}', $convertedValue);\n";
      source += '  }\n';
      methods.add(source);
    }

    return methods;
  }

  // Generates a method for a remote D-Bus method call.
  String _generateRemoteMethodCall(List<String> memberNames,
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
    argsList.add(
        '{bool noAutoStart = false, bool allowInteractiveAuthorization = false}');

    var isNoReply = _getBooleanAnnotation(
        method.annotations, 'org.freedesktop.DBus.Method.NoReply');

    String returnType;
    if (isNoReply || outputArgs.isEmpty) {
      returnType = 'Future<void>';
    } else if (outputArgs.length == 1) {
      var type = getDartType(outputArgs.first.type);
      returnType = 'Future<${type.nativeType}>';
    } else {
      returnType = 'Future<List<DBusValue>>';
    }

    var methodArgs = [
      "'${interface.name}'",
      "'${method.name}'",
      "[${argValues.join(', ')}]",
      "replySignature: DBusSignature('${method.outputSignature.value}')"
    ];
    if (isNoReply) {
      methodArgs.add('noReplyExpected: true');
    }
    methodArgs.add('noAutoStart: noAutoStart');
    methodArgs
        .add('allowInteractiveAuthorization: allowInteractiveAuthorization');
    var methodCall = "await callMethod(${methodArgs.join(', ')});";

    var methodName = _getUniqueMethodName(memberNames, 'call${method.name}');

    var source = '';
    source += '  /// Invokes ${interface.name}.${method.name}()\n';
    source += '  $returnType $methodName(${argsList.join(', ')}) async {\n';
    if (isNoReply || outputArgs.isEmpty) {
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

  // Generates a class to contain a signal response.
  String _generateRemoteSignalClass(String classPrefix,
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
    source += 'class $classPrefix${signal.name} extends DBusSignal {\n';
    if (properties.isNotEmpty) {
      source += properties.join();
      source += '\n';
    }
    source +=
        '  $signalClassName(DBusSignal signal) : super(sender: signal.sender, path: signal.path, interface: signal.interface, name: signal.name, values: signal.values);\n';
    source += '}\n';

    return source;
  }

  // Generates a variable for a signal stream.
  String _generateRemoteSignalVariable(String variableName, String classPrefix,
      DBusIntrospectInterface interface, DBusIntrospectSignal signal) {
    var signalClassName = '$classPrefix${signal.name}';

    var source = '';
    source += '  /// Stream of ${interface.name}.${signal.name} signals.\n';
    source += '  late final Stream<$signalClassName> $variableName;\n';

    return source;
  }

  // Generates a constructor for a signal stream.
  String _generateRemoteSignalConstructor(
      String variableName,
      String classPrefix,
      DBusIntrospectInterface interface,
      DBusIntrospectSignal signal) {
    var signalClassName = '$classPrefix${signal.name}';
    return "    $variableName = DBusRemoteObjectSignalStream(object: this, interface: '${interface.name}', name: '${signal.name}', signature: DBusSignature('${signal.signature.value}')).asBroadcastStream().map((signal) => $signalClassName(signal));\n";
  }

  // Converts a introspection node to a Dart class name using the object path or interface name.
  // e.g.
  // If a path is available: '/org/freedesktop/Notifications' -> 'OrgFreedesktopNotifications'.
  // If no path, use the first interface name: 'org.freedesktop.Notifications' -> 'OrgFreedesktopNotifications'.
  String? _nodeToClassName() {
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

  // Make switch (if/else) statement.
  String _makeSwitch(Iterable<_SwitchBranch> branches,
      [String? defaultBranch]) {
    if (branches.isEmpty) {
      return defaultBranch ?? '';
    }

    var source = '';
    var isFirst = true;
    for (var branch in branches) {
      var statement = isFirst ? 'if' : '} else if';
      source += '$statement (${branch.condition}) {\n';
      source += _indentSource(1, branch.source);
      isFirst = false;
    }

    if (defaultBranch != null) {
      source += '} else {\n';
      source += _indentSource(1, defaultBranch);
    }
    source += '}\n';

    return source;
  }

  // Indent the given lines of source code.
  String _indentSource(int indent, String source) {
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

  String? _getAnnotation(
      Iterable<DBusIntrospectAnnotation> annotations, String name) {
    for (var annotation in annotations) {
      if (annotation.name == name) {
        return annotation.value;
      }
    }

    return null;
  }

  bool _getBooleanAnnotation(
      Iterable<DBusIntrospectAnnotation> annotations, String name,
      {bool defaultValue = false}) {
    var value = _getAnnotation(annotations, name);
    return value == null ? defaultValue : value == 'true';
  }
}
