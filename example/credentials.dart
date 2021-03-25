import 'dart:math';

import 'package:dbus/dbus.dart';

void main() async {
  var client = DBusClient.system();
  var names = await client.listNames();
  var rows = [
    ['Name', 'PID', 'UID']
  ];
  for (var name in names) {
    var credentials = await client.getConnectionCredentials(name);
    rows.add([
      name,
      credentials.processId.toString(),
      credentials.unixUserId.toString()
    ]);
  }
  var rowLengths = [0, 0, 0];
  for (var row in rows) {
    for (var i = 0; i < row.length; i++) {
      rowLengths[i] = max(rowLengths[i], row[i].length);
    }
  }
  for (var row in rows) {
    print(
        '${row[0].padRight(rowLengths[0])} ${row[1].padLeft(rowLengths[1])} ${row[2].padLeft(rowLengths[2])}');
  }
  await client.close();
}
