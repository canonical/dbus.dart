import 'dart:convert';
import 'dart:typed_data';

import 'dbus_buffer.dart';
import 'dbus_bus_name.dart';
import 'dbus_error_name.dart';
import 'dbus_interface_name.dart';
import 'dbus_member_name.dart';
import 'dbus_message.dart';
import 'dbus_value.dart';

/// Decodes DBus messages from binary data.
class DBusWSReadBuffer {
  /// Json data in the buffer.
  String _responseData = "";

  void setResponseData(String responsedata) {
    _responseData = responsedata;
  }

  /// Reads a D-Bus message from the buffer or returns null if not enough data.
  DBusMessage? readMessage() {
    Map<String,dynamic> jsonResult = {};

    var type;
    var serial;

    if (_responseData.startsWith("invoke:")) {
      // print("> readMessage ${_responseData}");
      jsonResult = json.decode(_responseData.substring("invoke:".length));
      serial = jsonResult['id']['serial'];

      if (jsonResult['result']!=null) {
        type = DBusMessageType.methodReturn;
      } else if (jsonResult['error']!=null) {
        type = DBusMessageType.error;
      }
      // print("> readMessage type: $type, jr: $jsonResult");
    } else if (_responseData.startsWith("addMatch:")) {
      if (jsonResult['result']!=null) {
        type = DBusMessageType.methodReturn;
      } else if (jsonResult['error']!=null) {
        type = DBusMessageType.error;
      }
      serial = jsonResult['id'];
      // print("> readMessage (addMatch) type: $type jr: ${_responseData}");
    } else if (_responseData.startsWith("signal:")) {
      type = DBusMessageType.signal;
      jsonResult = json.decode(_responseData.substring("signal:".length));
      serial = jsonResult['serial'];
      // print("> readMessage type $type, jr: $jsonResult");
    } 

    // var type = {
    //   1: DBusMessageType.methodCall,
    //   2: DBusMessageType.methodReturn,
    //   3: DBusMessageType.error,
    //   4: DBusMessageType.signal
    // }[readDBusByte()!.value];

    if (type == null) {
      throw 'Invalid type received';
    }
    var flags = <DBusMessageFlag>{};
    if (jsonResult['flags']!=null) {
      var flagsValue = jsonResult['flags'];
      if (flagsValue & 0x01 != 0) {
        flags.add(DBusMessageFlag.noReplyExpected);
      }
      if (flagsValue & 0x02 != 0) {
        flags.add(DBusMessageFlag.noAutoStart);
      }
      if (flagsValue & 0x04 != 0) {
        flags.add(DBusMessageFlag.allowInteractiveAuthorization);
      }
    }

    DBusSignature? signature;
    DBusObjectPath? path;
    DBusInterfaceName? interface;
    DBusMemberName? member;
    DBusErrorName? errorName;
    int? replySerial;
    DBusBusName? destination;
    DBusBusName? sender;
    var fdCount = 0;

    if (jsonResult['path']!=null) {
      path = DBusObjectPath(jsonResult['path']);
    }
    if (jsonResult['interface']!=null) {
      interface = DBusInterfaceName(jsonResult['interface']);
    }
    if (jsonResult['member']!=null) {
      member = DBusMemberName(jsonResult['member']);
    }
    if (jsonResult['errorName']!=null) {
      errorName = DBusErrorName(jsonResult['errorName']);
    }
    if (jsonResult['destination']!=null) {
      destination = DBusBusName(jsonResult['destination']);
    }
    if (jsonResult['sender']!=null) {
      sender = DBusBusName(jsonResult['sender']);
      if (!(sender.value == 'org.freedesktop.DBus' || sender.isUnique)) {
        throw 'Sender contains non-unique bus name';
      }
    }

    var values = <DBusValue>[  ];
    var values_in_json  = null;

    if (type == DBusMessageType.methodReturn) {
      replySerial = jsonResult['id']['serial'];
      signature = DBusSignature(jsonResult['id']['signature']);
      values_in_json = jsonResult['result'];
    } else if (type == DBusMessageType.signal) {
      replySerial = jsonResult['id'];
      signature = DBusSignature(jsonResult['signature']);
      values_in_json = jsonResult['body'];
    } else if (type == DBusMessageType.error) {
      replySerial = jsonResult['id']['serial'];
      // for (var i in jsonResult['error']) {
      //   print(">>>>");
      //   print("$i");
      //   print("${i.runtimeType}");
      // }
      errorName = DBusErrorName.fromJson(jsonResult['error'][0]);
    }
    // print("> readMessage: signature: $signature");

    if (signature != null) {
      if (values_in_json!=null) {
        var signatures = signature.split();
        int idx = 0;
        assert(signatures.length == values_in_json.length);
        for (var s in signatures) {
          // print("> readMessage: signature $signature, idx: $idx, body@$idx ${values_in_json[idx]}");
          var value = readDBusValue(s, values_in_json[idx]);
          if (value == null) {
            return null;
          }
          values.add(value);
          idx++;
        }
      } else {
        throw 'Message has signature $signature but json body is null';
      }
    } else {
      if (values_in_json!=null && values_in_json.length != 0) {
        throw 'Message has no signature but contains data items of length ${values_in_json.length}';
      }
    }

    return DBusMessage(type,
        flags: flags,
        serial: serial,
        path: path,
        interface: interface,
        member: member,
        errorName: errorName,
        replySerial: replySerial,
        destination: destination,
        sender: sender,
        values: values);
  }

  /// Reads a [DBusByte] from the buffer or returns null if not enough data.
  DBusByte? readDBusByte(dynamic item) {
    return DBusByte(item as int);
  }

  /// Reads a [DBusBoolean] from the buffer or returns null if not enough data.
  DBusBoolean? readDBusBoolean(dynamic item) {
    return DBusBoolean((item as int)!= 0);
  }

  /// Reads a [DBusInt16] from the buffer or returns null if not enough data.
  DBusInt16? readDBusInt16(dynamic item) {
    return DBusInt16(item as int);
  }

  /// Reads a [DBusUint16] from the buffer or returns null if not enough data.
  DBusUint16? readDBusUint16(dynamic item) {
    return DBusUint16(item as int);
  }

  /// Reads a [DBusInt32] from the buffer or returns null if not enough data.
  DBusInt32? readDBusInt32(dynamic item) {
    return DBusInt32(item as int);
  }

  /// Reads a [DBusUint32] from the buffer or returns null if not enough data.
  DBusUint32? readDBusUint32(dynamic item) {
    return DBusUint32(item as int);
  }

  /// Reads a [DBusInt64] from the buffer or returns null if not enough data.
  DBusInt64? readDBusInt64(dynamic item) {
    return DBusInt64(item as int);
  }

  /// Reads a [DBusUint64] from the buffer or returns null if not enough data.
  DBusUint64? readDBusUint64(dynamic item) {
    return DBusUint64(item as int);
  }

  /// Reads a [DBusDouble] from the buffer or returns null if not enough data.
  DBusDouble? readDBusDouble(dynamic item) {
    return DBusDouble(item as double);
  }

  /// Reads a [DBusString] from the buffer or returns null if not enough data.
  DBusString? readDBusString(dynamic item) {
    return DBusString(item as String);
  }

  /// Reads a [DBusObjectPath] from the buffer or returns null if not enough data.
  DBusObjectPath? readDBusObjectPath(dynamic item) {
    if (item == null) {
      return null;
    }
    return DBusObjectPath(item as String);
  }

  /// Reads a [DBusSignature] from the buffer or returns null if not enough data.
  DBusSignature? readDBusSignature(dynamic item) {
    String signatureText = item as String;
    if (signatureText.contains('m')) {
      throw 'Signature contains reserved maybe type';
    }
    return DBusSignature(signatureText);
  }

  // yua{sv}
  // "result": [
  //   0,
  //   1,
  //   [
  //     [
  //       "macAddress",
  //       [ //begin: v
  //         [
  //           {
  //             "type": "s",
  //             "child": []
  //           }
  //         ],
  //         [
  //           "f0:b3:1e:21:c6:a5"
  //         ]
  //       ] //end: v
  //     ]
  //   ]
  // ]
  // v: [ 
  //      [ {type:'x', child: []} ],
  //      [ data ] 
  //    ]
  /// Reads a [DBusVariant] from the buffer or returns null if not enough data.
  DBusVariant? readDBusVariant(dynamic item) {
    //todo: this maybe incomplete (what is child?)
    List<dynamic> variant_in_json = item;

    var signature = readDBusSignature(variant_in_json[0][0]['type'] as String);
    if (signature == null) {
      return null;
    }

    var childValue = readDBusValue(signature, variant_in_json[1][0]);
    if (childValue == null) {
      return null;
    }

    return DBusVariant(childValue);
  }

  /// Reads a [DBusStruct] from the buffer or returns null if not enough data.
  DBusStruct? readDBusStruct(Iterable<DBusSignature> childSignatures, dynamic item) {
    var children = <DBusValue>[];
    var list = item as List<dynamic>;
    int i = 0;
    assert(children.length == list.length);
    // print("readDBusStruct: $childSignatures $item");
    for (var signature in childSignatures) {
      var child = readDBusValue(signature, list[i]);
      if (child == null) {
        return null;
      }
      children.add(child);
      i++;
    }

    return DBusStruct(children);
  }

  /// Reads a [DBusArray] from the buffer or returns null if not enough data.
  DBusArray? readDBusArray(DBusSignature childSignature, dynamic item) {
    var children = <DBusValue>[];
    for (var i in item as List<dynamic>) {
      var value = readDBusValue(childSignature, i);
      children.add(value!);
    }

    return DBusArray(childSignature, children);
  }

  DBusDict? readDBusDict(
      DBusSignature keySignature, DBusSignature valueSignature,
      dynamic item) {
    var children = <DBusValue, DBusValue>{};
    // print("readDBusDict: $keySignature $valueSignature $item");
    for (var i in item as List<dynamic>) {
      var l = i as List<dynamic>;
      var key = readDBusValue(keySignature, l[0]);
      var value = readDBusValue(valueSignature, l[1]);
      children[key!] = value!;
    }

    return DBusDict(keySignature, valueSignature, children);
  }

  /// Reads a [DBusValue] with [signature].
  DBusValue? readDBusValue(DBusSignature signature, dynamic item) {
    // print("readDBusValue signature: $signature item: $item");
    var s = signature.value;
    if (s == 'y') {
      return readDBusByte(item);
    } else if (s == 'b') {
      return readDBusBoolean(item);
    } else if (s == 'n') {
      return readDBusInt16(item);
    } else if (s == 'q') {
      return readDBusUint16(item);
    } else if (s == 'i') {
      return readDBusInt32(item);
    } else if (s == 'u') {
      return readDBusUint32(item);
    } else if (s == 'x') {
      return readDBusInt64(item);
    } else if (s == 't') {
      return readDBusUint64(item);
    } else if (s == 'd') {
      return readDBusDouble(item);
    } else if (s == 's') {
      return readDBusString(item);
    } else if (s == 'o') {
      return readDBusObjectPath(item);
    } else if (s == 'g') {
      return readDBusSignature(item);
    } else if (s == 'v') {
      return readDBusVariant(item);
    } else if (s == 'm') {
      throw 'D-Bus reserved maybe type not valid';
    } else if (s.startsWith('a{') && s.endsWith('}')) {
      var childSignature = DBusSignature(s.substring(2, s.length - 1));
      var signatures = childSignature.split();
      if (signatures.length != 2) {
        throw 'Invalid dict signature ${childSignature.value}';
      }
      var keySignature = signatures[0];
      var valueSignature = signatures[1];
      if (!keySignature.isBasic) {
        throw 'Invalid dict key signature ${keySignature.value}';
      }
      return readDBusDict(keySignature, valueSignature, item);
    } else if (s.startsWith('a')) {
      return readDBusArray(DBusSignature(s.substring(1, s.length)), item);
    } else if (s.startsWith('(') && s.endsWith(')')) {
      return readDBusStruct(
          DBusSignature(s.substring(1, s.length - 1)).split(), item);
    } else {
      throw "Unknown D-Bus data type '$s'";
    }
  }

  void flush() {
    _responseData = "";
  }

  @override
  String toString() {
    return "DBusReadBuffer('$_responseData')";
  }
}
