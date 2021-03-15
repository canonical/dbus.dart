import 'package:dbus/dbus.dart';

void main() async {
  var server = DBusServer();
  var address = await server.listenUnixSocket();
  print('Listening on $address');
}
