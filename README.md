[![Pub Package](https://img.shields.io/pub/v/dbus.svg)](https://pub.dev/packages/dbus)

A native Dart client implementation of [D-Bus](https://www.freedesktop.org/wiki/Software/dbus/).

## Accessing a remote object using *dart-dbus*

The easist way to access an existing D-Bus service is to use *dart-dbus*
to generate a Dart object. Start with an D-Bus interface definition:

```xml
<node name="/org/freedesktop/hostname1">
  <interface name="org.freedesktop.hostname1">
    <property name="Hostname" type="s" access="read"/>
  </interface>
</node>
```

Use *dart-dbus* to generate a Dart source file:

```
$ dart-dbus generate-remote-object hostname1.xml -o hostname1.dart
```

You can then use the generated `hostname1.dart` to access that remote
object:

```dart
import 'package:dbus/dbus.dart';
import 'hostname1.dart';

var client = DBusClient.system();
var hostname1 = OrgFreeDesktopHostname1(client, 'org.freedesktop.hostname1');
var hostname = await hostname1.hostname;
print('hostname: ${hostname}')
await client.close();
```

## Accessing a remote object manually

You can access remote objects without using *dart-dbus* if you want.
This requires you to handle error cases yourself.
The equivalent of the above example is:

```dart
import 'package:dbus/dbus.dart';

var client = DBusClient.system();
var object = DBusRemoteObject(client, 'org.freedesktop.hostname1', DBusObjectPath('/org/freedesktop/hostname1'));
var hostname = await object.getProperty('org.freedesktop.hostname1', 'Hostname');
print('hostname: ${hostname.toNative()}');
await client.close();
```

## Exporting an object on the bus

```dart
import 'package:dbus/dbus.dart';

class TestObject extends DBusObject {
  @override
  DBusObjectPath get path {
    return DBusObjectPath('/com/example/Test');
  }

  @override
  Future<MethodResponse> handleMethodCall(String sender, String interface, String member, List<DBusValue> values) async {
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
client.registerObject(TestObject());
```
