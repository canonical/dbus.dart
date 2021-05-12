import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:dbus/code_generator.dart';
import 'package:dbus/dbus.dart';

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
    var node = await loadNode(filename);
    var comment =
        'This file was generated using the following command and may be overwritten.\ndart-dbus $name $filename';
    var source = DBusCodeGenerator(node,
            comment: comment, className: argResults?['class-name'])
        .generateServerSource();
    await writeSource(source, argResults?['output']);
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
    var node = await loadNode(filename);
    var comment =
        'This file was generated using the following command and may be overwritten.\ndart-dbus $name $filename';
    var source = DBusCodeGenerator(node,
            comment: comment, className: argResults?['class-name'])
        .generateClientSource();
    await writeSource(source, argResults?['output']);
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

Future<DBusIntrospectNode> loadNode(String filename) async {
  String xml;
  if (filename == '-') {
    // Due to a Dart bug, we can't read as a stream because EOF is not detected:
    // var data = await stdin.fold<List<int>>([], (previous, element) { previous.addAll(element); return previous; });
    // https://github.com/dart-lang/sdk/issues/21796
    xml = '';
    while (true) {
      var line = stdin.readLineSync(retainNewlines: true);
      if (line == null) {
        break;
      }
      xml += line;
    }
  } else {
    xml = await File(filename).readAsString();
  }
  return parseDBusIntrospectXml(xml);
}

Future<void> writeSource(String source, String? outputFilename) async {
  if (outputFilename == null || outputFilename == '-') {
    print(source);
  } else {
    await File(outputFilename).writeAsString(source);
    print('Wrote to $outputFilename');
  }
}
