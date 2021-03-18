import 'package:dbus/dbus.dart';
import 'package:test/test.dart';

const isMethodResponseException = TypeMatcher<DBusMethodResponseException>();

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
  test('ping', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client = DBusClient(address);

    // Check can ping the server.
    await client.ping();
  });

  test('list names', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client = DBusClient(address);

    // Check the server and this clients name is reported.
    var names = await client.listNames();
    expect(names, equals(['org.freedesktop.DBus', client.uniqueName]));
  });

  test('list activatable names', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client = DBusClient(address);

    // Not currently supported, so should be empty.
    var names = await client.listActivatableNames();
    expect(names, isEmpty);
  });

  test('request name', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client = DBusClient(address);

    // Check name is currently unowned.
    var hasOwner = await client.nameHasOwner('com.example.Test');
    expect(hasOwner, isFalse);
    var names = await client.listQueuedOwners('com.example.Test');
    expect(names, isEmpty);

    // Check get an event when acquired.
    client.nameAcquired.listen(expectAsync1((name) {
      expect(name, equals('com.example.Test'));
    }));

    // Request the name.
    var reply = await client.requestName('com.example.Test');
    expect(reply, equals(DBusRequestNameReply.primaryOwner));

    // Check name is owned.
    expect(client.ownedNames, equals(['com.example.Test']));
    names = await client.listNames();
    expect(
        names,
        equals(
            ['org.freedesktop.DBus', client.uniqueName, 'com.example.Test']));
    hasOwner = await client.nameHasOwner('com.example.Test');
    expect(hasOwner, isTrue);
    var owner = await client.getNameOwner('com.example.Test');
    expect(owner, equals(client.uniqueName));
    names = await client.listQueuedOwners('com.example.Test');
    expect(names, [client.uniqueName]);
  });

  test('request name - already owned', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client = DBusClient(address);

    // Request the name twice
    var reply = await client.requestName('com.example.Test');
    expect(reply, equals(DBusRequestNameReply.primaryOwner));
    reply = await client.requestName('com.example.Test');
    expect(reply, equals(DBusRequestNameReply.alreadyOwner));

    // Check name is owned only once.
    var hasOwner = await client.nameHasOwner('com.example.Test');
    expect(hasOwner, isTrue);
    var owner = await client.getNameOwner('com.example.Test');
    expect(owner, equals(client.uniqueName));
    var names = await client.listQueuedOwners('com.example.Test');
    expect(names, [client.uniqueName]);
  });

  test('request name - queue', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Own a name with one client.
    var reply = await client1.requestName('com.example.Test');
    expect(reply, equals(DBusRequestNameReply.primaryOwner));

    // Attempt to replace the name with another client.
    reply = await client2.requestName('com.example.Test');
    expect(reply, equals(DBusRequestNameReply.inQueue));

    // Check name is correctly owned and second client is in queue.
    var hasOwner = await client1.nameHasOwner('com.example.Test');
    expect(hasOwner, isTrue);
    var owner = await client1.getNameOwner('com.example.Test');
    expect(owner, equals(client1.uniqueName));
    var names = await client1.listQueuedOwners('com.example.Test');
    expect(names, equals([client1.uniqueName, client2.uniqueName]));
  });

  test('request name - do not queue', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Own a name with one client.
    var reply = await client1.requestName('com.example.Test');
    expect(reply, equals(DBusRequestNameReply.primaryOwner));

    // Attempt to replace the name with another client.
    reply = await client2.requestName('com.example.Test',
        flags: {DBusRequestNameFlag.doNotQueue});
    expect(reply, equals(DBusRequestNameReply.exists));

    // Check name is correctly owned and second client is not in queue.
    var hasOwner = await client1.nameHasOwner('com.example.Test');
    expect(hasOwner, isTrue);
    var owner = await client1.getNameOwner('com.example.Test');
    expect(owner, equals(client1.uniqueName));
    var names = await client1.listQueuedOwners('com.example.Test');
    expect(names, equals([client1.uniqueName]));
  });

  test('request name - replace', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Own a name with one client.
    var reply = await client1.requestName('com.example.Test',
        flags: {DBusRequestNameFlag.allowReplacement});
    expect(reply, equals(DBusRequestNameReply.primaryOwner));

    // Replace the name with another client.
    reply = await client2.requestName('com.example.Test',
        flags: {DBusRequestNameFlag.replaceExisting});
    expect(reply, equals(DBusRequestNameReply.primaryOwner));

    // Check name is correctly owned and second client is in queue.
    var hasOwner = await client1.nameHasOwner('com.example.Test');
    expect(hasOwner, isTrue);
    var owner = await client1.getNameOwner('com.example.Test');
    expect(owner, equals(client2.uniqueName));
    var names = await client1.listQueuedOwners('com.example.Test');
    expect(names, equals([client2.uniqueName, client1.uniqueName]));
  });

  test('request name - replace, do not queue', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Own a name with one client.
    var reply = await client1.requestName('com.example.Test', flags: {
      DBusRequestNameFlag.allowReplacement,
      DBusRequestNameFlag.doNotQueue
    });
    expect(reply, equals(DBusRequestNameReply.primaryOwner));

    // Replace the name with another client.
    reply = await client2.requestName('com.example.Test',
        flags: {DBusRequestNameFlag.replaceExisting});
    expect(reply, equals(DBusRequestNameReply.primaryOwner));

    // Check name is correctly owned and first client is not in queue.
    var hasOwner = await client1.nameHasOwner('com.example.Test');
    expect(hasOwner, isTrue);
    var owner = await client1.getNameOwner('com.example.Test');
    expect(owner, equals(client2.uniqueName));
    var names = await client1.listQueuedOwners('com.example.Test');
    expect(names, equals([client2.uniqueName]));
  });

  test('request name - replace not allowed', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Own a name with one client.
    var reply = await client1.requestName('com.example.Test');
    expect(reply, equals(DBusRequestNameReply.primaryOwner));

    // Attempt to replace the name with another client.
    reply = await client2.requestName('com.example.Test',
        flags: {DBusRequestNameFlag.replaceExisting});
    expect(reply, equals(DBusRequestNameReply.inQueue));

    // Check name is correctly owned and second client is in queue.
    var hasOwner = await client1.nameHasOwner('com.example.Test');
    expect(hasOwner, isTrue);
    var owner = await client1.getNameOwner('com.example.Test');
    expect(owner, equals(client1.uniqueName));
    var names = await client1.listQueuedOwners('com.example.Test');
    expect(names, equals([client1.uniqueName, client2.uniqueName]));
  });

  test('request name - empty', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client = DBusClient(address);

    // Attempt to request an empty bus name
    expect(client.requestName(''), throwsA(isMethodResponseException));
  });

  test('request name - unique', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client = DBusClient(address);

    // Attempt to request a unique bus name
    expect(client.requestName(':unique'), throwsA(isMethodResponseException));
  });

  test('request name - not enough elements', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client = DBusClient(address);

    // Attempt to request a unique bus name
    expect(client.requestName('foo'), throwsA(isMethodResponseException));
  });

  test('request name - leading period', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client = DBusClient(address);

    // Attempt to request a unique bus name
    expect(client.requestName('.foo.bar'), throwsA(isMethodResponseException));
  });

  test('request name - trailing period', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client = DBusClient(address);

    // Attempt to request a unique bus name
    expect(client.requestName('foo.bar.'), throwsA(isMethodResponseException));
  });

  test('request name - empty element', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client = DBusClient(address);

    // Attempt to request a unique bus name
    expect(client.requestName('foo..bar'), throwsA(isMethodResponseException));
  });

  test('release name', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client = DBusClient(address);

    // Check get an event when acquired and lost
    client.nameAcquired.listen(expectAsync1((name) {
      expect(name, equals('com.example.Test'));
    }));
    client.nameLost.listen(expectAsync1((name) {
      expect(name, equals('com.example.Test'));
    }));

    // Request the name.
    var requestReply = await client.requestName('com.example.Test');
    expect(requestReply, equals(DBusRequestNameReply.primaryOwner));

    // Release the name.
    var releaseReply = await client.releaseName('com.example.Test');
    expect(releaseReply, equals(DBusReleaseNameReply.released));

    // Check name is unowned.
    var hasOwner = await client.nameHasOwner('com.example.Test');
    expect(hasOwner, isFalse);
    var names = await client.listQueuedOwners('com.example.Test');
    expect(names, isEmpty);
  });

  test('release name - non existant', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client = DBusClient(address);

    // Release a name that's not in use.
    var releaseReply = await client.releaseName('com.example.Test');
    expect(releaseReply, equals(DBusReleaseNameReply.nonExistant));
  });

  test('release name - not owner', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Own a name with one client.
    var requestReply = await client1.requestName('com.example.Test',
        flags: {DBusRequestNameFlag.allowReplacement});
    expect(requestReply, equals(DBusRequestNameReply.primaryOwner));

    // Attempt to release that name from another client.
    var releaseReply = await client2.releaseName('com.example.Test');
    expect(releaseReply, equals(DBusReleaseNameReply.notOwner));
  });

  test('release name - queue', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Own a name with one client.
    var requestReply = await client1.requestName('com.example.Test');
    expect(requestReply, equals(DBusRequestNameReply.primaryOwner));

    // Join queue for this name.
    requestReply = await client2.requestName('com.example.Test',
        flags: {DBusRequestNameFlag.replaceExisting});
    expect(requestReply, equals(DBusRequestNameReply.inQueue));

    // Have the first client release the name.
    var releaseReply = await client1.releaseName('com.example.Test');
    expect(releaseReply, equals(DBusReleaseNameReply.released));

    // Check name is correctly transferred to second client..
    var hasOwner = await client1.nameHasOwner('com.example.Test');
    expect(hasOwner, isTrue);
    var owner = await client1.getNameOwner('com.example.Test');
    expect(owner, equals(client2.uniqueName));
    var names = await client1.listQueuedOwners('com.example.Test');
    expect(names, equals([client2.uniqueName]));
  });

  test('release name - empty', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client = DBusClient(address);

    // Attempt to release an empty bus name.
    expect(client.releaseName(''), throwsA(isMethodResponseException));
  });

  test('release name - unique name', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client = DBusClient(address);

    // Attempt to release the unique name of this client.
    expect(client.releaseName(client.uniqueName),
        throwsA(isMethodResponseException));
  });

  test('call method', () async {
    var server = DBusServer();
    var address = await server.listenUnixSocket();
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes a method.
    await client1.registerObject(EchoObject());

    // Call the method from another client.
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
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes a method.
    var object = DBusObject();
    await client1.registerObject(object);

    // Subscribe to the signal from another client.
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
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes introspection data.
    await client1.registerObject(IntrospectObject());

    // Read introspection data from the first client.
    var remoteObject =
        DBusRemoteObject(client2, client1.uniqueName, DBusObjectPath('/'));
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
