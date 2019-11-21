import 'package:dbus_client/dbus_client.dart';

main() async {
  var client = DBusClient.system();
  await client.connect();
  var result = await client.getProperty(destination: 'org.freedesktop.hostname1',
                                        path: '/org/freedesktop/hostname1',
                                        interface: 'org.freedesktop.hostname1',
                                        name: 'Hostname');
  var hostname = (result.value as DBusString).value;
  print ("hostname: ${hostname}");
}
