import 'dbus_client.dart';
import 'dbus_introspect.dart';
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
DBusMethodResponse handleIntrospectableMethodCall(Set<DBusObjectPath> objects,
    DBusObjectPath path, String member, List<DBusValue> values) {
  if (member == 'Introspect') {
    var children = <String>{};
    var pathElements = path.split();
    for (var path in objects) {
      var elements = path.split();
      if (!_isSubnode(pathElements, elements)) continue;
      var x = elements[pathElements.length];
      children.add(x);
    }
    var xml = '<node>';
    if (objects.contains(path)) {
      var interfaces = <DBusIntrospectInterface>[];
      interfaces.add(introspectIntrospectable());
      interfaces.add(introspectPeer());
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
    for (var node in children) {
      xml += '<node name="${node}"/>';
    }
    xml += '</node>';
    return DBusMethodSuccessResponse([DBusString(xml)]);
  } else {
    return DBusMethodErrorResponse.unknownMethod();
  }
}

bool _isSubnode(List<String> parent, List<String> child) {
  if (parent.length >= child.length) return false;
  for (var i = 0; i < parent.length; i++) {
    if (child[i] != parent[i]) {
      return false;
    }
  }
  return true;
}
