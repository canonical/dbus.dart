import 'dart:io';

import 'dbus_introspect.dart';
import 'dbus_method_call.dart';
import 'dbus_method_response.dart';
import 'dbus_value.dart';

/// Returns introspection data for the org.freedesktop.DBus.Peer interface.
DBusIntrospectInterface introspectPeer() {
  final getMachineIdMethod = DBusIntrospectMethod('GetMachineId', args: [
    DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out,
        name: 'machine_uuid')
  ]);
  final pingMethod = DBusIntrospectMethod('Ping');
  final peer = DBusIntrospectInterface('org.freedesktop.DBus.Peer',
      methods: [getMachineIdMethod, pingMethod]);
  return peer;
}

/// Handles method calls on the org.freedesktop.DBus.Peer interface.
Future<DBusMethodResponse> handlePeerMethodCall(
    DBusMethodCall methodCall) async {
  if (methodCall.name == 'GetMachineId') {
    if (methodCall.signature != DBusSignature('')) {
      return DBusMethodErrorResponse.invalidArgs();
    }
    return DBusMethodSuccessResponse([DBusString(await getMachineId())]);
  } else if (methodCall.name == 'Ping') {
    if (methodCall.signature != DBusSignature('')) {
      return DBusMethodErrorResponse.invalidArgs();
    }
    return DBusMethodSuccessResponse();
  } else {
    return DBusMethodErrorResponse.unknownMethod();
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
