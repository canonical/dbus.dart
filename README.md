[![Pub Package](https://img.shields.io/pub/v/dbus.svg)](https://pub.dev/packages/dbus)

A native Dart client implementation of [D-Bus](https://www.freedesktop.org/wiki/Software/dbus/).

## Accessing a remote object

```dart
import 'package:dbus/dbus.dart';

var client = DBusClient.system();
await client.connect();
var proxy = DBusObjectProxy(client, 'org.freedesktop.hostname1', '/org/freedesktop/hostname1');
var result = await proxy.getProperty('org.freedesktop.hostname1', 'Hostname');
var hostname = (result as DBusString).value;
print('hostname: ${hostname}');
await client.disconnect();
```

### Exporting an object on the bus

```dart
import 'package:dbus/dbus.dart';

class TestObject extends DBusObject {
  @override
  Future<MethodResponse> handleMethodCall(String interface, String member, List<DBusValue> values) async {
    if (interface == 'com.example.Test') {
      if (member == 'Test') {
        return DBusMethodSuccessResponse([DBusString('Hello World!')]);
      } else {
        return DBusMethodErrorResponse.unknownMethod();
      }
    } else {
      return DBusMethodErrorResponse.unknownInterface();
    }
  }
}

var client = DBusClient.session();
await client.connect();
client.registerObject('/com/example/Test', TestObject());
```
