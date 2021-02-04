import 'dart:io';

import 'dbus_introspect.dart';
import 'dbus_method_response.dart';
import 'dbus_value.dart';

/// Returns introspection data for the org.freedesktop.DBus.Peer interface.
DBusIntrospectInterface introspectPeer() {
  final getMachineIdMethod = DBusIntrospectMethod('GetMachineId', args: [
    DBusIntrospectArgument(
        'machine_uuid', DBusSignature('s'), DBusArgumentDirection.out)
  ]);
  final pingMethod = DBusIntrospectMethod('Ping');
  final peer = DBusIntrospectInterface('org.freedesktop.DBus.Peer',
      methods: [getMachineIdMethod, pingMethod]);
  return peer;
}

/// Handles method calls on the org.freedesktop.DBus.Peer interface.
Future<DBusMethodResponse> handlePeerMethodCall(
    String? member, List<DBusValue>? values) async {
  if (member == 'GetMachineId') {
    if (values!.isNotEmpty) {
      return DBusMethodErrorResponse.invalidArgs();
    }
    final machineId = await _getMachineId();
    return DBusMethodSuccessResponse([DBusString(machineId)]);
  } else if (member == 'Ping') {
    if (values!.isNotEmpty) {
      return DBusMethodErrorResponse.invalidArgs();
    }
    return DBusMethodSuccessResponse();
  } else {
    return DBusMethodErrorResponse.unknownMethod();
  }
}

/// Returns the unique ID for this machine.
Future<String> _getMachineId() async {
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
