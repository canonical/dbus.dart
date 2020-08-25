import 'package:dbus/dbus.dart';

void main() async {
  var client = DBusClient.system();
  var object = DBusRemoteObject(client, 'org.freedesktop.NetworkManager',
      DBusObjectPath('/org/freedesktop'));

  await object.subscribeObjectManagerSignals(
      interfacesAddedCallback: interfacesAdded,
      interfacesRemovedCallback: interfacesRemoved,
      propertiesChangedCallback: propertiesChanged);

  var objects = await object.getManagedObjects();
  objects.forEach((objectPath, interfacesAndProperties) {
    print('${objectPath.value}');
    printInterfacesAndProperties(interfacesAndProperties);
  });
}

void interfacesAdded(DBusObjectPath objectPath,
    Map<String, Map<String, DBusValue>> interfacesAndProperties) {
  print('${objectPath.value}');
  printInterfacesAndProperties(interfacesAndProperties);
}

void interfacesRemoved(DBusObjectPath objectPath, List<String> interfaces) {
  for (var interface in interfaces) {
    print('${objectPath.value} removed interfaces ${interface}');
  }
}

void propertiesChanged(
    DBusObjectPath objectPath,
    String interfaceName,
    Map<String, DBusValue> changedProperties,
    List<String> invalidatedProperties) {
  print('${objectPath.value}');
  printInterfacesAndProperties({interfaceName: changedProperties});
}

void printInterfacesAndProperties(
    Map<String, Map<String, DBusValue>> interfacesAndProperties) {
  interfacesAndProperties.forEach((interface, properties) {
    print('  ${interface}');
    properties.forEach((name, value) {
      print('    ${name}: ${value.toNative()}');
    });
  });
}
