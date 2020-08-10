import 'dbus_value.dart';

/// Tree structure of registered objects.
class DBusObjectTree {
  final root = DBusObjectTreeNode('');

  /// Add the given [path] into the object tree.
  void add(DBusObjectPath path) {
    var node = root;
    for (var element in path.split()) {
      var child = node.children[element];
      if (child == null) {
        child = DBusObjectTreeNode(element);
        node.children[element] = child;
      }
      node = child;
    }
    node.isObject = true;
  }

  /// Find the node for the given [path], or return null if not in the tree.
  DBusObjectTreeNode lookup(DBusObjectPath path) {
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

  /// True if an object is on this node.
  var isObject = false;

  /// Child nodes
  final children = Map<String, DBusObjectTreeNode>();

  /// Creates a new tree node.
  DBusObjectTreeNode(this.name) {}
}
