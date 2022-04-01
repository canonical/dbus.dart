import 'dart:io';

import 'package:dbus/code_generator.dart';
import 'package:dbus/dbus.dart';
import 'package:test/test.dart';
import 'package:dbus/src/dbus_value_ws_ext.dart';
import 'package:dbus/src/dbus_ws_read_buffer.dart';
import 'package:dbus/src/dbus_ws_message.dart';
import 'package:dbus/src/dbus_message.dart';
import 'package:dbus/src/dbus_ws_write_buffer.dart';
import 'package:dbus/src/dbus_interface_name.dart';
import 'package:dbus/src/dbus_member_name.dart';
import 'package:dbus/src/dbus_bus_name.dart';

void main() {
  for (var name in [
    'method-no-args',
    'method-single-input',
    'method-single-output',
    'method-single-output-2',
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
      var generator = DBusCodeGenerator(node, withAnnotations: true);
      var code = generator.generateClientSource();
      var expectedCode =
          await File('test/generated-code-annotations/$name.client.out')
              .readAsString();
      expect(code, equals(expectedCode));
    });
  }
  test('DBusValueToJson', () {
    expect(DBusArray.int32([1, 2, 3]).toJson(), [1, 2, 3]);
    expect(
        DBusStruct([DBusInt32(64), DBusString('xxx')]).toJson(), [64, 'xxx']);
  });

  test('DBusWSReadBuffer', () {
    DBusWSReadBuffer readBuffer = DBusWSReadBuffer();
    expect(readBuffer.readDBusValue(DBusSignature('y'), 2), DBusByte(2));
    expect(
        readBuffer.readDBusValue(DBusSignature('b'), true), DBusBoolean(true));
    expect(readBuffer.readDBusValue(DBusSignature('n'), -32767),
        DBusInt16(-32767));
    expect(
        readBuffer.readDBusValue(DBusSignature('q'), 65535), DBusUint16(65535));
    expect(readBuffer.readDBusValue(DBusSignature('i'), -2147483648),
        DBusInt32(-2147483648));
    expect(readBuffer.readDBusValue(DBusSignature('u'), 4294967295),
        DBusUint32(4294967295));
    expect(readBuffer.readDBusValue(DBusSignature('x'), -1), DBusInt64(-1));
    expect(readBuffer.readDBusValue(DBusSignature('t'), 1), DBusUint64(1));
    expect(readBuffer.readDBusValue(DBusSignature('d'), 66), DBusDouble(66.0));
    expect(readBuffer.readDBusValue(DBusSignature('d'), 1.5), DBusDouble(1.5));
    expect(readBuffer.readDBusValue(DBusSignature('s'), '1'), DBusString('1'));
    expect(readBuffer.readDBusValue(DBusSignature('as'), ['a', 'b']),
        DBusArray.string(['a', 'b']));
    expect(readBuffer.readDBusValue(DBusSignature('(si)'), ['a', 5]),
        DBusStruct([DBusString('a'), DBusInt32(5)]));
    expect(
        readBuffer.readDBusValue(DBusSignature('a(si)'), [
          ['a', 5],
          ['b', 6]
        ]),
        DBusArray(DBusSignature('(si)'), [
          DBusStruct([DBusString('a'), DBusInt32(5)]),
          DBusStruct([DBusString('b'), DBusInt32(6)])
        ]));
    expect(
        readBuffer.readDBusValue(DBusSignature('a{si}'), [
          ['a', 5],
          ['b', 6]
        ]),
        DBusDict(DBusSignature('s'), DBusSignature('i'),
            {DBusString('a'): DBusInt32(5), DBusString('b'): DBusInt32(6)}));
    //todo: reverse engineered, more tests for variants are required. Deeper understanding of how js dbus provides variants.
    expect(
        readBuffer.readDBusVariant([
          [
            {'type': 'i', 'child': []}
          ],
          [64]
        ]),
        DBusVariant(DBusInt32(64)));
    expect(
        readBuffer.readDBusVariant([
          [
            {'type': 's', 'child': []}
          ],
          ['data']
        ]),
        DBusVariant(DBusString('data')));
  });

  test('DBusWSReadBuffer', () {
    var wsbuff = DBusWSWriteBuffer();
    var msg = DBusWSMessage(
      DBusMessageType.methodCall,
      serial:123,
      path:DBusObjectPath('/test/path'),
      interface:DBusInterfaceName('test.iface'),
      member:DBusMemberName('m'),
      destination:DBusBusName('test.dd'),
      replySignature:DBusSignature('(ss)')
    );
    wsbuff.writeMessage(msg);
    expect(wsbuff.data, 'invoke:{"id":{"serial":123,"signature":"(ss)"},"destination":"test.dd","path":"/test/path","interface":"test.iface","member":"m"}');
    var msg2 = DBusWSMessage(
      DBusMessageType.methodCall,
      serial:123,
      path:DBusObjectPath('/test/path'),
      interface:DBusInterfaceName('test.iface'),
      member:DBusMemberName('m'),
      destination:DBusBusName('test.dd'),
      replySignature:DBusSignature('(ss)'),
      values:[
        DBusDict(DBusSignature('s'), DBusSignature('i'),
            {DBusString('a'): DBusInt32(5), DBusString('b'): DBusInt32(6)})
      ]
    );
    wsbuff.writeMessage(msg2);
    expect(wsbuff.data,
        'invoke:{"id":{"serial":123,"signature":"(ss)"},"destination":"test.dd","path":"/test/path","interface":"test.iface","member":"m","body":[{"a":5,"b":6}],"signature":"a{si}"}');
  });
}
