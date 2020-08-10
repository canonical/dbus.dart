import 'dbus_introspect.dart';
import 'dbus_method_response.dart';
import 'dbus_object_tree.dart';
import 'dbus_peer.dart';
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
DBusMethodResponse handleIntrospectableMethodCall(DBusObjectTree objectTree,
    DBusObjectPath path, String member, List<DBusValue> values) {
  if (member == 'Introspect') {
    var node = objectTree.lookup(path);
    var xml = '<node>';
    if (node != null && node.object != null) {
      var interfaces = <DBusIntrospectInterface>[];
      interfaces.add(introspectIntrospectable());
      interfaces.add(introspectPeer());
      interfaces.addAll(node.object.introspect());
      for (var interface in interfaces) {
        xml += '<interface name="${interface.name}">';
        for (var method in interface.methods) {
          xml += '<method name="${method.name}">';
          for (var arg in method.args) {
            xml += '<arg';
            if (arg.name != null) xml += ' name="${arg.name}"';
            xml += ' type="${arg.type.value}"';
            if (arg.direction == DBusArgumentDirection.in_) {
              xml += ' direction="in"';
            } else if (arg.direction == DBusArgumentDirection.out) {
              xml += ' direction="out"';
            }
            xml += '/>';
          }
          xml += '</method>';
        }
        xml += '</interface>';
      }
    }
    for (var child in node.children.keys) {
      xml += '<node name="${child}"/>';
    }
    xml += '</node>';
    return DBusMethodSuccessResponse([DBusString(xml)]);
  } else {
    return DBusMethodErrorResponse.unknownMethod();
  }
}
