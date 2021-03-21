import 'dart:io';

import 'package:dbus/dbus.dart';

void main() async {
  var server = DBusServer();
  var address =
      await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
  print('Listening on $address');
}
