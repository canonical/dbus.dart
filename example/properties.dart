import 'package:dbus/dbus.dart';

void main() async {
  var client = DBusClient.system();
  var object = DBusRemoteObject(client, 'org.freedesktop.NetworkManager',
      DBusObjectPath('/org/freedesktop/NetworkManager'));
  var properties =
      await object.getAllProperties('org.freedesktop.NetworkManager');
  properties.forEach((name, value) {
    print('${name}: ${value}');
  });

  print('');
  print('Hardware addresses:');
  var devicePaths = (properties['Devices'] as DBusArray).children;
  for (var path in devicePaths) {
    var device =
        DBusRemoteObject(client, 'org.freedesktop.NetworkManager', path);
    var value = await device.getProperty(
        'org.freedesktop.NetworkManager.Device', 'HwAddress');
    var address = (value as DBusString).value;
    print('${address}');
  }

  await client.close();
}
