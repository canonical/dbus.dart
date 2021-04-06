import 'dbus_introspect.dart';
import 'dbus_method_call.dart';
import 'dbus_method_response.dart';
import 'dbus_object.dart';
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
  final propertiesChangedSignal =
      DBusIntrospectSignal('PropertiesChanged', args: [
    DBusIntrospectArgument(
        'interface_name', DBusSignature('s'), DBusArgumentDirection.out),
    DBusIntrospectArgument('changed_properties', DBusSignature('a{sv}'),
        DBusArgumentDirection.out),
    DBusIntrospectArgument('invalidated_properties', DBusSignature('as'),
        DBusArgumentDirection.out)
  ]);
  final introspectable = DBusIntrospectInterface(
      'org.freedesktop.DBus.Properties',
      methods: [getMethod, setMethod, getAllMethod],
      signals: [propertiesChangedSignal]);
  return introspectable;
}

/// Handles method calls on the org.freedesktop.DBus.Properties interface.
Future<DBusMethodResponse> handlePropertiesMethodCall(
    DBusObject object, DBusMethodCall methodCall) async {
  if (methodCall.name == 'Get') {
    if (methodCall.signature != DBusSignature('ss')) {
      return DBusMethodErrorResponse.invalidArgs();
    }
    var interfaceName = (methodCall.values[0] as DBusString).value;
    var propertyName = (methodCall.values[1] as DBusString).value;
    return await object.getProperty(interfaceName, propertyName);
  } else if (methodCall.name == 'Set') {
    if (methodCall.signature != DBusSignature('ssv')) {
      return DBusMethodErrorResponse.invalidArgs();
    }
    var interfaceName = (methodCall.values[0] as DBusString).value;
    var propertyName = (methodCall.values[1] as DBusString).value;
    var value = (methodCall.values[2] as DBusVariant).value;
    return await object.setProperty(interfaceName, propertyName, value);
  } else if (methodCall.name == 'GetAll') {
    if (methodCall.signature != DBusSignature('s')) {
      return DBusMethodErrorResponse.invalidArgs();
    }
    var interfaceName = (methodCall.values[0] as DBusString).value;
    return await object.getAllProperties(interfaceName);
  } else {
    return DBusMethodErrorResponse.unknownMethod();
  }
}
