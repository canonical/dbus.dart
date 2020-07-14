[![Pub Package](https://img.shields.io/pub/v/dbus_client.svg)](https://pub.dev/packages/dbus_client)

A native Dart client implementation of [D-Bus](https://www.freedesktop.org/wiki/Software/dbus/).

## Example

```dart
import 'package:dbus_client/dbus_client.dart';

var client = DBusClient.system();
await client.connect();
var result = await client.getProperty(
    destination: 'org.freedesktop.hostname1',
    path: '/org/freedesktop/hostname1',
    interface: 'org.freedesktop.hostname1',
    name: 'Hostname');
var hostname = (result.value as DBusString).value;
print("hostname: ${hostname}");
```
