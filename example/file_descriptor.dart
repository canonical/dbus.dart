import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';

class TestObject extends DBusObject {
  TestObject() : super(DBusObjectPath('/com/canonical/DBusDart'));

  @override
  List<DBusIntrospectInterface> introspect() {
    return [
      DBusIntrospectInterface('com.canonical.DBusDart', methods: [
        DBusIntrospectMethod('Open', args: [
          DBusIntrospectArgument(DBusSignature('h'), DBusArgumentDirection.out,
              name: 'fd')
        ])
      ])
    ];
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != 'com.canonical.DBusDart') {
      return DBusMethodErrorResponse.unknownInterface();
    }

    if (methodCall.name == 'Open') {
      // Write a file to use for testing.
      await File('FD_TEST').writeAsString('Hello World!', flush: true);

      print('Client opens file for reading');
      var file = await File('FD_TEST').open();
      return DBusMethodSuccessResponse(
          [DBusUnixFd(ResourceHandle.fromFile(file))]);
    } else {
      return DBusMethodErrorResponse.unknownMethod();
    }
  }
}

void main(List<String> args) async {
  var client = DBusClient.session();

  String? mode;
  if (args.isNotEmpty) {
    mode = args[0];
  }
  if (mode == 'client') {
    var object = DBusRemoteObject(client,
        name: 'com.canonical.DBusDart',
        path: DBusObjectPath('/com/canonical/DBusDart'));

    var result = await object.callMethod('com.canonical.DBusDart', 'Open', [],
        replySignature: DBusSignature('h'));
    var handle = result.returnValues[0].asUnixFd();
    var file = handle.toFile();

    print('Contents of file:');
    print(utf8.decode(await file.read(1024)));
  } else if (mode == 'server') {
    await client.requestName('com.canonical.DBusDart');
    var object = TestObject();
    await client.registerObject(object);
  } else {
    print('Usage:');
    print('file_descriptor.dart server - Run as a server');
    print('file_descriptor.dart client - Run as a client');
  }
}
