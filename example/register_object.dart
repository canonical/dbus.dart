import 'package:dbus/dbus.dart';

// Test with:
// $ gdbus call --session --dest com.canonical.DBusDart --object-path /com/canonical/DBusDart --method com.canonical.DBusDart.Test

class TestObject extends DBusObject {
  @override
  List<DBusIntrospectInterface> introspect() {
    final testMethod = DBusIntrospectMethod('Test');
    return [
      DBusIntrospectInterface('com.canonical.DBusDart', methods: [testMethod])
    ];
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(
      String interface, String member, List<DBusValue> values) async {
    if (member == 'Test') {
      return DBusMethodSuccessResponse([DBusString('Hello World!')]);
    } else {
      return DBusMethodErrorResponse.unknownMethod();
    }
  }
}

void main() async {
  var client = DBusClient.session();
  await client.connect();
  await client.requestName('com.canonical.DBusDart');
  client.registerObject('/com/canonical/DBusDart', TestObject());
}
