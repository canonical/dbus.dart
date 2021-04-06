import 'dbus_object.dart';
import 'dbus_value.dart';

/// Tree structure of registered objects.
class DBusObjectTree {
  final root = DBusObjectTreeNode('');

  /// Add the given [path] into the object tree.
  void add(DBusObjectPath path, DBusObject object) {
    var node = root;
    for (var element in path.split()) {
      var child = node.children[element];
      if (child == null) {
        child = DBusObjectTreeNode(element);
        node.children[element] = child;
      }
      node = child;
    }
    node.object = object;
  }

  /// Find the node for the given [path], or return null if not in the tree.
  DBusObjectTreeNode? lookup(DBusObjectPath path) {
    var node = root;
    for (var element in path.split()) {
      var child = node.children[element];
      if (child == null) {
        return null;
      }
      node = child;
    }

    return node;
  }
}

/// A node in a [DBusObjectTree].
class DBusObjectTreeNode {
  /// Name of this node, e.g. 'com'
  String name;

  /// Object registered on this node.
  DBusObject? object;

  /// Child nodes
  final children = <String, DBusObjectTreeNode>{};

  /// Creates a new tree node.
  DBusObjectTreeNode(this.name);
}
