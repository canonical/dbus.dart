import 'package:dbus_client/dbus_client.dart';

main() async {
  var client = DBusClient.session();
  await client.connect();
  var values = [
    new DBusString(''), // App name
    new DBusUint32(0), // Replaces
    new DBusString(''), // Icon
    new DBusString('Hello World!'), // Summary
    new DBusString(''), // Body
    new DBusArray(new DBusSignature('s')), // Actions
    new DBusDict(new DBusSignature('s'), new DBusSignature('v')), // Hints
    new DBusInt32(-1), // Expire timeout
  ];
  var result = await client.callMethod(
      destination: 'org.freedesktop.Notifications',
      path: '/org/freedesktop/Notifications',
      interface: 'org.freedesktop.Notifications',
      member: 'Notify',
      values: values);
  var id = (result[0] as DBusUint32).value;
  print('notify ${id}');
}
