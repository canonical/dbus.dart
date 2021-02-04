import 'dbus_introspect.dart';
import 'dbus_method_response.dart';
import 'dbus_object_tree.dart';
import 'dbus_value.dart';

/// Returns introspection data for the org.freedesktop.DBus.Properties interface.
DBusIntrospectInterface introspectProperties() {
  final getMethod = DBusIntrospectMethod('Get', args: [
    DBusIntrospectArgument(
        'interface_name', DBusSignature('s'), DBusArgumentDirection.in_),
    DBusIntrospectArgument(
        'property_name', DBusSignature('s'), DBusArgumentDirection.in_),
    DBusIntrospectArgument(
        'value', DBusSignature('v'), DBusArgumentDirection.out),
  ]);
  final setMethod = DBusIntrospectMethod('Set', args: [
    DBusIntrospectArgument(
        'interface_name', DBusSignature('s'), DBusArgumentDirection.in_),
    DBusIntrospectArgument(
        'property_name', DBusSignature('s'), DBusArgumentDirection.in_),
    DBusIntrospectArgument(
        'value', DBusSignature('v'), DBusArgumentDirection.in_),
  ]);
  final getAllMethod = DBusIntrospectMethod('GetAll', args: [
    DBusIntrospectArgument(
        'interface_name', DBusSignature('s'), DBusArgumentDirection.in_),
    DBusIntrospectArgument(
        'props', DBusSignature('a{sv}'), DBusArgumentDirection.out),
  ]);
  final introspectable = DBusIntrospectInterface(
      'org.freedesktop.DBus.Properties',
      methods: [getMethod, setMethod, getAllMethod]);
  return introspectable;
}

/// Handles method calls on the org.freedesktop.DBus.Properties interface.
Future<DBusMethodResponse> handlePropertiesMethodCall(DBusObjectTree objectTree,
    DBusObjectPath? path, String? member, List<DBusValue>? values) async {
  if (member == 'Get') {
    var node = objectTree.lookup(path!);
    if (node == null || node.object == null) {
      return DBusMethodErrorResponse.unknownObject();
    }
    if (values!.length != 2 ||
        values[0].signature != DBusSignature('s') ||
        values[1].signature != DBusSignature('s')) {
      return DBusMethodErrorResponse.invalidArgs();
    }
    var interfaceName = (values[0] as DBusString).value;
    var propertyName = (values[1] as DBusString).value;
    return await node.object!.getProperty(interfaceName, propertyName);
  } else if (member == 'Set') {
    var node = objectTree.lookup(path!);
    if (node == null || node.object == null) {
      return DBusMethodErrorResponse.unknownObject();
    }
    if (values!.length != 3 ||
        values[0].signature != DBusSignature('s') ||
        values[1].signature != DBusSignature('s') ||
        values[2].signature != DBusSignature('v')) {
      return DBusMethodErrorResponse.invalidArgs();
    }
    var interfaceName = (values[0] as DBusString).value;
    var propertyName = (values[1] as DBusString).value;
    var value = (values[2] as DBusVariant).value;
    return await node.object!.setProperty(interfaceName, propertyName, value);
  } else if (member == 'GetAll') {
    var node = objectTree.lookup(path!);
    if (node == null || node.object == null) {
      return DBusMethodErrorResponse.unknownObject();
    }
    if (values!.length != 1 || values[0].signature != DBusSignature('s')) {
      return DBusMethodErrorResponse.invalidArgs();
    }
    var interfaceName = (values[0] as DBusString).value;
    return await node.object!.getAllProperties(interfaceName);
  } else {
    return DBusMethodErrorResponse.unknownMethod();
  }
}
