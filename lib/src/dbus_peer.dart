import 'dart:io';

import 'dbus_client.dart';
import 'dbus_value.dart';

/// Handles method calls on the org.freedesktop.DBus.Peer interface.
Future<DBusMethodResponse> handlePeerMethodCall(
    String member, List<DBusValue> values) async {
  if (member == 'GetMachineId') {
    final machineId = await _getMachineId();
    return DBusMethodSuccessResponse([DBusString(machineId)]);
  } else if (member == 'Ping') {
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
  if (machineId == '') machineId = await readFirstLine('/etc/machine-id');

  return machineId;
}
