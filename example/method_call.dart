import 'dbus_client.dart';

// Test with:
// $ gdbus call --session --dest com.canonical.DBusDart --object-path / --method com.canonical.DBusDart.Test

main() async {
  var client = DBusClient.session();
  await client.connect();
  await client.requestName('com.canonical.DBusDart');
  client.listenMethod('com.canonical.DBusDart',
      (String path, String interface, String member, List<DBusValue> values) {
    if (member == 'Test') return [new DBusString('Hello World!')];
  });
}
