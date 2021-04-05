import 'dbus_introspect.dart';
import 'dbus_method_call.dart';
import 'dbus_method_response.dart';
import 'dbus_object_manager.dart';
import 'dbus_object_tree.dart';
import 'dbus_peer.dart';
import 'dbus_properties.dart';
import 'dbus_value.dart';

/// Returns introspection data for the org.freedesktop.DBus.Introspectable interface.
DBusIntrospectInterface introspectIntrospectable() {
  final introspectMethod = DBusIntrospectMethod('Introspect', args: [
    DBusIntrospectArgument(
        'xml_data', DBusSignature('s'), DBusArgumentDirection.out)
  ]);
  final introspectable = DBusIntrospectInterface(
      'org.freedesktop.DBus.Introspectable',
      methods: [introspectMethod]);
  return introspectable;
}

/// Handles method calls on the org.freedesktop.DBus.Introspectable interface.
DBusMethodResponse handleIntrospectableMethodCall(
    DBusObjectTreeNode? node, DBusMethodCall methodCall) {
  if (methodCall.name == 'Introspect') {
    if (methodCall.signature != DBusSignature('')) {
      return DBusMethodErrorResponse.invalidArgs();
    }

    var interfaces = <DBusIntrospectInterface>[];
    var object = node?.object;
    if (object != null) {
      interfaces.add(introspectIntrospectable());
      interfaces.add(introspectPeer());
      interfaces.add(introspectProperties());
      if (object.isObjectManager) {
        interfaces.add(introspectObjectManager());
      }
      interfaces.addAll(object.introspect());
    }
    var children = <DBusIntrospectNode>[];
    if (node != null) {
      children
          .addAll(node.children.keys.map((name) => DBusIntrospectNode(name)));
    }
    var xml =
        DBusIntrospectNode(null, interfaces, children).toXml().toXmlString();
    return DBusMethodSuccessResponse([DBusString(xml)]);
  } else {
    return DBusMethodErrorResponse.unknownMethod();
  }
}
