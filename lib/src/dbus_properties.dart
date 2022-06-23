import 'dbus_introspect.dart';
import 'dbus_method_call.dart';
import 'dbus_method_response.dart';
import 'dbus_object.dart';
import 'dbus_value.dart';

/// Returns introspection data for the org.freedesktop.DBus.Properties interface.
DBusIntrospectInterface introspectProperties() {
  final getMethod = DBusIntrospectMethod('Get', args: [
    DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_,
        name: 'interface_name'),
    DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_,
        name: 'property_name'),
    DBusIntrospectArgument(DBusSignature('v'), DBusArgumentDirection.out,
        name: 'value'),
  ]);
  final setMethod = DBusIntrospectMethod('Set', args: [
    DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_,
        name: 'interface_name'),
    DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_,
        name: 'property_name'),
    DBusIntrospectArgument(DBusSignature('v'), DBusArgumentDirection.in_,
        name: 'value'),
  ]);
  final getAllMethod = DBusIntrospectMethod('GetAll', args: [
    DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_,
        name: 'interface_name'),
    DBusIntrospectArgument(DBusSignature('a{sv}'), DBusArgumentDirection.out,
        name: 'props'),
  ]);
  final propertiesChangedSignal =
      DBusIntrospectSignal('PropertiesChanged', args: [
    DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out,
        name: 'interface_name'),
    DBusIntrospectArgument(DBusSignature('a{sv}'), DBusArgumentDirection.out,
        name: 'changed_properties'),
    DBusIntrospectArgument(DBusSignature('as'), DBusArgumentDirection.out,
        name: 'invalidated_properties')
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
    var interfaceName = methodCall.values[0].asString();
    var propertyName = methodCall.values[1].asString();
    return await object.getProperty(interfaceName, propertyName);
  } else if (methodCall.name == 'Set') {
    if (methodCall.signature != DBusSignature('ssv')) {
      return DBusMethodErrorResponse.invalidArgs();
    }
    var interfaceName = methodCall.values[0].asString();
    var propertyName = methodCall.values[1].asString();
    var value = methodCall.values[2].asVariant();
    return await object.setProperty(interfaceName, propertyName, value);
  } else if (methodCall.name == 'GetAll') {
    if (methodCall.signature != DBusSignature('s')) {
      return DBusMethodErrorResponse.invalidArgs();
    }
    var interfaceName = methodCall.values[0].asString();
    return await object.getAllProperties(interfaceName);
  } else {
    return DBusMethodErrorResponse.unknownMethod();
  }
}
