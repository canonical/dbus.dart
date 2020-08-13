import 'package:dbus/dbus.dart';

// Test with:
// $ gdbus call --session --dest com.canonical.DBusDart --object-path /com/canonical/DBusDart --method com.canonical.DBusDart.Test

class TestObject extends DBusObject {
  var callCount = 0;

  @override
  DBusObjectPath get path {
    return DBusObjectPath('/com/canonical/DBusDart');
  }

  @override
  List<DBusIntrospectInterface> introspect() {
    final testMethod = DBusIntrospectMethod('Test');
    final countProperty = DBusIntrospectProperty('Count', DBusSignature('x'),
        access: DBusPropertyAccess.read);
    return [
      DBusIntrospectInterface('com.canonical.DBusDart',
          methods: [testMethod], properties: [countProperty])
    ];
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(
      String interface, String member, List<DBusValue> values) async {
    if (interface != 'com.canonical.DBusDart') {
      return DBusMethodErrorResponse.unknownInterface();
    }

    if (member == 'Test') {
      callCount++;
      return DBusMethodSuccessResponse([DBusString('Hello World!')]);
    } else {
      return DBusMethodErrorResponse.unknownMethod();
    }
  }

  @override
  Future<DBusMethodResponse> getProperty(
      String interface, String member) async {
    if (interface != 'com.canonical.DBusDart') {
      return DBusMethodErrorResponse.unknownInterface();
    }

    if (member == 'Count') {
      return DBusGetPropertyResponse(DBusInt64(callCount));
    } else {
      return DBusMethodErrorResponse.unknownProperty();
    }
  }

  @override
  Future<DBusMethodResponse> setProperty(
      String interface, String member, DBusValue value) async {
    if (interface != 'com.canonical.DBusDart') {
      return DBusMethodErrorResponse.unknownInterface();
    }

    if (member == 'Count') {
      return DBusMethodErrorResponse.propertyReadOnly();
    } else {
      return DBusMethodErrorResponse.unknownProperty();
    }
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    if (interface != 'com.canonical.DBusDart') {
      return DBusMethodErrorResponse.unknownInterface();
    }

    return DBusGetAllPropertiesResponse({'Count': DBusInt64(callCount)});
  }
}

void main() async {
  var client = DBusClient.session();
  await client.requestName('com.canonical.DBusDart');
  client.registerObject(TestObject());
}
