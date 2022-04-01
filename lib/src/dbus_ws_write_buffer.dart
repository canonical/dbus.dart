import 'dart:convert';
import 'dart:typed_data';

import 'dbus_buffer.dart';
import 'dbus_ws_message.dart';
import 'dbus_value.dart';
import 'dbus_value_ws_ext.dart';
import 'dart:convert';

/// Encodes DBus messages to Json data.
class DBusWSWriteBuffer {
  /// Data generated.
  Map<String,dynamic> _data = {};

  String get data { 
    return "invoke:"+json.encode(_data);
  }

  /// Writes a [DBusMessage] to the buffer.
  void writeMessage(DBusWSMessage message) {
    _data["id"] = { "serial": message.serial, "signature": message.replySignature!.value };
    _data["destination"] = message.destination!.value;
    _data["path"] = message.path!.value;
    _data["interface"] = message.interface!.value;
    _data["member"] = message.member!.value;

    final body = <dynamic> [];
    for (var value in message.values) {
      body.add(value.toJson());
    }

    if (body.length > 0) {
      _data["body"] = body;
      _data["signature"] = message.signature.value;
    }

    // print("> writeMesage:$_data");
    // print("> writeMesage:$data");
  }
}
