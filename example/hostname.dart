import 'package:dbus/dbus.dart';

void main() async {
  var client = DBusClient.system();
  var object = DBusRemoteObject(client, 'org.freedesktop.hostname1',
      DBusObjectPath('/org/freedesktop/hostname1'));
  var hostname =
      await (object.getProperty('org.freedesktop.hostname1', 'Hostname') as Future<DBusValue>);
  print('hostname: ${hostname.toNative()}');
  await client.close();
}
