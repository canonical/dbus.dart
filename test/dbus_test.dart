import 'dart:io';

import 'package:dbus/code_generator.dart';
import 'package:dbus/dbus.dart';
import 'package:dbus/src/getuid.dart';
import 'package:test/test.dart';

// Test server that exposes an activatable service.
class ServerWithActivatableService extends DBusServer {
  @override
  List<String> get activatableNames =>
      ['com.example.NotRunning', 'com.example.AlreadyRunning'];

  @override
  Future<DBusServerStartServiceResult> startServiceByName(String name) async {
    if (name == 'com.example.NotRunning') {
      return DBusServerStartServiceResult.success;
    } else if (name == 'com.example.AlreadyRunning') {
      return DBusServerStartServiceResult.alreadyRunning;
    } else {
      return DBusServerStartServiceResult.notFound;
    }
  }
}

class TestObject extends DBusObject {
  // Method call to expect
  final String? expectedMethodName;

  // Arguments to expect on method call.
  final List<DBusValue>? expectedMethodValues;

  // Flags to expect on method call.
  final Set<DBusMethodCallFlag>? expectedMethodFlags;

  // Responses to send to method calls.
  final Map<String, DBusMethodResponse> methodResponses;

  // Data to return when introspected.
  final List<DBusIntrospectInterface> introspectData;

  // Values for each property.
  final Map<String, DBusValue> propertyValues;

  // Error responses to give when getting a property.
  final Map<String, DBusMethodErrorResponse> propertyGetErrors;

  // Error responses to give when setting a property.
  final Map<String, DBusMethodErrorResponse> propertySetErrors;

  // Interfaces reported by an object manager.
  final Map<String, Map<String, DBusValue>> interfacesAndProperties_;

  TestObject(
      {DBusObjectPath path = const DBusObjectPath.unchecked('/'),
      this.expectedMethodName,
      this.expectedMethodValues,
      this.expectedMethodFlags,
      this.methodResponses = const {},
      this.introspectData = const [],
      this.propertyValues = const {},
      this.propertyGetErrors = const {},
      this.propertySetErrors = const {},
      this.interfacesAndProperties_ = const {}})
      : super(path);

  void updateInterface(String name, Map<String, DBusValue> properties) {
    interfacesAndProperties_[name] = properties;
  }

  void removeInterface(String name) {
    interfacesAndProperties_.remove(name);
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    var name = methodCall.interface != null
        ? '${methodCall.interface}.${methodCall.name}'
        : methodCall.name;

    if (expectedMethodName != null) {
      expect(name, equals(expectedMethodName));
    }
    if (expectedMethodValues != null) {
      expect(methodCall.values, equals(expectedMethodValues));
    }
    if (expectedMethodFlags != null) {
      expect(methodCall.flags, equals(expectedMethodFlags));
    }

    var response = methodResponses[name];
    return response ?? DBusMethodErrorResponse.unknownMethod();
  }

  @override
  List<DBusIntrospectInterface> introspect() {
    return introspectData;
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    var propertyName = '$interface.$name';
    var response = propertyGetErrors[propertyName];
    if (response != null) {
      return response;
    }
    var value = propertyValues[propertyName];
    if (value == null) {
      return DBusMethodErrorResponse.unknownProperty();
    }
    return DBusGetPropertyResponse(value);
  }

  @override
  Future<DBusMethodResponse> setProperty(
      String interface, String name, DBusValue value) async {
    var propertyName = '$interface.$name';
    var response = propertySetErrors[propertyName];
    if (response != null) {
      return response;
    }
    propertyValues[propertyName] = value;
    return DBusMethodSuccessResponse();
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    var prefix = '$interface.';
    var properties = <String, DBusValue>{};
    propertyValues.forEach((name, value) {
      if (name.startsWith(prefix)) {
        properties[name.substring(prefix.length)] = value;
      }
    });
    return DBusGetAllPropertiesResponse(properties);
  }

  @override
  Map<String, Map<String, DBusValue>> get interfacesAndProperties =>
      interfacesAndProperties_;
}

void main() {
  test('ping', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);

    // Check can ping the server.
    await client.ping();
    await client.close();
  });

  test('ping - ipv4 tcp', () async {
    var server = DBusServer();
    var address = await server.listenAddress(
        DBusAddress.tcp('localhost', family: DBusAddressTcpFamily.ipv4));
    var client = DBusClient(address);

    // Check can ping the server.
    await client.ping();
    await client.close();
  });

  test('ping - ipv6 tcp', () async {
    var server = DBusServer();
    var address = await server.listenAddress(
        DBusAddress.tcp('localhost', family: DBusAddressTcpFamily.ipv6));
    var client = DBusClient(address);

    // Check can ping the server.
    await client.ping();
    await client.close();
  }, tags: ['ipv6']);

  test('list names', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);

    // Check the server and this clients name is reported.
    var names = await client.listNames();
    expect(names, equals(['org.freedesktop.DBus', client.uniqueName]));
    await client.close();
  });

  test('request name', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
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

    await client.close();
  });

  test('request name - already owned', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
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

    await client.close();
  });

  test('request name - queue', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
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

    await client1.close();
    await client2.close();
  });

  test('request name - do not queue', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
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

    await client1.close();
    await client2.close();
  });

  test('request name - replace', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
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

    await client1.close();
    await client2.close();
  });

  test('request name - replace, do not queue', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
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

    await client1.close();
    await client2.close();
  });

  test('request name - replace not allowed', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
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

    await client1.close();
    await client2.close();
  });

  test('request name - empty', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);

    // Attempt to request an empty bus name
    try {
      await client.requestName('');
      fail('Expected DBusMethodResponseException');
    } on DBusMethodResponseException catch (e) {
      expect(e.response.errorName,
          equals('org.freedesktop.DBus.Error.InvalidArgs'));
    }

    await client.close();
  });

  test('request name - unique', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);

    // Attempt to request a unique bus name
    try {
      await client.requestName(':unique');
      fail('Expected DBusMethodResponseException');
    } on DBusMethodResponseException catch (e) {
      expect(e.response.errorName,
          equals('org.freedesktop.DBus.Error.InvalidArgs'));
    }

    await client.close();
  });

  test('request name - not enough elements', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);

    // Attempt to request a unique bus name
    try {
      await client.requestName('foo');
      fail('Expected DBusMethodResponseException');
    } on DBusMethodResponseException catch (e) {
      expect(e.response.errorName,
          equals('org.freedesktop.DBus.Error.InvalidArgs'));
    }

    await client.close();
  });

  test('request name - leading period', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);

    // Attempt to request a unique bus name
    try {
      await client.requestName('.foo.bar');
      fail('Expected DBusMethodResponseException');
    } on DBusMethodResponseException catch (e) {
      expect(e.response.errorName,
          equals('org.freedesktop.DBus.Error.InvalidArgs'));
    }

    await client.close();
  });

  test('request name - trailing period', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);

    // Attempt to request a unique bus name
    try {
      await client.requestName('foo.bar.');
      fail('Expected DBusMethodResponseException');
    } on DBusMethodResponseException catch (e) {
      expect(e.response.errorName,
          equals('org.freedesktop.DBus.Error.InvalidArgs'));
    }

    await client.close();
  });

  test('request name - empty element', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);

    // Attempt to request a unique bus name
    try {
      await client.requestName('foo..bar');
      fail('Expected DBusMethodResponseException');
    } on DBusMethodResponseException catch (e) {
      expect(e.response.errorName,
          equals('org.freedesktop.DBus.Error.InvalidArgs'));
    }

    await client.close();
  });

  test('release name', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
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

    await client.close();
  });

  test('release name - non existant', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);

    // Release a name that's not in use.
    var releaseReply = await client.releaseName('com.example.Test');
    expect(releaseReply, equals(DBusReleaseNameReply.nonExistant));

    await client.close();
  });

  test('release name - not owner', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Own a name with one client.
    var requestReply = await client1.requestName('com.example.Test',
        flags: {DBusRequestNameFlag.allowReplacement});
    expect(requestReply, equals(DBusRequestNameReply.primaryOwner));

    // Attempt to release that name from another client.
    var releaseReply = await client2.releaseName('com.example.Test');
    expect(releaseReply, equals(DBusReleaseNameReply.notOwner));

    await client1.close();
    await client2.close();
  });

  test('release name - queue', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
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

    await client1.close();
    await client2.close();
  });

  test('release name - empty', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);

    // Attempt to release an empty bus name.
    try {
      await client.releaseName('');
      fail('Expected DBusMethodResponseException');
    } on DBusMethodResponseException catch (e) {
      expect(e.response.errorName,
          equals('org.freedesktop.DBus.Error.InvalidArgs'));
    }

    await client.close();
  });

  test('release name - unique name', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);

    // Attempt to release the unique name of this client.
    try {
      await client.releaseName(client.uniqueName);
      fail('Expected DBusMethodResponseException');
    } on DBusMethodResponseException catch (e) {
      expect(e.response.errorName,
          equals('org.freedesktop.DBus.Error.InvalidArgs'));
    }

    await client.close();
  });

  test('list activatable names', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);

    // Only the bus service available by default.
    var names = await client.listActivatableNames();
    expect(names, equals(['org.freedesktop.DBus']));

    await client.close();
  });

  test('start service by name', () async {
    var server = ServerWithActivatableService();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);

    var names = await client.listActivatableNames();
    expect(
        names,
        equals([
          'org.freedesktop.DBus',
          'com.example.NotRunning',
          'com.example.AlreadyRunning'
        ]));

    var result1 = await client.startServiceByName('com.example.NotRunning');
    expect(result1, equals(DBusStartServiceByNameReply.success));

    var result2 = await client.startServiceByName('com.example.AlreadyRunning');
    expect(result2, equals(DBusStartServiceByNameReply.alreadyRunning));

    try {
      await client.startServiceByName('com.example.DoesNotExist');
      fail('Expected DBusMethodResponseException');
    } on DBusMethodResponseException catch (e) {
      expect(e.response.errorName,
          equals('org.freedesktop.DBus.Error.ServiceNotFound'));
    }

    await client.close();
  });

  test('get unix user', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);

    var uid = await client.getConnectionUnixUser('org.freedesktop.DBus');
    expect(uid, equals(getuid()));

    await client.close();
  });

  test('get process id', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);

    var pid_ = await client.getConnectionUnixProcessId('org.freedesktop.DBus');
    expect(pid_, equals(pid));

    await client.close();
  });

  test('get credentials', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);

    var credentials =
        await client.getConnectionCredentials('org.freedesktop.DBus');
    expect(credentials.unixUserId, equals(getuid()));
    expect(credentials.processId, equals(pid));

    await client.close();
  });

  test('call method', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes a method.
    await client1.registerObject(
        TestObject(expectedMethodName: 'Test', expectedMethodValues: [
      DBusString('Hello'),
      DBusUint32(42)
    ], expectedMethodFlags: {}, methodResponses: {
      'Test': DBusMethodSuccessResponse([DBusString('World'), DBusUint32(99)])
    }));

    // Call the method from another client.
    var response = await client2.callMethod(
        destination: client1.uniqueName,
        path: DBusObjectPath('/'),
        name: 'Test',
        values: [DBusString('Hello'), DBusUint32(42)]);
    expect(response.values, equals([DBusString('World'), DBusUint32(99)]));

    await client1.close();
    await client2.close();
  });

  test('call method - no response', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes a method.
    await client1.registerObject(
        TestObject(expectedMethodFlags: {DBusMethodCallFlag.noReplyExpected}));

    // Call the method from another client.
    var response = await client2.callMethod(
        destination: client1.uniqueName,
        path: DBusObjectPath('/'),
        name: 'Test',
        values: [DBusString('Hello'), DBusUint32(42)],
        flags: {DBusMethodCallFlag.noReplyExpected});
    expect(response.values, equals([]));

    await client1.close();
    await client2.close();
  });

  test('call method - registered name', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes a method.
    await client1.requestName('com.example.Test');
    await client1.registerObject(
        TestObject(methodResponses: {'Test': DBusMethodSuccessResponse()}));

    // Call the method from another client.
    var response = await client2.callMethod(
        destination: 'com.example.Test',
        path: DBusObjectPath('/'),
        name: 'Test',
        values: [DBusString('Hello'), DBusUint32(42)]);
    expect(response.values, equals([]));

    await client1.close();
    await client2.close();
  });

  test('call method - expected signature', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes a method.
    await client1.registerObject(TestObject(methodResponses: {
      'Test': DBusMethodSuccessResponse([DBusString('Hello'), DBusUint32(42)])
    }));

    // Call the method from another client and check the signature.
    var response = await client2.callMethod(
        destination: client1.uniqueName,
        path: DBusObjectPath('/'),
        name: 'Test',
        replySignature: DBusSignature('su'));
    expect(response.values, equals([DBusString('Hello'), DBusUint32(42)]));

    await client1.close();
    await client2.close();
  });

  test('call method - expected signature mismatch', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes a method.
    await client1.registerObject(TestObject(methodResponses: {
      'Test': DBusMethodSuccessResponse([DBusString('Hello'), DBusUint32(42)])
    }));

    // Call the method from another client and check the signature.
    try {
      await client2.callMethod(
          destination: client1.uniqueName,
          path: DBusObjectPath('/'),
          name: 'Test',
          replySignature: DBusSignature('us'));
      fail('Expected DBusReplySignatureException');
    } on DBusReplySignatureException catch (e) {
      expect(e.response.values, equals([DBusString('Hello'), DBusUint32(42)]));
    }

    await client1.close();
    await client2.close();
  });

  test('call method - no autostart', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes a method.
    await client1.registerObject(TestObject(
        expectedMethodFlags: {DBusMethodCallFlag.noAutoStart},
        methodResponses: {'Test': DBusMethodSuccessResponse()}));

    // Call the method from another client.
    var response = await client2.callMethod(
        destination: client1.uniqueName,
        path: DBusObjectPath('/'),
        name: 'Test',
        values: [DBusString('Hello'), DBusUint32(42)],
        flags: {DBusMethodCallFlag.noAutoStart});
    expect(response.values, equals([]));

    await client1.close();
    await client2.close();
  });

  test('call method - allow interactive authorization', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes a method.
    await client1.registerObject(TestObject(
        expectedMethodFlags: {DBusMethodCallFlag.allowInteractiveAuthorization},
        methodResponses: {'Test': DBusMethodSuccessResponse()}));

    // Call the method from another client.
    var response = await client2.callMethod(
        destination: client1.uniqueName,
        path: DBusObjectPath('/'),
        name: 'Test',
        values: [DBusString('Hello'), DBusUint32(42)],
        flags: {DBusMethodCallFlag.allowInteractiveAuthorization});
    expect(response.values, equals([]));

    await client1.close();
    await client2.close();
  });

  test('call method - error', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes a method.
    await client1.registerObject(
        TestObject(expectedMethodName: 'Test', methodResponses: {
      'Test': DBusMethodErrorResponse(
          'com.example.Error', [DBusString('Count'), DBusUint32(42)])
    }));

    // Call the method from another client.
    try {
      await client2.callMethod(
          destination: client1.uniqueName,
          path: DBusObjectPath('/'),
          name: 'Test');
      fail('Expected DBusMethodResponseException');
    } on DBusMethodResponseException catch (e) {
      expect(e.response.errorName, equals('com.example.Error'));
      expect(e.response.values, equals([DBusString('Count'), DBusUint32(42)]));
    }

    await client1.close();
    await client2.close();
  });

  test('call method - remote object', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes a method.
    await client1.registerObject(TestObject(
        expectedMethodName: 'com.example.Test.Foo',
        expectedMethodValues: [
          DBusString('Hello'),
          DBusUint32(42)
        ],
        expectedMethodFlags: {},
        methodResponses: {
          'com.example.Test.Foo':
              DBusMethodSuccessResponse([DBusString('World'), DBusUint32(99)])
        }));

    // Call the method from another client.
    var remoteObject =
        DBusRemoteObject(client2, client1.uniqueName, DBusObjectPath('/'));
    var response = await remoteObject.callMethod(
        'com.example.Test', 'Foo', [DBusString('Hello'), DBusUint32(42)]);
    expect(response.values, equals([DBusString('World'), DBusUint32(99)]));

    await client1.close();
    await client2.close();
  });

  test('call method - remote object - expected signature', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes a method.
    await client1.registerObject(TestObject(
        expectedMethodName: 'com.example.Test.Foo',
        expectedMethodFlags: {},
        methodResponses: {
          'com.example.Test.Foo':
              DBusMethodSuccessResponse([DBusString('World'), DBusUint32(99)])
        }));

    // Call the method from another client.
    var remoteObject =
        DBusRemoteObject(client2, client1.uniqueName, DBusObjectPath('/'));
    var response = await remoteObject.callMethod('com.example.Test', 'Foo', [],
        replySignature: DBusSignature('su'));
    expect(response.values, equals([DBusString('World'), DBusUint32(99)]));

    await client1.close();
    await client2.close();
  });

  test('call method - remote object - expected signature mismatch', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes a method.
    await client1.registerObject(TestObject(
        expectedMethodName: 'com.example.Test.Foo',
        expectedMethodFlags: {},
        methodResponses: {
          'com.example.Test.Foo':
              DBusMethodSuccessResponse([DBusString('Hello'), DBusUint32(42)])
        }));

    // Call the method from another client.
    var remoteObject =
        DBusRemoteObject(client2, client1.uniqueName, DBusObjectPath('/'));
    try {
      await remoteObject.callMethod('com.example.Test', 'Foo', [],
          replySignature: DBusSignature('us'));
      fail('Expected DBusReplySignatureException');
    } on DBusReplySignatureException catch (e) {
      expect(e.response.values, equals([DBusString('Hello'), DBusUint32(42)]));
    }

    await client1.close();
    await client2.close();
  });

  test('subscribe signal', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client to emit a signal.
    var object = DBusObject(DBusObjectPath('/'));
    await client1.registerObject(object);

    // Subscribe to the signal from another client.
    var signals =
        DBusSignalStream(client2, interface: 'com.example.Test', name: 'Ping');
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

  test('subscribe signal - remote object', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client to emit a signal.
    var object = DBusObject(DBusObjectPath('/'));
    await client1.registerObject(object);

    // Subscribe to the signal from another client.
    var remoteObject =
        DBusRemoteObject(client2, client1.uniqueName, DBusObjectPath('/'));
    var signals =
        DBusRemoteObjectSignalStream(remoteObject, 'com.example.Test', 'Ping');
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

  test('subscribe signal - remote named object', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client to emit a signal.
    var object = DBusObject(DBusObjectPath('/'));
    await client1.requestName('com.example.Test');
    await client1.registerObject(object);

    // Subscribe to the signal from another client.
    var remoteObject =
        DBusRemoteObject(client2, 'com.example.Test', DBusObjectPath('/'));
    var signals =
        DBusRemoteObjectSignalStream(remoteObject, 'com.example.Test', 'Ping');
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
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes introspection data.
    await client1.registerObject(TestObject(introspectData: [
      DBusIntrospectInterface('com.example.Test',
          methods: [DBusIntrospectMethod('Foo')])
    ]));

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
            '<signal name="PropertiesChanged">'
            '<arg name="interface_name" type="s"/>'
            '<arg name="changed_properties" type="a{sv}"/>'
            '<arg name="invalidated_properties" type="as"/>'
            '</signal>'
            '</interface>'
            '<interface name="com.example.Test">'
            '<method name="Foo"/>'
            '</interface>'
            '</node>'));

    await client1.close();
    await client2.close();
  });

  test('introspect - not introspectable', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address, introspectable: false);
    var client2 = DBusClient(address);

    // Create a client that exposes introspection data.
    await client1.registerObject(TestObject(introspectData: [
      DBusIntrospectInterface('com.example.Test',
          methods: [DBusIntrospectMethod('Foo')])
    ]));

    // Unable to read introspection data from the first client.
    var remoteObject =
        DBusRemoteObject(client2, client1.uniqueName, DBusObjectPath('/'));
    try {
      await remoteObject.introspect();
      fail('Expected DBusMethodResponseException');
    } on DBusMethodResponseException catch (e) {
      expect(e.response.errorName,
          equals('org.freedesktop.DBus.Error.UnknownMethod'));
    }

    await client1.close();
    await client2.close();
  });

  test('get property', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes an object with properties.
    var object = TestObject(propertyValues: {
      'com.example.Test.ReadWrite': DBusString('RW'),
      'com.example.Test.ReadOnly': DBusString('RO'),
      'com.example.Test.WriteOnly': DBusString('WO')
    }, propertyGetErrors: {
      'com.example.Test.WriteOnly': DBusMethodErrorResponse.propertyWriteOnly()
    }, propertySetErrors: {
      'com.example.Test.ReadOnly': DBusMethodErrorResponse.propertyReadOnly(),
    });
    await client1.registerObject(object);

    var remoteObject =
        DBusRemoteObject(client2, client1.uniqueName, DBusObjectPath('/'));

    // Get properties from another client.

    var readWriteValue =
        await remoteObject.getProperty('com.example.Test', 'ReadWrite');
    expect(readWriteValue, equals(DBusString('RW')));

    var readOnlyValue =
        await remoteObject.getProperty('com.example.Test', 'ReadOnly');
    expect(readOnlyValue, equals(DBusString('RO')));

    expect(remoteObject.getProperty('com.example.Test', 'WriteOnly'),
        throwsException);

    await client1.close();
    await client2.close();
  });

  test('get property - match signature', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes an object with properties.
    var object = TestObject(
        propertyValues: {'com.example.Test.Property': DBusString('Value')});
    await client1.registerObject(object);

    var remoteObject =
        DBusRemoteObject(client2, client1.uniqueName, DBusObjectPath('/'));

    // Get properties and check they match expected signature.
    expect(
        await remoteObject.getProperty('com.example.Test', 'Property',
            signature: DBusSignature('s')),
        equals(DBusString('Value')));
    expect(
        () async => await remoteObject.getProperty(
            'com.example.Test', 'Property',
            signature: DBusSignature('i')),
        throwsA(isA<DBusPropertySignatureException>()));

    await client1.close();
    await client2.close();
  });

  test('set property', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes an object with properties.
    var object = TestObject(propertyValues: {
      'com.example.Test.ReadWrite': DBusString(''),
      'com.example.Test.ReadOnly': DBusString(''),
      'com.example.Test.WriteOnly': DBusString('')
    }, propertyGetErrors: {
      'com.example.Test.WriteOnly': DBusMethodErrorResponse.propertyWriteOnly()
    }, propertySetErrors: {
      'com.example.Test.ReadOnly': DBusMethodErrorResponse.propertyReadOnly(),
    });
    await client1.registerObject(object);

    var remoteObject =
        DBusRemoteObject(client2, client1.uniqueName, DBusObjectPath('/'));

    // Set properties from another client.

    await remoteObject.setProperty(
        'com.example.Test', 'ReadWrite', DBusString('RW'));
    expect(object.propertyValues['com.example.Test.ReadWrite'],
        equals(DBusString('RW')));

    expect(
        remoteObject.setProperty(
            'com.example.Test', 'ReadOnly', DBusString('RO')),
        throwsException);

    await remoteObject.setProperty(
        'com.example.Test', 'WriteOnly', DBusString('WO'));
    expect(object.propertyValues['com.example.Test.WriteOnly'],
        equals(DBusString('WO')));

    await client1.close();
    await client2.close();
  });

  test('get all properties', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes an object with properties.
    var object = TestObject(propertyValues: {
      'com.example.Test.Property1': DBusString('VALUE1'),
      'com.example.Test.Property2': DBusString('VALUE2')
    });
    await client1.registerObject(object);

    var remoteObject =
        DBusRemoteObject(client2, client1.uniqueName, DBusObjectPath('/'));

    var properties = await remoteObject.getAllProperties('com.example.Test');
    expect(
        properties,
        equals({
          'Property1': DBusString('VALUE1'),
          'Property2': DBusString('VALUE2')
        }));
  });

  test('properties changed', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Create a client that exposes an object with properties.
    var object = TestObject();
    await client1.registerObject(object);

    /// Subscribe to properties changed signals.
    var remoteObject =
        DBusRemoteObject(client2, client1.uniqueName, DBusObjectPath('/'));
    remoteObject.propertiesChanged.listen(expectAsync1((signal) {
      expect(signal.propertiesInterface, equals('com.example.Test'));
      expect(
          signal.changedProperties,
          equals({
            'Property1': DBusString('VALUE1'),
            'Property2': DBusString('VALUE2')
          }));
      expect(signal.invalidatedProperties, equals(['Invalid1', 'Invalid2']));
    }));

    // Do a round-trip to the server to ensure the signal has been subscribed to.
    await client2.ping();

    object.emitPropertiesChanged('com.example.Test', changedProperties: {
      'Property1': DBusString('VALUE1'),
      'Property2': DBusString('VALUE2')
    }, invalidatedProperties: [
      'Invalid1',
      'Invalid2'
    ]);
  });

  test('object manager', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Register an object manager and a few objects with properties.
    await client1
        .registerObject(DBusObject(DBusObjectPath('/'), isObjectManager: true));
    await client1.registerObject(TestObject(
        path: DBusObjectPath('/com/example/Object1'),
        interfacesAndProperties_: {
          'com.example.Interface1': {'number': DBusUint32(1)}
        }));
    await client1.registerObject(TestObject(
        path: DBusObjectPath('/com/example/Object2'),
        interfacesAndProperties_: {
          'com.example.Interface1': {'number': DBusUint32(2)},
          'com.example.Interface2': {'value': DBusString('FOO')}
        }));

    var remoteManagerObject = DBusRemoteObjectManager(
        client2, client1.uniqueName, DBusObjectPath('/'));
    var objects = await remoteManagerObject.getManagedObjects();
    expect(
        objects,
        equals({
          DBusObjectPath('/com/example/Object1'): {
            'org.freedesktop.DBus.Introspectable': {},
            'org.freedesktop.DBus.Properties': {},
            'com.example.Interface1': {'number': DBusUint32(1)}
          },
          DBusObjectPath('/com/example/Object2'): {
            'org.freedesktop.DBus.Introspectable': {},
            'org.freedesktop.DBus.Properties': {},
            'com.example.Interface1': {'number': DBusUint32(2)},
            'com.example.Interface2': {'value': DBusString('FOO')}
          }
        }));

    await client1.close();
    await client2.close();
  });

  test('object manager - no interfaces', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Register an object manager and an object without any interfaces other than the standard ones.
    await client1
        .registerObject(DBusObject(DBusObjectPath('/'), isObjectManager: true));
    await client1.registerObject(
        TestObject(path: DBusObjectPath('/com/example/Object')));

    var remoteManagerObject = DBusRemoteObjectManager(
        client2, client1.uniqueName, DBusObjectPath('/'));
    var objects = await remoteManagerObject.getManagedObjects();
    expect(
        objects,
        equals({
          DBusObjectPath('/com/example/Object'): {
            'org.freedesktop.DBus.Introspectable': {},
            'org.freedesktop.DBus.Properties': {}
          }
        }));

    await client1.close();
    await client2.close();
  });

  test('object manager - not introspectable', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address, introspectable: false);
    var client2 = DBusClient(address);

    // Register an object manager and one object. The client doesn't support introspection.
    await client1
        .registerObject(DBusObject(DBusObjectPath('/'), isObjectManager: true));
    await client1.registerObject(
        TestObject(path: DBusObjectPath('/com/example/Object')));

    var remoteManagerObject = DBusRemoteObjectManager(
        client2, client1.uniqueName, DBusObjectPath('/'));
    var objects = await remoteManagerObject.getManagedObjects();
    expect(
        objects,
        equals({
          DBusObjectPath('/com/example/Object'): {
            'org.freedesktop.DBus.Properties': {}
          }
        }));
  });

  test('object manager - object added', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Register an object manager with one object.
    var objectManager = DBusObject(DBusObjectPath('/'), isObjectManager: true);
    await client1.registerObject(objectManager);
    await client1.registerObject(
        TestObject(path: DBusObjectPath('/com/example/Object1')));

    // Subscribe to object manager signals.
    var remoteManagerObject = DBusRemoteObjectManager(
        client2, client1.uniqueName, DBusObjectPath('/'));
    remoteManagerObject.signals.listen(expectAsync1((signal) {
      expect(signal, TypeMatcher<DBusObjectManagerInterfacesAddedSignal>());
      var interfacesAdded = signal as DBusObjectManagerInterfacesAddedSignal;
      expect(interfacesAdded.changedPath,
          equals(DBusObjectPath('/com/example/Object2')));
      expect(
          interfacesAdded.interfacesAndProperties,
          equals({
            'org.freedesktop.DBus.Introspectable': {},
            'org.freedesktop.DBus.Properties': {},
            'com.example.Interface': {
              'Property1': DBusString('VALUE1'),
              'Property2': DBusString('VALUE2')
            }
          }));
    }));

    // Do a round-trip to the server to ensure the signal has been subscribed to.
    await client2.ping();

    // Add a second object.
    await client1.registerObject(TestObject(
        path: DBusObjectPath('/com/example/Object2'),
        interfacesAndProperties_: {
          'com.example.Interface': {
            'Property1': DBusString('VALUE1'),
            'Property2': DBusString('VALUE2')
          }
        }));
  });

  test('object manager - object removed', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Register an object manager with two objects.
    var objectManager = DBusObject(DBusObjectPath('/'), isObjectManager: true);
    await client1.registerObject(objectManager);
    await client1.registerObject(
        TestObject(path: DBusObjectPath('/com/example/Object1')));
    var object2 = TestObject(
        path: DBusObjectPath('/com/example/Object2'),
        interfacesAndProperties_: {
          'org.freedesktop.DBus.Introspectable': {},
          'org.freedesktop.DBus.Properties': {},
          'com.example.Interface1': {'number': DBusUint32(2)},
          'com.example.Interface2': {'value': DBusString('FOO')}
        });
    await client1.registerObject(object2);

    // Subscribe to object manager signals.
    var remoteManagerObject = DBusRemoteObjectManager(
        client2, client1.uniqueName, DBusObjectPath('/'));
    remoteManagerObject.signals.listen(expectAsync1((signal) {
      expect(signal, TypeMatcher<DBusObjectManagerInterfacesRemovedSignal>());
      var interfacesRemoved =
          signal as DBusObjectManagerInterfacesRemovedSignal;
      expect(interfacesRemoved.changedPath,
          equals(DBusObjectPath('/com/example/Object2')));
      expect(
          interfacesRemoved.interfaces,
          equals([
            'org.freedesktop.DBus.Introspectable',
            'org.freedesktop.DBus.Properties',
            'com.example.Interface1',
            'com.example.Interface2'
          ]));
    }));

    // Do a round-trip to the server to ensure the signal has been subscribed to.
    await client2.ping();

    // Remove an object.
    await client1.unregisterObject(object2);
  });

  test('object manager - interface added', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Register an object manager with one object.
    var objectManager = DBusObject(DBusObjectPath('/'), isObjectManager: true);
    await client1.registerObject(objectManager);
    var object = TestObject(
        path: DBusObjectPath('/com/example/Object'),
        interfacesAndProperties_: {'com.example.Interface1': {}});
    await client1.registerObject(object);

    // Subscribe to object manager signals.
    var remoteManagerObject = DBusRemoteObjectManager(
        client2, client1.uniqueName, DBusObjectPath('/'));
    remoteManagerObject.signals.listen(expectAsync1((signal) {
      expect(signal, TypeMatcher<DBusObjectManagerInterfacesAddedSignal>());
      var interfacesAdded = signal as DBusObjectManagerInterfacesAddedSignal;
      expect(interfacesAdded.changedPath,
          equals(DBusObjectPath('/com/example/Object')));
      expect(
          interfacesAdded.interfacesAndProperties,
          equals({
            'com.example.Interface2': {
              'Property1': DBusString('VALUE1'),
              'Property2': DBusString('VALUE2')
            }
          }));
    }));

    // Do a round-trip to the server to ensure the signal has been subscribed to.
    await client2.ping();

    // Add an interface to the object.
    object.updateInterface('com.example.Interface2', {});
    objectManager.emitInterfacesAdded(object.path, {
      'com.example.Interface2': {
        'Property1': DBusString('VALUE1'),
        'Property2': DBusString('VALUE2')
      }
    });
  });

  test('object manager - interface removed', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Register an object manager with one object.
    var objectManager = DBusObject(DBusObjectPath('/'), isObjectManager: true);
    await client1.registerObject(objectManager);
    var object = TestObject(
        path: DBusObjectPath('/com/example/Object'),
        interfacesAndProperties_: {
          'com.example.Interface1': {},
          'com.example.Interface2': {}
        });
    await client1.registerObject(object);

    // Subscribe to object manager signals.
    var remoteManagerObject = DBusRemoteObjectManager(
        client2, client1.uniqueName, DBusObjectPath('/'));
    remoteManagerObject.signals.listen(expectAsync1((signal) {
      expect(signal, TypeMatcher<DBusObjectManagerInterfacesRemovedSignal>());
      var interfacesRemoved =
          signal as DBusObjectManagerInterfacesRemovedSignal;
      expect(interfacesRemoved.changedPath,
          equals(DBusObjectPath('/com/example/Object')));
      expect(interfacesRemoved.interfaces, equals(['com.example.Interface2']));
    }));

    // Do a round-trip to the server to ensure the signal has been subscribed to.
    await client2.ping();

    // Remove an interface from the object.
    object.removeInterface('com.example.Interface2');
    objectManager
        .emitInterfacesRemoved(object.path, ['com.example.Interface2']);
  });

  test('object manager - properties changed', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);

    // Register an object manager with one object.
    var objectManager = DBusObject(DBusObjectPath('/'), isObjectManager: true);
    await client1.registerObject(objectManager);
    var object = TestObject(
        path: DBusObjectPath('/com/example/Object'),
        interfacesAndProperties_: {
          'com.example.Interface1': {},
          'com.example.Interface2': {}
        });
    await client1.registerObject(object);

    // Subscribe to object manager signals.
    var remoteManagerObject = DBusRemoteObjectManager(
        client2, client1.uniqueName, DBusObjectPath('/'));
    remoteManagerObject.signals.listen(expectAsync1((signal) {
      expect(signal, TypeMatcher<DBusPropertiesChangedSignal>());
      var propertiesChanged = signal as DBusPropertiesChangedSignal;
      expect(
          propertiesChanged.changedProperties,
          equals({
            'Property1': DBusString('VALUE1'),
            'Property2': DBusString('VALUE2')
          }));
      expect(propertiesChanged.invalidatedProperties, equals([]));
    }));

    // Do a round-trip to the server to ensure the signal has been subscribed to.
    await client2.ping();

    // Change a property on the object.
    object.emitPropertiesChanged('com.example.Test', changedProperties: {
      'Property1': DBusString('VALUE1'),
      'Property2': DBusString('VALUE2')
    });
  });

  test('intropect xml - empty', () {
    expect(() => parseDBusIntrospectXml(''), throwsFormatException);
  });

  test('intropect xml - unknown tag', () {
    expect(() => parseDBusIntrospectXml('<foo/>'), throwsFormatException);
  });

  test('intropect xml - empty node', () {
    var node = parseDBusIntrospectXml('<node/>');
    expect(node, equals(DBusIntrospectNode()));
  });

  test('intropect xml - named node', () {
    var node = parseDBusIntrospectXml('<node name="/com/example/Test"/>');
    expect(node, equals(DBusIntrospectNode(name: '/com/example/Test')));
  });

  test('intropect xml - interface annotation', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><annotation name="com.example.Test.Name" value="AnnotationValue"/></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test', annotations: [
            DBusIntrospectAnnotation('com.example.Test.Name', 'AnnotationValue')
          ])
        ])));
  });

  test('intropect xml - empty interface', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"/></node>');
    expect(
        node,
        equals(DBusIntrospectNode(
            interfaces: [DBusIntrospectInterface('com.example.Test')])));
  });

  test('intropect xml - missing interface name', () {
    expect(() => parseDBusIntrospectXml('<node><interface/></node>'),
        throwsFormatException);
  });

  test('intropect xml - method no args', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><method name="Hello"/></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test',
              methods: [DBusIntrospectMethod('Hello')])
        ])));
  });

  test('intropect xml - method input arg', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><method name="Hello"><arg type="s"/></method></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test', methods: [
            DBusIntrospectMethod('Hello', args: [
              DBusIntrospectArgument(
                  DBusSignature('s'), DBusArgumentDirection.in_)
            ])
          ])
        ])));
  });

  test('intropect xml - method named arg', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><method name="Hello"><arg name="text" type="s"/></method></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test', methods: [
            DBusIntrospectMethod('Hello', args: [
              DBusIntrospectArgument(
                  DBusSignature('s'), DBusArgumentDirection.in_,
                  name: 'text')
            ])
          ])
        ])));
  });

  test('intropect xml - method input arg', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><method name="Hello"><arg type="s" direction="in"/></method></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test', methods: [
            DBusIntrospectMethod('Hello', args: [
              DBusIntrospectArgument(
                  DBusSignature('s'), DBusArgumentDirection.in_)
            ])
          ])
        ])));
  });

  test('intropect xml - method output arg', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><method name="Hello"><arg type="s" direction="out"/></method></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test', methods: [
            DBusIntrospectMethod('Hello', args: [
              DBusIntrospectArgument(
                  DBusSignature('s'), DBusArgumentDirection.out)
            ])
          ])
        ])));
  });

  test('intropect xml - method arg annotation', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><method name="Hello"><arg type="s"><annotation name="com.example.Test.Name" value="AnnotationValue"/></arg></method></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test', methods: [
            DBusIntrospectMethod('Hello', args: [
              DBusIntrospectArgument(
                  DBusSignature('s'), DBusArgumentDirection.in_, annotations: [
                DBusIntrospectAnnotation(
                    'com.example.Test.Name', 'AnnotationValue')
              ])
            ])
          ])
        ])));
  });

  test('intropect xml - method annotation', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><method name="Hello"><annotation name="com.example.Test.Name" value="AnnotationValue"/></method></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test', methods: [
            DBusIntrospectMethod('Hello', annotations: [
              DBusIntrospectAnnotation(
                  'com.example.Test.Name', 'AnnotationValue')
            ])
          ])
        ])));
  });

  test('intropect xml - missing method name', () {
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><method/></interface></node>'),
        throwsFormatException);
  });

  test('intropect xml - missing argument type', () {
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><method name="Hello"><arg/></method></interface></node>'),
        throwsFormatException);
  });

  test('intropect xml - unknown argument direction', () {
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><method name="Hello"><arg type="s" direction="down"/></method></interface></node>'),
        throwsFormatException);
  });

  test('intropect xml - signal', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><signal name="CountChanged"/></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test',
              signals: [DBusIntrospectSignal('CountChanged')])
        ])));
  });

  test('intropect xml - signal argument', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><signal name="CountChanged"><arg type="u"/></signal></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test', signals: [
            DBusIntrospectSignal('CountChanged', args: [
              DBusIntrospectArgument(
                  DBusSignature('u'), DBusArgumentDirection.out)
            ])
          ])
        ])));
  });

  test('intropect xml - signal output argument', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><signal name="CountChanged"><arg type="u" direction="out"/></signal></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test', signals: [
            DBusIntrospectSignal('CountChanged', args: [
              DBusIntrospectArgument(
                  DBusSignature('u'), DBusArgumentDirection.out)
            ])
          ])
        ])));
  });

  test('intropect xml - signal annotation', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><signal name="CountChanged"><annotation name="com.example.Test.Name" value="AnnotationValue"/></signal></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test', signals: [
            DBusIntrospectSignal('CountChanged', annotations: [
              DBusIntrospectAnnotation(
                  'com.example.Test.Name', 'AnnotationValue')
            ])
          ])
        ])));
  });

  test('intropect xml - signal no name', () {
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><signal/></interface></node>'),
        throwsFormatException);
  });

  test('intropect xml - signal input argument', () {
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><signal><arg type="u" direction="in"/></signal></interface></node>'),
        throwsFormatException);
  });

  test('intropect xml - property', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><property name="Count" type="u"/></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test',
              properties: [DBusIntrospectProperty('Count', DBusSignature('u'))])
        ])));
  });

  test('intropect xml - property - read access', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><property name="Count" type="u" access="read"/></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test', properties: [
            DBusIntrospectProperty('Count', DBusSignature('u'),
                access: DBusPropertyAccess.read)
          ])
        ])));
  });

  test('intropect xml - property - write access', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><property name="Count" type="u" access="write"/></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test', properties: [
            DBusIntrospectProperty('Count', DBusSignature('u'),
                access: DBusPropertyAccess.write)
          ])
        ])));
  });

  test('intropect xml - property - readwrite access', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><property name="Count" type="u" access="readwrite"/></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test', properties: [
            DBusIntrospectProperty('Count', DBusSignature('u'),
                access: DBusPropertyAccess.readwrite)
          ])
        ])));
  });

  test('intropect xml - property annotation', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><property name="Count" type="u"><annotation name="com.example.Test.Name" value="AnnotationValue"/></property></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test', properties: [
            DBusIntrospectProperty('Count', DBusSignature('u'), annotations: [
              DBusIntrospectAnnotation(
                  'com.example.Test.Name', 'AnnotationValue')
            ])
          ])
        ])));
  });

  test('intropect xml - property no name or type', () {
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><property/></interface></node>'),
        throwsFormatException);
  });

  test('intropect xml - property no name', () {
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><property type="u"/></interface></node>'),
        throwsFormatException);
  });

  test('intropect xml - property no type', () {
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><property name="Count"/></interface></node>'),
        throwsFormatException);
  });

  test('intropect xml - property unknown access', () {
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><property name="Count" type="u" access="cook"/></interface></node>'),
        throwsFormatException);
  });

  for (var name in [
    'method-no-args',
    'method-single-input',
    'method-single-output',
    'method-multiple-inputs',
    'method-multiple-outputs',
    'method-unnamed-arg',
    'methods',
    'property',
    'properties',
    'property-access',
    'signal-no-args',
    'signal-single-arg',
    'signal-multiple-args',
    'signals',
    'multiple-interfaces'
  ]) {
    test('code generator - client - $name', () async {
      var xml = await File('test/generated-code/$name.in').readAsString();
      var node = parseDBusIntrospectXml(xml);
      var generator = DBusCodeGenerator(node);
      var code = generator.generateClientSource();
      var expectedCode =
          await File('test/generated-code/$name.client.out').readAsString();
      expect(code, equals(expectedCode));
    });

    test('code generator - server - $name', () async {
      var xml = await File('test/generated-code/$name.in').readAsString();
      var node = parseDBusIntrospectXml(xml);
      var generator = DBusCodeGenerator(node);
      var code = generator.generateServerSource();
      var expectedCode =
          await File('test/generated-code/$name.server.out').readAsString();
      expect(code, equals(expectedCode));
    });
  }
}
