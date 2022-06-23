import 'dbus_client.dart';
import 'dbus_introspect.dart';
import 'dbus_method_response.dart';
import 'dbus_signal.dart';
import 'dbus_value.dart';

/// A stream of signals from a remote object.
class DBusRemoteObjectSignalStream extends DBusSignalStream {
  /// Creates a stream of signals [interface].[name] from [object].
  ///
  /// If [signature] is provided this causes the stream to throw a
  /// [DBusSignalSignatureException] if a signal is received that does not
  /// match the provided signature.
  DBusRemoteObjectSignalStream(
      {required DBusRemoteObject object,
      required String interface,
      required String name,
      DBusSignature? signature})
      : super(object.client,
            sender: object.name,
            path: object.path,
            interface: interface,
            name: name,
            signature: signature);
}

/// Signal received when properties are changed.
class DBusPropertiesChangedSignal extends DBusSignal {
  /// The interface the properties are on.
  String get propertiesInterface => values[0].asString();

  /// Properties that have changed and their new values.
  Map<String, DBusValue> get changedProperties =>
      values[1].asStringVariantDict();

  /// Properties that have changed but require their values to be requested.
  List<String> get invalidatedProperties => values[2].asStringArray().toList();

  DBusPropertiesChangedSignal(DBusSignal signal)
      : super(
            sender: signal.sender,
            path: signal.path,
            interface: signal.interface,
            name: signal.name,
            values: signal.values);
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

  /// The name of the client providing this object.
  final String name;

  /// The path to the object.
  final DBusObjectPath path;

  /// Stream of signals when the remote object indicates a property has changed.
  late final Stream<DBusPropertiesChangedSignal> propertiesChanged;

  /// Creates an object that access accesses a remote D-Bus object using bus [name] with [path].
  DBusRemoteObject(this.client, {required this.name, required this.path}) {
    var rawPropertiesChanged = DBusRemoteObjectSignalStream(
        object: this,
        interface: 'org.freedesktop.DBus.Properties',
        name: 'PropertiesChanged');
    propertiesChanged = rawPropertiesChanged.map((signal) {
      if (signal.signature == DBusSignature('sa{sv}as')) {
        return DBusPropertiesChangedSignal(signal);
      } else {
        throw 'org.freedesktop.DBus.Properties.PropertiesChanged contains invalid values ${signal.values}';
      }
    });
  }

  /// Gets the introspection data for this object.
  ///
  /// Throws [DBusServiceUnknownException] if there is the requested service is not available.
  /// Throws [DBusUnknownObjectException] if this object is not available.
  /// Throws [DBusUnknownInterfaceException] if introspection is not supported by this object.
  Future<DBusIntrospectNode> introspect() async {
    var result = await client.callMethod(
        destination: name,
        path: path,
        interface: 'org.freedesktop.DBus.Introspectable',
        name: 'Introspect',
        replySignature: DBusSignature('s'));
    var xml = result.returnValues[0].asString();
    return parseDBusIntrospectXml(xml);
  }

  /// Gets a property on this object.
  ///
  /// If [signature] is provided this causes this method to throw a
  /// [DBusPropertySignatureException] if a property is returned that does not
  /// match the provided signature.
  ///
  /// Throws [DBusServiceUnknownException] if there is the requested service is not available.
  /// Throws [DBusUnknownObjectException] if this object is not available.
  /// Throws [DBusUnknownInterfaceException] if properties are not supported by this object.
  /// Throws [DBusUnknownPropertyException] if the property doesn't exist.
  /// Throws [DBusPropertyWriteOnlyException] if the property can't be read.
  Future<DBusValue> getProperty(String interface, String name,
      {DBusSignature? signature}) async {
    var result = await client.callMethod(
        destination: this.name,
        path: path,
        interface: 'org.freedesktop.DBus.Properties',
        name: 'Get',
        values: [DBusString(interface), DBusString(name)],
        replySignature: DBusSignature('v'));
    var value = result.returnValues[0].asVariant();
    if (signature != null && value.signature != signature) {
      throw DBusPropertySignatureException('$interface.$name', value);
    }
    return value;
  }

  /// Gets the values of all the properties on this object.
  ///
  /// Throws [DBusServiceUnknownException] if there is the requested service is not available.
  /// Throws [DBusUnknownObjectException] if this object is not available.
  /// Throws [DBusUnknownInterfaceException] if properties are not supported by this object.
  Future<Map<String, DBusValue>> getAllProperties(String interface) async {
    var result = await client.callMethod(
        destination: name,
        path: path,
        interface: 'org.freedesktop.DBus.Properties',
        name: 'GetAll',
        values: [DBusString(interface)],
        replySignature: DBusSignature('a{sv}'));
    return result.returnValues[0].asStringVariantDict();
  }

  /// Sets a property on this object.
  ///
  /// Throws [DBusServiceUnknownException] if there is the requested service is not available.
  /// Throws [DBusUnknownObjectException] if this object is not available.
  /// Throws [DBusUnknownInterfaceException] if properties are not supported by this object.
  /// Throws [DBusUnknownPropertyException] if the property doesn't exist.
  /// Throws [DBusPropertyReadOnlyException] if the property can't be written.
  Future<void> setProperty(
      String interface, String name, DBusValue value) async {
    await client.callMethod(
        destination: this.name,
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
  ///
  /// Throws [DBusServiceUnknownException] if there is the requested service is not available.
  /// Throws [DBusUnknownObjectException] if this object is not available.
  /// Throws [DBusUnknownInterfaceException] if [interface] is not provided by this object.
  /// Throws [DBusUnknownMethodException] if the method with [name] is not available.
  /// Throws [DBusInvalidArgsException] if [args] aren't correct.
  Future<DBusMethodSuccessResponse> callMethod(
      String? interface, String name, Iterable<DBusValue> values,
      {DBusSignature? replySignature,
      bool noReplyExpected = false,
      bool noAutoStart = false,
      bool allowInteractiveAuthorization = false}) async {
    return client.callMethod(
        destination: this.name,
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
    return "$runtimeType(name: '$name', path: '${path.value}')";
  }
}
