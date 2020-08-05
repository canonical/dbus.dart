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
}

/// Annotation that applies to a D-Bus interface, method, signal, property or argument.
class DBusIntrospectAnnotation {
  /// Name of the annotation, e.g. 'org.freedesktop.DBus.Deprecated'.
  final String name;

  /// Value of the annotation, e.g. 'true'.
  final String value;

  DBusIntrospectAnnotation(this.name, this.value);
}

/// Parse D-Bus introspection data.
///
/// Data can received from [DBusObjectProxy.introspect] or from an interface definition document.
List<DBusIntrospectNode> parseDBusIntrospectXml(String xml) {
  var document = XmlDocument.parse(xml);
  var nodes = List<DBusIntrospectNode>();
  for (var node in document.findElements('node'))
    nodes.add(_parseIntrospectNode(node));
  return nodes;
}

DBusIntrospectNode _parseIntrospectNode(XmlNode node) {
  var name = node.getAttribute('name');
  var interfaces = List<DBusIntrospectInterface>();
  for (var interface in node.findElements('interface')) {
    interfaces.add(_parseIntrospectInterface(interface));
  }

  return DBusIntrospectNode(DBusObjectPath(name), interfaces);
}

DBusIntrospectInterface _parseIntrospectInterface(XmlNode node) {
  var name = node.getAttribute('name');
  var methods = List<DBusIntrospectMethod>();
  var signals = List<DBusIntrospectSignal>();
  var properties = List<DBusIntrospectProperty>();
  for (var method in node.findElements('method'))
    methods.add(_parseIntrospectMethod(method));
  for (var signal in node.findElements('signal'))
    signals.add(_parseIntrospectSignal(signal));
  for (var property in node.findElements('property'))
    properties.add(_parseIntrospectProperty(property));
  var annotations = _parseIntrospectAnnotations(node);

  return DBusIntrospectInterface(name,
      methods: methods,
      signals: signals,
      properties: properties,
      annotations: annotations);
}

DBusIntrospectMethod _parseIntrospectMethod(XmlNode node) {
  var name = node.getAttribute('name');
  var args = List<DBusIntrospectArgument>();
  for (var arg in node.findElements('arg'))
    args.add(_parseIntrospectArgument(arg));
  var annotations = _parseIntrospectAnnotations(node);
  return DBusIntrospectMethod(name, args: args, annotations: annotations);
}

DBusIntrospectSignal _parseIntrospectSignal(XmlNode node) {
  var name = node.getAttribute('name');
  var args = List<DBusIntrospectArgument>();
  for (var arg in node.findElements('arg'))
    args.add(_parseIntrospectArgument(arg));
  var annotations = _parseIntrospectAnnotations(node);
  return DBusIntrospectSignal(name, args: args, annotations: annotations);
}

DBusIntrospectProperty _parseIntrospectProperty(XmlNode node) {
  var name = node.getAttribute('name');
  var type = DBusSignature(node.getAttribute('type'));
  var accessText = node.getAttribute('access');
  var access = DBusPropertyAccess.readwrite;
  if (accessText == 'read') {
    access = DBusPropertyAccess.read;
  } else if (accessText == 'write') {
    access = DBusPropertyAccess.write;
  }
  var annotations = _parseIntrospectAnnotations(node);
  return DBusIntrospectProperty(name, type,
      access: access, annotations: annotations);
}

DBusIntrospectArgument _parseIntrospectArgument(XmlNode node) {
  var name = node.getAttribute('name');
  var type = DBusSignature(node.getAttribute('type'));
  var directionText = node.getAttribute('direction');
  var direction = DBusArgumentDirection.in_;
  if (directionText == 'out') direction = DBusArgumentDirection.out;
  var annotations = _parseIntrospectAnnotations(node);
  return DBusIntrospectArgument(name, type, direction,
      annotations: annotations);
}

List<DBusIntrospectAnnotation> _parseIntrospectAnnotations(XmlNode node) {
  var annotations = List<DBusIntrospectAnnotation>();
  for (var annotation in node.findElements('annotation')) {
    var name = node.getAttribute('name');
    var value = node.getAttribute('value');
    annotations.add(DBusIntrospectAnnotation(name, value));
  }
  return annotations;
}
