import 'dbus_value.dart';
import 'package:xml/xml.dart';

/// Access allowed to D-Bus properties. Properties may be [readwrite], [read]-only or [write]-only.
enum DBusPropertyAccess { readwrite, read, write }

/// The direction a D-Bus method argument is passed, either [in_] for inputs (e.g. method arguments) or [out] for outputs.
enum DBusArgumentDirection { in_, out }

/// Introspection information about a D-Bus node.
class DBusIntrospectNode {
  /// D-Bus object this node represents, either absolute or relative (optional).
  final String name;

  /// Interfaces this node uses.
  final List<DBusIntrospectInterface> interfaces;

  /// Child nodes.
  final List<DBusIntrospectNode> children;

  DBusIntrospectNode(this.name,
      [this.interfaces = const [], this.children = const []]);

  factory DBusIntrospectNode.fromXml(XmlNode node) {
    var name = node.getAttribute('name');
    var interfaces = node
        .findElements('interface')
        .map((n) => DBusIntrospectInterface.fromXml(n))
        .toList();
    var children = node
        .findElements('node')
        .map((n) => DBusIntrospectNode.fromXml(n))
        .toList();
    return DBusIntrospectNode(name, interfaces, children);
  }

  XmlNode toXml() {
    var attributes = <XmlAttribute>[];
    if (name != null) {
      attributes.add(XmlAttribute(XmlName('name'), name));
    }
    var children_ = <XmlNode>[];
    children_.addAll(interfaces.map((i) => i.toXml()));
    children_.addAll(children.map((c) => c.toXml()));
    return XmlElement(XmlName('node'), attributes, children_);
  }
}

/// Introspection information about a D-Bus interface.
class DBusIntrospectInterface {
  /// Name of the interface, e.g. 'org.freedesktop.DBus'.
  final String name;

  /// Methods on this interface.
  final List<DBusIntrospectMethod> methods;

  /// Signals emitted on this interface.
  final List<DBusIntrospectSignal> signals;

  /// Properties on this interface.
  final List<DBusIntrospectProperty> properties;

  /// Annotations for this interface.
  final List<DBusIntrospectAnnotation> annotations;

  DBusIntrospectInterface(this.name,
      {this.methods = const [],
      this.signals = const [],
      this.properties = const [],
      this.annotations = const []});

  factory DBusIntrospectInterface.fromXml(XmlNode node) {
    var name = node.getAttribute('name');
    var methods = node
        .findElements('method')
        .map((n) => DBusIntrospectMethod.fromXml(n))
        .toList();
    var signals = node
        .findElements('signal')
        .map((n) => DBusIntrospectSignal.fromXml(n))
        .toList();
    var properties = node
        .findElements('property')
        .map((n) => DBusIntrospectProperty.fromXml(n))
        .toList();
    var annotations = node
        .findElements('annotation')
        .map((n) => DBusIntrospectAnnotation.fromXml(n))
        .toList();
    return DBusIntrospectInterface(name,
        methods: methods,
        signals: signals,
        properties: properties,
        annotations: annotations);
  }

  XmlNode toXml() {
    var children = <XmlNode>[];
    children.addAll(methods.map((m) => m.toXml()));
    children.addAll(signals.map((s) => s.toXml()));
    children.addAll(properties.map((p) => p.toXml()));
    children.addAll(annotations.map((a) => a.toXml()));
    return XmlElement(
        XmlName('interface'), [XmlAttribute(XmlName('name'), name)], children);
  }
}

/// Introspection information about a D-Bus method.
class DBusIntrospectMethod {
  /// Name of this method, e.g. 'RequestName'.
  final String name;

  /// Arguments to pass to method.
  final List<DBusIntrospectArgument> args;

  /// Annotations for this method.
  final List<DBusIntrospectAnnotation> annotations;

  DBusIntrospectMethod(this.name,
      {this.args = const [], this.annotations = const []});

  factory DBusIntrospectMethod.fromXml(XmlNode node) {
    var name = node.getAttribute('name');
    var args = node
        .findElements('arg')
        .map((n) => DBusIntrospectArgument.fromXml(n))
        .toList();
    var annotations = node
        .findElements('annotation')
        .map((n) => DBusIntrospectAnnotation.fromXml(n))
        .toList();
    return DBusIntrospectMethod(name, args: args, annotations: annotations);
  }

  XmlNode toXml() {
    var children = <XmlNode>[];
    children.addAll(args.map((a) => a.toXml()));
    children.addAll(annotations.map((a) => a.toXml()));
    return XmlElement(
        XmlName('method'), [XmlAttribute(XmlName('name'), name)], children);
  }
}

/// Introspection information about a D-Bus signal.
class DBusIntrospectSignal {
  /// Name of this signal, e.g. 'NameLost'.
  final String name;

  /// Arguments sent with signal.
  final List<DBusIntrospectArgument> args;

  /// Annotations for this signal.
  final List<DBusIntrospectAnnotation> annotations;

  DBusIntrospectSignal(this.name,
      {this.args = const [], this.annotations = const []});

  factory DBusIntrospectSignal.fromXml(XmlNode node) {
    var name = node.getAttribute('name');
    var args = node
        .findElements('arg')
        .map((n) => DBusIntrospectArgument.fromXml(n))
        .toList();
    var annotations = node
        .findElements('annotation')
        .map((n) => DBusIntrospectAnnotation.fromXml(n))
        .toList();
    return DBusIntrospectSignal(name, args: args, annotations: annotations);
  }

  XmlNode toXml() {
    var children = <XmlNode>[];
    children.addAll(args.map((a) => a.toXml()));
    children.addAll(annotations.map((a) => a.toXml()));
    return XmlElement(
        XmlName('signal'), [XmlAttribute(XmlName('name'), name)], children);
  }
}

/// Introspection information about a D-Bus property.
class DBusIntrospectProperty {
  /// Name of this property, e.g. 'Features'.
  final String name;

  /// Type of this property.
  final DBusSignature type;

  /// Read/write access to this property.
  final DBusPropertyAccess access;

  /// Annotations for this property.
  final List<DBusIntrospectAnnotation> annotations;

  DBusIntrospectProperty(this.name, this.type,
      {this.access = DBusPropertyAccess.readwrite,
      this.annotations = const []});

  factory DBusIntrospectProperty.fromXml(XmlNode node) {
    var name = node.getAttribute('name');
    var type = DBusSignature(node.getAttribute('type'));
    var accessText = node.getAttribute('access');
    var access = DBusPropertyAccess.readwrite;
    if (accessText == 'read') {
      access = DBusPropertyAccess.read;
    } else if (accessText == 'write') {
      access = DBusPropertyAccess.write;
    }
    var annotations = node
        .findElements('annotation')
        .map((n) => DBusIntrospectAnnotation.fromXml(n))
        .toList();
    return DBusIntrospectProperty(name, type,
        access: access, annotations: annotations);
  }

  XmlNode toXml() {
    var attributes = <XmlAttribute>[];
    if (name != null) {
      attributes.add(XmlAttribute(XmlName('name'), name));
    }
    attributes.add(XmlAttribute(XmlName('type'), type.value));
    if (access == DBusPropertyAccess.readwrite) {
      attributes.add(XmlAttribute(XmlName('access'), 'readwrite'));
    } else if (access == DBusPropertyAccess.read) {
      attributes.add(XmlAttribute(XmlName('access'), 'read'));
    } else if (access == DBusPropertyAccess.write) {
      attributes.add(XmlAttribute(XmlName('access'), 'write'));
    }
    return XmlElement(XmlName('property'), attributes,
        annotations.map((a) => a.toXml()).toList());
  }
}

/// Introspection information about a D-Bus argument.
class DBusIntrospectArgument {
  /// Name of this argument, e.g. 'name' (optional).
  final String name;

  /// Type of this argument.
  final DBusSignature type;

  /// Direction this argument is passed.
  final DBusArgumentDirection direction;

  /// Annotations for this argument.
  final List<DBusIntrospectAnnotation> annotations;

  DBusIntrospectArgument(this.name, this.type, this.direction,
      {this.annotations = const []});

  factory DBusIntrospectArgument.fromXml(XmlNode node) {
    var name = node.getAttribute('name');
    var type = DBusSignature(node.getAttribute('type'));
    var directionText = node.getAttribute('direction');
    DBusArgumentDirection direction;
    if (directionText == 'in') {
      direction = DBusArgumentDirection.in_;
    } else if (directionText == 'out') {
      direction = DBusArgumentDirection.out;
    }
    var annotations = node
        .findElements('annotation')
        .map((n) => DBusIntrospectAnnotation.fromXml(n))
        .toList();
    return DBusIntrospectArgument(name, type, direction,
        annotations: annotations);
  }

  XmlNode toXml() {
    var attributes = <XmlAttribute>[];
    if (name != null) {
      attributes.add(XmlAttribute(XmlName('name'), name));
    }
    attributes.add(XmlAttribute(XmlName('type'), type.value));
    if (direction == DBusArgumentDirection.in_) {
      attributes.add(XmlAttribute(XmlName('direction'), 'in'));
    } else if (direction == DBusArgumentDirection.out) {
      attributes.add(XmlAttribute(XmlName('direction'), 'out'));
    }
    return XmlElement(
        XmlName('arg'), attributes, annotations.map((a) => a.toXml()).toList());
  }
}

/// Annotation that applies to a D-Bus interface, method, signal, property or argument.
class DBusIntrospectAnnotation {
  /// Name of the annotation, e.g. 'org.freedesktop.DBus.Deprecated'.
  final String name;

  /// Value of the annotation, e.g. 'true'.
  final String value;

  DBusIntrospectAnnotation(this.name, this.value);

  factory DBusIntrospectAnnotation.fromXml(XmlNode node) {
    var name = node.getAttribute('name');
    var value = node.getAttribute('value');
    return DBusIntrospectAnnotation(name, value);
  }

  XmlNode toXml() {
    return XmlElement(XmlName('method'), [
      XmlAttribute(XmlName('name'), name),
      XmlAttribute(XmlName('value'), value)
    ]);
  }
}

/// Parse D-Bus introspection data.
List<DBusIntrospectNode> parseDBusIntrospectXml(String xml) {
  var document = XmlDocument.parse(xml);
  return document
      .findElements('node')
      .map((n) => DBusIntrospectNode.fromXml(n))
      .toList();
}
