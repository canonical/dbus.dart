import 'dbus_value.dart';
import 'package:xml/xml.dart';

/// Access allowed to D-Bus properties. Properties may be [readwrite], [read]-only or [write]-only.
enum DBusPropertyAccess { readwrite, read, write }

/// The direction a D-Bus method argument is passed, either [in_] for inputs (e.g. method arguments) or [out] for outputs.
enum DBusArgumentDirection { in_, out }

/// Introspection information about a D-Bus node.
class DBusIntrospectNode {
  /// D-Bus object this node represents (optional).
  final DBusObjectPath name;

  /// Interfaces this node uses.
  final List<DBusIntrospectInterface> interfaces;

  DBusIntrospectNode(this.name, this.interfaces);

  factory DBusIntrospectNode.fromXml(XmlNode node) {
    var name = node.getAttribute('name');
    var interfaces = <DBusIntrospectInterface>[];
    for (var interface in node.findElements('interface')) {
      interfaces.add(DBusIntrospectInterface.fromXml(interface));
    }
    return DBusIntrospectNode(DBusObjectPath(name), interfaces);
  }

  XmlNode toXml() {
    return XmlElement(
        XmlName('node'),
        [XmlAttribute(XmlName('name'), name.value)],
        interfaces.map((i) => i.toXml()));
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
    var methods = <DBusIntrospectMethod>[];
    for (var method in node.findElements('method')) {
      methods.add(DBusIntrospectMethod.fromXml(method));
    }
    var signals = <DBusIntrospectSignal>[];
    for (var signal in node.findElements('signal')) {
      signals.add(DBusIntrospectSignal.fromXml(signal));
    }
    var properties = <DBusIntrospectProperty>[];
    for (var property in node.findElements('property')) {
      properties.add(DBusIntrospectProperty.fromXml(property));
    }
    var annotations = <DBusIntrospectAnnotation>[];
    for (var annotation in node.findElements('annotation')) {
      annotations.add(DBusIntrospectAnnotation.fromXml(annotation));
    }
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
    var args = <DBusIntrospectArgument>[];
    for (var arg in node.findElements('arg')) {
      args.add(DBusIntrospectArgument.fromXml(arg));
    }
    var annotations = <DBusIntrospectAnnotation>[];
    for (var annotation in node.findElements('annotation')) {
      annotations.add(DBusIntrospectAnnotation.fromXml(annotation));
    }
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
    var args = <DBusIntrospectArgument>[];
    for (var arg in node.findElements('arg')) {
      args.add(DBusIntrospectArgument.fromXml(arg));
    }
    var annotations = <DBusIntrospectAnnotation>[];
    for (var annotation in node.findElements('annotation')) {
      annotations.add(DBusIntrospectAnnotation.fromXml(annotation));
    }
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
    var annotations = <DBusIntrospectAnnotation>[];
    for (var annotation in node.findElements('annotation')) {
      annotations.add(DBusIntrospectAnnotation.fromXml(annotation));
    }
    return DBusIntrospectProperty(name, type,
        access: access, annotations: annotations);
  }

  XmlNode toXml() {
    var attributes = <XmlAttribute>[];
    if (name != null) attributes.add(XmlAttribute(XmlName('name'), name));
    attributes.add(XmlAttribute(XmlName('type'), type.value));
    if (access == DBusPropertyAccess.readwrite) {
      attributes.add(XmlAttribute(XmlName('access'), 'readwrite'));
    } else if (access == DBusPropertyAccess.read) {
      attributes.add(XmlAttribute(XmlName('access'), 'read'));
    } else if (access == DBusPropertyAccess.write) {
      attributes.add(XmlAttribute(XmlName('access'), 'write'));
    }
    return XmlElement(
        XmlName('property'), attributes, annotations.map((a) => a.toXml()));
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
    var direction = DBusArgumentDirection.in_;
    if (directionText == 'out') direction = DBusArgumentDirection.out;
    var annotations = <DBusIntrospectAnnotation>[];
    for (var annotation in node.findElements('annotation')) {
      annotations.add(DBusIntrospectAnnotation.fromXml(annotation));
    }
    return DBusIntrospectArgument(name, type, direction,
        annotations: annotations);
  }

  XmlNode toXml() {
    var attributes = <XmlAttribute>[];
    if (name != null) attributes.add(XmlAttribute(XmlName('name'), name));
    attributes.add(XmlAttribute(XmlName('type'), type.value));
    if (direction == DBusArgumentDirection.in_) {
      attributes.add(XmlAttribute(XmlName('direction'), 'in'));
    } else if (direction == DBusArgumentDirection.out) {
      attributes.add(XmlAttribute(XmlName('direction'), 'out'));
    }
    return XmlElement(
        XmlName('argument'), attributes, annotations.map((a) => a.toXml()));
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
///
/// Data can received from [DBusObjectProxy.introspect] or from an interface definition document.
List<DBusIntrospectNode> parseDBusIntrospectXml(String xml) {
  var document = XmlDocument.parse(xml);
  var nodes = <DBusIntrospectNode>[];
  for (var node in document.findElements('node')) {
    nodes.add(DBusIntrospectNode.fromXml(node));
  }
  return nodes;
}
