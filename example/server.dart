import 'package:dbus/dbus.dart';

void main() async {
  var server = DBusServer();
  const socketName = '/tmp/test-dbus-server';
  await server.listenUnixSocket(socketName);
  print('Listening on unix:path=$socketName');
}
