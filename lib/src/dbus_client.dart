import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'dbus_address.dart';
import 'dbus_message.dart';
import 'dbus_read_buffer.dart';
import 'dbus_value.dart';
import 'dbus_write_buffer.dart';

// FIXME: Use more efficient data store than List<int>?
// FIXME: Use ByteData more efficiently - don't copy when reading/writing

typedef SignalCallback(
    String path, String interface, String member, List<DBusValue> values);
typedef Future<List<DBusValue>> MethodCallback(
    String path, String interface, String member, List<DBusValue> values);

typedef _getuidC = Int32 Function();
typedef _getuidDart = int Function();

int _getuid() {
  final dylib = DynamicLibrary.open('libc.so.6');
  final getuidP = dylib.lookupFunction<_getuidC, _getuidDart>('getuid');
  return getuidP();
}

class _MethodCall {
  int serial;
  var completer = Completer<List<DBusValue>>();

  _MethodCall(this.serial) {}
}

class _SignalHandler {
  SignalCallback callback;

  _SignalHandler(this.callback);
}

class _MethodHandler {
  String interface;
  MethodCallback callback;

  _MethodHandler(this.interface, this.callback) {}
}

/// A client connection to a D-Bus server.
class DBusClient {
  String _address;
  Socket _socket;
  DBusReadBuffer _readBuffer;
  var _authenticateCompleter = Completer();
  var _lastSerial = 0;
  var _methodCalls = List<_MethodCall>();
  var _signalHandlers = List<_SignalHandler>();
  var _methodHandlers = List<_MethodHandler>();

  /// Creates a new DBus client to connect on [address].
  DBusClient(String address) {
    _address = address;
  }

  /// Creates a new DBus client to communicate with the system bus.
  DBusClient.system() {
    var address = Platform.environment['DBUS_SYSTEM_BUS_ADDRESS'];
    if (address == null) {
      address = 'unix:path=/run/dbus/system_bus_socket';
    }
    _address = address;
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
      address = 'unix:path=${runtimeDir}/bus';
    }
    _address = address;
  }

  listenSignal(SignalCallback callback) {
    _signalHandlers.add(_SignalHandler(callback));
  }

  listenMethod(String interface, MethodCallback callback) {
    _methodHandlers.add(_MethodHandler(interface, callback));
  }

  /// Connects to the D-Bus server.
  connect() async {
    var address = DBusAddress(_address);
    if (address.transport != 'unix') {
      throw 'D-Bus address transport not supported: ${_address}';
    }

    var paths = List<String>();
    for (var property in address.properties) {
      if (property.key == 'path') paths.add(property.value);
    }
    if (paths.length == 0) {
      throw 'Unable to determine D-Bus unix address path: ${_address}';
    }

    var socket_address =
        InternetAddress(paths[0], type: InternetAddressType.unix);
    _socket = await Socket.connect(socket_address, 0);
    _readBuffer = DBusReadBuffer();
    _socket.listen(_processData);

    await _authenticate();

    await callMethod(
        destination: 'org.freedesktop.DBus',
        path: '/org/freedesktop/DBus',
        interface: 'org.freedesktop.DBus',
        member: 'Hello');
  }

  disconnect() async {
    await _socket.close();
  }

  _authenticate() async {
    // Send an empty byte, as this is required if sending the credentials as a socket control message.
    // We rely on the server using SO_PEERCRED to check out credentials.
    _socket.add([0]);

    var uid = _getuid();
    var uidString = '';
    for (var c in uid.toString().runes) {
      uidString += c.toRadixString(16).padLeft(2, '0');
    }
    _socket.write('AUTH EXTERNAL ${uidString}\r\n');

    return _authenticateCompleter.future;
  }

  _processData(Uint8List data) {
    _readBuffer.writeBytes(data);

    var complete = false;
    while (!complete) {
      if (!_authenticateCompleter.isCompleted) {
        complete = _processAuth();
      } else {
        complete = _processMessages();
      }
      _readBuffer.flush();
    }
  }

  bool _processAuth() {
    var line = _readBuffer.readLine();
    if (line == null) return true;

    if (line.startsWith('OK ')) {
      _socket.write('BEGIN\r\n');
      _authenticateCompleter.complete();
    } else {
      throw 'Failed to authenticate: ${line}';
    }

    return false;
  }

  bool _processMessages() {
    var message = DBusMessage();
    var start = _readBuffer.readOffset;
    if (!message.unmarshal(_readBuffer)) {
      _readBuffer.readOffset = start;
      return true;
    }

    if (message.type == MessageType.MethodCall) {
      _processMethodCall(message);
    } else if (message.type == MessageType.MethodReturn ||
        message.type == MessageType.Error) {
      _processMethodReturn(message);
    } else if (message.type == MessageType.Signal) {
      for (var handler in _signalHandlers) {
        handler.callback(
            message.path, message.interface, message.member, message.values);
      }
    }

    return false;
  }

  _processMethodCall(DBusMessage message) async {
    var handler = _findMethodHandler(message.interface);
    if (handler == null) return;

    var result = await handler.callback(
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

  _processMethodReturn(DBusMessage message) {
    var methodCall = _findMethodCall(message.replySerial);
    if (methodCall == null) return;
    _methodCalls.remove(methodCall);

    if (message.type == MessageType.Error) {
      print('Error: ${message.errorName}'); // FIXME
    }
    methodCall.completer.complete(message.values);
  }

  _MethodCall _findMethodCall(int serial) {
    for (var methodCall in _methodCalls) {
      if (methodCall.serial == serial) return methodCall;
    }
    return null;
  }

  _MethodHandler _findMethodHandler(String interface) {
    for (var handler in _methodHandlers) {
      if (handler.interface == interface) return handler;
    }
    return null;
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
    for (var name in (result[0] as DBusArray).children) {
      names.add((name as DBusString).value);
    }
    return names;
  }

  Future<List<String>> listActivatableNames() async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: '/org/freedesktop/DBus',
        interface: 'org.freedesktop.DBus',
        member: 'ListActivatableNames');
    var names = List<String>();
    for (var name in (result[0] as DBusArray).children) {
      names.add((name as DBusString).value);
    }
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

    var call = _MethodCall(message.serial);
    _methodCalls.add(call);

    return call.completer.future;
  }

  _sendMessage(DBusMessage message) {
    var buffer = DBusWriteBuffer();
    message.marshal(buffer);
    _socket.add(buffer.data);
  }
}
