import 'package:dbus/dbus.dart';

Future<void> acquireName(
    DBusClient client, String name, Set<DBusRequestNameFlag> flags) async {
  var result = await client.requestName(name, flags: flags);
  switch (result) {
    case DBusRequestNameReply.primaryOwner:
      print('Now the owner of name $name');
      break;
    case DBusRequestNameReply.inQueue:
      print('In queue to own name $name');
      break;
    case DBusRequestNameReply.exists:
      print('Unable to own name $name, already in use');
      break;
    case DBusRequestNameReply.alreadyOwner:
      print('Already the owner of name $name');
      break;
  }
}

void main() async {
  var client = DBusClient.session();
  client.nameAcquired.listen((name) => print('Acquired name $name'));
  client.nameLost.listen((name) => print('Lost name $name'));
  await acquireName(client, 'com.canonical.DBusDart1', {});
  await acquireName(client, 'com.canonical.DBusDart2',
      {DBusRequestNameFlag.allowReplacement});
  await acquireName(
      client, 'com.canonical.DBusDart3', {DBusRequestNameFlag.replaceExisting});
  await acquireName(client, 'com.canonical.DBusDart4', {
    DBusRequestNameFlag.allowReplacement,
    DBusRequestNameFlag.replaceExisting
  });

  print('Currently own names: ${client.ownedNames}');
}
