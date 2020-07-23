import 'package:unix_domain_socket/unix_domain_socket.dart';

import "dart:async";
import "dart:convert";
import "dart:ffi";
import "dart:io";
import "dart:isolate";

import "dbus_address.dart";
import "dbus_message.dart";
import "dbus_read_buffer.dart";
import "dbus_value.dart";
import "dbus_write_buffer.dart";

// FIXME: Use more efficient data store than List<int>?
// FIXME: Use ByteData more efficiently - don't copy when reading/writing

typedef _getuidC = Int32 Function();
typedef _getuidDart = int Function();

int _getuid() {
  final dylib = DynamicLibrary.open('libc.so.6');
  final getuidP = dylib.lookupFunction<_getuidC, _getuidDart>('getuid');
  return getuidP();
}

class ReadData {
  UnixDomainSocket socket;
  SendPort port;
}

/// A client connection to a D-Bus server.
class DBusClient {
  UnixDomainSocket _socket;
  var _lastSerial = 0;
  Stream _messageStream;

  /// Creates a new DBus client to connect on [address].
  DBusClient(String address) {
    _setAddress(address);
  }

  /// Creates a new DBus client to communicate with the system bus.
  DBusClient.system() {
    var address = Platform.environment['DBUS_SYSTEM_BUS_ADDRESS'];
    if (address == null) address = 'unix:path=/run/dbus/system_bus_socket';
    _setAddress(address);
  }

  /// Creates a new DBus client to communicate with the session bus.
  DBusClient.session() {
    var address = Platform.environment['DBUS_SESSION_BUS_ADDRESS'];
    if (address == null) {
      var runtimeDir = Platform.environment['XDG_USER_DIR'];
      if (runtimeDir == null) {
        var uid = _getuid();
        runtimeDir = '/run/user/${uid}';
      }
      address = "unix:path=${runtimeDir}/bus";
    }
    _setAddress(address);
  }

  _setAddress(String address_string) {
    var address = DBusAddress(address_string);
    if (address.transport != 'unix')
      throw 'D-Bus address transport not supported: ${address_string}';

    var paths = List<String>();
    for (var property in address.properties) {
      if (property.key == 'path') paths.add(property.value);
    }
    if (paths.length == 0)
      throw 'Unable to determine D-Bus unix address path: ${address_string}';

    _socket = UnixDomainSocket.create(paths[0]);
    var dbusMessages = ReceivePort();
    _messageStream = dbusMessages.asBroadcastStream();
    var data = ReadData();
    data.port = dbusMessages.sendPort;
    data.socket = _socket;
    Isolate.spawn(_read, data);

    _authenticate();
  }

  listenSignal(
      void onSignal(String path, String interface, String member,
          List<DBusValue> values)) {
    _messageStream.listen((dynamic receivedData) {
      var message = receivedData as DBusMessage;
      if (message.type == MessageType.Signal)
        onSignal(
            message.path, message.interface, message.member, message.values);
    });
  }

  // FIXME: Should be async
  listenMethod(
      String interface,
      List<DBusValue> onMethod(String path, String interface, String member,
          List<DBusValue> values)) {
    _messageStream.listen((dynamic receivedData) {
      var message = receivedData as DBusMessage;
      if (message.type == MessageType.MethodCall &&
          message.interface == interface) {
        var result = onMethod(
            message.path, message.interface, message.member, message.values);
        _lastSerial++;
        var response = DBusMessage(
            type: MessageType.MethodReturn,
            serial: _lastSerial,
            replySerial: message.serial,
            destination: message.sender,
            values: result);
        _sendMessage(response);
      }
    });
  }

  /// Connects to the D-Bus server.
  connect() async {
    await callMethod(
        destination: 'org.freedesktop.DBus',
        path: '/org/freedesktop/DBus',
        interface: 'org.freedesktop.DBus',
        member: 'Hello');
  }

  /// Requests usage of [name] as a D-Bus object name.
  // FIXME(robert-ancell): Use an enum for flags.
  Future<int> requestName(String name, {int flags = 0}) async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: '/org/freedesktop/DBus',
        interface: 'org.freedesktop.DBus',
        member: 'RequestName',
        values: [DBusString(name), DBusUint32(flags)]);
    return (result[0] as DBusUint32).value;
  }

  /// Releases the D-Bus object name previously acquired using requestName().
  Future<int> releaseName(String name) async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: '/org/freedesktop/DBus',
        interface: 'org.freedesktop.DBus',
        member: 'ReleaseName',
        values: [DBusString(name)]);
    return (result[0] as DBusUint32).value;
  }

  /// Lists the registered names on the bus.
  Future<List<String>> listNames() async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: '/org/freedesktop/DBus',
        interface: 'org.freedesktop.DBus',
        member: 'ListNames');
    var names = List<String>();
    for (var name in (result[0] as DBusArray).children)
      names.add((name as DBusString).value);
    return names;
  }

  Future<List<String>> listActivatableNames() async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: '/org/freedesktop/DBus',
        interface: 'org.freedesktop.DBus',
        member: 'ListActivatableNames');
    var names = List<String>();
    for (var name in (result[0] as DBusArray).children)
      names.add((name as DBusString).value);
    return names;
  }

  Future<bool> nameHasOwner(String name) async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: '/org/freedesktop/DBus',
        interface: 'org.freedesktop.DBus',
        member: 'NameHasOwner',
        values: [DBusString(name)]);
    return (result[0] as DBusBoolean).value;
  }

  addMatch(String rule) async {
    await callMethod(
        destination: 'org.freedesktop.DBus',
        path: '/org/freedesktop/DBus',
        interface: 'org.freedesktop.DBus',
        member: 'AddMatch',
        values: [DBusString(rule)]);
  }

  removeMatch(String rule) async {
    await callMethod(
        destination: 'org.freedesktop.DBus',
        path: '/org/freedesktop/DBus',
        interface: 'org.freedesktop.DBus',
        member: 'RemoveMatch',
        values: [DBusString(rule)]);
  }

  Future<String> getId() async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: '/org/freedesktop/DBus',
        interface: 'org.freedesktop.DBus',
        member: 'GetId');
    return (result[0] as DBusString).value;
  }

  peerPing(String destination, String path) async {
    await callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Peer',
        member: 'Ping');
  }

  /// Gets the machine ID of a D-Bus object.
  Future<String> peerGetMachineId(String destination, String path) async {
    var result = await callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Peer',
        member: 'GetMachineId');
    return (result[0] as DBusString).value;
  }

  /// Gets the introspection data about a D-Bus object.
  Future<String> introspect(String destination, String path) async {
    var result = await callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Introspectable',
        member: 'Introspect');
    return (result[0] as DBusString).value;
  }

  /// Gets a property on a D-Bus object.
  Future<DBusVariant> getProperty(
      {String destination, String path, String interface, String name}) async {
    var result = await callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Properties',
        member: 'Get',
        values: [DBusString(interface), DBusString(name)]);
    return result[0] as DBusVariant;
  }

  /// Gets the values of all the properties of a D-Bus object.
  Future<DBusDict> getAllProperties(
      {String destination, String path, String interface}) async {
    var result = await callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Properties',
        member: 'GetAll',
        values: [DBusString(interface)]);
    return result[0] as DBusDict;
  }

  // Sets a property on a D-Bus object.
  setProperty(
      {String destination,
      String path,
      String interface,
      String name,
      DBusValue value}) async {
    await callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Properties',
        member: 'Set',
        values: [DBusString(interface), DBusString(name), DBusVariant(value)]);
  }

  /// Invokes a method on a D-Bus object.
  Future<List<DBusValue>> callMethod(
      {String destination,
      String path,
      String interface,
      String member,
      List<DBusValue> values}) async {
    if (values == null) values = List<DBusValue>();
    _lastSerial++;
    var message = DBusMessage(
        type: MessageType.MethodCall,
        serial: _lastSerial,
        destination: destination,
        path: path,
        interface: interface,
        member: member,
        values: values);
    _sendMessage(message);

    var completer = Completer<List<DBusValue>>();
    _messageStream.listen((dynamic receivedData) {
      var m = receivedData as DBusMessage;
      if (m.replySerial == message.serial) {
        if (m.type == MessageType.Error)
          print('Error: ${m.errorName}'); // FIXME
        completer.complete(m.values);
      }
    });

    return completer.future;
  }

  _sendMessage(DBusMessage message) {
    var buffer = DBusWriteBuffer();
    message.marshal(buffer);
    _socket.write(buffer.data);
  }

  _authenticate() {
    _socket.sendCredentials();
    var uid = _getuid();
    var uid_str = '';
    for (var c in uid.toString().runes)
      uid_str += c.toRadixString(16).padLeft(2);
    _socket.write(utf8.encode('AUTH\r\n'));
    print(utf8.decode(_socket.read(1024)));
    _socket.write(utf8.encode('AUTH EXTERNAL ${uid_str}\r\n'));
    print(utf8.decode(_socket.read(1024)));
    _socket.write(utf8.encode('BEGIN\r\n'));
  }
}

_read(ReadData _data) {
  var readBuffer = DBusReadBuffer();
  while (true) {
    var message = DBusMessage();
    var start = readBuffer.readOffset;
    if (!message.unmarshal(readBuffer)) {
      readBuffer.readOffset = start;
      var data = _data.socket.read(1024);
      readBuffer.writeBytes(data);
      continue;
    }
    readBuffer.flush();

    _data.port.send(message);
  }
}
