import 'package:dbus/dbus.dart';

// Test with:
// $ gdbus call --session --dest com.canonical.DBusDart --object-path /com/canonical/DBusDart --method com.canonical.DBusDart.Test

class TestObject extends DBusObject {
  var callCount = 0;

  TestObject() : super(DBusObjectPath('/com/canonical/DBusDart'));

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
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != 'com.canonical.DBusDart') {
      return DBusMethodErrorResponse.unknownInterface();
    }

    if (methodCall.name == 'Test') {
      callCount++;
      return DBusMethodSuccessResponse([DBusString('Hello World!')]);
    } else {
      return DBusMethodErrorResponse.unknownMethod();
    }
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    if (interface != 'com.canonical.DBusDart') {
      return DBusMethodErrorResponse.unknownInterface();
    }

    if (name == 'Count') {
      return DBusGetPropertyResponse(DBusInt64(callCount));
    } else {
      return DBusMethodErrorResponse.unknownProperty();
    }
  }

  @override
  Future<DBusMethodResponse> setProperty(
      String interface, String name, DBusValue value) async {
    if (interface != 'com.canonical.DBusDart') {
      return DBusMethodErrorResponse.unknownInterface();
    }

    if (name == 'Count') {
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
  await client.registerObject(TestObject());
}
