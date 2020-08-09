import 'dbus_client.dart';
import 'dbus_value.dart';

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
      xml += '<interface name="org.freedesktop.DBus.Introspectable">';
      xml += '<method name="Introspect">';
      xml += '<arg name="xml_data" type="s" direction="out"/>';
      xml += '</method>';
      xml += '</interface>';
      xml += '<interface name="org.freedesktop.DBus.Peer">';
      xml += '<method name="GetMachineId">';
      xml += '<arg name="machine_uuid" type="s" direction="out"/>';
      xml += '</method>';
      xml += '<method name="Ping"/>';
      xml += '</interface>';
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
