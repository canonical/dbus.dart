import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'dbus_address.dart';
import 'dbus_introspectable.dart';
import 'dbus_message.dart';
import 'dbus_peer.dart';
import 'dbus_read_buffer.dart';
import 'dbus_value.dart';
import 'dbus_write_buffer.dart';

// FIXME: Use more efficient data store than List<int>?
// FIXME: Use ByteData more efficiently - don't copy when reading/writing

/// A response to a method call.
abstract class DBusMethodResponse {
  /// Gets the value returned from this method or throws an exception if an error received.
  List<DBusValue> get returnValues;
}

/// A success response to a method call.
class DBusMethodSuccessResponse extends DBusMethodResponse {
  /// Values returned from the method.
  List<DBusValue> values;

  /// Creates a new success response to a method call returning [values].
  DBusMethodSuccessResponse([this.values = const []]);

  @override
  List<DBusValue> get returnValues => values;
}

class DBusMethodErrorResponse extends DBusMethodResponse {
  /// The name of the error that occurred.
  String errorName;

  /// Additional values passed with the error.
  List<DBusValue> values;

  /// Creates a new error response to a method call with the error [errorName] and optional [values].
  DBusMethodErrorResponse(this.errorName, [this.values = const []]);

  /// Creates a new error response indicating the request failed.
  DBusMethodErrorResponse.failed(String message)
      : this('org.freedesktop.DBus.Error.Failed', [DBusString(message)]);

  /// Creates a new error response indicating an unknown interface.
  DBusMethodErrorResponse.unknownInterface()
      : this('org.freedesktop.DBus.Error.UnknownInterface',
            [DBusString('Object does not implement the interface')]);

  /// Creates a new error response indicating an unknown method.
  DBusMethodErrorResponse.unknownMethod()
      : this('org.freedesktop.DBus.Error.UnknownMethod',
            [DBusString('Unknown / invalid message')]);

  /// Creates a new error response indicating the arguments passed were invalid.
  DBusMethodErrorResponse.invalidArgs()
      : this('org.freedesktop.DBus.Error.InvalidArgs',
            [DBusString('Invalid type / number of args')]);

  @override
  List<DBusValue> get returnValues => throw 'Error: ${errorName}';
}

typedef SignalCallback = Function(
    String path, String interface, String member, List<DBusValue> values);
typedef MethodCallback = Future<DBusMethodResponse> Function(
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
  var completer = Completer<DBusMethodResponse>();

  _MethodCall(this.serial);
}

class _SignalHandler {
  SignalCallback callback;

  _SignalHandler(this.callback);
}

class _MethodHandler {
  String interface;
  MethodCallback callback;

  _MethodHandler(this.interface, this.callback);
}

/// A client connection to a D-Bus server.
class DBusClient {
  String _address;
  Socket _socket;
  DBusReadBuffer _readBuffer;
  final _authenticateCompleter = Completer();
  var _lastSerial = 0;
  final _methodCalls = <_MethodCall>[];
  final _signalHandlers = <_SignalHandler>[];
  final _methodHandlers = <_MethodHandler>[];
  final _objects = <DBusObjectPath>{};

  /// Creates a new DBus client to connect on [address].
  DBusClient(String address) {
    _address = address;
  }

  /// Creates a new DBus client to communicate with the system bus.
  DBusClient.system() {
    var address = Platform.environment['DBUS_SYSTEM_BUS_ADDRESS'];
    address ??= 'unix:path=/run/dbus/system_bus_socket';
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

  void listenSignal(SignalCallback callback) {
    _signalHandlers.add(_SignalHandler(callback));
  }

  void listenMethod(String interface, MethodCallback callback) {
    _methodHandlers.add(_MethodHandler(interface, callback));
  }

  /// Connects to the D-Bus server.
  void connect() async {
    var address = DBusAddress(_address);
    if (address.transport != 'unix') {
      throw 'D-Bus address transport not supported: ${_address}';
    }

    var paths = <String>[];
    for (var property in address.properties) {
      if (property.key == 'path') paths.add(property.value);
    }
    if (paths.isEmpty) {
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

  void disconnect() async {
    await _socket.close();
  }

  Future<dynamic> _authenticate() async {
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

  void _processData(Uint8List data) {
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
        handler.callback(message.path.value, message.interface, message.member,
            message.values);
      }
    }

    return false;
  }

  void _processMethodCall(DBusMessage message) async {
    DBusMethodResponse response;
    if (message.interface == 'org.freedesktop.DBus.Introspectable') {
      response = await handleIntrospectableMethodCall(
          _objects, message.path, message.member, message.values);
    } else if (message.interface == 'org.freedesktop.DBus.Peer') {
      response = await handlePeerMethodCall(message.member, message.values);
    } else if (!_objects.contains(message.path)) {
      response = DBusMethodErrorResponse.unknownInterface();
    } else {
      var handler = _findMethodHandler(message.interface);
      if (handler != null) {
        response = await handler.callback(message.path.value, message.interface,
            message.member, message.values);
      } else {
        response = DBusMethodErrorResponse.unknownInterface();
      }
    }

    if (response is DBusMethodErrorResponse) {
      _sendError(
          message.serial, message.sender, response.errorName, response.values);
    } else if (response is DBusMethodSuccessResponse) {
      _sendReturn(message.serial, message.sender, response.values);
    }
  }

  void _processMethodReturn(DBusMessage message) {
    var methodCall = _findMethodCall(message.replySerial);
    if (methodCall == null) return;
    _methodCalls.remove(methodCall);

    DBusMethodResponse response;
    if (message.type == MessageType.Error) {
      response = DBusMethodErrorResponse(message.errorName, message.values);
    } else {
      response = DBusMethodSuccessResponse(message.values);
    }
    methodCall.completer.complete(response);
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
    return (result.returnValues[0] as DBusUint32).value;
  }

  /// Releases the D-Bus object name previously acquired using requestName().
  Future<int> releaseName(String name) async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: '/org/freedesktop/DBus',
        interface: 'org.freedesktop.DBus',
        member: 'ReleaseName',
        values: [DBusString(name)]);
    return (result.returnValues[0] as DBusUint32).value;
  }

  /// Lists the registered names on the bus.
  Future<List<String>> listNames() async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: '/org/freedesktop/DBus',
        interface: 'org.freedesktop.DBus',
        member: 'ListNames');
    var names = <String>[];
    for (var name in (result.returnValues[0] as DBusArray).children) {
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
    var names = <String>[];
    for (var name in (result.returnValues[0] as DBusArray).children) {
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
    return (result.returnValues[0] as DBusBoolean).value;
  }

  void addMatch(String rule) async {
    await callMethod(
        destination: 'org.freedesktop.DBus',
        path: '/org/freedesktop/DBus',
        interface: 'org.freedesktop.DBus',
        member: 'AddMatch',
        values: [DBusString(rule)]);
  }

  void removeMatch(String rule) async {
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
    return (result.returnValues[0] as DBusString).value;
  }

  void peerPing(String destination, String path) async {
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
    return (result.returnValues[0] as DBusString).value;
  }

  /// Invokes a method on a D-Bus object.
  Future<DBusMethodResponse> callMethod(
      {String destination,
      String path,
      String interface,
      String member,
      List<DBusValue> values}) async {
    values ??= <DBusValue>[];
    _sendMethodCall(destination, path, interface, member, values);

    var call = _MethodCall(_lastSerial);
    _methodCalls.add(call);

    return call.completer.future;
  }

  /// Emits a signal from a D-Bus object.
  void emitSignal(
      {String destination,
      String path,
      String interface,
      String member,
      List<DBusValue> values}) {
    _sendSignal(destination, path, interface, member, values);
  }

  /// Registers a new object on the bus with the given [path].
  void registerObject(String path) {
    _objects.add(DBusObjectPath(path));
  }

  void _sendMethodCall(String destination, String path, String interface,
      String member, List<DBusValue> values) {
    _lastSerial++;
    var message = DBusMessage(
        type: MessageType.MethodCall,
        serial: _lastSerial,
        destination: destination,
        path: DBusObjectPath(path),
        interface: interface,
        member: member,
        values: values);
    _sendMessage(message);
  }

  void _sendSignal(String destination, String path, String interface,
      String member, List<DBusValue> values) {
    _lastSerial++;
    var message = DBusMessage(
        type: MessageType.Signal,
        serial: _lastSerial,
        destination: destination,
        path: DBusObjectPath(path),
        interface: interface,
        member: member,
        values: values);
    _sendMessage(message);
  }

  void _sendError(int serial, String destination, String errorName,
      List<DBusValue> values) {
    _lastSerial++;
    var message = DBusMessage(
        type: MessageType.Error,
        serial: _lastSerial,
        errorName: errorName,
        replySerial: serial,
        destination: destination,
        values: values);
    _sendMessage(message);
  }

  void _sendReturn(int serial, String destination, List<DBusValue> values) {
    _lastSerial++;
    var message = DBusMessage(
        type: MessageType.MethodReturn,
        serial: _lastSerial,
        replySerial: serial,
        destination: destination,
        values: values);
    _sendMessage(message);
  }

  void _sendMessage(DBusMessage message) {
    var buffer = DBusWriteBuffer();
    message.marshal(buffer);
    _socket.add(buffer.data);
  }
}
