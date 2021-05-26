import 'dbus_client.dart';
import 'dbus_introspect.dart';
import 'dbus_method_response.dart';
import 'dbus_signal.dart';
import 'dbus_value.dart';

/// A stream of signals from a remote object.
class DBusRemoteObjectSignalStream extends DBusSignalStream {
  /// Creates a stream of signals [interface.name] from [object].
  ///
  /// If [signature] is provided this causes the stream to throw a
  /// [DBusSignalSignatureException] if a signal is received that does not
  /// match the provided signature.
  DBusRemoteObjectSignalStream(
      DBusRemoteObject object, String interface, String name,
      {DBusSignature? signature})
      : super(object.client,
            sender: object.destination,
            path: object.path,
            interface: interface,
            name: name,
            signature: signature);
}

/// Signal received when properties are changed.
class DBusPropertiesChangedSignal extends DBusSignal {
  /// The interface the properties are on.
  String get propertiesInterface => (values[0] as DBusString).value;

  /// Properties that have changed and their new values.
  Map<String, DBusValue> get changedProperties =>
      (values[1] as DBusDict).children.map((name, value) =>
          MapEntry((name as DBusString).value, (value as DBusVariant).value));

  /// Properties that have changed but require their values to be requested.
  List<String> get invalidatedProperties => (values[2] as DBusArray)
      .children
      .map((value) => (value as DBusString).value)
      .toList();

  DBusPropertiesChangedSignal(DBusSignal signal)
      : super(signal.sender, signal.path, signal.interface, signal.name,
            signal.values);
}

/// Exception thrown when a D-Bus property returns a value that don't match the expected signature.
class DBusPropertySignatureException implements Exception {
  /// The name of the property.
  final String propertyName;

  /// The value that was returned.
  final DBusValue value;

  DBusPropertySignatureException(this.propertyName, this.value);

  @override
  String toString() {
    return '$propertyName returned invalid value: $value';
  }
}

/// An object to simplify access to a D-Bus object.
class DBusRemoteObject {
  /// The client this object is accessed from.
  final DBusClient client;

  /// The address of the client providing this object.
  final String destination;

  /// The path to the object.
  final DBusObjectPath path;

  /// Stream of signals when the remote object indicates a property has changed.
  late final Stream<DBusPropertiesChangedSignal> propertiesChanged;

  /// Creates an object that access accesses a remote D-Bus object at [destination], [path].
  DBusRemoteObject(this.client, this.destination, this.path) {
    var rawPropertiesChanged = DBusRemoteObjectSignalStream(
        this, 'org.freedesktop.DBus.Properties', 'PropertiesChanged');
    propertiesChanged = rawPropertiesChanged.map((signal) {
      if (signal.signature == DBusSignature('sa{sv}as')) {
        return DBusPropertiesChangedSignal(signal);
      } else {
        throw 'org.freedesktop.DBus.Properties.PropertiesChanged contains invalid values ${signal.values}';
      }
    });
  }

  /// Gets the introspection data for this object.
  Future<DBusIntrospectNode> introspect() async {
    var result = await client.callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Introspectable',
        name: 'Introspect',
        replySignature: DBusSignature('s'));
    var xml = (result.returnValues[0] as DBusString).value;
    return parseDBusIntrospectXml(xml);
  }

  /// Gets a property on this object.
  ///
  /// If [signature] is provided this causes this method to throw a
  /// [DBusPropertySignatureException] if a property is returned that does not
  /// match the provided signature.
  Future<DBusValue> getProperty(String interface, String name,
      {DBusSignature? signature}) async {
    var result = await client.callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Properties',
        name: 'Get',
        values: [DBusString(interface), DBusString(name)],
        replySignature: DBusSignature('v'));
    var value = (result.returnValues[0] as DBusVariant).value;
    if (signature != null && value.signature != signature) {
      throw DBusPropertySignatureException('$interface.$name', value);
    }
    return value;
  }

  /// Gets the values of all the properties on this object.
  Future<Map<String, DBusValue>> getAllProperties(String interface) async {
    var result = await client.callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Properties',
        name: 'GetAll',
        values: [DBusString(interface)],
        replySignature: DBusSignature('a{sv}'));
    return (result.returnValues[0] as DBusDict).children.map((key, value) =>
        MapEntry((key as DBusString).value, (value as DBusVariant).value));
  }

  /// Sets a property on this object.
  Future<void> setProperty(
      String interface, String name, DBusValue value) async {
    await client.callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Properties',
        name: 'Set',
        values: [DBusString(interface), DBusString(name), DBusVariant(value)],
        replySignature: DBusSignature(''));
  }

  /// Invokes a method on this object.
  /// Throws [DBusMethodResponseException] if the remote side returns an error.
  ///
  /// If [replySignature] is provided this causes this method to throw a
  /// [DBusReplySignatureException] if the result is successful but the returned
  /// values do not match the provided signature.
  Future<DBusMethodSuccessResponse> callMethod(
      String? interface, String name, Iterable<DBusValue> values,
      {DBusSignature? replySignature,
      bool noReplyExpected = false,
      bool noAutoStart = false,
      bool allowInteractiveAuthorization = false}) async {
    return client.callMethod(
        destination: destination,
        path: path,
        interface: interface,
        name: name,
        values: values,
        replySignature: replySignature,
        noReplyExpected: noReplyExpected,
        noAutoStart: noAutoStart,
        allowInteractiveAuthorization: allowInteractiveAuthorization);
  }

  @override
  String toString() {
    return "DBusRemoteObject(destination: '$destination', path: '${path.value}')";
  }
}
