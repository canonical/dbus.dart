import 'package:dbus/dbus.dart';

void main() async {
  var client = DBusClient.system();
  var object = DBusRemoteObjectManager(client,
      name: 'org.freedesktop.NetworkManager',
      path: DBusObjectPath('/org/freedesktop'));

  object.signals.listen((signal) {
    if (signal is DBusObjectManagerInterfacesAddedSignal) {
      print(signal.changedPath.value);
      printInterfacesAndProperties(signal.interfacesAndProperties);
    } else if (signal is DBusObjectManagerInterfacesRemovedSignal) {
      for (var interface in signal.interfaces) {
        print('${signal.changedPath.value} removed interfaces $interface');
      }
    } else if (signal is DBusPropertiesChangedSignal) {
      print(signal.path.value);
      printInterfacesAndProperties(
          {signal.propertiesInterface: signal.changedProperties});
    }
  });

  var objects = await object.getManagedObjects();
  objects.forEach((objectPath, interfacesAndProperties) {
    print(objectPath.value);
    printInterfacesAndProperties(interfacesAndProperties);
  });
}

void printInterfacesAndProperties(
    Map<String, Map<String, DBusValue>> interfacesAndProperties) {
  interfacesAndProperties.forEach((interface, properties) {
    print('  $interface');
    properties.forEach((name, value) {
      print('    $name: ${value.toNative()}');
    });
  });
}
