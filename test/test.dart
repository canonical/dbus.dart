import 'package:dbus/dbus.dart';
import 'package:test/test.dart';

// Test object which has an Echo() method.
class EchoObject extends DBusObject {
  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.name == 'Echo') {
      return DBusMethodSuccessResponse(methodCall.values);
    } else {
      return DBusMethodErrorResponse.unknownMethod();
    }
  }
}

// Test object which has introspection data.
class IntrospectObject extends DBusObject {
  @override
  List<DBusIntrospectInterface> introspect() {
    return [
      DBusIntrospectInterface('com.example.Test',
          methods: [DBusIntrospectMethod('Foo')])
    ];
  }
}

void main() {
  test('ping server', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();

    // Check can ping the server.
    var client = DBusClient(address);
    await client.ping('org.freedesktop.DBus');
  });

  test('method call', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();

    // Create a client that exposes a method.
    var client1 = DBusClient(address);
    await client1.registerObject(EchoObject());

    // Call the method from another client.
    var client2 = DBusClient(address);
    var response = await client2.callMethod(
        destination: client1.uniqueName,
        path: DBusObjectPath('/'),
        member: 'Echo',
        values: [DBusString('Hello'), DBusUint32(42)]);
    expect(response, TypeMatcher<DBusMethodSuccessResponse>());
    expect((response as DBusMethodSuccessResponse).values,
        equals([DBusString('Hello'), DBusUint32(42)]));
  });

  test('emit signal', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();

    // Create a client that exposes a method.
    var client1 = DBusClient(address);
    var object = DBusObject();
    await client1.registerObject(object);

    // Subscribe to the signal from another client.
    var client2 = DBusClient(address);
    var signals =
        client2.subscribeSignals(interface: 'com.example.Test', member: 'Ping');
    signals.listen(expectAsync1((signal) {
      expect(signal.sender, equals(client1.uniqueName));
      expect(signal.path, equals(DBusObjectPath('/')));
      expect(signal.interface, equals('com.example.Test'));
      expect(signal.name, equals('Ping'));
      expect(signal.values, equals([DBusString('Hello'), DBusUint32(42)]));
    }));

    // Do a round-trip to the server to ensure the signal has been subscribed to.
    await client2.ping();

    // Emit the signal.
    object.emitSignal(
        'com.example.Test', 'Ping', [DBusString('Hello'), DBusUint32(42)]);
  });

  test('introspect', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();

    // Create a client that exposes introspection data.
    var client1 = DBusClient(address);
    await client1.registerObject(IntrospectObject());

    // Read introspection data from the first client.
    var client2 = DBusClient(address);
    var remoteObject =
        DBusRemoteObject(client2, client1.uniqueName!, DBusObjectPath('/'));
    var node = await remoteObject.introspect();
    expect(
        node.toXml().toXmlString(),
        equals('<node>'
            '<interface name="org.freedesktop.DBus.Introspectable">'
            '<method name="Introspect">'
            '<arg name="xml_data" type="s" direction="out"/>'
            '</method>'
            '</interface>'
            '<interface name="org.freedesktop.DBus.Peer">'
            '<method name="GetMachineId">'
            '<arg name="machine_uuid" type="s" direction="out"/>'
            '</method>'
            '<method name="Ping"/>'
            '</interface>'
            '<interface name="org.freedesktop.DBus.Properties">'
            '<method name="Get">'
            '<arg name="interface_name" type="s" direction="in"/>'
            '<arg name="property_name" type="s" direction="in"/>'
            '<arg name="value" type="v" direction="out"/>'
            '</method>'
            '<method name="Set">'
            '<arg name="interface_name" type="s" direction="in"/>'
            '<arg name="property_name" type="s" direction="in"/>'
            '<arg name="value" type="v" direction="in"/>'
            '</method>'
            '<method name="GetAll">'
            '<arg name="interface_name" type="s" direction="in"/>'
            '<arg name="props" type="a{sv}" direction="out"/>'
            '</method>'
            '</interface>'
            '<interface name="com.example.Test">'
            '<method name="Foo"/>'
            '</interface>'
            '</node>'));
  });
}
