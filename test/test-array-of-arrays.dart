import 'package:dbus/code_generator.dart';
import 'package:dbus/dbus.dart';
import 'package:dbus/src/dbus_bus_name.dart';
import 'package:dbus/src/dbus_error_name.dart';
import 'package:dbus/src/dbus_interface_name.dart';
import 'package:dbus/src/dbus_match_rule.dart';
import 'package:dbus/src/dbus_member_name.dart';
import 'package:dbus/src/dbus_message.dart';
import 'package:dbus/src/dbus_write_buffer.dart';
import 'package:dbus/src/dbus_uuid.dart';
import 'package:dbus/src/getuid.dart';
import 'package:dbus/src/dbus_value.dart';

import 'dart:convert';
import 'dart:io';


void main() async {
  print('TEST new array of arrays DBus types');

  //type=iaayi
  var test_aay = [
    DBusInt32(42),
    DBusArray(DBusSignature('a'), [
      DBusArray(DBusSignature('y'), [DBusByte(88), DBusByte(88), DBusByte(88)])
    ]),
    DBusInt32(69),
  ];
  print('TEST Signature [iaayi]');
  dumpAsMessage(test_aay);

  //type = iaasi
  var test_aas = [
    DBusInt32(42),
    DBusArray(DBusSignature('a'), [
      DBusArray(DBusSignature('s'),
          [DBusString('XXX'), DBusString('YYY'), DBusString('ZZZ')])
    ]),
    DBusInt32(69),
  ];
  print('TEST Signature [iaasi]');
  dumpAsMessage(test_aas);

  //type = iaayaasi
  var test_both = [
    DBusInt32(42),
    DBusArray(DBusSignature('a'), [
      DBusArray(DBusSignature('y'), [DBusByte(88), DBusByte(88), DBusByte(88)]),
    ]),
    DBusArray(DBusSignature('a'), [
      DBusArray(DBusSignature('s'),
          [DBusString('XXX'), DBusString('YYY'), DBusString('ZZZ')])
    ]),
    DBusInt32(69),
  ];
  print('TEST Signature [iaayaasi]');
  dumpAsMessage(test_both);

  // type=iasi
  var test_str_only = [
    DBusInt32(42),
    DBusString('XXX'),
    DBusInt32(69),
  ];
  print('TEST Signature [isi]');
  dumpAsMessage(test_str_only);

  // type=ias
  var test_str_no_trailing = [
    DBusInt32(42),
    DBusString('XXX'),
  ];
  print('TEST Signature [is]');
  dumpAsMessage(test_str_no_trailing);


  var test_fail = [
    DBusInt32(42),
    DBusArray(DBusSignature('a'), [
      DBusArray(DBusSignature('y'), [DBusByte(88), DBusByte(88), DBusByte(88)]),
      DBusArray(DBusSignature('y'), [DBusByte(99), DBusByte(99), DBusByte(99)]),
    ]),
  ];
  print('TEST Signature [iaay]');
  dumpAsMessage(test_fail);

  print('DONE\n');
}

void dumpAsMessage(List<DBusValue> valArr) {
  print('++++Test fake message with values\n');
  DBusMessage fakeMsg = DBusMessage(
    DBusMessageType.methodCall,
    path: null,
    interface:null,
    member:null,
    errorName:null,
    replySerial:null,
    destination: null,
    sender: null,
    values: valArr,
  );

  DBusWriteBuffer dbwb = DBusWriteBuffer();
  dbwb.writeMessage(fakeMsg);

  print('    ++++Fake message with values\n'+fakeMsg.toString());
  print('    ++++RAW fake message bytes\n${dbwb.data}');
  //dbwb.data.forEach((b)=> print(b.runtimeType.toString()+' => '+b.toString()));
  print('++++DONE Test fake message with values');
}
