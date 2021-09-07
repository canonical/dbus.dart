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
  final bool expectedMethodNoReplyExpected;
  final bool expectedMethodNoAutoStart;
  final bool expectedMethodAllowInteractiveAuthorization;

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
      this.expectedMethodNoReplyExpected = false,
      this.expectedMethodNoAutoStart = false,
      this.expectedMethodAllowInteractiveAuthorization = false,
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
    expect(methodCall.noReplyExpected, equals(expectedMethodNoReplyExpected));
    expect(methodCall.noAutoStart, equals(expectedMethodNoAutoStart));
    expect(methodCall.allowInteractiveAuthorization,
        equals(expectedMethodAllowInteractiveAuthorization));

    var response = methodResponses[name];
    if (response == null) {
      if (methodCall.interface != null) {
        for (var name in methodResponses.keys) {
          if (name.startsWith('${methodCall.interface}.')) {
            return DBusMethodErrorResponse.unknownMethod();
          }
        }
        return DBusMethodErrorResponse.unknownInterface();
      } else {
        return DBusMethodErrorResponse.unknownMethod();
      }
    }

    return response;
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

class TestEmitObject extends DBusObject {
  TestEmitObject() : super(DBusObjectPath('/'));

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    await emitSignal('com.example.Test', 'Event');
    return DBusMethodSuccessResponse();
  }
}

class TestManagerObject extends DBusObject {
  TestManagerObject() : super(DBusObjectPath('/'), isObjectManager: true);

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    await client?.registerObject(
        TestObject(path: DBusObjectPath('/com/example/Object1')));
    return DBusMethodSuccessResponse();
  }
}

void main() {
  test('value - byte', () async {
    expect(() => DBusByte(-1), throwsArgumentError);
    expect(DBusByte(0).value, equals(0));
    expect(DBusByte(255).value, equals(255));
    expect(() => DBusByte(256), throwsArgumentError);
    expect(DBusByte(0).signature, equals(DBusSignature('y')));
    expect(DBusByte(42).toNative(), equals(42));
    expect(DBusByte(42) == DBusByte(42), isTrue);
    expect(DBusByte(42) == DBusByte(99), isFalse);
  });

  test('value - boolean', () async {
    expect(DBusBoolean(false).value, isFalse);
    expect(DBusBoolean(true).value, isTrue);
    expect(DBusBoolean(true).signature, equals(DBusSignature('b')));
    expect(DBusBoolean(true).toNative(), equals(true));
    expect(DBusBoolean(false).toNative(), equals(false));
    expect(DBusBoolean(true) == DBusBoolean(true), isTrue);
    expect(DBusBoolean(true) == DBusBoolean(false), isFalse);
  });

  test('value - int16', () async {
    expect(() => DBusInt16(-32769), throwsArgumentError);
    expect(DBusInt16(-32768).value, equals(-32768));
    expect(DBusInt16(0).value, equals(0));
    expect(DBusInt16(32767).value, equals(32767));
    expect(() => DBusInt16(32768), throwsArgumentError);
    expect(DBusInt16(0).signature, equals(DBusSignature('n')));
    expect(DBusInt16(-42).toNative(), equals(-42));
    expect(DBusInt16(42) == DBusInt16(42), isTrue);
    expect(DBusInt16(42) == DBusInt16(99), isFalse);
  });

  test('value - uint16', () async {
    expect(() => DBusUint16(-1), throwsArgumentError);
    expect(DBusUint16(0).value, equals(0));
    expect(DBusUint16(65535).value, equals(65535));
    expect(() => DBusUint16(65536), throwsArgumentError);
    expect(DBusUint16(0).signature, equals(DBusSignature('q')));
    expect(DBusUint16(42).toNative(), equals(42));
    expect(DBusUint16(42) == DBusUint16(42), isTrue);
    expect(DBusUint16(42) == DBusUint16(99), isFalse);
  });

  test('value - int32', () async {
    expect(() => DBusInt32(-2147483649), throwsArgumentError);
    expect(DBusInt32(-2147483648).value, equals(-2147483648));
    expect(DBusInt32(0).value, equals(0));
    expect(DBusInt32(2147483647).value, equals(2147483647));
    expect(() => DBusInt32(2147483648), throwsArgumentError);
    expect(DBusInt32(0).signature, equals(DBusSignature('i')));
    expect(DBusInt32(-42).toNative(), equals(-42));
    expect(DBusInt32(42) == DBusInt32(42), isTrue);
    expect(DBusInt32(42) == DBusInt32(99), isFalse);
  });

  test('value - uint32', () async {
    expect(() => DBusUint32(-1), throwsArgumentError);
    expect(DBusUint32(0).value, equals(0));
    expect(DBusUint32(4294967295).value, equals(4294967295));
    expect(() => DBusUint32(4294967296), throwsArgumentError);
    expect(DBusUint32(0).signature, equals(DBusSignature('u')));
    expect(DBusUint32(42).toNative(), equals(42));
    expect(DBusUint32(42) == DBusUint32(42), isTrue);
    expect(DBusUint32(42) == DBusUint32(99), isFalse);
  });

  test('value - int64', () async {
    expect(DBusInt64(-9223372036854775808).value, equals(-9223372036854775808));
    expect(DBusInt64(0).value, equals(0));
    expect(DBusInt64(9223372036854775807).value, equals(9223372036854775807));
    expect(DBusInt64(0).signature, equals(DBusSignature('x')));
    expect(DBusInt64(-42).toNative(), equals(-42));
    expect(DBusInt64(42) == DBusInt64(42), isTrue);
    expect(DBusInt64(42) == DBusInt64(99), isFalse);
  });

  test('value - uint64', () async {
    expect(DBusUint64(0).value, equals(0));
    expect(DBusUint64(0xffffffffffffffff).value, equals(0xffffffffffffffff));
    expect(() => DBusUint32(4294967296), throwsArgumentError);
    expect(DBusUint64(0).signature, equals(DBusSignature('t')));
    expect(DBusUint64(42).toNative(), equals(42));
    expect(DBusUint64(42) == DBusUint64(42), isTrue);
    expect(DBusUint64(42) == DBusUint64(99), isFalse);
  });

  test('value - double', () async {
    expect(DBusDouble(3.14159).value, equals(3.14159));
    expect(DBusDouble(3.14159).signature, equals(DBusSignature('d')));
    expect(DBusDouble(3.14159).toNative(), equals(3.14159));
    expect(DBusDouble(3.14159) == DBusDouble(3.14159), isTrue);
    expect(DBusDouble(3.14159) == DBusDouble(2.71828), isFalse);
  });

  test('value - string', () async {
    expect(DBusString('').value, equals(''));
    expect(DBusString('one').value, equals('one'));
    expect(DBusString('😄🙃🤪🧐').value, equals('😄🙃🤪🧐'));
    expect(DBusString('!' * 1024).value, equals('!' * 1024));
    expect(DBusString('one').signature, equals(DBusSignature('s')));
    expect(DBusString('one').toNative(), equals('one'));
    expect(DBusString('one') == DBusString('one'), isTrue);
    expect(DBusString('one') == DBusString('two'), isFalse);
  });

  test('value - object path', () async {
    expect(DBusObjectPath('/').value, equals('/'));
    expect(DBusObjectPath('/com').value, equals('/com'));
    expect(
        DBusObjectPath('/com/example/Test').value, equals('/com/example/Test'));
    // Empty.
    expect(() => DBusObjectPath(''), throwsArgumentError);
    // Empty element.
    expect(() => DBusObjectPath('//'), throwsArgumentError);
    expect(() => DBusObjectPath('//example/Test'), throwsArgumentError);
    // Missing leading '/'
    expect(() => DBusObjectPath('com/example/Test'), throwsArgumentError);
    // Trailing '/'.
    expect(() => DBusObjectPath('/com/example/Test/'), throwsArgumentError);
    // Invalid characters
    expect(() => DBusObjectPath(r'/com/example/Te$t'), throwsArgumentError);
    expect(() => DBusObjectPath(r'/com/example/T😄st'), throwsArgumentError);
    expect(DBusObjectPath('/com/example/Test').signature,
        equals(DBusSignature('o')));
    expect(DBusObjectPath('/com/example/Test').toNative(),
        equals(DBusObjectPath('/com/example/Test')));
    expect(
        DBusObjectPath('/com/example/Test') ==
            DBusObjectPath('/com/example/Test'),
        isTrue);
    expect(
        DBusObjectPath('/com/example/Test') ==
            DBusObjectPath('/com/example/Test2'),
        isFalse);
  });

  test('value - signature', () async {
    expect(DBusSignature('').value, equals(''));
    expect(DBusSignature('s').value, equals('s'));
    expect(DBusSignature('ybnq').value, equals('ybnq'));
    expect(DBusSignature('s' * 255).value, equals('s' * 255));
    // Basic types.
    expect(DBusSignature('').isBasic, isFalse);
    expect(DBusSignature('y').isBasic, isTrue);
    expect(DBusSignature('b').isBasic, isTrue);
    expect(DBusSignature('n').isBasic, isTrue);
    expect(DBusSignature('q').isBasic, isTrue);
    expect(DBusSignature('i').isBasic, isTrue);
    expect(DBusSignature('u').isBasic, isTrue);
    expect(DBusSignature('x').isBasic, isTrue);
    expect(DBusSignature('t').isBasic, isTrue);
    expect(DBusSignature('d').isBasic, isTrue);
    expect(DBusSignature('s').isBasic, isTrue);
    expect(DBusSignature('o').isBasic, isTrue);
    expect(DBusSignature('g').isBasic, isTrue);
    expect(DBusSignature('v').isBasic, isFalse);
    expect(DBusSignature('mv').isBasic, isFalse);
    expect(DBusSignature('()').isBasic, isFalse);
    expect(DBusSignature('as').isBasic, isFalse);
    expect(DBusSignature('a{sv}').isBasic, isFalse);
    expect(DBusSignature('yy').isBasic, isFalse);
    // Single complete types
    expect(DBusSignature('').isSingleCompleteType, isFalse);
    expect(DBusSignature('y').isSingleCompleteType, isTrue);
    expect(DBusSignature('b').isSingleCompleteType, isTrue);
    expect(DBusSignature('n').isSingleCompleteType, isTrue);
    expect(DBusSignature('q').isSingleCompleteType, isTrue);
    expect(DBusSignature('i').isSingleCompleteType, isTrue);
    expect(DBusSignature('u').isSingleCompleteType, isTrue);
    expect(DBusSignature('x').isSingleCompleteType, isTrue);
    expect(DBusSignature('t').isSingleCompleteType, isTrue);
    expect(DBusSignature('d').isSingleCompleteType, isTrue);
    expect(DBusSignature('s').isSingleCompleteType, isTrue);
    expect(DBusSignature('o').isSingleCompleteType, isTrue);
    expect(DBusSignature('g').isSingleCompleteType, isTrue);
    expect(DBusSignature('v').isSingleCompleteType, isTrue);
    expect(DBusSignature('mv').isSingleCompleteType, isTrue);
    expect(DBusSignature('()').isSingleCompleteType, isTrue);
    expect(DBusSignature('as').isSingleCompleteType, isTrue);
    expect(DBusSignature('a{sv}').isSingleCompleteType, isTrue);
    expect(DBusSignature('yy').isSingleCompleteType, isFalse);
    // Container types.
    expect(DBusSignature('()').value, equals('()'));
    expect(DBusSignature('(iss)').value, equals('(iss)'));
    expect(DBusSignature('as').value, equals('as'));
    expect(DBusSignature('a{sv}').value, equals('a{sv}'));
    // Unknown character.
    expect(() => DBusSignature('!'), throwsArgumentError);
    // Too long.
    expect(() => DBusSignature('s' * 256), throwsArgumentError);
    // Missing array type.
    expect(() => DBusSignature('a'), throwsArgumentError);
    expect(() => DBusSignature('(a)'), throwsArgumentError);
    expect(() => DBusSignature('aa'), throwsArgumentError);
    expect(() => DBusSignature('a{sa}'), throwsArgumentError);
    // Missing maybe type.
    expect(() => DBusSignature('m'), throwsArgumentError);
    // Containers containing invalid types.
    expect(() => DBusSignature('(!)'), throwsArgumentError);
    expect(() => DBusSignature('a!'), throwsArgumentError);
    expect(() => DBusSignature('a{!!}'), throwsArgumentError);
    // Missing opening/closing characters.
    expect(() => DBusSignature('('), throwsArgumentError);
    expect(() => DBusSignature(')'), throwsArgumentError);
    expect(() => DBusSignature('(s'), throwsArgumentError);
    expect(() => DBusSignature('s)'), throwsArgumentError);
    expect(() => DBusSignature('a{'), throwsArgumentError);
    expect(() => DBusSignature('}'), throwsArgumentError);
    expect(() => DBusSignature('a{sv'), throwsArgumentError);
    expect(() => DBusSignature('sv}'), throwsArgumentError);
    // Dict entry outside of array.
    expect(() => DBusSignature('{}'), throwsArgumentError);
    // Dict with wrong number of types.
    expect(() => DBusSignature('a{}'), throwsArgumentError);
    expect(() => DBusSignature('a{s}'), throwsArgumentError);
    expect(() => DBusSignature('a{siv}'), throwsArgumentError);
    expect(
        DBusSignature('ybnq').split(),
        equals([
          DBusSignature('y'),
          DBusSignature('b'),
          DBusSignature('n'),
          DBusSignature('q')
        ]));
    expect(DBusSignature('(ybnq)').split(), equals([DBusSignature('(ybnq)')]));
    expect(DBusSignature('').split(), equals([]));
    expect(DBusSignature('s').signature, equals(DBusSignature('g')));
    expect(DBusSignature('s').toNative(), equals(DBusSignature('s')));
    expect(DBusSignature('a{sv}') == DBusSignature('a{sv}'), isTrue);
    expect(DBusSignature('a{sv}') == DBusSignature('s'), isFalse);
  });

  test('value - variant', () async {
    expect(DBusVariant(DBusString('one')).value, equals(DBusString('one')));
    expect(DBusVariant(DBusUint32(2)).value, equals(DBusUint32(2)));
    expect(
        DBusVariant(DBusString('one')).signature, equals(DBusSignature('v')));
    expect(DBusVariant(DBusString('one')).toNative(), equals('one'));
    expect(DBusVariant(DBusString('one')) == DBusVariant(DBusString('one')),
        isTrue);
    expect(
        DBusVariant(DBusString('one')) == DBusVariant(DBusUint32(2)), isFalse);
  });

  test('value - maybe', () async {
    expect(DBusMaybe(DBusSignature('s'), DBusString('one')).value,
        equals(DBusString('one')));
    expect(DBusMaybe(DBusSignature('s'), null).value, isNull);
    expect(
        () => DBusMaybe(DBusSignature('s'), DBusInt32(1)), throwsArgumentError);
    expect(DBusMaybe(DBusSignature('s'), null).signature,
        equals(DBusSignature('ms')));
    expect(DBusMaybe(DBusSignature('s'), DBusString('one')).toNative(),
        equals('one'));
    expect(DBusMaybe(DBusSignature('s'), null).toNative(), isNull);
    expect(
        DBusMaybe(DBusSignature('s'), DBusString('one')) ==
            DBusMaybe(DBusSignature('s'), DBusString('one')),
        isTrue);
    expect(
        DBusMaybe(DBusSignature('s'), DBusString('one')) ==
            DBusMaybe(DBusSignature('s'), null),
        isFalse);
    expect(
        DBusMaybe(DBusSignature('s'), DBusString('as')) ==
            DBusMaybe(DBusSignature('g'), DBusSignature('as')),
        isFalse);
  });

  test('value - struct', () async {
    expect(DBusStruct([]).children, equals([]));
    expect(
        DBusStruct([DBusString('one'), DBusUint32(2), DBusDouble(3.0)])
            .children,
        equals([DBusString('one'), DBusUint32(2), DBusDouble(3.0)]));
    expect(DBusStruct([]).signature, equals(DBusSignature('()')));
    expect(
        DBusStruct([DBusString('one'), DBusUint32(2), DBusDouble(3.0)])
            .toNative(),
        equals(['one', 2, 3.0]));
    expect(
        DBusStruct([DBusString('one'), DBusUint32(2), DBusDouble(3.0)])
            .signature,
        equals(DBusSignature('(sud)')));
    expect(
        DBusStruct([DBusString('one'), DBusUint32(2), DBusDouble(3.0)]) ==
            DBusStruct([DBusString('one'), DBusUint32(2), DBusDouble(3.0)]),
        isTrue);
    expect(
        DBusStruct([DBusString('one'), DBusUint32(2), DBusDouble(3.0)]) ==
            DBusStruct([DBusString('one'), DBusInt32(2), DBusDouble(3.0)]),
        isFalse);
  });

  test('value - array', () async {
    expect(DBusArray(DBusSignature('s'), []).children, equals([]));
    // Signature must be single complete type.
    expect(() => DBusArray(DBusSignature('si'), []), throwsArgumentError);
    expect(
        DBusArray(DBusSignature('s'), [
          DBusString('one'),
          DBusString('two'),
          DBusString('three')
        ]).children,
        equals([DBusString('one'), DBusString('two'), DBusString('three')]));
    expect(
        () => DBusArray(DBusSignature('s'),
            [DBusString('one'), DBusUint32(2), DBusDouble(3.0)]),
        throwsArgumentError);
    expect(DBusArray(DBusSignature('s'), []).childSignature,
        equals(DBusSignature('s')));
    expect(DBusArray(DBusSignature('s'), []).signature,
        equals(DBusSignature('as')));
    expect(
        DBusArray(DBusSignature('s'), [
          DBusString('one'),
          DBusString('two'),
          DBusString('three')
        ]).toNative(),
        equals(['one', 'two', 'three']));
    expect(
        DBusArray(DBusSignature('s'),
                [DBusString('one'), DBusString('two'), DBusString('three')]) ==
            DBusArray(DBusSignature('s'),
                [DBusString('one'), DBusString('two'), DBusString('three')]),
        isTrue);
    expect(
        DBusArray(DBusSignature('s'),
                [DBusString('one'), DBusString('two'), DBusString('three')]) ==
            DBusArray(DBusSignature('s'),
                [DBusString('three'), DBusString('two'), DBusString('one')]),
        isFalse);
  });

  test('value - dict', () async {
    expect(DBusDict(DBusSignature('i'), DBusSignature('s'), {}).children,
        equals({}));
    expect(
        DBusDict(DBusSignature('i'), DBusSignature('s'), {
          DBusInt32(1): DBusString('one'),
          DBusInt32(2): DBusString('two'),
          DBusInt32(3): DBusString('three')
        }).children,
        equals({
          DBusInt32(1): DBusString('one'),
          DBusInt32(2): DBusString('two'),
          DBusInt32(3): DBusString('three')
        }));
    // Keys that don't match signature.
    expect(
        () => DBusDict(DBusSignature('i'), DBusSignature('s'), {
              DBusInt32(1): DBusString('one'),
              DBusUint32(2): DBusString('two'),
              DBusInt32(3): DBusString('three')
            }),
        throwsArgumentError);
    // Values that don't match signature.
    expect(
        () => DBusDict(DBusSignature('i'), DBusSignature('s'), {
              DBusInt32(1): DBusString('one'),
              DBusInt32(2): DBusUint32(2),
              DBusInt32(3): DBusString('three')
            }),
        throwsArgumentError);
    // Only single types are allowed as keys.
    expect(() => DBusDict(DBusSignature('ii'), DBusSignature('s'), {}),
        throwsArgumentError);
    // Value must be a complete type.
    expect(() => DBusDict(DBusSignature('s'), DBusSignature('ss'), {}),
        throwsArgumentError);
    expect(DBusDict(DBusSignature('i'), DBusSignature('s'), {}).keySignature,
        equals(DBusSignature('i')));
    expect(DBusDict(DBusSignature('i'), DBusSignature('s'), {}).valueSignature,
        equals(DBusSignature('s')));
    expect(DBusDict(DBusSignature('i'), DBusSignature('s'), {}).signature,
        equals(DBusSignature('a{is}')));
    expect(
        DBusDict(DBusSignature('i'), DBusSignature('s'), {
          DBusInt32(1): DBusString('one'),
          DBusInt32(2): DBusString('two'),
          DBusInt32(3): DBusString('three')
        }).toNative(),
        equals({1: 'one', 2: 'two', 3: 'three'}));
    expect(
        DBusDict(DBusSignature('i'), DBusSignature('s'), {
              DBusInt32(1): DBusString('one'),
              DBusInt32(2): DBusString('two'),
              DBusInt32(3): DBusString('three')
            }) ==
            DBusDict(DBusSignature('i'), DBusSignature('s'), {
              DBusInt32(1): DBusString('one'),
              DBusInt32(2): DBusString('two'),
              DBusInt32(3): DBusString('three')
            }),
        isTrue);
    expect(
        DBusDict(DBusSignature('i'), DBusSignature('s'), {
              DBusInt32(1): DBusString('one'),
              DBusInt32(2): DBusString('two'),
              DBusInt32(3): DBusString('three')
            }) ==
            DBusDict(DBusSignature('i'), DBusSignature('s'), {
              DBusInt32(1): DBusString('three'),
              DBusInt32(2): DBusString('two'),
              DBusInt32(3): DBusString('one')
            }),
        isFalse);
  });

  test('ping', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Check can ping the server.
    await client.ping();
  });

  test('ping - abstract', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(abstract: 'abstract'));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Check can ping the server.
    await client.ping();
  });

  test('ping - ipv4 tcp', () async {
    var server = DBusServer();
    var address = await server.listenAddress(
        DBusAddress.tcp('localhost', family: DBusAddressTcpFamily.ipv4));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Check can ping the server.
    await client.ping();
  });

  test('ping - ipv6 tcp', () async {
    // Check if IPv6 support is available on this host, otherwise skip the test.
    try {
      var socket = await ServerSocket.bind(InternetAddress.loopbackIPv6, 0);
      await socket.close();
    } on SocketException {
      markTestSkipped('IPv6 support not available');
      return;
    }

    var server = DBusServer();
    var address = await server.listenAddress(
        DBusAddress.tcp('localhost', family: DBusAddressTcpFamily.ipv6));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Check can ping the server.
    await client.ping();
  });

  test('server closed', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(abstract: 'abstract'));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
    });

    // Connect to the server.
    await client.ping();

    // Stop the server.
    await server.close();

    // Check error trying to send message.
    expect(() => client.ping(), throwsA(isA<DBusClosedException>()));
  });

  test('client closed', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Connect to the server, then close.
    await client1.ping();
    var name1 = client1.uniqueName;

    // Succesfully ping the first client.
    await client2.ping(name1);

    // Close the first client.
    await client1.close();

    // Try and ping the closed client.
    expect(
        () => client2.ping(name1), throwsA(isA<DBusServiceUnknownException>()));
  });

  test('list names', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Check the server and this clients name is reported.
    var names = await client.listNames();
    expect(names, equals(['org.freedesktop.DBus', client.uniqueName]));
  });

  test('request name', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

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
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

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
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

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
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

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
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

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
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

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
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

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
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Attempt to request an empty bus name
    expect(
        () => client.requestName(''), throwsA(isA<DBusInvalidArgsException>()));
  });

  test('request name - unique', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Attempt to request a unique bus name
    expect(() => client.requestName(':unique'),
        throwsA(isA<DBusInvalidArgsException>()));
  });

  test('request name - not enough elements', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Attempt to request a unique bus name
    expect(() => client.requestName('foo'),
        throwsA(isA<DBusInvalidArgsException>()));
  });

  test('request name - leading period', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Attempt to request a unique bus name
    expect(() => client.requestName('.foo.bar'),
        throwsA(isA<DBusInvalidArgsException>()));
  });

  test('request name - trailing period', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Attempt to request a unique bus name
    expect(() => client.requestName('foo.bar.'),
        throwsA(isA<DBusInvalidArgsException>()));
  });

  test('request name - empty element', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Attempt to request a unique bus name
    expect(() => client.requestName('foo..bar'),
        throwsA(isA<DBusInvalidArgsException>()));
  });

  test('release name', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

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
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Release a name that's not in use.
    var releaseReply = await client.releaseName('com.example.Test');
    expect(releaseReply, equals(DBusReleaseNameReply.nonExistant));
  });

  test('release name - not owner', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

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
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

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
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Attempt to release an empty bus name.
    expect(
        () => client.releaseName(''), throwsA(isA<DBusInvalidArgsException>()));
  });

  test('release name - unique name', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Attempt to release the unique name of this client.
    expect(() => client.releaseName(client.uniqueName),
        throwsA(isA<DBusInvalidArgsException>()));
  });

  test('list activatable names', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Only the bus service available by default.
    var names = await client.listActivatableNames();
    expect(names, equals(['org.freedesktop.DBus']));
  });

  test('start service by name', () async {
    var server = ServerWithActivatableService();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

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

    expect(() => client.startServiceByName('com.example.DoesNotExist'),
        throwsA(isA<DBusServiceUnknownException>()));
  });

  test('get unix user', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    var uid = await client.getConnectionUnixUser('org.freedesktop.DBus');
    expect(uid, equals(getuid()));
  });

  test('get process id', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    var pid_ = await client.getConnectionUnixProcessId('org.freedesktop.DBus');
    expect(pid_, equals(pid));
  });

  test('get credentials', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    var credentials =
        await client.getConnectionCredentials('org.freedesktop.DBus');
    expect(credentials.unixUserId, equals(getuid()));
    expect(credentials.processId, equals(pid));
  });

  test('call method', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client that exposes a method.
    await client1.registerObject(
        TestObject(expectedMethodName: 'Test', expectedMethodValues: [
      DBusString('Hello'),
      DBusUint32(42)
    ], methodResponses: {
      'Test': DBusMethodSuccessResponse([DBusString('World'), DBusUint32(99)])
    }));

    // Call the method from another client.
    var response = await client2.callMethod(
        destination: client1.uniqueName,
        path: DBusObjectPath('/'),
        name: 'Test',
        values: [DBusString('Hello'), DBusUint32(42)]);
    expect(response.values, equals([DBusString('World'), DBusUint32(99)]));
  });

  test('call method - no response', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client that exposes a method.
    await client1
        .registerObject(TestObject(expectedMethodNoReplyExpected: true));

    // Call the method from another client.
    var response = await client2.callMethod(
        destination: client1.uniqueName,
        path: DBusObjectPath('/'),
        name: 'Test',
        values: [DBusString('Hello'), DBusUint32(42)],
        noReplyExpected: true);
    expect(response.values, equals([]));
  });

  test('call method - registered name', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

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
  });

  test('call method - dict container key', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client that exposes a method.
    await client1.registerObject(TestObject(expectedMethodName: 'Test'));

    // Call the method from another client.
    try {
      await client2.callMethod(
          destination: client1.uniqueName,
          path: DBusObjectPath('/'),
          name: 'Test',
          values: [DBusDict(DBusSignature('(is)'), DBusSignature('s'), {})]);
      fail('Expected UnsupportedError');
    } on UnsupportedError catch (e) {
      expect(e.message,
          equals("D-Bus doesn't support dicts with non basic key types"));
    }
  });

  test('call method - maybe type', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client that exposes a method.
    await client1.registerObject(TestObject(expectedMethodName: 'Test'));

    // Call the method from another client.
    try {
      await client2.callMethod(
          destination: client1.uniqueName,
          path: DBusObjectPath('/'),
          name: 'Test',
          values: [DBusMaybe(DBusSignature('s'), DBusString('Hello'))]);
      fail('Expected UnsupportedError');
    } on UnsupportedError catch (e) {
      expect(e.message, equals("D-Bus doesn't support reserved maybe type"));
    }
  });

  test('call method - maybe signature', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client that exposes a method.
    await client1.registerObject(TestObject(expectedMethodName: 'Test'));

    // Call the method from another client.
    try {
      await client2.callMethod(
          destination: client1.uniqueName,
          path: DBusObjectPath('/'),
          name: 'Test',
          values: [DBusSignature('ms')]);
      fail('Expected UnsupportedError');
    } on UnsupportedError catch (e) {
      expect(e.message,
          equals("D-Bus doesn't support reserved maybe type in signatures"));
    }
  });

  test('call method - expected signature', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

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
  });

  test('call method - expected signature mismatch', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

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
  });

  test('call method - no autostart', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client that exposes a method.
    await client1.registerObject(TestObject(
        expectedMethodNoAutoStart: true,
        methodResponses: {'Test': DBusMethodSuccessResponse()}));

    // Call the method from another client.
    var response = await client2.callMethod(
        destination: client1.uniqueName,
        path: DBusObjectPath('/'),
        name: 'Test',
        values: [DBusString('Hello'), DBusUint32(42)],
        noAutoStart: true);
    expect(response.values, equals([]));
  });

  test('call method - allow interactive authorization', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client that exposes a method.
    await client1.registerObject(TestObject(
        expectedMethodAllowInteractiveAuthorization: true,
        methodResponses: {'Test': DBusMethodSuccessResponse()}));

    // Call the method from another client.
    var response = await client2.callMethod(
        destination: client1.uniqueName,
        path: DBusObjectPath('/'),
        name: 'Test',
        values: [DBusString('Hello'), DBusUint32(42)],
        allowInteractiveAuthorization: true);
    expect(response.values, equals([]));
  });

  test('call method - error', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

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
  });

  test('call method - failed', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client that exposes a method.
    await client1.registerObject(TestObject(methodResponses: {
      'Test': DBusMethodErrorResponse.failed('Failure message')
    }));

    // Call the method from another client.
    try {
      await client2.callMethod(
          destination: client1.uniqueName,
          path: DBusObjectPath('/'),
          name: 'Test');
      fail('Expected DBusMethodResponseException');
    } on DBusFailedException catch (e) {
      expect(e.message, equals('Failure message'));
    }
  });

  test('call method - unknown object', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a simple client.
    await client1.registerObject(TestObject());

    // Try and access an unknown object.
    expect(
        () => client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/no/such/object'),
            name: 'Test'),
        throwsA(isA<DBusUnknownObjectException>()));
  });

  test('call method - unknown interface', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a simple client with an object.
    await client1.registerObject(TestObject());

    // Try and access an unknown interface on that object.
    expect(
        () => client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            interface: 'com.example.NoSuchInterface',
            name: 'Test'),
        throwsA(isA<DBusUnknownInterfaceException>()));
  });

  test('call method - unknown method', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a simple client with an object.
    await client1.registerObject(TestObject());

    // Try and access an unknown interface on that object.
    expect(
        () => client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            name: 'NoSuchMethod'),
        throwsA(isA<DBusUnknownMethodException>()));
  });

  test('call method - access denied', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client that exposes a method that generates an access denied error.
    await client1.registerObject(TestObject(methodResponses: {
      'Test': DBusMethodErrorResponse.accessDenied('Failure message')
    }));

    // Call the method from another client.
    expect(
        () => client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            name: 'Test'),
        throwsA(isA<DBusAccessDeniedException>()));
  });

  test('call method - remote object', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client that exposes a method.
    await client1.registerObject(TestObject(
        expectedMethodName: 'com.example.Test.Foo',
        expectedMethodValues: [
          DBusString('Hello'),
          DBusUint32(42)
        ],
        methodResponses: {
          'com.example.Test.Foo':
              DBusMethodSuccessResponse([DBusString('World'), DBusUint32(99)])
        }));

    // Call the method from another client.
    var remoteObject = DBusRemoteObject(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
    var response = await remoteObject.callMethod(
        'com.example.Test', 'Foo', [DBusString('Hello'), DBusUint32(42)]);
    expect(response.values, equals([DBusString('World'), DBusUint32(99)]));
  });

  test('call method - remote object - expected signature', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client that exposes a method.
    await client1.registerObject(TestObject(
        expectedMethodName: 'com.example.Test.Foo',
        methodResponses: {
          'com.example.Test.Foo':
              DBusMethodSuccessResponse([DBusString('World'), DBusUint32(99)])
        }));

    // Call the method from another client.
    var remoteObject = DBusRemoteObject(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
    var response = await remoteObject.callMethod('com.example.Test', 'Foo', [],
        replySignature: DBusSignature('su'));
    expect(response.values, equals([DBusString('World'), DBusUint32(99)]));
  });

  test('call method - remote object - expected signature mismatch', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client that exposes a method.
    await client1.registerObject(TestObject(
        expectedMethodName: 'com.example.Test.Foo',
        methodResponses: {
          'com.example.Test.Foo':
              DBusMethodSuccessResponse([DBusString('Hello'), DBusUint32(42)])
        }));

    // Call the method from another client.
    var remoteObject = DBusRemoteObject(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
    try {
      await remoteObject.callMethod('com.example.Test', 'Foo', [],
          replySignature: DBusSignature('us'));
      fail('Expected DBusReplySignatureException');
    } on DBusReplySignatureException catch (e) {
      expect(e.response.values, equals([DBusString('Hello'), DBusUint32(42)]));
    }
  });

  test('subscribe signal', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

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
    await object.emitSignal(
        'com.example.Test', 'Ping', [DBusString('Hello'), DBusUint32(42)]);
  });

  test('subscribe signal - match signature', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client to emit a signal.
    var object = DBusObject(DBusObjectPath('/'));
    await client1.registerObject(object);

    // Subscribe to the signal from another client.
    var signals = DBusSignalStream(client2,
        interface: 'com.example.Test',
        name: 'Ping',
        signature: DBusSignature('su'));
    expect(
        signals,
        emitsInOrder([
          DBusSignal(
              sender: client1.uniqueName,
              path: DBusObjectPath('/'),
              interface: 'com.example.Test',
              name: 'Ping',
              values: [DBusString('Hello'), DBusUint32(42)]),
          emitsError(isA<DBusSignalSignatureException>())
        ]));

    // Do a round-trip to the server to ensure the signal has been subscribed to.
    await client2.ping();

    // Emit one signal with correct signature, one without
    await object.emitSignal(
        'com.example.Test', 'Ping', [DBusString('Hello'), DBusUint32(42)]);
    await object.emitSignal(
        'com.example.Test', 'Ping', [DBusUint32(42), DBusString('Hello')]);
  });

  test('subscribe signal - remote object', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client to emit a signal.
    var object = DBusObject(DBusObjectPath('/'));
    await client1.registerObject(object);

    // Subscribe to the signal from another client.
    var remoteObject = DBusRemoteObject(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
    var signals = DBusRemoteObjectSignalStream(
        object: remoteObject, interface: 'com.example.Test', name: 'Ping');
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
    await object.emitSignal(
        'com.example.Test', 'Ping', [DBusString('Hello'), DBusUint32(42)]);
  });

  test('subscribe signal - remote object - match signature', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client to emit a signal.
    var object = DBusObject(DBusObjectPath('/'));
    await client1.registerObject(object);

    // Subscribe to the signal from another client.
    var remoteObject = DBusRemoteObject(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
    var signals = DBusRemoteObjectSignalStream(
        object: remoteObject,
        interface: 'com.example.Test',
        name: 'Ping',
        signature: DBusSignature('su'));
    expect(
        signals,
        emitsInOrder([
          DBusSignal(
              sender: client1.uniqueName,
              path: DBusObjectPath('/'),
              interface: 'com.example.Test',
              name: 'Ping',
              values: [DBusString('Hello'), DBusUint32(42)]),
          emitsError(isA<DBusSignalSignatureException>())
        ]));

    // Do a round-trip to the server to ensure the signal has been subscribed to.
    await client2.ping();

    // Emit one signal with correct signature, one without
    await object.emitSignal(
        'com.example.Test', 'Ping', [DBusString('Hello'), DBusUint32(42)]);
    await object.emitSignal(
        'com.example.Test', 'Ping', [DBusUint32(42), DBusString('Hello')]);
  });

  test('subscribe signal - remote named object', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client to emit a signal.
    var object = DBusObject(DBusObjectPath('/'));
    await client1.requestName('com.example.Test');
    await client1.registerObject(object);

    // Subscribe to the signal from another client.
    var remoteObject = DBusRemoteObject(client2,
        name: 'com.example.Test', path: DBusObjectPath('/'));
    var signals = DBusRemoteObjectSignalStream(
        object: remoteObject, interface: 'com.example.Test', name: 'Ping');
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
    await object.emitSignal(
        'com.example.Test', 'Ping', [DBusString('Hello'), DBusUint32(42)]);
  });

  test('signal from method call', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client to emit a signal.
    var object = TestEmitObject();
    await client1.registerObject(object);

    // Subscribe to the signal from another client.
    // Check that the signal is recived before the method call response completes.
    var methodCallDone = false;
    var remoteObject = DBusRemoteObject(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
    var signals = DBusRemoteObjectSignalStream(
        object: remoteObject, interface: 'com.example.Test', name: 'Event');
    signals.listen(expectAsync1((signal) {
      expect(methodCallDone, isFalse);
    }));

    // Make the method call that will emit the signal.
    await remoteObject.callMethod('com.example.Test', 'EmitEvent', []);
    methodCallDone = true;
  });

  test('introspect', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client that exposes introspection data.
    await client1.registerObject(TestObject(introspectData: [
      DBusIntrospectInterface('com.example.Test',
          methods: [DBusIntrospectMethod('Foo')])
    ]));

    // Read introspection data from the first client.
    var remoteObject = DBusRemoteObject(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
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
  });

  test('introspect - not introspectable', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address, introspectable: false);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client that exposes introspection data.
    await client1.registerObject(TestObject(introspectData: [
      DBusIntrospectInterface('com.example.Test',
          methods: [DBusIntrospectMethod('Foo')])
    ]));

    // Unable to read introspection data from the first client.
    var remoteObject = DBusRemoteObject(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
    expect(() => remoteObject.introspect(),
        throwsA(isA<DBusUnknownInterfaceException>()));
  });

  test('get property', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

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

    var remoteObject = DBusRemoteObject(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));

    // Get properties from another client.

    var readWriteValue =
        await remoteObject.getProperty('com.example.Test', 'ReadWrite');
    expect(readWriteValue, equals(DBusString('RW')));

    var readOnlyValue =
        await remoteObject.getProperty('com.example.Test', 'ReadOnly');
    expect(readOnlyValue, equals(DBusString('RO')));

    expect(remoteObject.getProperty('com.example.Test', 'WriteOnly'),
        throwsException);

    expect(remoteObject.getProperty('com.example.Test', 'Unknown'),
        throwsException);
  });

  test('get property - match signature', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client that exposes an object with properties.
    var object = TestObject(
        propertyValues: {'com.example.Test.Property': DBusString('Value')});
    await client1.registerObject(object);

    var remoteObject = DBusRemoteObject(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));

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
  });

  test('set property', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

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

    var remoteObject = DBusRemoteObject(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));

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
  });

  test('get all properties', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client that exposes an object with properties.
    var object = TestObject(propertyValues: {
      'com.example.Test.Property1': DBusString('VALUE1'),
      'com.example.Test.Property2': DBusString('VALUE2')
    });
    await client1.registerObject(object);

    var remoteObject = DBusRemoteObject(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));

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
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Create a client that exposes an object with properties.
    var object = TestObject();
    await client1.registerObject(object);

    /// Subscribe to properties changed signals.
    var remoteObject = DBusRemoteObject(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
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

    await object.emitPropertiesChanged('com.example.Test', changedProperties: {
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
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

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

    var remoteManagerObject = DBusRemoteObjectManager(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
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
  });

  test('object manager - no interfaces', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Register an object manager and an object without any interfaces other than the standard ones.
    await client1
        .registerObject(DBusObject(DBusObjectPath('/'), isObjectManager: true));
    await client1.registerObject(
        TestObject(path: DBusObjectPath('/com/example/Object')));

    var remoteManagerObject = DBusRemoteObjectManager(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
    var objects = await remoteManagerObject.getManagedObjects();
    expect(
        objects,
        equals({
          DBusObjectPath('/com/example/Object'): {
            'org.freedesktop.DBus.Introspectable': {},
            'org.freedesktop.DBus.Properties': {}
          }
        }));
  });

  test('object manager - not introspectable', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address, introspectable: false);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Register an object manager and one object. The client doesn't support introspection.
    await client1
        .registerObject(DBusObject(DBusObjectPath('/'), isObjectManager: true));
    await client1.registerObject(
        TestObject(path: DBusObjectPath('/com/example/Object')));

    var remoteManagerObject = DBusRemoteObjectManager(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
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
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Register an object manager with one object.
    var objectManager = DBusObject(DBusObjectPath('/'), isObjectManager: true);
    await client1.registerObject(objectManager);
    await client1.registerObject(
        TestObject(path: DBusObjectPath('/com/example/Object1')));

    // Subscribe to object manager signals.
    var remoteManagerObject = DBusRemoteObjectManager(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
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
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

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
    var remoteManagerObject = DBusRemoteObjectManager(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
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
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Register an object manager with one object.
    var objectManager = DBusObject(DBusObjectPath('/'), isObjectManager: true);
    await client1.registerObject(objectManager);
    var object = TestObject(
        path: DBusObjectPath('/com/example/Object'),
        interfacesAndProperties_: {'com.example.Interface1': {}});
    await client1.registerObject(object);

    // Subscribe to object manager signals.
    var remoteManagerObject = DBusRemoteObjectManager(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
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
    await objectManager.emitInterfacesAdded(object.path, {
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
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

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
    var remoteManagerObject = DBusRemoteObjectManager(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
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
    await objectManager
        .emitInterfacesRemoved(object.path, ['com.example.Interface2']);
  });

  test('object manager - properties changed', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

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
    var remoteManagerObject = DBusRemoteObjectManager(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
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
    await object.emitPropertiesChanged('com.example.Test', changedProperties: {
      'Property1': DBusString('VALUE1'),
      'Property2': DBusString('VALUE2')
    });
  });

  test('object manager - object added from method call', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await server.close();
    });

    // Register an object manager that responds to a method call.
    await client1.registerObject(TestManagerObject());

    // Subscribe to object manager signals.
    // Check that the signal is recived before the method call response completes.
    var methodCallDone = false;
    var remoteManagerObject = DBusRemoteObjectManager(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
    remoteManagerObject.signals.listen(expectAsync1((signal) {
      expect(methodCallDone, isFalse);
      expect(signal, TypeMatcher<DBusObjectManagerInterfacesAddedSignal>());
      var interfacesAdded = signal as DBusObjectManagerInterfacesAddedSignal;
      expect(interfacesAdded.changedPath,
          equals(DBusObjectPath('/com/example/Object1')));
    }));

    // Call a method that adds an object.
    var remoteObject = DBusRemoteObject(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
    await remoteObject.callMethod('com.example.Test', 'AddObject', []);
    methodCallDone = true;
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
    'method-no-reply',
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
