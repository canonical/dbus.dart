import 'dbus_introspect.dart';
import 'dbus_method_call.dart';
import 'dbus_method_response.dart';
import 'dbus_object.dart';
import 'dbus_object_tree.dart';
import 'dbus_value.dart';

Map<String, Map<String, DBusValue>> expandObjectInterfaceAndProperties(
    DBusObject object,
    {bool introspectable = true}) {
  var interfacesAndProperties = <String, Map<String, DBusValue>>{};

  // Start with the standard interfaces.
  if (introspectable) {
    interfacesAndProperties['org.freedesktop.DBus.Introspectable'] = {};
  }
  interfacesAndProperties['org.freedesktop.DBus.Properties'] = {};

  // Add the interfaces the user has defined (overwriting the above if necessary).
  interfacesAndProperties.addAll(object.interfacesAndProperties);

  return interfacesAndProperties;
}

/// Returns introspection data for the org.freedesktop.DBus.ObjectManager interface.
DBusIntrospectInterface introspectObjectManager() {
  final introspectMethod = DBusIntrospectMethod('GetManagedObjects', args: [
    DBusIntrospectArgument(
        DBusSignature('a{oa{sa{sv}}}'), DBusArgumentDirection.out,
        name: 'objpath_interfaces_and_properties')
  ]);
  final interfacesAddedSignal = DBusIntrospectSignal('InterfacesAdded', args: [
    DBusIntrospectArgument(DBusSignature('o'), DBusArgumentDirection.out,
        name: 'object_path'),
    DBusIntrospectArgument(
        DBusSignature('a{sa{sv}}'), DBusArgumentDirection.out,
        name: 'interfaces_and_properties')
  ]);
  final interfacesRemovedSignal =
      DBusIntrospectSignal('InterfacesRemoved', args: [
    DBusIntrospectArgument(DBusSignature('o'), DBusArgumentDirection.out,
        name: 'object_path'),
    DBusIntrospectArgument(DBusSignature('as'), DBusArgumentDirection.out,
        name: 'interfaces')
  ]);
  final introspectable = DBusIntrospectInterface(
      'org.freedesktop.DBus.ObjectManager',
      methods: [introspectMethod],
      signals: [interfacesAddedSignal, interfacesRemovedSignal]);
  return introspectable;
}

/// Handles method calls on the org.freedesktop.DBus.ObjectManager interface.
DBusMethodResponse handleObjectManagerMethodCall(
    DBusObjectTree objectTree, DBusMethodCall methodCall,
    {bool introspectable = true}) {
  if (methodCall.name == 'GetManagedObjects') {
    var objpathInterfacesAndProperties = <DBusObjectPath, DBusValue>{};
    void addObjects(DBusObjectTreeNode node) {
      var object = node.object;
      if (object != null && !object.isObjectManager) {
        DBusValue encodeProperties(Map<String, DBusValue> properties) =>
            DBusDict.stringVariant(properties);
        DBusValue encodeInterfacesAndProperties(
                Map<String, Map<String, DBusValue>> interfacesAndProperties) =>
            DBusDict(
                DBusSignature('s'),
                DBusSignature('a{sv}'),
                interfacesAndProperties.map<DBusValue, DBusValue>((name,
                        properties) =>
                    MapEntry(DBusString(name), encodeProperties(properties))));

        objpathInterfacesAndProperties[object.path] =
            encodeInterfacesAndProperties(expandObjectInterfaceAndProperties(
                object,
                introspectable: introspectable));
      }
      for (var childNode in node.children.values) {
        addObjects(childNode);
      }
    }

    addObjects(objectTree.root);

    return DBusMethodSuccessResponse([
      DBusDict(DBusSignature('o'), DBusSignature('a{sa{sv}}'),
          objpathInterfacesAndProperties)
    ]);
  } else {
    return DBusMethodErrorResponse.unknownMethod();
  }
}
