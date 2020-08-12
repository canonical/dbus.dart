import 'package:dbus/dbus.dart';

void main() async {
  var client = DBusClient.system();
  await client.connect();
  var proxy = DBusObjectProxy(client, 'org.freedesktop.hostname1',
      DBusObjectPath('/org/freedesktop/hostname1'));
  var result = await proxy.getProperty('org.freedesktop.hostname1', 'Hostname');
  var hostname = (result as DBusString).value;
  print('hostname: ${hostname}');
  await client.disconnect();
}
