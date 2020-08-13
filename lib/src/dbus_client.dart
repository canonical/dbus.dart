import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'dbus_address.dart';
import 'dbus_introspectable.dart';
import 'dbus_message.dart';
import 'dbus_method_response.dart';
import 'dbus_object.dart';
import 'dbus_object_tree.dart';
import 'dbus_peer.dart';
import 'dbus_properties.dart';
import 'dbus_read_buffer.dart';
import 'dbus_value.dart';
import 'dbus_write_buffer.dart';
import 'getuid.dart';

// FIXME: Use more efficient data store than List<int>?
// FIXME: Use ByteData more efficiently - don't copy when reading/writing

typedef SignalCallback = Function(DBusObjectPath path, String interface,
    String member, List<DBusValue> values);

class _MethodCall {
  int serial;
  var completer = Completer<DBusMethodResponse>();

  _MethodCall(this.serial);
}

/// A subscription to D-Bus signals.
class DBusSignalSubscription {
  /// Senders sibscribed to.
  final String sender;

  /// Interface subscribed to.
  final String interface;

  /// Member subscribed to.
  final String member;

  /// Path subscribed to.
  final DBusObjectPath path;

  /// Function called when signala are received.
  SignalCallback callback;

  /// Creates
  DBusSignalSubscription(
      this.sender, this.interface, this.member, this.path, this.callback);
}

/// A client connection to a D-Bus server.
class DBusClient {
  String _address;
  Socket _socket;
  DBusReadBuffer _readBuffer;
  final _authenticateCompleter = Completer();
  var _lastSerial = 0;
  final _methodCalls = <_MethodCall>[];
  final _signalSubscriptions = <DBusSignalSubscription>[];
  final _objectTree = DBusObjectTree();
  final _matchRules = <String, int>{};
  final _ownedNames = <String, String>{};

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
        var uid = getuid();
        runtimeDir = '/run/user/${uid}';
      }
      address = 'unix:path=${runtimeDir}/bus';
    }
    _address = address;
  }

  /// Disconnects the client from the D-Bus server.
  void disconnect() async {
    await _socket.close();
  }

  /// Requests usage of [name] as a D-Bus object name.
  // FIXME(robert-ancell): Use an enum for flags.
  Future<int> requestName(String name, {int flags = 0}) async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        member: 'RequestName',
        values: [DBusString(name), DBusUint32(flags)]);
    var values = result.returnValues;
    if (values.length != 1 || values[0].signature != DBusSignature('u')) {
      throw 'RequestName returned invalid result: ${values}';
    }
    return (values[0] as DBusUint32).value;
  }

  /// Releases the D-Bus object name previously acquired using requestName().
  Future<int> releaseName(String name) async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        member: 'ReleaseName',
        values: [DBusString(name)]);
    var values = result.returnValues;
    if (values.length != 1 || values[0].signature != DBusSignature('u')) {
      throw 'ReleaseName returned invalid result: ${values}';
    }
    return (result.returnValues[0] as DBusUint32).value;
  }

  /// Lists the registered names on the bus.
  Future<List<String>> listNames() async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        member: 'ListNames');
    var values = result.returnValues;
    if (values.length != 1 || values[0].signature != DBusSignature('as')) {
      throw 'ListNames returned invalid result: ${values}';
    }
    return (values[0] as DBusArray)
        .children
        .map((v) => (v as DBusString).value)
        .toList();
  }

  /// Returns a list of names that activate services.
  Future<List<String>> listActivatableNames() async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        member: 'ListActivatableNames');
    var values = result.returnValues;
    if (values.length != 1 || values[0].signature != DBusSignature('as')) {
      throw 'ListActivatableNames returned invalid result: ${values}';
    }
    return (values[0] as DBusArray)
        .children
        .map((v) => (v as DBusString).value)
        .toList();
  }

  /// Returns true if the [name] is currently registered on the bus.
  Future<bool> nameHasOwner(String name) async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        member: 'NameHasOwner',
        values: [DBusString(name)]);
    var values = result.returnValues;
    if (values.length != 1 || values[0].signature != DBusSignature('b')) {
      throw 'NameHasOwner returned invalid result: ${values}';
    }
    return (values[0] as DBusBoolean).value;
  }

  /// Returns the unique connection name of the client that owns [name].
  Future<String> getNameOwner(String name) async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        member: 'GetNameOwner',
        values: [DBusString(name)]);
    if (result is DBusMethodErrorResponse &&
        result.errorName == 'org.freedesktop.DBus.Error.NameHasNoOwner') {
      return null;
    }
    var values = result.returnValues;
    if (values.length != 1 || values[0].signature != DBusSignature('s')) {
      throw 'GetNameOwner returned invalid result: ${values}';
    }
    return (values[0] as DBusString).value;
  }

  /// Gets the unique ID of the bus.
  Future<String> getId() async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        member: 'GetId');
    var values = result.returnValues;
    if (values.length != 1 || values[0].signature != DBusSignature('s')) {
      throw 'GetId returned invalid result: ${values}';
    }
    return (values[0] as DBusString).value;
  }

  /// Sends a ping request to the client at the given [destination].
  Future ping(String destination) async {
    var result = await callMethod(
        destination: destination,
        path: DBusObjectPath('/'),
        interface: 'org.freedesktop.DBus.Peer',
        member: 'Ping');
    if (result.returnValues.isNotEmpty) {
      throw 'Ping returned invalid result: ${result.returnValues}';
    }
  }

  /// Gets the machine ID of the client at the given [destination].
  Future<String> getMachineId(String destination) async {
    var result = await callMethod(
        destination: destination,
        path: DBusObjectPath('/'),
        interface: 'org.freedesktop.DBus.Peer',
        member: 'GetMachineId');
    var values = result.returnValues;
    if (values.length != 1 || values[0].signature != DBusSignature('s')) {
      throw 'GetMachineId returned invalid result: ${values}';
    }
    return (values[0] as DBusString).value;
  }

  /// Invokes a method on a D-Bus object.
  Future<DBusMethodResponse> callMethod(
      {String destination,
      DBusObjectPath path,
      String interface,
      String member,
      List<DBusValue> values}) async {
    values ??= <DBusValue>[];
    _sendMethodCall(destination, path, interface, member, values);

    var call = _MethodCall(_lastSerial);
    _methodCalls.add(call);

    return call.completer.future;
  }

  /// Subscribe to signals on the D-Bus and call [callback] when one is received.
  ///
  /// Setting [sender], [interface], [member] or [path] will filter signals that match the given values.
  ///
  /// When the subscription is no longer needed call [unsubscribeSignals].
  Future<DBusSignalSubscription> subscribeSignals(SignalCallback callback,
      {String sender,
      String interface,
      String member,
      DBusObjectPath path}) async {
    var subscription =
        DBusSignalSubscription(sender, interface, member, path, callback);

    // Update match rules on the D-Bus server.
    await _addMatch(_makeMatchRule('signal', subscription.sender,
        subscription.interface, subscription.member, subscription.path));

    // Get the unique name of the sender (as this is the name the messages will use).
    if (sender != null && !_ownedNames.containsValue(sender)) {
      var uniqueName = await getNameOwner(sender);
      if (uniqueName != null) {
        _ownedNames[sender] = uniqueName;
      }
    }

    _signalSubscriptions.add(subscription);

    return subscription;
  }

  /// Unsubscribe a [subscription] previously set using [subscribeSignals].
  void unsubscribeSignals(DBusSignalSubscription subscription) async {
    if (!_signalSubscriptions.contains(subscription)) {
      throw 'Attempted to remove unknown signal subscription';
    }

    /// Unsubscribe on the server
    await _removeMatch(_makeMatchRule('signal', subscription.sender,
        subscription.interface, subscription.member, subscription.path));

    _signalSubscriptions.remove(subscription);
  }

  /// Emits a signal from a D-Bus object.
  void emitSignal(
      {String destination,
      DBusObjectPath path,
      String interface,
      String member,
      List<DBusValue> values = const []}) async {
    await _sendSignal(destination, path, interface, member, values);
  }

  /// Registers an [object] on the bus.
  void registerObject(DBusObject object) {
    if (object.client != null) {
      throw 'Client already registered';
    }
    object.client = this;
    _objectTree.add(object.path, object);
  }

  /// Performs authentication with D-Bus server.
  Future<dynamic> _authenticate() async {
    // Send an empty byte, as this is required if sending the credentials as a socket control message.
    // We rely on the server using SO_PEERCRED to check out credentials.
    _socket.add([0]);

    var uid = getuid();
    var uidString = '';
    for (var c in uid.toString().runes) {
      uidString += c.toRadixString(16).padLeft(2, '0');
    }
    _socket.write('AUTH EXTERNAL ${uidString}\r\n');

    return _authenticateCompleter.future;
  }

  /// Connects to the D-Bus server.
  void _connect() async {
    if (_authenticateCompleter.isCompleted) {
      return;
    }

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
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        member: 'Hello');

    // Listen for name ownership changes - we need these to match incoming signals.
    await subscribeSignals(_handleNameOwnerChanged,
        sender: 'org.freedesktop.DBus',
        interface: 'org.freedesktop.DBus',
        member: 'NameOwnerChanged');
  }

  /// Handles the org.freedesktop.DBus.NameOwnerChanged signal and updates the table of known names.
  void _handleNameOwnerChanged(DBusObjectPath path, String interface,
      String member, List<DBusValue> values) {
    if (values.length != 3 ||
        values[0].signature != DBusSignature('s') ||
        values[1].signature != DBusSignature('s') ||
        values[2].signature != DBusSignature('s')) {
      throw 'AddMatch returned invalid result: ${values}';
    }

    var name = (values[0] as DBusString).value;
    var newOwner = (values[2] as DBusString).value;
    if (newOwner != '') {
      _ownedNames[name] = newOwner;
    } else {
      _ownedNames.remove(name);
    }
  }

  /// Match a match rule for the given filter.
  String _makeMatchRule(String type, String sender, String interface,
      String member, DBusObjectPath path) {
    var rules = <String>[];
    rules.add("type='${type}'");
    if (sender != null) {
      rules.add("sender='${sender}'");
    }
    if (interface != null) {
      rules.add("interface='${interface}'");
    }
    if (member != null) {
      rules.add("member='${member}'");
    }
    if (path != null) {
      rules.add("path='${path.value}'");
    }
    return rules.join(',');
  }

  /// Adds a rule to match which messages to receive.
  void _addMatch(String rule) async {
    var count = _matchRules[rule];
    if (count == null) {
      var result = await callMethod(
          destination: 'org.freedesktop.DBus',
          path: DBusObjectPath('/org/freedesktop/DBus'),
          interface: 'org.freedesktop.DBus',
          member: 'AddMatch',
          values: [DBusString(rule)]);
      var values = result.returnValues;
      if (values.isNotEmpty) {
        throw 'AddMatch returned invalid result: ${values}';
      }
      count = 1;
    } else {
      count = count + 1;
    }
    _matchRules[rule] = count;
  }

  /// Removes an existing rule to match which messages to receive.
  void _removeMatch(String rule) async {
    var count = _matchRules[rule];
    if (count == null) {
      throw 'Attempted to remove match that is not added: ${rule}';
    }

    if (count == 1) {
      var result = await callMethod(
          destination: 'org.freedesktop.DBus',
          path: DBusObjectPath('/org/freedesktop/DBus'),
          interface: 'org.freedesktop.DBus',
          member: 'RemoveMatch',
          values: [DBusString(rule)]);
      var values = result.returnValues;
      if (values.isNotEmpty) {
        throw 'RemoveMatch returned invalid result: ${values}';
      }
      _matchRules.remove(rule);
    } else {
      _matchRules[rule] = count - 1;
    }
  }

  /// Processes incoming data from the D-Bus server.
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

  /// Processes authentication messages received from the D-Bus server.
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

  /// Processes messages (method calls/returns/errors/signals) received from the D-Bus server.
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
      _processMethodResponse(message);
    } else if (message.type == MessageType.Signal) {
      _processSignal(message);
    }

    return false;
  }

  /// Processes a method call from the D-Bus server.
  void _processMethodCall(DBusMessage message) async {
    DBusMethodResponse response;
    if (message.interface == 'org.freedesktop.DBus.Introspectable') {
      response = await handleIntrospectableMethodCall(
          _objectTree, message.path, message.member, message.values);
    } else if (message.interface == 'org.freedesktop.DBus.Peer') {
      response = await handlePeerMethodCall(message.member, message.values);
    } else if (message.interface == 'org.freedesktop.DBus.Properties') {
      response = await handlePropertiesMethodCall(
          _objectTree, message.path, message.member, message.values);
    } else {
      var object = _objectTree.lookupObject(message.path);
      if (object != null) {
        response = await object.handleMethodCall(
            message.interface, message.member, message.values);
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

  /// Processes a method return or error result from the D-Bus server.
  void _processMethodResponse(DBusMessage message) {
    var methodCall =
        _methodCalls.firstWhere((c) => c.serial == message.replySerial);
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

  /// Processes a signal received from the D-Bus server.
  void _processSignal(DBusMessage message) {
    for (var subscription in _signalSubscriptions) {
      String makeUnique(String sender) {
        var uniqueSender = _ownedNames[sender];
        if (uniqueSender != null) {
          return uniqueSender;
        }
        return sender;
      }

      var sender = makeUnique(subscription.sender);
      if (sender != null && sender != message.sender) {
        continue;
      }
      if (subscription.interface != null &&
          subscription.interface != message.interface) {
        continue;
      }
      if (subscription.member != null &&
          subscription.member != message.member) {
        continue;
      }
      if (subscription.path != null && subscription.path != message.path) {
        continue;
      }

      subscription.callback(
          message.path, message.interface, message.member, message.values);
    }
  }

  /// Sends a method call to the D-Bus server.
  void _sendMethodCall(String destination, DBusObjectPath path,
      String interface, String member, List<DBusValue> values) async {
    _lastSerial++;
    var message = DBusMessage(
        type: MessageType.MethodCall,
        serial: _lastSerial,
        destination: destination,
        path: path,
        interface: interface,
        member: member,
        values: values);
    await _sendMessage(message);
  }

  /// Sends a method return to the D-Bus server.
  void _sendReturn(
      int serial, String destination, List<DBusValue> values) async {
    _lastSerial++;
    var message = DBusMessage(
        type: MessageType.MethodReturn,
        serial: _lastSerial,
        replySerial: serial,
        destination: destination,
        values: values);
    await _sendMessage(message);
  }

  /// Sends an error to the D-Bus server.
  void _sendError(int serial, String destination, String errorName,
      List<DBusValue> values) async {
    _lastSerial++;
    var message = DBusMessage(
        type: MessageType.Error,
        serial: _lastSerial,
        errorName: errorName,
        replySerial: serial,
        destination: destination,
        values: values);
    await _sendMessage(message);
  }

  /// Sends a signal to the D-Bus server.
  void _sendSignal(String destination, DBusObjectPath path, String interface,
      String member, List<DBusValue> values) async {
    _lastSerial++;
    var message = DBusMessage(
        type: MessageType.Signal,
        serial: _lastSerial,
        destination: destination,
        path: path,
        interface: interface,
        member: member,
        values: values);
    await _sendMessage(message);
  }

  /// Sends a message (method call/return/error/signal) to the D-Bus server.
  void _sendMessage(DBusMessage message) async {
    await _connect();
    var buffer = DBusWriteBuffer();
    message.marshal(buffer);
    _socket.add(buffer.data);
  }
}
