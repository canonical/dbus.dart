import 'package:dbus/dbus.dart';

void main() async {
  var client = DBusClient.session();
  var object = DBusRemoteObject(client, 'org.freedesktop.Notifications',
      DBusObjectPath('/org/freedesktop/Notifications'));
  var values = [
    DBusString(''), // App name
    DBusUint32(0), // Replaces
    DBusString(''), // Icon
    DBusString('Hello World!'), // Summary
    DBusString(''), // Body
    DBusArray(DBusSignature('s')), // Actions
    DBusDict(DBusSignature('s'), DBusSignature('v')), // Hints
    DBusInt32(-1), // Expire timeout
  ];
  var result = await object.callMethod(
      'org.freedesktop.Notifications', 'Notify', values);
  var id = result.returnValues[0];
  print('notify ${id.toNative()}');
  await client.close();
}
