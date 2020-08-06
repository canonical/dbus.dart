[![Pub Package](https://img.shields.io/pub/v/dbus.svg)](https://pub.dev/packages/dbus)

A native Dart client implementation of [D-Bus](https://www.freedesktop.org/wiki/Software/dbus/).

## Example

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
