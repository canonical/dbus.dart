import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'dbus_address.dart';
import 'dbus_introspectable.dart';
import 'dbus_match_rule.dart';
import 'dbus_message.dart';
import 'dbus_method_call.dart';
import 'dbus_method_response.dart';
import 'dbus_object.dart';
import 'dbus_object_tree.dart';
import 'dbus_peer.dart';
import 'dbus_properties.dart';
import 'dbus_read_buffer.dart';
import 'dbus_signal.dart';
import 'dbus_value.dart';
import 'dbus_write_buffer.dart';
import 'getuid.dart';

// FIXME: Use more efficient data store than List<int>?
// FIXME: Use ByteData more efficiently - don't copy when reading/writing

/// Reply received when calling [DBusClient.requestName].
enum DBusRequestNameReply { primaryOwner, inQueue, exists, alreadyOwner }

/// Flags passed to [DBusClient.requestName].
enum DBusRequestNameFlag { allowReplacement, replaceExisting, doNotQueue }

/// Reply received when calling [DBusClient.releaseName].
enum DBusReleaseNameReply { released, nonExistant, notOwner }

class _DBusSignalSubscription {
  final DBusClient client;
  final DBusMatchRule rule;
  final controller = StreamController<DBusSignal>();

  Stream<DBusSignal> get stream => controller.stream;

  _DBusSignalSubscription(this.client, String? sender, String? interface,
      String? member, DBusObjectPath? path, DBusObjectPath? pathNamespace)
      : rule = DBusMatchRule(
            type: DBusMessageType.signal,
            sender: sender,
            interface: interface,
            member: member,
            path: path,
            pathNamespace: pathNamespace) {
    controller.onListen = onListen;
    controller.onCancel = onCancel;
  }

  void onListen() {
    client._addMatch(rule.toDBusString());
  }

  Future<void> onCancel() async {
    await client._removeMatch(rule.toDBusString());
    client._signalSubscriptions.remove(this);
  }
}

/// A client connection to a D-Bus server.
class DBusClient {
  late final String _address;
  Socket? _socket;
  final _readBuffer = DBusReadBuffer();
  final _authenticateCompleter = Completer();
  Completer? _connectCompleter;
  var _lastSerial = 0;
  final _methodCalls = <int, Completer<DBusMethodResponse>>{};
  final _signalSubscriptions = <_DBusSignalSubscription>[];
  StreamSubscription<DBusSignal>? _nameAcquiredSubscription;
  StreamSubscription<DBusSignal>? _nameLostSubscription;
  StreamSubscription<DBusSignal>? _nameOwnerSubscription;
  final _objectTree = DBusObjectTree();
  final _matchRules = <String, int>{};

  // Maps D-Bus names (e.g. 'org.freedesktop.DBus') to unique names (e.g. ':1').
  final _nameOwners = <String, String>{};

  // Names owned by this client. e.g. [ 'com.example.Foo', 'com.example.Bar' ].
  final _ownedNames = <String>{};

  // Unique name of this client, e.g. ':42'.
  String? _uniqueName;
  final _nameAcquiredController = StreamController<String>();
  final _nameLostController = StreamController<String>();

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
        runtimeDir = '/run/user/$uid';
      }
      address = 'unix:path=$runtimeDir/bus';
    }
    _address = address;
  }

  /// Terminates all active connections. If a client remains unclosed, the Dart process may not terminate.
  Future<void> close() async {
    if (_nameAcquiredSubscription != null) {
      await _nameAcquiredSubscription?.cancel();
    }
    if (_nameLostSubscription != null) {
      await _nameLostSubscription?.cancel();
    }
    if (_nameOwnerSubscription != null) {
      await _nameOwnerSubscription?.cancel();
    }
    if (_socket != null) {
      await _socket?.close();
    }
  }

  /// Gets the unique name this connection uses.
  String get uniqueName => _uniqueName ?? '';

  /// Gets the names owned by this connection.
  Iterable<String> get ownedNames => _ownedNames;

  /// Stream of names as they are acquired by this client.
  Stream<String> get nameAcquired => _nameAcquiredController.stream;

  /// Stream of names as this client loses them.
  Stream<String> get nameLost => _nameLostController.stream;

  /// Requests usage of [name] as a D-Bus object name.
  Future<DBusRequestNameReply> requestName(String name,
      {Set<DBusRequestNameFlag> flags = const {}}) async {
    var flagsValue = 0;
    for (var flag in flags) {
      switch (flag) {
        case DBusRequestNameFlag.allowReplacement:
          flagsValue |= 0x1;
          break;
        case DBusRequestNameFlag.replaceExisting:
          flagsValue |= 0x2;
          break;
        case DBusRequestNameFlag.doNotQueue:
          flagsValue |= 0x4;
          break;
      }
    }
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        member: 'RequestName',
        values: [DBusString(name), DBusUint32(flagsValue)]);
    if (result.signature != DBusSignature('u')) {
      throw 'org.freedesktop.DBus.RequestName returned invalid result: ${result.returnValues}';
    }
    var returnCode = (result.returnValues[0] as DBusUint32).value;
    switch (returnCode) {
      case 1:
        _ownedNames.add(name);
        return DBusRequestNameReply.primaryOwner;
      case 2:
        return DBusRequestNameReply.inQueue;
      case 3:
        return DBusRequestNameReply.exists;
      case 4:
        return DBusRequestNameReply.alreadyOwner;
      default:
        throw 'org.freedesktop.DBusRequestName returned unknown return code: $returnCode';
    }
  }

  /// Releases the D-Bus object name previously acquired using requestName().
  Future<DBusReleaseNameReply> releaseName(String name) async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        member: 'ReleaseName',
        values: [DBusString(name)]);
    if (result.signature != DBusSignature('u')) {
      throw 'org.freedesktop.DBus.ReleaseName returned invalid result: ${result.returnValues}';
    }
    var returnCode = (result.returnValues[0] as DBusUint32).value;
    switch (returnCode) {
      case 1:
        _ownedNames.remove(name);
        return DBusReleaseNameReply.released;
      case 2:
        return DBusReleaseNameReply.nonExistant;
      case 3:
        return DBusReleaseNameReply.notOwner;
      default:
        throw 'org.freedesktop.DBus.ReleaseName returned unknown return code: $returnCode';
    }
  }

  /// Lists the unique bus names of the clients queued to own the well-known bus [name].
  Future<List<String>> listQueuedOwners(String name) async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        member: 'ListQueuedOwners',
        values: [DBusString(name)]);
    if (result.signature != DBusSignature('as')) {
      throw 'org.freedesktop.DBus.ListQueuedOwners returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusArray)
        .children
        .map((v) => (v as DBusString).value)
        .toList();
  }

  /// Lists the registered names on the bus.
  Future<List<String>> listNames() async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        member: 'ListNames');
    if (result.signature != DBusSignature('as')) {
      throw 'org.freedesktop.DBus.ListNames returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusArray)
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
    if (result.signature != DBusSignature('as')) {
      throw 'org.freedesktop.DBus.ListActivatableNames returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusArray)
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
    if (result.signature != DBusSignature('b')) {
      throw 'org.freedesktop.DBus.NameHasOwner returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusBoolean).value;
  }

  /// Returns the unique connection name of the client that owns [name].
  Future<String?> getNameOwner(String name) async {
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
    if (result.signature != DBusSignature('s')) {
      throw 'org.freedesktop.DBus.GetNameOwner returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusString).value;
  }

  /// Gets the unique ID of the bus.
  Future<String> getId() async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        member: 'GetId');
    if (result.signature != DBusSignature('s')) {
      throw 'org.freedesktop.DBus.GetId returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusString).value;
  }

  /// Sends a ping request to the client at the given [destination].
  /// If [destination] is not set, pings the D-Bus server.
  Future<void> ping([String destination = 'org.freedesktop.DBus']) async {
    var result = await callMethod(
        destination: destination,
        path: DBusObjectPath('/'),
        interface: 'org.freedesktop.DBus.Peer',
        member: 'Ping');
    if (result.returnValues.isNotEmpty) {
      throw 'org.freedesktop.DBus.Peer.Ping returned invalid result: ${result.returnValues}';
    }
  }

  /// Gets the machine ID of the client at the given [destination].
  /// If [destination] is not set, gets the machine the D-Bus server is running on.
  Future<String> getMachineId(
      [String destination = 'org.freedesktop.DBus']) async {
    var result = await callMethod(
        destination: destination,
        path: DBusObjectPath('/'),
        interface: 'org.freedesktop.DBus.Peer',
        member: 'GetMachineId');
    if (result.signature != DBusSignature('s')) {
      throw 'org.freedesktop.DBus.Peer.GetMachineId returned invalid result: ${result.returnValues}';
    }
    return (result.returnValues[0] as DBusString).value;
  }

  /// Invokes a method on a D-Bus object.
  Future<DBusMethodResponse> callMethod(
      {String? destination,
      @required DBusObjectPath? path,
      String? interface,
      @required String? member,
      Iterable<DBusValue> values = const []}) async {
    return await _callMethod(destination, path!, interface, member!, values);
  }

  /// Subscribe to signals that match [sender], [interface], [member], [path] and/or [pathNamespace].
  Stream<DBusSignal> subscribeSignals({
    String? sender,
    String? interface,
    String? member,
    DBusObjectPath? path,
    DBusObjectPath? pathNamespace,
  }) {
    var subscription = _DBusSignalSubscription(
        this, sender, interface, member, path, pathNamespace);

    // Get the unique name of the sender (as this is the name the messages will use).
    if (sender != null) {
      _findUniqueName(sender);
    }

    _signalSubscriptions.add(subscription);

    return subscription.stream;
  }

  /// Find the unique name for a D-Bus client.
  Future<String?> _findUniqueName(String name) async {
    if (_nameOwners.containsValue(name)) return _nameOwners[name];

    var uniqueName = await getNameOwner(name);
    if (uniqueName != null) {
      _nameOwners[name] = uniqueName;
    }

    return uniqueName;
  }

  /// Emits a signal from a D-Bus object.
  Future<void> emitSignal(
      {String? destination,
      @required DBusObjectPath? path,
      @required String? interface,
      @required String? member,
      Iterable<DBusValue> values = const []}) async {
    await _sendSignal(destination, path!, interface!, member!, values);
  }

  /// Registers an [object] on the bus.
  Future<void> registerObject(DBusObject object) async {
    if (object.client != null) {
      throw 'Client already registered';
    }
    object.client = this;
    _objectTree.add(object.path, object);
    await _connect();
  }

  /// Open a socket connection to the D-Bus server.
  Future<void> _openSocket() async {
    var address = DBusAddress.fromString(_address);
    if (address.transport != 'unix') {
      throw 'D-Bus address transport not supported: $_address';
    }

    var paths = <String>[];
    for (var property in address.properties) {
      if (property.key == 'path') {
        paths.add(property.value);
      }
    }
    if (paths.isEmpty) {
      throw 'Unable to determine D-Bus unix address path: $_address';
    }

    var socket_address =
        InternetAddress(paths[0], type: InternetAddressType.unix);
    _socket = await Socket.connect(socket_address, 0);
    _socket?.listen(_processData);
  }

  /// Performs authentication with D-Bus server.
  Future<dynamic> _authenticate() async {
    // Send an empty byte, as this is required if sending the credentials as a socket control message.
    // We rely on the server using SO_PEERCRED to check out credentials.
    _socket?.add([0]);

    var uid = getuid();
    var uidString = '';
    for (var c in uid.toString().runes) {
      uidString += c.toRadixString(16).padLeft(2, '0');
    }
    _socket?.write('AUTH EXTERNAL $uidString\r\n');

    return _authenticateCompleter.future;
  }

  /// Connects to the D-Bus server.
  Future<void> _connect() async {
    // If already connecting, wait for that to complete.
    if (_connectCompleter != null) {
      return _connectCompleter?.future;
    }
    _connectCompleter = Completer();

    await _openSocket();
    await _authenticate();

    // The first message to the bus must be this call, note requireConnect is
    // false as the _connect call hasn't yet completed and would otherwise have
    // been called again.
    var result = await _callMethod(
        'org.freedesktop.DBus',
        DBusObjectPath('/org/freedesktop/DBus'),
        'org.freedesktop.DBus',
        'Hello',
        [],
        requireConnect: false);
    if (result.signature != DBusSignature('s')) {
      throw 'org.freedesktop.DBus.Hello returned invalid result: ${result.returnValues}';
    }
    _uniqueName = (result.returnValues[0] as DBusString).value;

    // Notify anyone else awaiting connection.
    _connectCompleter?.complete();

    // Monitor name ownership so we know what names we have, and can match incoming signals from other clients.
    var nameAcquiredSignals = subscribeSignals(
        sender: 'org.freedesktop.DBus',
        interface: 'org.freedesktop.DBus',
        member: 'NameAcquired');
    _nameAcquiredSubscription = nameAcquiredSignals.listen(_handleNameAcquired);
    var nameLostSignals = subscribeSignals(
        sender: 'org.freedesktop.DBus',
        interface: 'org.freedesktop.DBus',
        member: 'NameLost');
    _nameLostSubscription = nameLostSignals.listen(_handleNameLost);
    var nameOwnerChangedSignals = subscribeSignals(
        sender: 'org.freedesktop.DBus',
        interface: 'org.freedesktop.DBus',
        member: 'NameOwnerChanged');
    _nameOwnerSubscription =
        nameOwnerChangedSignals.listen(_handleNameOwnerChanged);
  }

  /// Handles the org.freedesktop.DBus.NameAcquired signal.
  void _handleNameAcquired(DBusSignal signal) {
    if (signal.signature != DBusSignature('s')) {
      throw 'org.freedesktop.DBus.NameAcquired received with invalid arguments: ${signal.values}';
    }

    var name = (signal.values[0] as DBusString).value;

    _nameOwners[name] = _uniqueName!;
    _ownedNames.add(name);

    _nameAcquiredController.add(name);
  }

  /// Handles the org.freedesktop.DBus.NameLost signal.
  void _handleNameLost(DBusSignal signal) {
    if (signal.signature != DBusSignature('s')) {
      throw 'org.freedesktop.DBus.NameLost received with invalid arguments: ${signal.values}';
    }

    var name = (signal.values[0] as DBusString).value;

    _nameOwners.remove(name);
    _ownedNames.remove(name);

    _nameLostController.add(name);
  }

  /// Handles the org.freedesktop.DBus.NameOwnerChanged signal and updates the table of known names.
  void _handleNameOwnerChanged(DBusSignal signal) {
    if (signal.signature != DBusSignature('sss')) {
      throw 'org.freedesktop.DBus.NameOwnerChanged received with invalid arguments: ${signal.values}';
    }

    var name = (signal.values[0] as DBusString).value;
    var newOwner = (signal.values[2] as DBusString).value;
    if (newOwner != '') {
      _nameOwners[name] = newOwner;
    } else {
      _nameOwners.remove(name);
    }
  }

  /// Adds a rule to match which messages to receive.
  Future<void> _addMatch(String rule) async {
    var count = _matchRules[rule];
    if (count == null) {
      var result = await callMethod(
          destination: 'org.freedesktop.DBus',
          path: DBusObjectPath('/org/freedesktop/DBus'),
          interface: 'org.freedesktop.DBus',
          member: 'AddMatch',
          values: [DBusString(rule)]);
      if (result.returnValues.isNotEmpty) {
        throw 'org.freedesktop.DBus.AddMatch returned invalid result: ${result.returnValues}';
      }
      count = 1;
    } else {
      count = count + 1;
    }
    _matchRules[rule] = count;
  }

  /// Removes an existing rule to match which messages to receive.
  Future<void> _removeMatch(String rule) async {
    var count = _matchRules[rule];
    if (count == null) {
      throw 'Attempted to remove match that is not added: $rule';
    }

    if (count == 1) {
      var result = await callMethod(
          destination: 'org.freedesktop.DBus',
          path: DBusObjectPath('/org/freedesktop/DBus'),
          interface: 'org.freedesktop.DBus',
          member: 'RemoveMatch',
          values: [DBusString(rule)]);
      if (result.returnValues.isNotEmpty) {
        throw 'org.freedesktop.DBus.RemoveMatch returned invalid result: ${result.returnValues}';
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
    if (line == null) {
      return true;
    }

    if (line.startsWith('OK ')) {
      _socket?.write('BEGIN\r\n');
      _authenticateCompleter.complete();
    } else {
      throw 'Failed to authenticate: $line';
    }

    return false;
  }

  /// Processes messages (method calls/returns/errors/signals) received from the D-Bus server.
  bool _processMessages() {
    var start = _readBuffer.readOffset;
    var message = _readBuffer.readMessage();
    if (message == null) {
      _readBuffer.readOffset = start;
      return true;
    }

    if (message.type == DBusMessageType.methodCall) {
      _processMethodCall(message);
    } else if (message.type == DBusMessageType.methodReturn ||
        message.type == DBusMessageType.error) {
      _processMethodResponse(message);
    } else if (message.type == DBusMessageType.signal) {
      _processSignal(message);
    }

    return false;
  }

  /// Processes a method call from the D-Bus server.
  Future<void> _processMethodCall(DBusMessage message) async {
    DBusMethodResponse response;
    if (message.member == null) {
      response = DBusMethodErrorResponse.unknownMethod();
    } else if (message.path == null) {
      response = DBusMethodErrorResponse.unknownObject();
    } else if (message.interface == 'org.freedesktop.DBus.Introspectable') {
      response = handleIntrospectableMethodCall(
          _objectTree, message.path!, message.member!, message.values);
    } else if (message.interface == 'org.freedesktop.DBus.Peer') {
      response = await handlePeerMethodCall(message.member!, message.values);
    } else if (message.interface == 'org.freedesktop.DBus.Properties') {
      response = await handlePropertiesMethodCall(
          _objectTree, message.path!, message.member!, message.values);
    } else {
      var object = _objectTree.lookupObject(message.path!);
      if (object != null) {
        var methodCall = DBusMethodCall(message.sender ?? '', message.interface,
            message.member ?? '', message.values);
        response = await object.handleMethodCall(methodCall);
      } else {
        response = DBusMethodErrorResponse.unknownInterface();
      }
    }

    if (response is DBusMethodErrorResponse) {
      await _sendError(
          message.serial, message.sender, response.errorName, response.values);
    } else if (response is DBusMethodSuccessResponse) {
      await _sendReturn(message.serial, message.sender, response.values);
    }
  }

  /// Processes a method return or error result from the D-Bus server.
  void _processMethodResponse(DBusMessage message) {
    // Check has required fields.
    if (message.replySerial == null) {
      return;
    }

    var completer = _methodCalls[message.replySerial];
    if (completer == null) {
      return;
    }
    _methodCalls.remove(message.replySerial);

    DBusMethodResponse response;
    if (message.type == DBusMessageType.error) {
      response = DBusMethodErrorResponse(
          message.errorName ?? '(missing error name)', message.values);
    } else {
      response = DBusMethodSuccessResponse(message.values);
    }
    completer.complete(response);
  }

  /// Processes a signal received from the D-Bus server.
  void _processSignal(DBusMessage message) {
    // Check has required fields.
    if (message.path == null ||
        message.interface == null ||
        message.member == null) {
      return;
    }

    for (var subscription in _signalSubscriptions) {
      // If the subscription is for an owned name, check if that matches the unique name in the message.
      var sender = message.sender;
      if (_nameOwners[subscription.rule.sender] == sender) {
        sender = subscription.rule.sender;
      }

      if (!subscription.rule.match(
          type: DBusMessageType.signal,
          sender: sender,
          interface: message.interface,
          member: message.member,
          path: message.path)) {
        continue;
      }

      subscription.controller.add(DBusSignal(
          message.sender ?? '',
          message.path ?? DBusObjectPath('/'),
          message.interface ?? '',
          message.member ?? '',
          message.values));
    }
  }

  /// Invokes a method on a D-Bus object.
  Future<DBusMethodResponse> _callMethod(
      String? destination,
      DBusObjectPath path,
      String? interface,
      String member,
      Iterable<DBusValue> values,
      {bool requireConnect = true}) async {
    _lastSerial++;
    var serial = _lastSerial;
    var completer = Completer<DBusMethodResponse>();
    _methodCalls[serial] = completer;

    await _sendMethodCall(serial, destination, path, interface, member, values,
        requireConnect: requireConnect);

    return completer.future;
  }

  /// Sends a method call to the D-Bus server.
  Future<void> _sendMethodCall(
      int serial,
      String? destination,
      DBusObjectPath path,
      String? interface,
      String member,
      Iterable<DBusValue> values,
      {bool requireConnect = true}) async {
    var message = DBusMessage(DBusMessageType.methodCall,
        serial: _lastSerial,
        destination: destination,
        path: path,
        interface: interface,
        member: member,
        values: values.toList());
    await _sendMessage(message, requireConnect: requireConnect);
  }

  /// Sends a method return to the D-Bus server.
  Future<void> _sendReturn(
      int serial, String? destination, Iterable<DBusValue> values) async {
    _lastSerial++;
    var message = DBusMessage(DBusMessageType.methodReturn,
        serial: _lastSerial,
        replySerial: serial,
        destination: destination,
        values: values.toList());
    await _sendMessage(message);
  }

  /// Sends an error to the D-Bus server.
  Future<void> _sendError(int serial, String? destination, String errorName,
      Iterable<DBusValue> values) async {
    _lastSerial++;
    var message = DBusMessage(DBusMessageType.error,
        serial: _lastSerial,
        errorName: errorName,
        replySerial: serial,
        destination: destination,
        values: values.toList());
    await _sendMessage(message);
  }

  /// Sends a signal to the D-Bus server.
  Future<void> _sendSignal(String? destination, DBusObjectPath path,
      String interface, String member, Iterable<DBusValue> values) async {
    _lastSerial++;
    var message = DBusMessage(DBusMessageType.signal,
        serial: _lastSerial,
        destination: destination,
        path: path,
        interface: interface,
        member: member,
        values: values.toList());
    await _sendMessage(message);
  }

  /// Sends a message (method call/return/error/signal) to the D-Bus server.
  Future<void> _sendMessage(DBusMessage message,
      {bool requireConnect = true}) async {
    if (requireConnect) {
      await _connect();
    }
    var buffer = DBusWriteBuffer();
    buffer.writeMessage(message);
    _socket?.add(buffer.data);
  }

  @override
  String toString() {
    return "DBusClient('$_address')";
  }
}
