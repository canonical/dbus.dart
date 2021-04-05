import 'dbus_object.dart';
import 'dbus_value.dart';

/// Tree structure of registered objects.
class DBusObjectTree {
  final root = DBusObjectTreeNode(null, '');

  /// Add the given [path] into the object tree.
  DBusObjectTreeNode add(DBusObjectPath path, DBusObject object) {
    var node = root;
    for (var element in path.split()) {
      var child = node.children[element];
      if (child == null) {
        child = DBusObjectTreeNode(node, element);
        node.children[element] = child;
      }
      node = child;
    }
    node.object = object;

    return node;
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

  /// Removes the object at [path] from the tree.
  void remove(DBusObjectPath path) {
    var node = lookup(path);
    if (node == null) {
      return;
    }

    node.object = null;
    _prune(node);
  }

  /// Removes the given node and any parents if they don't contain objects.
  void _prune(DBusObjectTreeNode node) {
    if (node.object != null || node.children.isNotEmpty) {
      return;
    }

    var parent = node.parent;
    if (parent != null) {
      parent.children.remove(node);
      _prune(parent);
    }
  }
}

/// A node in a [DBusObjectTree].
class DBusObjectTreeNode {
  /// Name of this node, e.g. 'com'
  String name;

  /// Object registered on this node.
  DBusObject? object;

  /// Parent of this node.
  final DBusObjectTreeNode? parent;

  /// Child nodes.
  final children = <String, DBusObjectTreeNode>{};

  /// Creates a new tree node.
  DBusObjectTreeNode(this.parent, this.name);
}
