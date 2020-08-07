import 'package:dbus_client/dbus_client.dart';

// Test with:
// $ gdbus call --session --dest com.canonical.DBusDart --object-path /com/canonical/DBusDart --method com.canonical.DBusDart.Test

void main() async {
  var client = DBusClient.session();
  await client.connect();
  await client.requestName('com.canonical.DBusDart');
  client.registerObject('/com/canonical/DBusDart');
  client.listenMethod('com.canonical.DBusDart', (String path, String interface,
      String member, List<DBusValue> values) async {
    if (member == 'Test') {
      return DBusMethodSuccessResponse([DBusString('Hello World!')]);
    } else {
      return DBusMethodErrorResponse.unknownMethod();
    }
  });
}
