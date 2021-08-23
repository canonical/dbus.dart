import 'package:dbus/dbus.dart';

void main() async {
  var client = DBusClient.system();
  var object = DBusRemoteObject(client,
      name: 'org.freedesktop.hostname1',
      path: DBusObjectPath('/org/freedesktop/hostname1'));
  var hostname =
      await object.getProperty('org.freedesktop.hostname1', 'Hostname');
  print('hostname: ${hostname.toNative()}');
  await client.close();
}
