import 'dart:async';

import 'package:dbus/dbus.dart';

class TestObject extends DBusObject {
  TestObject() : super(DBusObjectPath('/com/canonical/DBusDart'));

  @override
  List<DBusIntrospectInterface> introspect() {
    return [
      DBusIntrospectInterface(
        'com.canonical.DBusDart',
        signals: [DBusIntrospectSignal('Ping')],
      )
    ];
  }
}

void main(List<String> args) async {
  var client = DBusClient.session();

  String? mode;
  if (args.isNotEmpty) {
    mode = args[0];
  }
  if (mode == 'client') {
    var object = DBusRemoteObject(
      client,
      name: 'com.canonical.DBusDart',
      path: DBusObjectPath('/com/canonical/DBusDart'),
    );
    var signals = DBusRemoteObjectSignalStream(
        object: object, interface: 'com.canonical.DBusDart', name: 'Ping');
    await for (var signal in signals) {
      var count = signal.values[0].asUint64();
      print('Ping $count!');
    }
  } else if (mode == 'server') {
    await client.requestName('com.canonical.DBusDart');
    var object = TestObject();
    await client.registerObject(object);
    var count = 0;
    Timer.periodic(Duration(seconds: 1), (timer) {
      print('Ping $count!');
      object.emitSignal('com.canonical.DBusDart', 'Ping', [DBusUint64(count)]);
      count++;
    });
  } else {
    print('Usage:');
    print('signals.dart server - Run as a server');
    print('signals.dart client - Run as a client');
    return;
  }
}
