import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:dbus/dbus.dart';
import 'package:dbus/src/dbus_dart_type.dart';

// FIXME(robert-ancell): Check for method name collisions

/// Command that generates a DartRemoteObject class from an introspection XML file.
class GenerateRemoteObjectCommand extends Command {
  @override
  final name = 'generate-remote-object';

  @override
  final description =
      'Generates a DartRemoteObject to access an object on the D-Bus.';

  GenerateRemoteObjectCommand() {
    argParser.addOption('output',
        abbr: 'o',
        valueHelp: 'remote_object.dart',
        help: 'Dart file to write to');
  }

  @override
  void run() async {
    if (argResults.rest.length != 1) {
      usageException(
          '${name} requires a single D-Bus interface file to be provided.');
    }
    generateModule(argResults.rest[0], argResults['output']);
  }
}

void main(List<String> args) async {
  var runner = CommandRunner('dart-dbus',
      'A tool to generate Dart classes from D-Bus interface defintions.');
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
void generateModule(String interfaceFilename, String outputFilename) async {
  var xml = await File(interfaceFilename).readAsString();
  var nodes = parseDBusIntrospectXml(xml);

  var classes = nodes.map((n) => generateRemoteObjectClass(n));

  var source = '';
  source += "import 'package:dbus/dbus.dart';\n";
  source += '\n';
  source += classes.join('\n');

  if (outputFilename == null || outputFilename == '-') {
    print(source);
  } else {
    await File(outputFilename).writeAsString(source);
    print('Wrote to ${outputFilename}');
  }
}

/// Generates a DBusRemoteObject class for the given introspection node.
String generateRemoteObjectClass(DBusIntrospectNode node) {
  // Need a name to generate a class
  if (node.name == null) {
    return null;
  }

  // FIXME(robert-ancell) add --org-name to strip off prefixes?
  var className = pathToClassName(node.name);

  var methods = <String>[];

  for (var interface in node.interfaces) {
    for (var property in interface.properties) {
      methods.addAll(generateRemotePropertyMethods(interface, property));
    }

    for (var method in interface.methods) {
      methods.add(generateRemoteMethodCall(interface, method));
    }

    for (var signal in interface.signals) {
      methods.add(generateRemoteSignalSubscription(interface, signal));
    }
  }

  var source = '';
  source += 'class ${className} extends DBusRemoteObject {\n';
  source +=
      '''  ${className}(DBusClient client, String destination, {DBusObjectPath path = const DBusObjectPath.unchecked('${node.name}')}) : super(client, destination, path);\n''';
  source += '\n';
  source += methods.join('\n');
  source += '}\n';

  return source;
}

/// Generate methods for the remote [property].
List<String> generateRemotePropertyMethods(
    DBusIntrospectInterface interface, DBusIntrospectProperty property) {
  var methods = <String>[];

  var type = getDartType(property.type);

  if (property.access == DBusPropertyAccess.readwrite ||
      property.access == DBusPropertyAccess.read) {
    var convertedValue = type.dbusToNative('value');
    var code = '';
    code += '  /// Gets ${interface.name}.${property.name}\n';
    code += '  Future<${type.nativeType}> get ${property.name} async {\n';
    code +=
        "    var value = await getProperty('${interface.name}', '${property.name}');\n";
    code += '    return ${convertedValue};\n';
    code += '  }\n';
    methods.add(code);
  }

  if (property.access == DBusPropertyAccess.readwrite ||
      property.access == DBusPropertyAccess.write) {
    var convertedValue = type.nativeToDBus('value');
    var code = '';
    code += '  /// Sets ${interface.name}.${property.name}\n';
    code += '  set ${property.name} (${type.nativeType} value) {\n';
    code +=
        "    setProperty('${interface.name}', '${property.name}', ${convertedValue});\n";
    code += '  }\n';
    methods.add(code);
  }

  return methods;
}

/// Generates a method for a remote D-Bus method call.
String generateRemoteMethodCall(
    DBusIntrospectInterface interface, DBusIntrospectMethod method) {
  var argValues = <String>[];
  var argsList = <String>[];
  var index = 0;
  for (var arg in method.args) {
    if (arg.direction == DBusArgumentDirection.in_) {
      var type = getDartType(arg.type);
      var argName = arg.name ?? 'arg_${index}';
      var convertedValue = type.nativeToDBus(argName);
      argsList.add('${type.nativeType} ${argName}');
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
      var returnValue = 'result.returnValues[${returnTypes.length}]';
      returnTypes.add(type.nativeType);
      var convertedValue = type.dbusToNative(returnValue);
      returnValues.add(convertedValue);
    }
    index++;
  }

  String returnType;
  if (returnTypes.isEmpty) {
    returnType = 'Future';
  } else if (returnTypes.length == 1) {
    returnType = 'Future<${returnTypes[0]}>';
  } else {
    returnType = 'Future<List<DBusValue>>';
  }

  var methodCall =
      "await callMethod('${interface.name}', '${method.name}', [${argValues.join(', ')}]);";

  var code = '';
  code += '  /// Invokes ${interface.name}.${method.name}()\n';
  code += '  ${returnType} ${method.name}(${argsList.join(', ')}) async {\n';
  if (returnTypes.isEmpty) {
    code += '    ${methodCall}\n';
  } else if (returnTypes.length == 1) {
    code += '    var result = ${methodCall}\n';
    code += '    return ${returnValues[0]};\n';
  } else {
    code += '    var result = ${methodCall}\n';
    code += '    return result.returnValues;\n';
  }
  code += '  }\n';

  return code;
}

/// Generates a method to subscribe to a signal.
String generateRemoteSignalSubscription(
    DBusIntrospectInterface interface, DBusIntrospectSignal signal) {
  var argValues = <String>[];
  var argsList = <String>[];
  var index = 0;
  var valueChecks = ['values.length == ${signal.args.length}'];
  for (var arg in signal.args) {
    var type = getDartType(arg.type);
    var argName = arg.name ?? 'arg_${index}';
    argsList.add('${type.nativeType} ${argName}');
    var valueName = 'values[${index}]';
    valueChecks
        .add("${valueName}.signature == DBusSignature('${arg.type.value}')");
    var convertedValue = type.dbusToNative(valueName);
    argValues.add(convertedValue);
    index++;
  }

  var code = '';
  code += '  /// Subscribes to ${interface.name}.${signal.name}\n';
  code +=
      '  Future<DBusSignalSubscription> subscribe${signal.name}(void Function(${argsList.join(', ')}) callback) async {\n';
  code +=
      "    return await subscribeSignal('${interface.name}', '${signal.name}', (values) {\n";
  code += '      if (${valueChecks.join(' && ')}) {\n';
  code += '        callback(${argValues.join(', ')});\n';
  code += '      }\n';
  code += '    });\n';
  code += '  }\n';

  return code;
}

/// Converts a D-Bus path to a Dart class name. e.g. 'org.freedesktop.Notifications' -> 'OrgFreedesktopNotifications'.
String pathToClassName(String path) {
  var className = '';
  for (var element in path.split('/')) {
    if (element == '') {
      continue;
    }

    var camelName = element[0].toUpperCase() + element.substring(1);
    className += camelName;
  }
  return className;
}
