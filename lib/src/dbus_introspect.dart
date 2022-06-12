import 'dbus_value.dart';
import 'package:xml/xml.dart';

/// Access allowed to D-Bus properties. Properties may be [readwrite], [read]-only or [write]-only.
enum DBusPropertyAccess { readwrite, read, write }

/// The direction a D-Bus method argument is passed, either [in_] for inputs (e.g. method arguments) or [out] for outputs.
enum DBusArgumentDirection { in_, out }

bool _listsEqual<T>(List<T> a, List<T> b) {
  if (a.length != b.length) {
    return false;
  }

  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }

  return true;
}

/// Introspection information about a D-Bus node.
class DBusIntrospectNode {
  /// D-Bus object this node represents, either absolute or relative (optional).
  final String? name;

  /// Interfaces this node uses.
  final List<DBusIntrospectInterface> interfaces;

  /// Child nodes.
  final List<DBusIntrospectNode> children;

  DBusIntrospectNode(
      {this.name, this.interfaces = const [], this.children = const []});

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
    return DBusIntrospectNode(
        name: name, interfaces: interfaces, children: children);
  }

  XmlNode toXml() {
    var attributes = <XmlAttribute>[];
    if (name != null) {
      attributes.add(XmlAttribute(XmlName('name'), name!));
    }
    var children_ = <XmlNode>[];
    children_.addAll(interfaces.map((i) => i.toXml()));
    children_.addAll(children.map((c) => c.toXml()));
    return XmlElement(XmlName('node'), attributes, children_);
  }

  @override
  String toString() {
    var parameters = <String, String?>{
      'name': name != null ? '$name' : null,
      'interfaces': interfaces.isNotEmpty ? interfaces.toString() : null,
      'children': children.isNotEmpty ? children.toString() : null
    };
    var parameterString = parameters.keys
        .where((key) => parameters[key] != null)
        .map((key) => '$key: ${parameters[key]}')
        .join(', ');
    return '$runtimeType($parameterString)';
  }

  @override
  bool operator ==(other) =>
      other is DBusIntrospectNode &&
      other.name == name &&
      _listsEqual(other.interfaces, interfaces) &&
      _listsEqual(other.children, children);

  @override
  int get hashCode => Object.hash(name, interfaces, children);
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
    if (name == null) {
      throw FormatException('D-Bus Introspection XML missing interface name');
    }
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

  @override
  String toString() {
    var parameters = <String, String?>{
      'methods': methods.isNotEmpty ? methods.toString() : null,
      'signals': signals.isNotEmpty ? signals.toString() : null,
      'properties': properties.isNotEmpty ? properties.toString() : null
    };
    var parameterString = ["'$name'"]
        .followedBy(parameters.keys
            .where((key) => parameters[key] != null)
            .map((key) => '$key: ${parameters[key]}'))
        .join(', ');
    return '$runtimeType($parameterString)';
  }

  @override
  bool operator ==(other) =>
      other is DBusIntrospectInterface &&
      other.name == name &&
      _listsEqual(other.methods, methods) &&
      _listsEqual(other.signals, signals) &&
      _listsEqual(other.properties, properties) &&
      _listsEqual(other.annotations, annotations);

  @override
  int get hashCode =>
      Object.hash(name, methods, signals, properties, annotations);
}

/// Introspection information about a D-Bus method.
class DBusIntrospectMethod {
  /// Name of this method, e.g. 'RequestName'.
  final String name;

  /// Arguments to pass to method.
  final List<DBusIntrospectArgument> args;

  /// Annotations for this method.
  final List<DBusIntrospectAnnotation> annotations;

  /// The signature for the input arguments in this method call.
  DBusSignature get inputSignature => args
      .where((arg) => arg.direction == DBusArgumentDirection.in_)
      .map((arg) => arg.type)
      .fold(DBusSignature(''), (a, b) => a + b);

  /// The signature for the output arguments in this method call.
  DBusSignature get outputSignature => args
      .where((arg) => arg.direction == DBusArgumentDirection.out)
      .map((arg) => arg.type)
      .fold(DBusSignature(''), (a, b) => a + b);

  DBusIntrospectMethod(this.name,
      {this.args = const [], this.annotations = const []});

  factory DBusIntrospectMethod.fromXml(XmlNode node) {
    var name = node.getAttribute('name');
    if (name == null) {
      throw FormatException('D-Bus Introspection XML missing method name');
    }
    var args = node
        .findElements('arg')
        .map(
            (n) => DBusIntrospectArgument.fromXml(n, DBusArgumentDirection.in_))
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

  @override
  String toString() {
    var parameters = <String, String?>{
      'args': args.isNotEmpty ? args.toString() : null,
      'annotations': annotations.isNotEmpty ? annotations.toString() : null
    };
    var parameterString = ["'$name'"]
        .followedBy(parameters.keys
            .where((key) => parameters[key] != null)
            .map((key) => '$key: ${parameters[key]}'))
        .join(', ');
    return '$runtimeType($parameterString)';
  }

  @override
  bool operator ==(other) =>
      other is DBusIntrospectMethod &&
      other.name == name &&
      _listsEqual(other.args, args) &&
      _listsEqual(other.annotations, annotations);

  @override
  int get hashCode => Object.hash(name, args, annotations);
}

/// Introspection information about a D-Bus signal.
class DBusIntrospectSignal {
  /// Name of this signal, e.g. 'NameLost'.
  final String name;

  /// Arguments sent with signal.
  final List<DBusIntrospectArgument> args;

  /// Annotations for this signal.
  final List<DBusIntrospectAnnotation> annotations;

  /// The signature for the arguments in this signals.
  DBusSignature get signature =>
      args.map((arg) => arg.type).fold(DBusSignature(''), (a, b) => a + b);

  DBusIntrospectSignal(this.name,
      {this.args = const [], this.annotations = const []});

  factory DBusIntrospectSignal.fromXml(XmlNode node) {
    var name = node.getAttribute('name');
    if (name == null) {
      throw FormatException('D-Bus Introspection XML missing signal name');
    }
    var args = node
        .findElements('arg')
        .map(
            (n) => DBusIntrospectArgument.fromXml(n, DBusArgumentDirection.out))
        .toList();
    var annotations = node
        .findElements('annotation')
        .map((n) => DBusIntrospectAnnotation.fromXml(n))
        .toList();
    return DBusIntrospectSignal(name, args: args, annotations: annotations);
  }

  XmlNode toXml() {
    var children = <XmlNode>[];
    children.addAll(args.map((a) => a.toXml(writeDirection: false)));
    children.addAll(annotations.map((a) => a.toXml()));
    return XmlElement(
        XmlName('signal'), [XmlAttribute(XmlName('name'), name)], children);
  }

  @override
  String toString() {
    var parameters = <String, String?>{
      'args': args.isNotEmpty ? args.toString() : null,
      'annotations': annotations.isNotEmpty ? annotations.toString() : null
    };
    var parameterString = ["'$name'"]
        .followedBy(parameters.keys
            .where((key) => parameters[key] != null)
            .map((key) => '$key: ${parameters[key]}'))
        .join(', ');
    return '$runtimeType($parameterString)';
  }

  @override
  bool operator ==(other) =>
      other is DBusIntrospectSignal &&
      other.name == name &&
      _listsEqual(other.args, args) &&
      _listsEqual(other.annotations, annotations);

  @override
  int get hashCode => Object.hash(name, args, annotations);
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
    if (name == null) {
      throw FormatException('D-Bus Introspection XML missing property name');
    }
    var typeString = node.getAttribute('type');
    if (typeString == null) {
      throw FormatException('D-Bus Introspection XML missing property type');
    }
    var type = DBusSignature(typeString);
    var accessText = node.getAttribute('access');
    var access = {
      null: DBusPropertyAccess.readwrite,
      'readwrite': DBusPropertyAccess.readwrite,
      'read': DBusPropertyAccess.read,
      'write': DBusPropertyAccess.write
    }[accessText];
    if (access == null) {
      throw FormatException("Unknown property access '$accessText'");
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
    attributes.add(XmlAttribute(XmlName('name'), name));
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

  @override
  String toString() {
    var parameters = <String, String?>{
      'access':
          access != DBusPropertyAccess.readwrite ? access.toString() : null,
      'annotations': annotations.isNotEmpty ? annotations.toString() : null
    };
    var parameterString = ["'$name'", type.toString()]
        .followedBy(parameters.keys
            .where((key) => parameters[key] != null)
            .map((key) => '$key: ${parameters[key]}'))
        .join(', ');
    return '$runtimeType($parameterString)';
  }

  @override
  bool operator ==(other) =>
      other is DBusIntrospectProperty &&
      other.name == name &&
      other.type == type &&
      other.access == access &&
      _listsEqual(other.annotations, annotations);

  @override
  int get hashCode => Object.hash(name, type, access, annotations);
}

/// Introspection information about a D-Bus argument.
class DBusIntrospectArgument {
  /// Name of this argument, e.g. 'name' (optional).
  final String? name;

  /// Type of this argument.
  final DBusSignature type;

  /// Direction this argument is passed.
  final DBusArgumentDirection direction;

  /// Annotations for this argument.
  final List<DBusIntrospectAnnotation> annotations;

  DBusIntrospectArgument(this.type, this.direction,
      {this.name, this.annotations = const []});

  factory DBusIntrospectArgument.fromXml(
      XmlNode node, DBusArgumentDirection defaultDirection) {
    var name = node.getAttribute('name');
    var typeString = node.getAttribute('type');
    if (typeString == null) {
      throw FormatException('D-Bus Introspection XML missing argument type');
    }
    var type = DBusSignature(typeString);
    var directionText = node.getAttribute('direction');
    var direction = {
      null: defaultDirection,
      'in': DBusArgumentDirection.in_,
      'out': DBusArgumentDirection.out
    }[directionText];
    if (direction == null) {
      throw FormatException("Unknown argument direction '$directionText'");
    }
    var annotations = node
        .findElements('annotation')
        .map((n) => DBusIntrospectAnnotation.fromXml(n))
        .toList();
    return DBusIntrospectArgument(type, direction,
        name: name, annotations: annotations);
  }

  XmlNode toXml({bool writeDirection = true}) {
    var attributes = <XmlAttribute>[];
    if (name != null) {
      attributes.add(XmlAttribute(XmlName('name'), name!));
    }
    attributes.add(XmlAttribute(XmlName('type'), type.value));
    if (writeDirection) {
      if (direction == DBusArgumentDirection.in_) {
        attributes.add(XmlAttribute(XmlName('direction'), 'in'));
      } else if (direction == DBusArgumentDirection.out) {
        attributes.add(XmlAttribute(XmlName('direction'), 'out'));
      }
    }
    return XmlElement(
        XmlName('arg'), attributes, annotations.map((a) => a.toXml()).toList());
  }

  @override
  String toString() {
    var parameters = <String, String?>{
      'name': name != null ? "'$name'" : null,
      'annotations': annotations.isNotEmpty ? annotations.toString() : null
    };
    var parameterString = [type.toString(), direction.toString()]
        .followedBy(parameters.keys
            .where((key) => parameters[key] != null)
            .map((key) => '$key: ${parameters[key]}'))
        .join(', ');
    return '$runtimeType($parameterString)';
  }

  @override
  bool operator ==(other) =>
      other is DBusIntrospectArgument &&
      other.name == name &&
      other.type == type &&
      other.direction == direction &&
      _listsEqual(other.annotations, annotations);

  @override
  int get hashCode => Object.hash(name, type, direction, annotations);
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
    if (name == null) {
      throw FormatException('D-Bus Introspection XML missing annotation name');
    }
    var value = node.getAttribute('value');
    if (value == null) {
      throw FormatException('D-Bus Introspection XML missing annotation value');
    }
    return DBusIntrospectAnnotation(name, value);
  }

  XmlNode toXml() {
    return XmlElement(XmlName('annotation'), [
      XmlAttribute(XmlName('name'), name),
      XmlAttribute(XmlName('value'), value)
    ]);
  }

  @override
  String toString() {
    return "$runtimeType('$name', '$value')";
  }

  @override
  bool operator ==(other) =>
      other is DBusIntrospectAnnotation &&
      other.name == name &&
      other.value == value;

  @override
  int get hashCode => Object.hash(name, value);
}

/// Parse D-Bus introspection data.
DBusIntrospectNode parseDBusIntrospectXml(String xml) {
  XmlDocument document;
  try {
    document = XmlDocument.parse(xml);
  } on XmlParserException catch (e) {
    throw FormatException('D-Bus Introspection XML not valid: ${e.message}');
  }
  var nodeName = document.rootElement.name.local;
  if (nodeName != 'node') {
    throw FormatException(
        "D-Bus Introspection XML has invalid root element '$nodeName', expected 'node'");
  }
  return DBusIntrospectNode.fromXml(document.rootElement);
}
