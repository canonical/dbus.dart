import 'package:dbus_client/dbus_client.dart';
import 'dart:collection';

main() async {
  var client = DBusClient.session();
  await client.connect();
  var proxy = DBusObjectProxy(client, 'org.freedesktop.Notifications',
      '/org/freedesktop/Notifications');
  var values = [
    new DBusString(''), // App name
    new DBusUint32(0), // Replaces
    new DBusString(''), // Icon
    new DBusString('Hello World!'), // Summary
    new DBusString(''), // Body
    new DBusArray(new DBusSignature('s'), []), // Actions
    new DBusDict(new DBusSignature('s'), new DBusSignature('v'),
        LinkedHashMap<DBusValue, DBusValue>()), // Hints
    new DBusInt32(-1), // Expire timeout
  ];
  var result =
      await proxy.callMethod('org.freedesktop.Notifications', 'Notify', values);
  var id = (result[0] as DBusUint32).value;
  print('notify ${id}');
  await client.disconnect();
}
