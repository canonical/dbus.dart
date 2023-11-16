import 'dart:io';

import 'package:dbus/code_generator.dart';
import 'package:dbus/dbus.dart';
import 'package:dbus/src/dbus_bus_name.dart';
import 'package:dbus/src/dbus_error_name.dart';
import 'package:dbus/src/dbus_interface_name.dart';
import 'package:dbus/src/dbus_match_rule.dart';
import 'package:dbus/src/dbus_member_name.dart';
import 'package:dbus/src/dbus_message.dart';
import 'package:dbus/src/dbus_uuid.dart';
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

/// Returns the unique ID for this machine.
Future<String> getMachineId() async {
  Future<String> readFirstLine(String path) async {
    var file = File(path);
    try {
      var lines = await file.readAsLines();
      return lines[0];
    } on FileSystemException {
      return '';
    }
  }

  var machineId = await readFirstLine('/var/lib/dbus/machine-id');
  if (machineId == '') {
    machineId = await readFirstLine('/etc/machine-id');
  }

  return machineId;
}

void main() {
  test('value - byte', () async {
    expect(() => DBusByte(-1), throwsA(isA<AssertionError>()));
    expect(DBusByte(0).value, equals(0));
    expect(DBusByte(255).value, equals(255));
    expect(() => DBusByte(256), throwsA(isA<AssertionError>()));
    expect(DBusByte(0).signature, equals(DBusSignature('y')));
    expect(DBusByte(42).asByte(), equals(42));
    expect(DBusByte(42).toNative(), equals(42));
    expect(DBusByte(42) == DBusByte(42), isTrue);
    expect(DBusByte(42) == DBusByte(99), isFalse);
    expect(DBusByte(42).toString(), equals('DBusByte(42)'));
    expect(DBusByte(44).signature, equals(DBusSignature.byte));

    // Check hash codes.
    var map = {DBusByte(1): 1, DBusByte(2): 2, DBusByte(3): 3};
    expect(map[DBusByte(2)], equals(2));
  });

  test('value - boolean', () async {
    expect(DBusBoolean(false).value, isFalse);
    expect(DBusBoolean(true).value, isTrue);
    expect(DBusBoolean(true).signature, equals(DBusSignature('b')));
    expect(DBusBoolean(true).asBoolean(), equals(true));
    expect(DBusBoolean(true).toNative(), equals(true));
    expect(DBusBoolean(false).toNative(), equals(false));
    expect(DBusBoolean(true) == DBusBoolean(true), isTrue);
    expect(DBusBoolean(true) == DBusBoolean(false), isFalse);
    expect(DBusBoolean(true).toString(), equals('DBusBoolean(true)'));
    expect(DBusBoolean(false).toString(), equals('DBusBoolean(false)'));
    expect(DBusBoolean(false).signature, equals(DBusSignature.boolean));

    // Check hash codes.
    var map = {DBusBoolean(false): 0, DBusBoolean(true): 1};
    expect(map[DBusBoolean(true)], equals(1));
  });

  test('value - int16', () async {
    expect(() => DBusInt16(-32769), throwsA(isA<AssertionError>()));
    expect(DBusInt16(-32768).value, equals(-32768));
    expect(DBusInt16(0).value, equals(0));
    expect(DBusInt16(32767).value, equals(32767));
    expect(() => DBusInt16(32768), throwsA(isA<AssertionError>()));
    expect(DBusInt16(0).signature, equals(DBusSignature('n')));
    expect(DBusInt16(-42).asInt16(), equals(-42));
    expect(DBusInt16(-42).toNative(), equals(-42));
    expect(DBusInt16(42) == DBusInt16(42), isTrue);
    expect(DBusInt16(42) == DBusInt16(99), isFalse);
    expect(DBusInt16(-42).toString(), equals('DBusInt16(-42)'));
    expect(DBusInt16(-42).signature, equals(DBusSignature.int16));

    // Check hash codes.
    var map = {DBusInt16(1): 1, DBusInt16(2): 2, DBusInt16(3): 3};
    expect(map[DBusInt16(2)], equals(2));
  });

  test('value - uint16', () async {
    expect(() => DBusUint16(-1), throwsA(isA<AssertionError>()));
    expect(DBusUint16(0).value, equals(0));
    expect(DBusUint16(65535).value, equals(65535));
    expect(() => DBusUint16(65536), throwsA(isA<AssertionError>()));
    expect(DBusUint16(0).signature, equals(DBusSignature('q')));
    expect(DBusUint16(42).asUint16(), equals(42));
    expect(DBusUint16(42).toNative(), equals(42));
    expect(DBusUint16(42) == DBusUint16(42), isTrue);
    expect(DBusUint16(42) == DBusUint16(99), isFalse);
    expect(DBusUint16(42).toString(), equals('DBusUint16(42)'));
    expect(DBusUint16(42).signature, equals(DBusSignature.uint16));

    // Check hash codes.
    var map = {DBusUint16(1): 1, DBusUint16(2): 2, DBusUint16(3): 3};
    expect(map[DBusUint16(2)], equals(2));
  });

  test('value - int32', () async {
    expect(() => DBusInt32(-2147483649), throwsA(isA<AssertionError>()));
    expect(DBusInt32(-2147483648).value, equals(-2147483648));
    expect(DBusInt32(0).value, equals(0));
    expect(DBusInt32(2147483647).value, equals(2147483647));
    expect(() => DBusInt32(2147483648), throwsA(isA<AssertionError>()));
    expect(DBusInt32(0).signature, equals(DBusSignature('i')));
    expect(DBusInt32(-42).asInt32(), equals(-42));
    expect(DBusInt32(-42).toNative(), equals(-42));
    expect(DBusInt32(42) == DBusInt32(42), isTrue);
    expect(DBusInt32(42) == DBusInt32(99), isFalse);
    expect(DBusInt32(-42).toString(), equals('DBusInt32(-42)'));
    expect(DBusInt32(42).signature, equals(DBusSignature.int32));

    // Check hash codes.
    var map = {DBusInt32(1): 1, DBusInt32(2): 2, DBusInt32(3): 3};
    expect(map[DBusInt32(2)], equals(2));
  });

  test('value - uint32', () async {
    expect(() => DBusUint32(-1), throwsA(isA<AssertionError>()));
    expect(DBusUint32(0).value, equals(0));
    expect(DBusUint32(4294967295).value, equals(4294967295));
    expect(() => DBusUint32(4294967296), throwsA(isA<AssertionError>()));
    expect(DBusUint32(0).signature, equals(DBusSignature('u')));
    expect(DBusUint32(42).asUint32(), equals(42));
    expect(DBusUint32(42).toNative(), equals(42));
    expect(DBusUint32(42) == DBusUint32(42), isTrue);
    expect(DBusUint32(42) == DBusUint32(99), isFalse);
    expect(DBusUint32(42).toString(), equals('DBusUint32(42)'));
    expect(DBusUint32(42).signature, equals(DBusSignature.uint32));

    // Check hash codes.
    var map = {DBusUint32(1): 1, DBusUint32(2): 2, DBusUint32(3): 3};
    expect(map[DBusUint32(2)], equals(2));
  });

  test('value - int64', () async {
    expect(DBusInt64(-9223372036854775808).value, equals(-9223372036854775808));
    expect(DBusInt64(0).value, equals(0));
    expect(DBusInt64(9223372036854775807).value, equals(9223372036854775807));
    expect(DBusInt64(0).signature, equals(DBusSignature('x')));
    expect(DBusInt64(-42).asInt64(), equals(-42));
    expect(DBusInt64(-42).toNative(), equals(-42));
    expect(DBusInt64(42) == DBusInt64(42), isTrue);
    expect(DBusInt64(42) == DBusInt64(99), isFalse);
    expect(DBusInt64(-42).toString(), equals('DBusInt64(-42)'));
    expect(DBusInt64(42).signature, equals(DBusSignature.int64));

    // Check hash codes.
    var map = {DBusInt64(1): 1, DBusInt64(2): 2, DBusInt64(3): 3};
    expect(map[DBusInt64(2)], equals(2));
  });

  test('value - uint64', () async {
    expect(DBusUint64(0).value, equals(0));
    expect(DBusUint64(0xffffffffffffffff).value, equals(0xffffffffffffffff));
    expect(() => DBusUint32(4294967296), throwsA(isA<AssertionError>()));
    expect(DBusUint64(0).signature, equals(DBusSignature('t')));
    expect(DBusUint64(42).asUint64(), equals(42));
    expect(DBusUint64(42).toNative(), equals(42));
    expect(DBusUint64(42) == DBusUint64(42), isTrue);
    expect(DBusUint64(42) == DBusUint64(99), isFalse);
    expect(DBusUint64(42).toString(), equals('DBusUint64(42)'));
    expect(DBusUint64(42).signature, equals(DBusSignature.uint64));

    // Check hash codes.
    var map = {DBusUint64(1): 1, DBusUint64(2): 2, DBusUint64(3): 3};
    expect(map[DBusUint64(2)], equals(2));
  });

  test('value - double', () async {
    expect(DBusDouble(3.14159).value, equals(3.14159));
    expect(DBusDouble(3.14159).signature, equals(DBusSignature('d')));
    expect(DBusDouble(3.14159).asDouble(), equals(3.14159));
    expect(DBusDouble(3.14159).toNative(), equals(3.14159));
    expect(DBusDouble(3.14159) == DBusDouble(3.14159), isTrue);
    expect(DBusDouble(3.14159) == DBusDouble(2.71828), isFalse);
    expect(DBusDouble(3.14159).toString(), equals('DBusDouble(3.14159)'));
    expect(DBusDouble(3.14159).signature, equals(DBusSignature.double));

    // Check hash codes.
    var map = {DBusDouble(1.1): 1, DBusDouble(2.2): 2, DBusDouble(3.3): 3};
    expect(map[DBusDouble(2.2)], equals(2));
  });

  test('value - string', () async {
    expect(DBusString('').value, equals(''));
    expect(DBusString('one').value, equals('one'));
    expect(DBusString('😄🙃🤪🧐').value, equals('😄🙃🤪🧐'));
    expect(DBusString('!' * 1024).value, equals('!' * 1024));
    expect(DBusString('one').signature, equals(DBusSignature('s')));
    expect(DBusString('one').asString(), equals('one'));
    expect(DBusString('one').toNative(), equals('one'));
    expect(DBusString('one') == DBusString('one'), isTrue);
    expect(DBusString('one') == DBusString('two'), isFalse);
    expect(DBusString('one').toString(), equals("DBusString('one')"));
    expect(DBusString('one').signature, equals(DBusSignature.string));

    // Check hash codes.
    var map = {
      DBusString('one'): 1,
      DBusString('two'): 2,
      DBusString('three'): 3
    };
    expect(map[DBusString('two')], equals(2));
  });

  test('value - object path', () async {
    expect(DBusObjectPath('/').value, equals('/'));
    expect(DBusObjectPath('/com').value, equals('/com'));
    expect(
        DBusObjectPath('/com/example/Test').value, equals('/com/example/Test'));
    // Unchecked constructor equivalent to standard constructor.
    expect(DBusObjectPath.unchecked('/com/example/Test'),
        equals(DBusObjectPath('/com/example/Test')));
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
    expect(DBusObjectPath('/com/example/Test').asObjectPath(),
        equals(DBusObjectPath('/com/example/Test')));
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
    expect(
        DBusObjectPath('/com/example/Test')
            .isInNamespace(DBusObjectPath('/com/example/Test')),
        isTrue);
    expect(
        DBusObjectPath('/com/example/Test')
            .isInNamespace(DBusObjectPath('/com/example')),
        isTrue);
    expect(
        DBusObjectPath('/com/example/Test')
            .isInNamespace(DBusObjectPath('/com')),
        isTrue);
    expect(
        DBusObjectPath('/com/example/Test').isInNamespace(DBusObjectPath('/')),
        isTrue);
    expect(
        DBusObjectPath('/com/example/Test')
            .isInNamespace(DBusObjectPath('/com/example/Test2')),
        isFalse);
    expect(
        DBusObjectPath('/com/example/Test')
            .isInNamespace(DBusObjectPath('/com/example2')),
        isFalse);
    expect(
        DBusObjectPath('/com/example/Test')
            .isInNamespace(DBusObjectPath('/com2/example')),
        isFalse);
    expect(DBusObjectPath('/com/example/Test').toString(),
        equals("DBusObjectPath('/com/example/Test')"));
    expect(DBusObjectPath('/com/example/Test').signature,
        equals(DBusSignature.objectPath));

    // Check hash codes.
    var map = {
      DBusObjectPath('/one'): 1,
      DBusObjectPath('/two'): 2,
      DBusObjectPath('/three'): 3
    };
    expect(map[DBusObjectPath('/two')], equals(2));
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
    expect(DBusSignature('s').asSignature(), equals(DBusSignature('s')));
    expect(DBusSignature('s').toNative(), equals(DBusSignature('s')));
    expect(DBusSignature('a{sv}') == DBusSignature('a{sv}'), isTrue);
    expect(DBusSignature('a{sv}') == DBusSignature('s'), isFalse);
    expect(
        DBusSignature('(ybnq)').toString(), equals("DBusSignature('(ybnq)')"));

    // Check hash codes.
    var map = {
      DBusSignature('n'): 16,
      DBusSignature('i'): 32,
      DBusSignature('t'): 64
    };
    expect(map[DBusSignature('i')], equals(32));
  });

  test('value - variant', () async {
    expect(DBusVariant(DBusString('one')).value, equals(DBusString('one')));
    expect(DBusVariant(DBusUint32(2)).value, equals(DBusUint32(2)));
    expect(
        DBusVariant(DBusString('one')).signature, equals(DBusSignature('v')));
    expect(
        DBusVariant(DBusString('one')).asVariant(), equals(DBusString('one')));
    expect(DBusVariant(DBusString('one')).toNative(), equals('one'));
    expect(DBusVariant(DBusString('one')) == DBusVariant(DBusString('one')),
        isTrue);
    expect(
        DBusVariant(DBusString('one')) == DBusVariant(DBusUint32(2)), isFalse);
    expect(DBusVariant(DBusString('one')).toString(),
        equals("DBusVariant(DBusString('one'))"));
    expect(DBusVariant(DBusString('one')).signature,
        equals(DBusSignature.variant));

    // Check hash codes.
    var map = {
      DBusVariant(DBusUint32(1)): 1,
      DBusVariant(DBusString('two')): 2,
      DBusVariant(DBusDouble(3.14159)): 3
    };
    expect(map[DBusVariant(DBusString('two'))], equals(2));
  });

  test('value - maybe', () async {
    expect(DBusMaybe(DBusSignature('s'), DBusString('one')).value,
        equals(DBusString('one')));
    expect(DBusMaybe(DBusSignature('s'), null).value, isNull);
    expect(
        () => DBusMaybe(DBusSignature('s'), DBusInt32(1)), throwsArgumentError);
    expect(DBusMaybe(DBusSignature('s'), null).signature,
        equals(DBusSignature('ms')));
    expect(DBusMaybe(DBusSignature('s'), DBusString('one')).asMaybe(),
        equals(DBusString('one')));
    expect(DBusMaybe(DBusSignature('s'), DBusString('one')).toNative(),
        equals('one'));
    expect(DBusMaybe(DBusSignature('s'), null).asMaybe(), isNull);
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
    expect(DBusMaybe(DBusSignature('s'), DBusString('one')).toString(),
        equals("DBusMaybe(DBusSignature('s'), DBusString('one'))"));
    expect(DBusMaybe(DBusSignature('s'), null).signature,
        equals(DBusSignature.maybe(DBusSignature.string)));
  });

  test('value - unix fd', () async {
    var stdinHandle = ResourceHandle.fromStdin(stdin);
    var stdoutHandle = ResourceHandle.fromStdout(stdout);
    expect(DBusUnixFd(stdinHandle).handle, equals(stdinHandle));
    expect(DBusUnixFd(stdinHandle).signature, equals(DBusSignature('h')));
    expect(DBusUnixFd(stdinHandle).asUnixFd(), equals(stdinHandle));
    expect(DBusUnixFd(stdinHandle).toNative(), equals(DBusUnixFd(stdinHandle)));
    expect(DBusUnixFd(stdinHandle) == DBusUnixFd(stdinHandle), isTrue);
    expect(DBusUnixFd(stdinHandle) == DBusUnixFd(stdoutHandle), isFalse);
    expect(DBusUnixFd(stdinHandle).toString(), equals('DBusUnixFd()'));
    expect(DBusUnixFd(stdinHandle).signature, equals(DBusSignature.unixFd));

    // Check hash codes.
    var map = {DBusUnixFd(stdinHandle): 0, DBusUnixFd(stdoutHandle): 1};
    expect(map[DBusUnixFd(stdoutHandle)], equals(1));
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
            .asStruct(),
        equals([DBusString('one'), DBusUint32(2), DBusDouble(3.0)]));
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
    expect(
        DBusStruct([DBusString('one'), DBusUint32(2), DBusDouble(3.0)])
            .toString(),
        equals(
            "DBusStruct([DBusString('one'), DBusUint32(2), DBusDouble(3.0)])"));
    expect(
        DBusStruct([DBusString('one'), DBusUint32(2), DBusDouble(3.0)])
            .signature,
        equals(DBusSignature.struct([
          DBusSignature.string,
          DBusSignature.uint32,
          DBusSignature.double
        ])));
    expect(
        DBusStruct([DBusString('one'), DBusUint32(2), DBusDouble(3.0)])
            .hashCode,
        equals(DBusStruct([DBusString('one'), DBusUint32(2), DBusDouble(3.0)])
            .hashCode));
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
    // Unchecked constructor equivalent to standard constructor.
    expect(
        DBusArray.unchecked(DBusSignature('s'),
            [DBusString('one'), DBusString('two'), DBusString('three')]),
        equals(DBusArray(DBusSignature('s'),
            [DBusString('one'), DBusString('two'), DBusString('three')])));
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
        ]).asArray(),
        equals([DBusString('one'), DBusString('two'), DBusString('three')]));
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

    // Check factory constructors are equivalent to their full expansions.
    expect(
        DBusArray.byte([1, 2, 3]),
        equals(DBusArray(
            DBusSignature('y'), [DBusByte(1), DBusByte(2), DBusByte(3)])));
    expect(DBusArray.byte([1, 2, 3]).asByteArray(), equals([1, 2, 3]));
    expect(
        DBusArray.boolean([false, true]),
        equals(DBusArray(
            DBusSignature('b'), [DBusBoolean(false), DBusBoolean(true)])));
    expect(DBusArray.boolean([false, true]).asBooleanArray(),
        equals([false, true]));
    expect(
        DBusArray.int16([1, 2, -3]),
        equals(DBusArray(
            DBusSignature('n'), [DBusInt16(1), DBusInt16(2), DBusInt16(-3)])));
    expect(DBusArray.int16([1, 2, -3]).asInt16Array(), equals([1, 2, -3]));
    expect(
        DBusArray.uint16([1, 2, 3]),
        equals(DBusArray(DBusSignature('q'),
            [DBusUint16(1), DBusUint16(2), DBusUint16(3)])));
    expect(DBusArray.uint16([1, 2, 3]).asUint16Array(), equals([1, 2, 3]));
    expect(
        DBusArray.int32([1, 2, -3]),
        equals(DBusArray(
            DBusSignature('i'), [DBusInt32(1), DBusInt32(2), DBusInt32(-3)])));
    expect(DBusArray.int32([1, 2, -3]).asInt32Array(), equals([1, 2, -3]));
    expect(
        DBusArray.uint32([1, 2, 3]),
        equals(DBusArray(DBusSignature('u'),
            [DBusUint32(1), DBusUint32(2), DBusUint32(3)])));
    expect(DBusArray.uint32([1, 2, 3]).asUint32Array(), equals([1, 2, 3]));
    expect(
        DBusArray.int64([1, 2, -3]),
        equals(DBusArray(
            DBusSignature('x'), [DBusInt64(1), DBusInt64(2), DBusInt64(-3)])));
    expect(DBusArray.int64([1, 2, -3]).asInt64Array(), equals([1, 2, -3]));
    expect(
        DBusArray.uint64([1, 2, 3]),
        equals(DBusArray(DBusSignature('t'),
            [DBusUint64(1), DBusUint64(2), DBusUint64(3)])));
    expect(DBusArray.uint64([1, 2, 3]).asUint64Array(), equals([1, 2, 3]));
    expect(
        DBusArray.double([1.1, 2.1, 3.1]),
        equals(DBusArray(DBusSignature('d'),
            [DBusDouble(1.1), DBusDouble(2.1), DBusDouble(3.1)])));
    expect(DBusArray.double([1.1, 2.1, 3.1]).asDoubleArray(),
        equals([1.1, 2.1, 3.1]));
    expect(
        DBusArray.string(['one', 'two', 'three']),
        equals(DBusArray(DBusSignature('s'),
            [DBusString('one'), DBusString('two'), DBusString('three')])));
    expect(DBusArray.string(['one', 'two', 'three']).asStringArray(),
        equals(['one', 'two', 'three']));
    expect(
        DBusArray.objectPath([
          DBusObjectPath('/one'),
          DBusObjectPath('/two'),
          DBusObjectPath('/three')
        ]),
        equals(DBusArray(DBusSignature('o'), [
          DBusObjectPath('/one'),
          DBusObjectPath('/two'),
          DBusObjectPath('/three')
        ])));
    expect(
        DBusArray.objectPath([
          DBusObjectPath('/one'),
          DBusObjectPath('/two'),
          DBusObjectPath('/three')
        ]).asObjectPathArray(),
        equals([
          DBusObjectPath('/one'),
          DBusObjectPath('/two'),
          DBusObjectPath('/three')
        ]));
    expect(
        DBusArray.variant(
            [DBusInt32(1), DBusString('two'), DBusDouble(3.14159)]),
        equals(DBusArray(DBusSignature('v'), [
          DBusVariant(DBusInt32(1)),
          DBusVariant(DBusString('two')),
          DBusVariant(DBusDouble(3.14159))
        ])));
    expect(
        DBusArray.variant(
                [DBusInt32(1), DBusString('two'), DBusDouble(3.14159)])
            .asVariantArray(),
        equals([DBusInt32(1), DBusString('two'), DBusDouble(3.14159)]));
    var stdinHandle = ResourceHandle.fromStdin(stdin);
    var stdoutHandle = ResourceHandle.fromStdout(stdout);
    expect(
        DBusArray.unixFd([stdinHandle, stdoutHandle]),
        equals(DBusArray(DBusSignature('h'),
            [DBusUnixFd(stdinHandle), DBusUnixFd(stdoutHandle)])));
    expect(DBusArray.unixFd([stdinHandle, stdoutHandle]).asUnixFdArray(),
        equals([stdinHandle, stdoutHandle]));

    expect(
        DBusArray(DBusSignature('ay'), [
          DBusArray.byte([1, 2, 3])
        ]).toString(),
        equals("DBusArray(DBusSignature('ay'), [DBusArray.byte([1, 2, 3])])"));
    expect(
        DBusArray(DBusSignature('ab'), [
          DBusArray.boolean([false, true])
        ]).toString(),
        equals(
            "DBusArray(DBusSignature('ab'), [DBusArray.boolean([false, true])])"));
    expect(DBusArray.byte([1, 2, 3]).toString(),
        equals('DBusArray.byte([1, 2, 3])'));
    expect(DBusArray.int16([1, 2, -3]).toString(),
        equals('DBusArray.int16([1, 2, -3])'));
    expect(DBusArray.uint16([1, 2, 3]).toString(),
        equals('DBusArray.uint16([1, 2, 3])'));
    expect(DBusArray.int32([1, 2, -3]).toString(),
        equals('DBusArray.int32([1, 2, -3])'));
    expect(DBusArray.uint32([1, 2, 3]).toString(),
        equals('DBusArray.uint32([1, 2, 3])'));
    expect(DBusArray.int64([1, 2, -3]).toString(),
        equals('DBusArray.int64([1, 2, -3])'));
    expect(DBusArray.uint64([1, 2, 3]).toString(),
        equals('DBusArray.uint64([1, 2, 3])'));
    expect(DBusArray.double([1.1, 2.1, 3.1]).toString(),
        equals('DBusArray.double([1.1, 2.1, 3.1])'));
    expect(DBusArray.string(['one', 'two', 'three']).toString(),
        equals("DBusArray.string(['one', 'two', 'three'])"));
    expect(
        DBusArray.objectPath([
          DBusObjectPath('/one'),
          DBusObjectPath('/two'),
          DBusObjectPath('/three')
        ]).toString(),
        equals(
            "DBusArray.objectPath([DBusObjectPath('/one'), DBusObjectPath('/two'), DBusObjectPath('/three')])"));
    expect(
        DBusArray.signature([DBusSignature('u'), DBusSignature('as')])
            .toString(),
        equals(
            "DBusArray.signature([DBusSignature('u'), DBusSignature('as')])"));
    expect(
        DBusArray.variant(
            [DBusInt32(1), DBusString('two'), DBusDouble(3.14159)]).toString(),
        equals(
            "DBusArray.variant([DBusInt32(1), DBusString('two'), DBusDouble(3.14159)])"));
    expect(
        DBusArray.variant(
            [DBusInt32(1), DBusString('two'), DBusDouble(3.14159)]).signature,
        equals(DBusSignature.array(DBusSignature.variant)));
    expect(
        DBusArray.unixFd([stdinHandle, stdoutHandle]).toString(),
        equals(
            "DBusArray.unixFd([Instance of '_ResourceHandleImpl', Instance of '_ResourceHandleImpl'])"));
    expect(DBusArray.unixFd([stdinHandle, stdoutHandle]).signature,
        equals(DBusSignature.array(DBusSignature.unixFd)));
    expect(DBusArray.string(['one', 'two', 'three']).hashCode,
        equals(DBusArray.string(['one', 'two', 'three']).hashCode));
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
    // Unchecked constructor equivalent to standard constructor.
    expect(
        DBusDict.unchecked(DBusSignature('i'), DBusSignature('s'), {
          DBusInt32(1): DBusString('one'),
          DBusInt32(2): DBusString('two'),
          DBusInt32(3): DBusString('three')
        }),
        equals(DBusDict(DBusSignature('i'), DBusSignature('s'), {
          DBusInt32(1): DBusString('one'),
          DBusInt32(2): DBusString('two'),
          DBusInt32(3): DBusString('three')
        })));
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
        }).asDict(),
        equals({
          DBusInt32(1): DBusString('one'),
          DBusInt32(2): DBusString('two'),
          DBusInt32(3): DBusString('three')
        }));
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
    // Check factory constructors are equivalent to their full expansions.
    expect(
        DBusDict.stringVariant({'one': DBusInt32(1), 'two': DBusDouble(2)}),
        equals(DBusDict(DBusSignature('s'), DBusSignature('v'), {
          DBusString('one'): DBusVariant(DBusInt32(1)),
          DBusString('two'): DBusVariant(DBusDouble(2))
        })));
    expect(
        DBusDict.stringVariant({'one': DBusInt32(1), 'two': DBusDouble(2)})
            .asStringVariantDict(),
        equals({'one': DBusInt32(1), 'two': DBusDouble(2)}));
    expect(
        DBusDict(DBusSignature('i'), DBusSignature('s'), {
          DBusInt32(1): DBusString('one'),
          DBusInt32(2): DBusString('two'),
          DBusInt32(3): DBusString('three')
        }).toString(),
        equals(
            "DBusDict(DBusSignature('i'), DBusSignature('s'), {DBusInt32(1): DBusString('one'), DBusInt32(2): DBusString('two'), DBusInt32(3): DBusString('three')})"));
    expect(
        DBusDict.stringVariant({'one': DBusInt32(1), 'two': DBusDouble(2)})
            .toString(),
        equals(
            "DBusDict.stringVariant({'one': DBusInt32(1), 'two': DBusDouble(2.0)})"));
    expect(
        DBusDict.stringVariant({'one': DBusInt32(1), 'two': DBusDouble(2)})
            .signature,
        equals(
            DBusSignature.dict(DBusSignature.string, DBusSignature.variant)));
    expect(
        DBusDict.stringVariant({'one': DBusInt32(1), 'two': DBusDouble(2)})
            .hashCode,
        equals(
            DBusDict.stringVariant({'one': DBusInt32(1), 'two': DBusDouble(2)})
                .hashCode));
  });

  test('uuid', () async {
    expect(
        DBusUUID.fromHexString('a61fb428740a11ec90d60242ac120003').value,
        equals([
          0xa6,
          0x1f,
          0xb4,
          0x28,
          0x74,
          0x0a,
          0x11,
          0xec,
          0x90,
          0xd6,
          0x02,
          0x42,
          0xac,
          0x12,
          0x00,
          0x03
        ]));
    expect(
        DBusUUID.fromHexString('a61fb428740a11ec90d60242ac120003')
            .toHexString(),
        equals('a61fb428740a11ec90d60242ac120003'));
    expect(() => DBusUUID.fromHexString('a61fb428-740a-11ec-90d6-0242ac120003'),
        throwsFormatException);
  });

  test('address', () async {
    // No transport.
    expect(() => DBusAddress(''), throwsException);

    // Missing divider.
    expect(() => DBusAddress('foo'), throwsException);

    // Key missing value.
    expect(() => DBusAddress('foo:key'), throwsException);

    // Duplicate key.
    expect(() => DBusAddress('foo:key=value,key=value'), throwsException);

    // Address created from string.
    var address = DBusAddress('transport:key1=value1,key2=value2');
    expect(address.transport, equals('transport'));
    expect(address.properties, equals({'key1': 'value1', 'key2': 'value2'}));
    expect(address.value, equals('transport:key1=value1,key2=value2'));

    // No properties.
    address = DBusAddress('transport:');
    expect(address.transport, equals('transport'));
    expect(address.properties, isEmpty);

    // Properties with escaped values.
    address = DBusAddress('transport:key=Hello%20World');
    expect(address.properties, equals({'key': 'Hello World'}));
    address = DBusAddress('transport:key=%2c%40%3d%09');
    expect(address.properties, equals({'key': ',@=\t'}));
    address = DBusAddress('transport:key=%f0%9f%98%84');
    expect(address.properties, equals({'key': '😄'}));

    // Address created from raw values.
    address = DBusAddress.withTransport(
        'transport', {'key1': 'value1', 'key2': 'value2'});
    expect(address.value, equals('transport:key1=value1,key2=value2'));

    // Properties with escaped values.
    address = DBusAddress.withTransport('transport', {'key': 'Hello World'});
    expect(address.value, equals('transport:key=Hello%20World'));
    address = DBusAddress.withTransport('transport', {'key': ',@=\t'});
    expect(address.value, equals('transport:key=%2c%40%3d%09'));
    address = DBusAddress.withTransport('transport', {'key': '😄'});
    expect(address.value, equals('transport:key=%f0%9f%98%84'));

    // Unix addresses.
    address = DBusAddress.unix();
    expect(address.value, equals('unix:'));
    address = DBusAddress.unix(
        path: '/path',
        dir: Directory('/dir'),
        tmpdir: Directory('/tmp'),
        abstract: 'foo',
        runtime: true);
    expect(
        address.value,
        equals(
            'unix:path=/path,dir=/dir,tmpdir=/tmp,abstract=foo,runtime=yes'));
    expect(DBusAddress.unix(path: '/path').toString(),
        equals("DBusAddress('unix:path=/path')"));

    // TCP addresses.
    address = DBusAddress.tcp('example.com');
    expect(address.value, equals('tcp:host=example.com'));
    address = DBusAddress.tcp('example.com',
        bind: '192.168.1.1', port: 42, family: DBusAddressTcpFamily.ipv4);
    expect(address.value,
        equals('tcp:host=example.com,bind=192.168.1.1,port=42,family=ipv4'));
    address = DBusAddress.tcp('example.com', family: DBusAddressTcpFamily.ipv6);
    expect(address.value, equals('tcp:host=example.com,family=ipv6'));
    expect(DBusAddress.tcp('example.com').toString(),
        equals("DBusAddress('tcp:host=example.com')"));
  });

  test('bus name', () async {
    expect(DBusBusName(':1.42').value, equals(':1.42'));
    expect(DBusBusName(':1.42').isUnique, isTrue);
    expect(() => DBusBusName(':42'), throwsFormatException);

    expect(DBusBusName('com.example.Test').value, equals('com.example.Test'));
    expect(DBusBusName('com.example.Test').isUnique, isFalse);
    expect(() => DBusBusName(''), throwsFormatException);
    expect(() => DBusBusName('com'), throwsFormatException);
    expect(DBusBusName('com.example').value, equals('com.example'));
    expect(DBusBusName('com.example.${'X' * 243}').value,
        equals('com.example.${'X' * 243}'));
    expect(
        () => DBusBusName('com.example.${'X' * 244}'), throwsFormatException);
    expect(() => DBusBusName('com.example.Test~1'), throwsFormatException);
    expect(DBusBusName('com.example.Test') == DBusBusName('com.example.Test'),
        isTrue);
    expect(DBusBusName('com.example.Test1') == DBusBusName('com.example.Test2'),
        isFalse);
    expect(DBusBusName('com.example.Test').toString(),
        equals("DBusBusName('com.example.Test')"));
  });

  test('interface name', () async {
    expect(DBusInterfaceName('com.example.Test').value,
        equals('com.example.Test'));
    expect(() => DBusInterfaceName(''), throwsFormatException);
    expect(() => DBusInterfaceName('com'), throwsFormatException);
    expect(DBusInterfaceName('com.example').value, equals('com.example'));
    expect(DBusInterfaceName('com.example.${'X' * 243}').value,
        equals('com.example.${'X' * 243}'));
    expect(() => DBusInterfaceName('com.example.${'X' * 244}'),
        throwsFormatException);
    expect(
        () => DBusInterfaceName('com.example.Test~1'), throwsFormatException);
    expect(
        DBusInterfaceName('com.example.Test') ==
            DBusInterfaceName('com.example.Test'),
        isTrue);
    expect(
        DBusInterfaceName('com.example.Test1') ==
            DBusInterfaceName('com.example.Test2'),
        isFalse);
    expect(DBusInterfaceName('com.example.Test').toString(),
        equals("DBusInterfaceName('com.example.Test')"));
  });

  test('error name', () async {
    expect(
        DBusErrorName('com.example.Error').value, equals('com.example.Error'));
    expect(() => DBusErrorName(''), throwsFormatException);
    expect(() => DBusErrorName('com'), throwsFormatException);
    expect(DBusErrorName('com.example').value, equals('com.example'));
    expect(DBusErrorName('com.example.${'X' * 243}').value,
        equals('com.example.${'X' * 243}'));
    expect(
        () => DBusErrorName('com.example.${'X' * 244}'), throwsFormatException);
    expect(() => DBusErrorName('com.example.Test~1'), throwsFormatException);
    expect(
        DBusErrorName('com.example.Test') == DBusErrorName('com.example.Test'),
        isTrue);
    expect(
        DBusErrorName('com.example.Test1') ==
            DBusErrorName('com.example.Test2'),
        isFalse);
    expect(DBusErrorName('com.example.Test').toString(),
        equals("DBusErrorName('com.example.Test')"));
  });

  test('member name', () async {
    expect(DBusMemberName('Member').value, equals('Member'));
    expect(() => DBusMemberName(''), throwsFormatException);
    expect(DBusMemberName('X' * 255).value, equals('X' * 255));
    expect(() => DBusMemberName('X' * 256), throwsFormatException);
    expect(() => DBusMemberName('Member~1'), throwsFormatException);
    expect(DBusMemberName('Member') == DBusMemberName('Member'), isTrue);
    expect(DBusMemberName('Member1') == DBusMemberName('Member2'), isFalse);
    expect(DBusMemberName('Member').toString(),
        equals("DBusMemberName('Member')"));
  });

  test('match rule', () async {
    // Empty rule.
    var rule1 = DBusMatchRule.fromDBusString('');
    expect(rule1.type, isNull);
    expect(rule1.sender, isNull);
    expect(rule1.interface, isNull);
    expect(rule1.member, isNull);
    expect(rule1.path, isNull);
    expect(rule1.pathNamespace, isNull);
    expect(rule1.toString(), equals('DBusMatchRule()'));

    // Basic fields.
    var rule2 = DBusMatchRule.fromDBusString(
        'type=method_call,sender=com.example.Test,interface=com.example.Test.Interface1,member=HelloWorld,path=/com/example/Test/Object1');
    expect(rule2.type, equals(DBusMessageType.methodCall));
    expect(rule2.sender, equals(DBusBusName('com.example.Test')));
    expect(rule2.interface,
        equals(DBusInterfaceName('com.example.Test.Interface1')));
    expect(rule2.member, equals(DBusMemberName('HelloWorld')));
    expect(rule2.path, equals(DBusObjectPath('/com/example/Test/Object1')));
    expect(
        rule2.toString(),
        equals(
            "DBusMatchRule(type=DBusMessageType.methodCall, sender=DBusBusName('com.example.Test'), interface=DBusInterfaceName('com.example.Test.Interface1'), member=DBusMemberName('HelloWorld'), path=DBusObjectPath('/com/example/Test/Object1'))"));

    // Comma between fields.
    expect(
        () => DBusMatchRule.fromDBusString(
            "type='method_call'sender='com.example.Test'"),
        throwsA(isA<DBusMatchRuleException>()));
    expect(
        () => DBusMatchRule.fromDBusString(
            "type='method_call' sender='com.example.Test'"),
        throwsA(isA<DBusMatchRuleException>()));
    expect(
        () => DBusMatchRule.fromDBusString(
            "type='method_call';sender='com.example.Test'"),
        throwsA(isA<DBusMatchRuleException>()));
    expect(() => DBusMatchRule.fromDBusString(',type=method_call'),
        throwsA(isA<DBusMatchRuleException>()));
    expect(() => DBusMatchRule.fromDBusString('type=method_call,'),
        throwsA(isA<DBusMatchRuleException>()));

    // Path namespaces.
    var rule3 = DBusMatchRule.fromDBusString(
        'type=signal,path_namespace=/com/example/Test');
    expect(rule3.pathNamespace, equals(DBusObjectPath('/com/example/Test')));
    expect(
        () => DBusMatchRule.fromDBusString(
            'path=/com/example/Test/Object1,path_namespace=/com/example/Test'),
        throwsA(isA<DBusMatchRuleException>()));

    // Quotes.
    expect(DBusMatchRule.fromDBusString('sender=com.example.Test').sender,
        equals(DBusBusName('com.example.Test')));
    expect(DBusMatchRule.fromDBusString("sender='com.example.Test'").sender,
        equals(DBusBusName('com.example.Test')));
    expect(
        () => DBusMatchRule.fromDBusString(
            "arg0=''\\''',arg1='\\',arg2=',',arg3='\\\\'"),
        returnsNormally);
    expect(
        () =>
            DBusMatchRule.fromDBusString("arg0=\\',arg1=\\,arg2=',',arg3=\\\\"),
        returnsNormally);
    expect(() => DBusMatchRule.fromDBusString("key='''"),
        throwsA(isA<DBusMatchRuleException>()));
    expect(() => DBusMatchRule.fromDBusString("key='value"),
        throwsA(isA<DBusMatchRuleException>()));
    expect(() => DBusMatchRule.fromDBusString("key=value'"),
        throwsA(isA<DBusMatchRuleException>()));

    // Value required
    expect(() => DBusMatchRule.fromDBusString('key1,key2=value2'),
        throwsA(isA<DBusMatchRuleException>()));
    expect(() => DBusMatchRule.fromDBusString('key1=value1,key2'),
        throwsA(isA<DBusMatchRuleException>()));

    // Valid types.
    expect(DBusMatchRule.fromDBusString("type='signal'").type,
        equals(DBusMessageType.signal));
    expect(DBusMatchRule.fromDBusString("type='method_call'").type,
        equals(DBusMessageType.methodCall));
    expect(DBusMatchRule.fromDBusString("type='method_return'").type,
        equals(DBusMessageType.methodReturn));
    expect(DBusMatchRule.fromDBusString("type='error'").type,
        equals(DBusMessageType.error));
    expect(() => DBusMatchRule.fromDBusString("type='invalid_type'"),
        throwsA(isA<DBusMatchRuleException>()));
  });

  test('message', () async {
    expect(DBusMessage(DBusMessageType.methodCall).toString(),
        equals('DBusMessage(type: DBusMessageType.methodCall, serial: 0)'));

    expect(
        DBusMessage(DBusMessageType.methodCall,
            flags: {DBusMessageFlag.noAutoStart},
            serial: 1234,
            path: DBusObjectPath('/com/example/Test/Object'),
            interface: DBusInterfaceName('com.example.Test.Interface1'),
            member: DBusMemberName('Hello'),
            destination: DBusBusName('com.example.Test2'),
            sender: DBusBusName('com.example.Test'),
            values: [DBusString('Ping')]).toString(),
        equals(
            "DBusMessage(type: DBusMessageType.methodCall, flags: {DBusMessageFlag.noAutoStart}, serial: 1234, path: DBusObjectPath('/com/example/Test/Object'), interface: DBusInterfaceName('com.example.Test.Interface1'), member: DBusMemberName('Hello'), destination: DBusBusName('com.example.Test2'), sender: DBusBusName('com.example.Test'), values: [DBusString('Ping')])"));

    expect(
        DBusMessage(DBusMessageType.methodReturn,
            flags: {DBusMessageFlag.noReplyExpected},
            serial: 1235,
            replySerial: 1234,
            destination: DBusBusName('com.example.Test1'),
            sender: DBusBusName('com.example.Test2'),
            values: [DBusString('Pong')]).toString(),
        equals(
            "DBusMessage(type: DBusMessageType.methodReturn, flags: {DBusMessageFlag.noReplyExpected}, serial: 1235, replySerial: 1234, destination: DBusBusName('com.example.Test1'), sender: DBusBusName('com.example.Test2'), values: [DBusString('Pong')])"));

    expect(
        DBusMessage(DBusMessageType.error,
            flags: {DBusMessageFlag.noReplyExpected},
            serial: 1235,
            errorName: DBusErrorName('com.example.Test.Error1'),
            replySerial: 1234,
            destination: DBusBusName('com.example.Test1'),
            sender: DBusBusName('com.example.Test2'),
            values: [DBusString('Error description')]).toString(),
        equals(
            "DBusMessage(type: DBusMessageType.error, flags: {DBusMessageFlag.noReplyExpected}, serial: 1235, errorName: DBusErrorName('com.example.Test.Error1'), replySerial: 1234, destination: DBusBusName('com.example.Test1'), sender: DBusBusName('com.example.Test2'), values: [DBusString('Error description')])"));

    expect(
        DBusMessage(DBusMessageType.signal,
            flags: {DBusMessageFlag.noReplyExpected},
            serial: 1236,
            path: DBusObjectPath('/com/example/Test/Object'),
            interface: DBusInterfaceName('com.example.Test.Interface1'),
            member: DBusMemberName('Event'),
            destination: DBusBusName('com.example.Test1'),
            sender: DBusBusName('com.example.Test2'),
            values: [DBusString('Boo')]).toString(),
        equals(
            "DBusMessage(type: DBusMessageType.signal, flags: {DBusMessageFlag.noReplyExpected}, serial: 1236, path: DBusObjectPath('/com/example/Test/Object'), interface: DBusInterfaceName('com.example.Test.Interface1'), member: DBusMemberName('Event'), destination: DBusBusName('com.example.Test1'), sender: DBusBusName('com.example.Test2'), values: [DBusString('Boo')])"));
  });

  test('method call', () async {
    expect(DBusMethodCall(sender: 'com.example.Test', name: 'Hello').toString(),
        equals("DBusMethodCall(sender: 'com.example.Test', name: 'Hello')"));
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

  test('double hello', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(abstract: 'abstract'));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Can't call hello a second time.
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'Hello'),
        throwsException);
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
    var owner = await client.getNameOwner('com.example.Test');
    expect(owner, isNull);
    var hasOwner = await client.nameHasOwner('com.example.Test');
    expect(hasOwner, isFalse);
    var names = await client.listQueuedOwners('com.example.Test');
    expect(names, isEmpty);

    // Check get events when acquired.
    expect(client.nameAcquired, emits('com.example.Test'));
    expect(
        client.nameOwnerChanged,
        emits(DBusNameOwnerChangedEvent('com.example.Test',
            oldOwner: null, newOwner: client.uniqueName)));

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
    owner = await client.getNameOwner('com.example.Test');
    expect(owner, equals(client.uniqueName));
    names = await client.listQueuedOwners('com.example.Test');
    expect(names, [client.uniqueName]);
  });

  test('request name - client closed', () async {
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

    // Connect client.
    await client1.ping();

    // Check name is released when client disconnects.
    expect(
        client2.nameOwnerChanged,
        emitsInOrder([
          DBusNameOwnerChangedEvent('com.example.Test',
              oldOwner: null, newOwner: client1.uniqueName),
          DBusNameOwnerChangedEvent('com.example.Test',
              oldOwner: client1.uniqueName, newOwner: null)
        ]));
    await client2.ping();

    // Request the name.
    var reply = await client1.requestName('com.example.Test');
    expect(reply, equals(DBusRequestNameReply.primaryOwner));

    // Close the client (name will be released).
    await client1.close();
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
    var client3 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await client3.close();
      await server.close();
    });

    // Connect client.
    await client1.ping();

    expect(
        client3.nameOwnerChanged,
        emits(DBusNameOwnerChangedEvent('com.example.Test',
            oldOwner: null, newOwner: client1.uniqueName)));
    await client3.ping();

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

  test('request name - queue, client closed', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    var client3 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await client3.close();
      await server.close();
    });

    // Connect clients.
    await client1.ping();
    await client2.ping();

    // Check name is transferred when the first client quits.
    expect(
        client3.nameOwnerChanged,
        emitsInOrder([
          DBusNameOwnerChangedEvent('com.example.Test',
              oldOwner: null, newOwner: client1.uniqueName),
          DBusNameOwnerChangedEvent('com.example.Test',
              oldOwner: client1.uniqueName, newOwner: client2.uniqueName)
        ]));
    await client3.ping();

    // Own a name with one client.
    var reply = await client1.requestName('com.example.Test');
    expect(reply, equals(DBusRequestNameReply.primaryOwner));

    // Attempt to replace the name with another client.
    reply = await client2.requestName('com.example.Test');
    expect(reply, equals(DBusRequestNameReply.inQueue));

    // Close first client (name will be transferred to second one).
    await client1.close();
  });

  test('request name - do not queue', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client1 = DBusClient(address);
    var client2 = DBusClient(address);
    var client3 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await client3.close();
      await server.close();
    });

    // Connect client.
    await client1.ping();

    expect(
        client3.nameOwnerChanged,
        emits(DBusNameOwnerChangedEvent('com.example.Test',
            oldOwner: null, newOwner: client1.uniqueName)));
    await client3.ping();

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
    var client3 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await client3.close();
      await server.close();
    });

    // Connect clients.
    await client1.ping();
    await client2.ping();

    // Check name is transferred to the second client.
    expect(
        client3.nameOwnerChanged,
        emitsInOrder([
          DBusNameOwnerChangedEvent('com.example.Test',
              oldOwner: null, newOwner: client1.uniqueName),
          DBusNameOwnerChangedEvent('com.example.Test',
              oldOwner: client1.uniqueName, newOwner: client2.uniqueName)
        ]));
    await client3.ping();

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
    var client3 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await client3.close();
      await server.close();
    });

    // Connect clients.
    await client1.ping();
    await client2.ping();

    // Check name is transferred to the second client.
    expect(
        client3.nameOwnerChanged,
        emitsInOrder([
          DBusNameOwnerChangedEvent('com.example.Test',
              oldOwner: null, newOwner: client1.uniqueName),
          DBusNameOwnerChangedEvent('com.example.Test',
              oldOwner: client1.uniqueName, newOwner: client2.uniqueName)
        ]));
    await client3.ping();

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
    var client3 = DBusClient(address);
    addTearDown(() async {
      await client1.close();
      await client2.close();
      await client3.close();
      await server.close();
    });

    // Connect client.
    await client1.ping();

    expect(
        client3.nameOwnerChanged,
        emits(DBusNameOwnerChangedEvent('com.example.Test',
            oldOwner: null, newOwner: client1.uniqueName)));
    await client3.ping();

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

  test('request name - invalid args', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Make requests with invalid args.
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'RequestName'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'RequestName',
            values: [DBusUint32(42)]),
        throwsA(isA<DBusInvalidArgsException>()));
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
    expect(() => client.requestName(':1.42'),
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

    // Connect client.
    await client.ping();

    // Check events when name acquired and lost
    expect(client.nameAcquired, emits('com.example.Test'));
    expect(client.nameLost, emits('com.example.Test'));
    expect(
        client.nameOwnerChanged,
        emitsInOrder([
          DBusNameOwnerChangedEvent('com.example.Test',
              oldOwner: null, newOwner: client.uniqueName),
          DBusNameOwnerChangedEvent('com.example.Test',
              oldOwner: client.uniqueName, newOwner: null)
        ]));

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

  test('release name - invalid args', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Make requests with invalid bus names.
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'ReleaseName'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'ReleaseName',
            values: [DBusUint32(42)]),
        throwsA(isA<DBusInvalidArgsException>()));
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

  test('release name - empty', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Attempt to release an empty name.
    expect(
        () => client.releaseName(''), throwsA(isA<DBusInvalidArgsException>()));
  });

  test('release name - invalid name', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Attempt to release an invalid name.
    expect(() => client.releaseName('com.example.Test~1'),
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

  test('names - invalid args', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Make requests with invalid args.
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'ListQueuedOwners'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(() => client.listQueuedOwners(''),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(() => client.listQueuedOwners('com.example.Test~1'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
                destination: 'org.freedesktop.DBus',
                path: DBusObjectPath('/'),
                interface: 'org.freedesktop.DBus',
                name: 'ListQueuedOwners',
                values: [
                  DBusString('org.freedesktop.DBus'),
                  DBusString('More data')
                ]),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'ListNames',
            values: [DBusString('Wrong data')]),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'ListActivatableNames',
            values: [DBusString('Wrong data')]),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'NameHasOwner'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(() => client.nameHasOwner(''),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(() => client.nameHasOwner('com.example.Test~1'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'NameHasOwner',
            values: [DBusString('com.example.Test'), DBusString('Bad data')]),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'GetNameOwner'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(() => client.getNameOwner(''),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(() => client.getNameOwner('com.example.Test~1'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'GetNameOwner',
            values: [DBusString('com.example.Test'), DBusString('Bad data')]),
        throwsA(isA<DBusInvalidArgsException>()));
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

    expect(() => client.startServiceByName(''),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(() => client.startServiceByName('com.example.Test~1'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'StartServiceByName'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'StartServiceByName',
            values: [DBusUint32(42)]),
        throwsA(isA<DBusInvalidArgsException>()));
  });

  test('get unix user - server', () async {
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

  test('get unix user - client', () async {
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

    // Connect client.
    await client1.ping();

    expect(() => client2.getConnectionUnixUser(client1.uniqueName),
        throwsA(isA<DBusNotSupportedException>()));
  });

  test('get unix user - unknown client', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    expect(() => client.getConnectionUnixUser('com.example.NotAClient'),
        throwsA(isA<DBusErrorException>()));
  });

  test('get unix user - invalid args', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    expect(() => client.getConnectionUnixUser(''),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(() => client.getConnectionUnixUser('com.example.Test~1'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'GetConnectionUnixUser'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'GetConnectionUnixUser',
            values: [DBusUint32(42)]),
        throwsA(isA<DBusInvalidArgsException>()));
  });

  test('get process id - server', () async {
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

  test('get process id - client', () async {
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

    // Connect client.
    await client1.ping();

    expect(() => client2.getConnectionUnixProcessId(client1.uniqueName),
        throwsA(isA<DBusNotSupportedException>()));
  });

  test('get process id - unknown client', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    expect(() => client.getConnectionUnixProcessId('com.example.NotAClient'),
        throwsA(isA<DBusErrorException>()));
  });

  test('get process id - invalid args', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    expect(() => client.getConnectionUnixProcessId(''),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(() => client.getConnectionUnixProcessId('com.example.Test~1'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'GetConnectionUnixProcessID'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'GetConnectionUnixProcessID',
            values: [DBusUint32(42)]),
        throwsA(isA<DBusInvalidArgsException>()));
  });

  test('get credentials - server', () async {
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

  test('get credentials - client', () async {
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

    // Connect client.
    await client1.ping();

    expect(() => client2.getConnectionCredentials(client1.uniqueName),
        throwsA(isA<DBusNotSupportedException>()));
  });

  test('get credentials - unknown client', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    expect(() => client.getConnectionCredentials('com.example.NotAClient'),
        throwsA(isA<DBusErrorException>()));
  });

  test('get credentials - invalid args', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    expect(() => client.getConnectionCredentials(''),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(() => client.getConnectionCredentials('com.example.Test~1'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'GetConnectionCredentials'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'GetConnectionCredentials',
            values: [DBusUint32(42)]),
        throwsA(isA<DBusInvalidArgsException>()));
  });

  test('get id', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    var id = await client.getId();
    expect(id, equals(server.uuid));
  });

  test('get machine id - server', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    var machineId = await getMachineId();

    var id = await client.getMachineId();
    expect(id, equals(machineId));
  });

  test('get machine id - client', () async {
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

    // Connect client.
    await client1.ping();

    var machineId = await getMachineId();

    var id = await client2.getMachineId(client1.uniqueName);
    expect(id, equals(machineId));
  });

  test('register object twice', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Check can only register an object once.
    var object = TestObject();
    await client.registerObject(object);
    expect(() => client.registerObject(object), throwsException);
  });

  test('register object second client', () async {
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

    // Check can only register an object on on client.
    var object = TestObject();
    await client1.registerObject(object);
    expect(() => client2.registerObject(object), throwsException);
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

  test('call method - all types', () async {
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

    var allTypes = [
      DBusByte(1),
      DBusInt16(2),
      DBusUint16(3),
      DBusInt32(4),
      DBusUint32(5),
      DBusInt64(6),
      DBusUint64(7),
      DBusDouble(8.0),
      DBusString('nine'),
      DBusObjectPath('/ten'),
      DBusSignature('dog'),
      DBusVariant(DBusString('variant')),
      DBusStruct([]),
      DBusArray.byte([0, 1, 255]),
      DBusArray.boolean([false, true]),
      DBusArray.int16([0, 1, -32768, 32767]),
      DBusArray.uint16([0, 1, 65535]),
      DBusArray.int32([0, 1, -2147483648, 2147483647]),
      DBusArray.uint32([0, 1, 4294967295]),
      DBusArray.int64([0, 1, -9223372036854775808, 9223372036854775807]),
      DBusArray.uint64([0, 1, 0xffffffffffffffff]),
      DBusArray.double([0, 1, 3.14159]),
      DBusArray.string(['Hello', 'World']),
      DBusArray.objectPath([
        DBusObjectPath('/com/example/Test1'),
        DBusObjectPath('/com/example/Test2')
      ]),
      DBusArray(DBusSignature('g'), [DBusSignature('y'), DBusSignature('as')]),
      DBusArray.variant([DBusString('Hello'), DBusUint32(42)]),
      DBusArray(DBusSignature('(sy)'), [
        DBusStruct([DBusString('A'), DBusByte(65)]),
        DBusStruct([DBusString('B'), DBusByte(66)])
      ]),
      DBusArray(DBusSignature('as'), [
        DBusArray.string(['H', 'e', 'l', 'l', 'o']),
        DBusArray.string(['W', 'o', 'r', 'l', 'd'])
      ]),
      DBusArray(DBusSignature('a{sv}'), [
        DBusDict.stringVariant(
            {'one': DBusByte(1), 'two': DBusInt16(2), 'three': DBusUint32(3)}),
        DBusDict.stringVariant(
            {'A': DBusString('Aye'), 'B': DBusDouble(3.14159)})
      ]),
      DBusDict(DBusSignature('i'), DBusSignature('s'), {
        DBusInt32(1): DBusString('one'),
        DBusInt32(2): DBusString('two'),
        DBusInt32(3): DBusString('three')
      })
    ];

    // Create a client that exposes a method that takes and returns all the DBus data types.
    await client1.registerObject(TestObject(
        expectedMethodValues: allTypes,
        methodResponses: {'Test': DBusMethodSuccessResponse(allTypes)}));

    // Call the method from another client.
    var response = await client2.callMethod(
        destination: client1.uniqueName,
        path: DBusObjectPath('/'),
        name: 'Test',
        values: allTypes);
    expect(response.values, equals(allTypes));
  });

  test('call method - unix fd types', () async {
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

    var unixFdTypes = [
      DBusUnixFd(ResourceHandle.fromStdin(stdin)),
      DBusStruct(
          [DBusUint32(0), DBusUnixFd(ResourceHandle.fromStdout(stdout))]),
      DBusVariant(DBusUnixFd(ResourceHandle.fromStdout(stdout))),
      DBusArray(DBusSignature('h'), [
        DBusUnixFd(ResourceHandle.fromStdin(stdin)),
        DBusUnixFd(ResourceHandle.fromStdout(stdout))
      ]),
      DBusDict(DBusSignature('i'), DBusSignature('h'), {
        DBusInt32(0): DBusUnixFd(ResourceHandle.fromStdin(stdin)),
        DBusInt32(1): DBusUnixFd(ResourceHandle.fromStdout(stdout))
      })
    ];

    // Create a client that exposes a method that takes and returns all the DBus unix fd data types.
    await client1.registerObject(TestObject(
        methodResponses: {'Test': DBusMethodSuccessResponse(unixFdTypes)}));

    // Call the method from another client.
    var response = await client2.callMethod(
        destination: client1.uniqueName,
        path: DBusObjectPath('/'),
        name: 'Test',
        values: unixFdTypes);
    expect(response.values, hasLength(5));
    expect(response.values[0], isA<DBusUnixFd>());
    expect(response.values[1].asStruct().elementAt(1), isA<DBusUnixFd>());
    expect(response.values[2].asVariant(), isA<DBusUnixFd>());
    expect(response.values[3].asArray()[0], isA<DBusUnixFd>());
    expect(response.values[3].asArray()[1], isA<DBusUnixFd>());
    expect(response.values[4].asDict()[DBusInt32(0)], isA<DBusUnixFd>());
    expect(response.values[4].asDict()[DBusInt32(0)], isA<DBusUnixFd>());
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

  test('call method - empty object', () async {
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

    // Create a client that exposes an object without any methods.
    await client1.registerObject(DBusObject(DBusObjectPath('/')));

    // Call the method from another client.
    expect(
        () => client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            name: 'Test',
            values: [DBusString('Hello'), DBusUint32(42)]),
        throwsA(isA<DBusUnknownInterfaceException>()));
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

    // Try and access an unknown method on that object.
    expect(
        () => client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            name: 'NoSuchMethod'),
        throwsA(isA<DBusUnknownMethodException>()));
  });

  test('call method - not supported', () async {
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
      'Test': DBusMethodErrorResponse.notSupported('Failure message')
    }));

    // Call the method from another client.
    expect(
        () => client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            name: 'Test'),
        throwsA(isA<DBusNotSupportedException>()));
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

  test('call method - auth failed', () async {
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

    // Create a client that exposes a method that generates an auth failed error.
    await client1.registerObject(TestObject(methodResponses: {
      'Test': DBusMethodErrorResponse.authFailed('Failure message')
    }));

    // Call the method from another client.
    expect(
        () => client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            name: 'Test'),
        throwsA(isA<DBusAuthFailedException>()));
  });

  test('call method - timeout', () async {
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

    // Create a client that exposes a method that generates a timeout error.
    await client1.registerObject(TestObject(methodResponses: {
      'Test': DBusMethodErrorResponse.timeout('Failure message')
    }));

    // Call the method from another client.
    expect(
        () => client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            name: 'Test'),
        throwsA(isA<DBusTimeoutException>()));
  });

  test('call method - timed out', () async {
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

    // Create a client that exposes a method that generates a timeout error.
    await client1.registerObject(TestObject(methodResponses: {
      'Test': DBusMethodErrorResponse.timedOut('Failure message')
    }));

    // Call the method from another client.
    expect(
        () => client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            name: 'Test'),
        throwsA(isA<DBusTimedOutException>()));
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

  test('call method - invalid name', () async {
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

    // Create a client with an object.
    await client1.registerObject(TestObject());

    // Method name empty.
    expect(
        client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            name: '',
            values: []),
        throwsFormatException);

    // Method name too long.
    expect(
        client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            name: 'x' * 256,
            values: []),
        throwsFormatException);

    // Method name contains invalid characters.
    expect(
        client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            name: 'Test!',
            values: []),
        throwsFormatException);
    expect(
        client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            name: 'Test-Method',
            values: []),
        throwsFormatException);
    expect(
        client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            name: '🤪',
            values: []),
        throwsFormatException);

    // Must not begin with a digit.
    expect(
        client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            name: '0Test',
            values: []),
        throwsFormatException);
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

  test('matches - invalid args', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'AddMatch'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'AddMatch',
            values: [DBusUint32(42)]),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'AddMatch',
            values: [DBusString('No a valid match')]),
        throwsA(isA<DBusErrorException>()));

    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'RemoveMatch'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'RemoveMatch',
            values: [DBusUint32(42)]),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'RemoveMatch',
            values: [DBusString('No a valid match')]),
        throwsA(isA<DBusErrorException>()));
    expect(
        () => client.callMethod(
            destination: 'org.freedesktop.DBus',
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus',
            name: 'RemoveMatch',
            values: [DBusString('type=signal,sender=not.a.real.Sender')]),
        throwsA(isA<DBusErrorException>()));
  });

  test('introspect - server', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Read introspection data from the server.
    var remoteObject = DBusRemoteObject(client,
        name: 'org.freedesktop.DBus', path: DBusObjectPath('/'));
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
            '<interface name="org.freedesktop.DBus">'
            '<method name="Hello">'
            '<arg name="unique_name" type="s" direction="out"/>'
            '</method>'
            '<method name="RequestName">'
            '<arg name="name" type="s" direction="in"/>'
            '<arg name="flags" type="u" direction="in"/>'
            '<arg name="result" type="u" direction="out"/>'
            '</method>'
            '<method name="ReleaseName">'
            '<arg name="name" type="s" direction="in"/>'
            '<arg name="result" type="u" direction="out"/>'
            '</method>'
            '<method name="ListQueuedOwners">'
            '<arg name="name" type="s" direction="in"/>'
            '<arg name="names" type="as" direction="out"/>'
            '</method>'
            '<method name="ListNames">'
            '<arg name="names" type="as" direction="out"/>'
            '</method>'
            '<method name="ListActivatableNames">'
            '<arg name="names" type="as" direction="out"/>'
            '</method>'
            '<method name="NameHasOwner">'
            '<arg name="name" type="s" direction="in"/>'
            '<arg name="result" type="b" direction="out"/>'
            '</method>'
            '<method name="StartServiceByName">'
            '<arg name="name" type="s" direction="in"/>'
            '<arg name="flags" type="u" direction="in"/>'
            '<arg name="result" type="u" direction="out"/>'
            '</method>'
            '<method name="GetNameOwner">'
            '<arg name="name" type="s" direction="in"/>'
            '<arg name="owner" type="s" direction="out"/>'
            '</method>'
            '<method name="GetConnectionUnixUser">'
            '<arg name="name" type="s" direction="in"/>'
            '<arg name="unix_user_id" type="u" direction="out"/>'
            '</method>'
            '<method name="GetConnectionUnixProcessID">'
            '<arg name="name" type="s" direction="in"/>'
            '<arg name="unix_process_id" type="u" direction="out"/>'
            '</method>'
            '<method name="GetConnectionCredentials">'
            '<arg name="name" type="s" direction="in"/>'
            '<arg name="credentials" type="a{sv}" direction="out"/>'
            '</method>'
            '<method name="AddMatch">'
            '<arg name="rule" type="s" direction="in"/>'
            '</method>'
            '<method name="RemoveMatch">'
            '<arg name="rule" type="s" direction="in"/>'
            '</method>'
            '<method name="GetId">'
            '<arg name="id" type="s" direction="out"/>'
            '</method>'
            '<signal name="NameOwnerChanged">'
            '<arg name="name" type="s"/>'
            '<arg name="old_owner" type="s"/>'
            '<arg name="new_owner" type="s"/>'
            '</signal>'
            '<signal name="NameLost">'
            '<arg name="name" type="s"/>'
            '</signal>'
            '<signal name="NameAcquired">'
            '<arg name="name" type="s"/>'
            '</signal>'
            '<property name="Features" type="as" access="read"/>'
            '<property name="Interfaces" type="as" access="read"/>'
            '</interface>'
            '</node>'));
  });

  test('introspect - client', () async {
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

  test('introspect - empty object', () async {
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

    // Create a client that exposes an object without introspection.
    await client1.registerObject(DBusObject(DBusObjectPath('/')));

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

  test('peer - invalid args', () async {
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

    // Connect client.
    await client1.ping();

    expect(
        () => client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus.Peer',
            name: 'Ping',
            values: [DBusString('Boo')]),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus.Peer',
            name: 'GetMachineId',
            values: [DBusString('Boo')]),
        throwsA(isA<DBusInvalidArgsException>()));
  });

  test('peer - unknown method', () async {
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

    // Connect client.
    await client1.ping();

    // Try and access an unknown method on the Peer interface.
    expect(
        () => client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus.Peer',
            name: 'NoSuchMethod'),
        throwsA(isA<DBusUnknownMethodException>()));
  });

  test('introspect - unknown method', () async {
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

    // Try and access an unknown method on the properties interface.
    expect(
        () => client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus.Introspectable',
            name: 'NoSuchMethod'),
        throwsA(isA<DBusUnknownMethodException>()));
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

  test('properties - invalid args', () async {
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

    // Try and access methods with invalid args on the properties interface.
    expect(
        () => client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus.Properties',
            name: 'Get'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus.Properties',
            name: 'Set'),
        throwsA(isA<DBusInvalidArgsException>()));
    expect(
        () => client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus.Properties',
            name: 'GetAll'),
        throwsA(isA<DBusInvalidArgsException>()));
  });

  test('properties - empty object', () async {
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

    // Create a client that exposes an object with no properties.
    await client1.registerObject(DBusObject(DBusObjectPath('/')));

    var remoteObject = DBusRemoteObject(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
    expect(() => remoteObject.getProperty('com.example.Test', 'Property'),
        throwsA(isA<DBusUnknownPropertyException>()));
    expect(
        () => remoteObject.setProperty(
            'com.example.Test', 'Property', DBusString('Foo')),
        throwsA(isA<DBusUnknownPropertyException>()));
    var properties = await remoteObject.getAllProperties('com.example.Test');
    expect(properties, isEmpty);
  });

  test('properties - unknown method', () async {
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

    // Try and access an unknown method on the properties interface.
    expect(
        () => client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus.Properties',
            name: 'NoSuchMethod'),
        throwsA(isA<DBusUnknownMethodException>()));
  });

  test('server properties', () async {
    var server = DBusServer();
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    var remoteObject = DBusRemoteObject(client,
        name: 'org.freedesktop.DBus', path: DBusObjectPath('/'));

    expect(await remoteObject.getProperty('org.freedesktop.DBus', 'Features'),
        equals(DBusArray.string([])));
    expect(
        remoteObject.setProperty(
            'org.freedesktop.DBus', 'Features', DBusArray.string(['abc'])),
        throwsException);

    expect(await remoteObject.getProperty('org.freedesktop.DBus', 'Interfaces'),
        equals(DBusArray.string([])));
    expect(
        remoteObject.setProperty(
            'org.freedesktop.DBus', 'Interfaces', DBusArray.string(['abc'])),
        throwsException);

    var properties =
        await remoteObject.getAllProperties('org.freedesktop.DBus');
    expect(
        properties,
        equals({
          'Features': DBusArray.string([]),
          'Interfaces': DBusArray.string([])
        }));
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

  test('object manager - introspect', () async {
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
            '<interface name="org.freedesktop.DBus.ObjectManager">'
            '<method name="GetManagedObjects">'
            '<arg name="objpath_interfaces_and_properties" type="a{oa{sa{sv}}}" direction="out"/>'
            '</method>'
            '<signal name="InterfacesAdded">'
            '<arg name="object_path" type="o"/>'
            '<arg name="interfaces_and_properties" type="a{sa{sv}}"/>'
            '</signal>'
            '<signal name="InterfacesRemoved">'
            '<arg name="object_path" type="o"/>'
            '<arg name="interfaces" type="as"/>'
            '</signal>'
            '</interface>'
            '<node name="com"/>'
            '</node>'));
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

    // Check object is removed.
    var objects = await remoteManagerObject.getManagedObjects();
    expect(
        objects,
        equals({
          DBusObjectPath('/com/example/Object1'): {
            'org.freedesktop.DBus.Introspectable': {},
            'org.freedesktop.DBus.Properties': {}
          }
        }));
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

  test('object manager - empty object', () async {
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

    // Register an object manager and an empty object.
    var objectManager = DBusObject(DBusObjectPath('/'), isObjectManager: true);
    await client1.registerObject(objectManager);
    await client1
        .registerObject(DBusObject(DBusObjectPath('/com/example/Object1')));

    var remoteManagerObject = DBusRemoteObjectManager(client2,
        name: client1.uniqueName, path: DBusObjectPath('/'));
    var objects = await remoteManagerObject.getManagedObjects();
    expect(
        objects,
        equals({
          DBusObjectPath('/com/example/Object1'): {
            'org.freedesktop.DBus.Introspectable': {},
            'org.freedesktop.DBus.Properties': {}
          }
        }));
  });

  test('object manager - unknown method', () async {
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

    // Register an object manager.
    var objectManager = DBusObject(DBusObjectPath('/'), isObjectManager: true);
    await client1.registerObject(objectManager);

    // Try and access an unknown method on the object manager interface.
    expect(
        () => client2.callMethod(
            destination: client1.uniqueName,
            path: DBusObjectPath('/'),
            interface: 'org.freedesktop.DBus.ObjectManager',
            name: 'NoSuchMethod'),
        throwsA(isA<DBusUnknownMethodException>()));
  });

  test('no message bus', () async {
    var server = DBusServer(messageBus: false);
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address, messageBus: false);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    await client.ping();
  });

  test('no message bus - introspect', () async {
    var server = DBusServer(messageBus: false);
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address, messageBus: false);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    // Read introspection data from the server.
    var remoteObject = DBusRemoteObject(client,
        name: 'org.freedesktop.DBus', path: DBusObjectPath('/'));
    var node = await remoteObject.introspect();
    expect(node.toXml().toXmlString(), equals('<node/>'));
  });

  test('no message bus - subscribe signal', () async {
    var server = DBusServer(messageBus: false);
    var address =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    var client = DBusClient(address, messageBus: false);
    addTearDown(() async {
      await client.close();
      await server.close();
    });

    var signals =
        DBusSignalStream(client, interface: 'com.example.Test', name: 'Ping');
    signals.listen(expectAsync1((signal) {
      expect(signal.sender, isNull);
      expect(signal.path, equals(DBusObjectPath('/')));
      expect(signal.interface, equals('com.example.Test'));
      expect(signal.name, equals('Ping'));
      expect(signal.values, equals([DBusString('Hello'), DBusUint32(42)]));
    }));

    // Ensure client is connected.
    await client.ping();

    server.emitSignal(
        path: DBusObjectPath('/'),
        interface: 'com.example.Test',
        name: 'Ping',
        values: [DBusString('Hello'), DBusUint32(42)]);
  });

  test('introspect xml - empty', () {
    expect(() => parseDBusIntrospectXml(''), throwsFormatException);
  });

  test('introspect xml - unknown tag', () {
    expect(() => parseDBusIntrospectXml('<foo/>'), throwsFormatException);
  });

  test('introspect xml - empty node', () {
    var node = parseDBusIntrospectXml('<node/>');
    expect(node, equals(DBusIntrospectNode()));
  });

  test('introspect xml - named node', () {
    var node = parseDBusIntrospectXml('<node name="/com/example/Test"/>');
    expect(node, equals(DBusIntrospectNode(name: '/com/example/Test')));
  });

  test('introspect xml - interface annotation', () {
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

  test('introspect xml - empty interface', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"/></node>');
    expect(
        node,
        equals(DBusIntrospectNode(
            interfaces: [DBusIntrospectInterface('com.example.Test')])));
  });

  test('introspect xml - missing interface name', () {
    expect(() => parseDBusIntrospectXml('<node><interface/></node>'),
        throwsFormatException);
  });

  test('introspect xml - method no args', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><method name="Hello"/></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test',
              methods: [DBusIntrospectMethod('Hello')])
        ])));
  });

  test('introspect xml - method input arg', () {
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

  test('introspect xml - method named arg', () {
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

  test('introspect xml - method input arg', () {
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

  test('introspect xml - method output arg', () {
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

  test('introspect xml - method arg annotation', () {
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

  test('introspect xml - method annotation', () {
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

  test('introspect xml - missing method name', () {
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><method/></interface></node>'),
        throwsFormatException);
  });

  test('introspect xml - missing argument type', () {
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><method name="Hello"><arg/></method></interface></node>'),
        throwsFormatException);
  });

  test('introspect xml - unknown argument direction', () {
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><method name="Hello"><arg type="s" direction="down"/></method></interface></node>'),
        throwsFormatException);
  });

  test('introspect xml - signal', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><signal name="CountChanged"/></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test',
              signals: [DBusIntrospectSignal('CountChanged')])
        ])));

    expect(DBusIntrospectSignal('Signal1').toString(),
        equals("DBusIntrospectSignal('Signal1')"));
  });

  test('introspect xml - signal argument', () {
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

  test('introspect xml - signal output argument', () {
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

  test('introspect xml - signal annotation', () {
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

  test('introspect xml - signal no name', () {
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><signal/></interface></node>'),
        throwsFormatException);
  });

  test('introspect xml - signal input argument', () {
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><signal><arg type="u" direction="in"/></signal></interface></node>'),
        throwsFormatException);
  });

  test('introspect xml - property', () {
    var node = parseDBusIntrospectXml(
        '<node><interface name="com.example.Test"><property name="Count" type="u"/></interface></node>');
    expect(
        node,
        equals(DBusIntrospectNode(interfaces: [
          DBusIntrospectInterface('com.example.Test',
              properties: [DBusIntrospectProperty('Count', DBusSignature('u'))])
        ])));

    expect(DBusIntrospectProperty('Property1', DBusSignature('s')).toString(),
        equals("DBusIntrospectProperty('Property1', DBusSignature('s'))"));
  });

  test('introspect xml - property - read access', () {
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

  test('introspect xml - property - write access', () {
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

  test('introspect xml - property - readwrite access', () {
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

  test('introspect xml - property annotation', () {
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

  test('introspect xml - property no name or type', () {
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><property/></interface></node>'),
        throwsFormatException);
  });

  test('introspect xml - property no name', () {
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><property type="u"/></interface></node>'),
        throwsFormatException);
  });

  test('introspect xml - property no type', () {
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><property name="Count"/></interface></node>'),
        throwsFormatException);
  });

  test('introspect xml - property unknown access', () {
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><property name="Count" type="u" access="cook"/></interface></node>'),
        throwsFormatException);
  });

  test('introspect xml - node', () {
    var noInterfaceNode = DBusIntrospectNode();
    expect(noInterfaceNode.toXml().toXmlString(), equals('<node/>'));

    var interfaceNode =
        DBusIntrospectNode(name: '/com/example/Object', interfaces: [
      DBusIntrospectInterface('com.example.Interface1'),
      DBusIntrospectInterface('com.example.Interface2')
    ]);
    expect(
        interfaceNode.toXml().toXmlString(),
        equals('<node name="/com/example/Object">'
            '<interface name="com.example.Interface1"/>'
            '<interface name="com.example.Interface2"/>'
            '</node>'));

    var treeNode = DBusIntrospectNode(name: '/com/example/Object', interfaces: [
      DBusIntrospectInterface('com.example.Interface1')
    ], children: [
      DBusIntrospectNode(name: 'Subobject1'),
      DBusIntrospectNode(name: 'Subobject2')
    ]);
    expect(
        treeNode.toXml().toXmlString(),
        equals('<node name="/com/example/Object">'
            '<interface name="com.example.Interface1"/>'
            '<node name="Subobject1"/>'
            '<node name="Subobject2"/>'
            '</node>'));

    expect(DBusIntrospectNode().toString(), equals('DBusIntrospectNode()'));
  });

  test('introspect xml - interface', () {
    var emptyInterface = DBusIntrospectInterface('com.example.Interface1');
    expect(emptyInterface.toXml().toXmlString(),
        equals('<interface name="com.example.Interface1"/>'));

    var methodInterface = DBusIntrospectInterface('com.example.Interface1',
        methods: [
          DBusIntrospectMethod('Method1'),
          DBusIntrospectMethod('Method2')
        ]);
    expect(
        methodInterface.toXml().toXmlString(),
        equals('<interface name="com.example.Interface1">'
            '<method name="Method1"/>'
            '<method name="Method2"/>'
            '</interface>'));

    var signalInterface = DBusIntrospectInterface('com.example.Interface1',
        signals: [
          DBusIntrospectSignal('Signal1'),
          DBusIntrospectSignal('Signal2')
        ]);
    expect(
        signalInterface.toXml().toXmlString(),
        equals('<interface name="com.example.Interface1">'
            '<signal name="Signal1"/>'
            '<signal name="Signal2"/>'
            '</interface>'));

    var propertyInterface =
        DBusIntrospectInterface('com.example.Interface1', properties: [
      DBusIntrospectProperty('Property1', DBusSignature('s')),
      DBusIntrospectProperty('Property2', DBusSignature('i'))
    ]);
    expect(
        propertyInterface.toXml().toXmlString(),
        equals('<interface name="com.example.Interface1">'
            '<property name="Property1" type="s" access="readwrite"/>'
            '<property name="Property2" type="i" access="readwrite"/>'
            '</interface>'));

    var annotatedInterface =
        DBusIntrospectInterface('com.example.Interface1', methods: [
      DBusIntrospectMethod('Method1')
    ], signals: [
      DBusIntrospectSignal('Signal1')
    ], properties: [
      DBusIntrospectProperty('Property1', DBusSignature('s'))
    ], annotations: [
      DBusIntrospectAnnotation('com.example.Annotation1', 'value1'),
      DBusIntrospectAnnotation('com.example.Annotation2', 'value2')
    ]);
    expect(
        annotatedInterface.toXml().toXmlString(),
        equals('<interface name="com.example.Interface1">'
            '<method name="Method1"/>'
            '<signal name="Signal1"/>'
            '<property name="Property1" type="s" access="readwrite"/>'
            '<annotation name="com.example.Annotation1" value="value1"/>'
            '<annotation name="com.example.Annotation2" value="value2"/>'
            '</interface>'));

    expect(DBusIntrospectInterface('com.example.Test.Interface1').toString(),
        equals("DBusIntrospectInterface('com.example.Test.Interface1')"));
  });

  test('introspect xml - method', () {
    var noArgMethod = DBusIntrospectMethod('Method1');
    expect(
        noArgMethod.toXml().toXmlString(), equals('<method name="Method1"/>'));

    var argMethod = DBusIntrospectMethod('Method1', args: [
      DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_),
      DBusIntrospectArgument(DBusSignature('as'), DBusArgumentDirection.in_,
          name: 'named_arg'),
      DBusIntrospectArgument(DBusSignature('i'), DBusArgumentDirection.out)
    ]);
    expect(
        argMethod.toXml().toXmlString(),
        equals('<method name="Method1">'
            '<arg type="s" direction="in"/>'
            '<arg name="named_arg" type="as" direction="in"/>'
            '<arg type="i" direction="out"/>'
            '</method>'));

    var annotatedMethod = DBusIntrospectMethod('Method1', args: [
      DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_),
    ], annotations: [
      DBusIntrospectAnnotation('com.example.Annotation1', 'value1'),
      DBusIntrospectAnnotation('com.example.Annotation2', 'value2')
    ]);
    expect(
        annotatedMethod.toXml().toXmlString(),
        equals('<method name="Method1">'
            '<arg type="s" direction="in"/>'
            '<annotation name="com.example.Annotation1" value="value1"/>'
            '<annotation name="com.example.Annotation2" value="value2"/>'
            '</method>'));

    expect(DBusIntrospectMethod('Method1').toString(),
        equals("DBusIntrospectMethod('Method1')"));
  });

  test('introspect xml - signal', () {
    var noArgSignal = DBusIntrospectSignal('Signal1');
    expect(
        noArgSignal.toXml().toXmlString(), equals('<signal name="Signal1"/>'));

    var argSignal = DBusIntrospectSignal('Signal1', args: [
      DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out),
      DBusIntrospectArgument(DBusSignature('i'), DBusArgumentDirection.out,
          name: 'named_arg')
    ]);
    expect(
        argSignal.toXml().toXmlString(),
        equals('<signal name="Signal1">'
            '<arg type="s"/>'
            '<arg name="named_arg" type="i"/>'
            '</signal>'));

    var annotatedSignal = DBusIntrospectSignal('Signal1', args: [
      DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out),
    ], annotations: [
      DBusIntrospectAnnotation('com.example.Annotation1', 'value1'),
      DBusIntrospectAnnotation('com.example.Annotation2', 'value2')
    ]);
    expect(
        annotatedSignal.toXml().toXmlString(),
        equals('<signal name="Signal1">'
            '<arg type="s"/>'
            '<annotation name="com.example.Annotation1" value="value1"/>'
            '<annotation name="com.example.Annotation2" value="value2"/>'
            '</signal>'));
  });

  test('introspect xml - property', () {
    var property = DBusIntrospectProperty('Property1', DBusSignature('s'));
    expect(property.toXml().toXmlString(),
        equals('<property name="Property1" type="s" access="readwrite"/>'));

    var readProperty = DBusIntrospectProperty(
        'ReadProperty', DBusSignature('s'),
        access: DBusPropertyAccess.read);
    expect(readProperty.toXml().toXmlString(),
        equals('<property name="ReadProperty" type="s" access="read"/>'));

    var writeProperty = DBusIntrospectProperty(
        'WriteProperty', DBusSignature('i'),
        access: DBusPropertyAccess.write);
    expect(writeProperty.toXml().toXmlString(),
        equals('<property name="WriteProperty" type="i" access="write"/>'));

    var readWriteProperty = DBusIntrospectProperty(
        'ReadWriteProperty', DBusSignature('ay'),
        access: DBusPropertyAccess.readwrite);
    expect(
        readWriteProperty.toXml().toXmlString(),
        equals(
            '<property name="ReadWriteProperty" type="ay" access="readwrite"/>'));

    var annotatedProperty = DBusIntrospectProperty(
        'Property1', DBusSignature('a{sv}'),
        annotations: [
          DBusIntrospectAnnotation('com.example.Annotation1', 'value1'),
          DBusIntrospectAnnotation('com.example.Annotation2', 'value2')
        ]);
    expect(
        annotatedProperty.toXml().toXmlString(),
        equals('<property name="Property1" type="a{sv}" access="readwrite">'
            '<annotation name="com.example.Annotation1" value="value1"/>'
            '<annotation name="com.example.Annotation2" value="value2"/>'
            '</property>'));
  });

  test('introspect xml - argument', () {
    var inArgument =
        DBusIntrospectArgument(DBusSignature('i'), DBusArgumentDirection.in_);
    expect(inArgument.toXml().toXmlString(),
        equals('<arg type="i" direction="in"/>'));

    var outArgument =
        DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out);
    expect(outArgument.toXml().toXmlString(),
        equals('<arg type="s" direction="out"/>'));

    var namedArgument = DBusIntrospectArgument(
        DBusSignature('s'), DBusArgumentDirection.in_,
        name: 'named_arg');
    expect(namedArgument.toXml().toXmlString(),
        equals('<arg name="named_arg" type="s" direction="in"/>'));

    var annotatedArgument = DBusIntrospectArgument(
        DBusSignature('s'), DBusArgumentDirection.out,
        annotations: [
          DBusIntrospectAnnotation('com.example.Annotation1', 'value1'),
          DBusIntrospectAnnotation('com.example.Annotation2', 'value2')
        ]);
    expect(
        annotatedArgument.toXml().toXmlString(),
        equals('<arg type="s" direction="out">'
            '<annotation name="com.example.Annotation1" value="value1"/>'
            '<annotation name="com.example.Annotation2" value="value2"/>'
            '</arg>'));

    expect(
        DBusIntrospectArgument(DBusSignature('u'), DBusArgumentDirection.out)
            .toString(),
        equals(
            "DBusIntrospectArgument(DBusSignature('u'), DBusArgumentDirection.out)"));
  });

  test('introspect xml - annotation', () {
    var annotation =
        DBusIntrospectAnnotation('com.example.Annotation1', 'value1');
    expect(annotation.toXml().toXmlString(),
        equals('<annotation name="com.example.Annotation1" value="value1"/>'));

    expect(
        DBusIntrospectAnnotation('com.example.Annotation1', 'AnnotationValue')
            .toString(),
        equals(
            "DBusIntrospectAnnotation('com.example.Annotation1', 'AnnotationValue')"));
  });

  test('introspect xml - annotation missing fields', () {
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><property name="Count" type="u"><annotation/></property></interface></node>'),
        throwsFormatException);
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><property name="Count" type="u"><annotation name="com.example.Test.Name"/></property></interface></node>'),
        throwsFormatException);
    expect(
        () => parseDBusIntrospectXml(
            '<node><interface name="com.example.Test"><property name="Count" type="u"><annotation value="AnnotationValue"/></property></interface></node>'),
        throwsFormatException);
  });

  test('server invalid addresses', () async {
    var server = DBusServer();
    expect(
        () => server.listenAddress(DBusAddress('invalid:')), throwsException);
    expect(() => server.listenAddress(DBusAddress('unix:')), throwsException);
    expect(() => server.listenAddress(DBusAddress('unix:runtime=INVALID')),
        throwsException);
    expect(() => server.listenAddress(DBusAddress('tcp:')), throwsException);
    expect(
        () => server
            .listenAddress(DBusAddress('tcp:host=com.example,family=INVALID')),
        throwsException);
    expect(
        () => server
            .listenAddress(DBusAddress('tcp:host=com.example,port=INVALID')),
        throwsException);
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

  test('code generator - comment', () async {
    var generator = DBusCodeGenerator(
        DBusIntrospectNode(name: '/com/example/Object'),
        comment: 'This is great code.\nIt is the best code.');
    expect(
        generator.generateClientSource(),
        equals('// This is great code.\n'
            '// It is the best code.\n'
            '\n'
            'import \'dart:io\';\n'
            'import \'package:dbus/dbus.dart\';\n'
            '\n'
            'class ComExampleObject extends DBusRemoteObject {\n'
            '  ComExampleObject(DBusClient client, String destination, {DBusObjectPath path = const DBusObjectPath.unchecked(\'/com/example/Object\')}) : super(client, name: destination, path: path);\n'
            '}\n'));
    expect(
        generator.generateServerSource(),
        equals('// This is great code.\n'
            '// It is the best code.\n'
            '\n'
            'import \'dart:io\';\n'
            'import \'package:dbus/dbus.dart\';\n'
            '\n'
            'class ComExampleObject extends DBusObject {\n'
            '  /// Creates a new object to expose on [path].\n'
            '  ComExampleObject({DBusObjectPath path = const DBusObjectPath.unchecked(\'/com/example/Object\')}) : super(path);\n'
            '}\n'));
  });
}
