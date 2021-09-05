import 'package:dbus/dbus.dart';

void main() async {
  var client = DBusClient.session();
  var object = DBusRemoteObject(client,
      name: 'org.freedesktop.Notifications',
      path: DBusObjectPath('/org/freedesktop/Notifications'));
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
  try {
    var result = await object.callMethod(
        'org.freedesktop.Notifications', 'Notify', values,
        replySignature: DBusSignature('u'));
    var id = result.returnValues[0];
    print('notify ${id.toNative()}');
  } on DBusServiceUnknownException {
    print('Notification service not available');
  }
  await client.close();
}
