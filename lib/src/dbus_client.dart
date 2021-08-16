import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'dbus_address.dart';
import 'dbus_auth_client.dart';
import 'dbus_bus_name.dart';
import 'dbus_error_name.dart';
import 'dbus_interface_name.dart';
import 'dbus_introspectable.dart';
import 'dbus_match_rule.dart';
import 'dbus_member_name.dart';
import 'dbus_message.dart';
import 'dbus_method_call.dart';
import 'dbus_method_response.dart';
import 'dbus_object.dart';
import 'dbus_object_manager.dart';
import 'dbus_object_tree.dart';
import 'dbus_peer.dart';
import 'dbus_properties.dart';
import 'dbus_read_buffer.dart';
import 'dbus_signal.dart';
import 'dbus_value.dart';
import 'dbus_write_buffer.dart';
import 'getuid.dart';

/// Reply received when calling [DBusClient.requestName].
enum DBusRequestNameReply { primaryOwner, inQueue, exists, alreadyOwner }

/// Flags passed to [DBusClient.requestName].
enum DBusRequestNameFlag { allowReplacement, replaceExisting, doNotQueue }

/// Reply received when calling [DBusClient.releaseName].
enum DBusReleaseNameReply { released, nonExistant, notOwner }

/// Reply received when calling [DBusClient.startServiceByName].
enum DBusStartServiceByNameReply { success, alreadyRunning }

/// Credentials returned in [DBusClient.getConnectionCredentials].
class DBusProcessCredentials {
  /// Unix user ID, if known.
  final int? unixUserId;

  /// Unix group IDs, if known.
  final List<int>? unixGroupIds;

  /// Process ID, if known.
  final int? processId;

  /// Windows security identifier, if known.
  final String? windowsSid;

  /// Security label, if known and format dependant on the security system in use.
  final List<int>? linuxSecurityLabel;

  /// Non-standard credentials.
  final Map<String, DBusValue> otherCredentials;

  const DBusProcessCredentials(
      {this.unixUserId,
      this.unixGroupIds,
      this.processId,
      this.windowsSid,
      this.linuxSecurityLabel,
      this.otherCredentials = const {}});

  @override
  String toString() {
    var parameters = <String, String?>{
      'unixUserId': unixUserId?.toString(),
      'unixGroupIds': unixGroupIds?.toString(),
      'processId': processId?.toString(),
      'windowsSid': windowsSid?.toString(),
      'linuxSecurityLabel': linuxSecurityLabel?.toString(),
      'otherCredentials':
          otherCredentials.isNotEmpty ? otherCredentials.toString() : null
    };
    return 'DBusProcessCredentials(' +
        parameters.keys
            .where((key) => parameters[key] != null)
            .map((key) => '$key=${parameters[key]}')
            .join(', ') +
        ')';
  }
}

/// A stream of signals.
class DBusSignalStream extends Stream<DBusSignal> {
  final DBusClient _client;
  final DBusMatchRule _rule;
  final DBusSignature? _signature;
  final _controller = StreamController<DBusSignal>();

  /// Creates a stream of signals that match [sender], [interface], [name], [path] and/or [pathNamespace].
  ///
  /// If [signature] is provided this causes the stream to throw a
  /// [DBusSignalSignatureException] if a signal is received that does not
  /// match the provided signature.
  DBusSignalStream(DBusClient client,
      {String? sender,
      String? interface,
      String? name,
      DBusObjectPath? path,
      DBusObjectPath? pathNamespace,
      DBusSignature? signature})
      : _client = client,
        _rule = DBusMatchRule(
            type: DBusMessageType.signal,
            sender: sender != null ? DBusBusName(sender) : null,
            interface: interface != null ? DBusInterfaceName(interface) : null,
            member: name != null ? DBusMemberName(name) : null,
            path: path,
            pathNamespace: pathNamespace),
        _signature = signature {
    _controller.onListen = _onListen;
    _controller.onCancel = _onCancel;
  }

  @override
  StreamSubscription<DBusSignal> listen(
      void Function(DBusSignal signal)? onData,
      {Function? onError,
      void Function()? onDone,
      bool? cancelOnError}) {
    _client._signalStreams.add(this);
    return _controller.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  void _onListen() {
    if (_rule.sender != null) {
      _client._findUniqueName(_rule.sender!);
    }
    _client._addMatch(_rule.toDBusString());
  }

  Future<void> _onCancel() async {
    await _client._removeMatch(_rule.toDBusString());
    _client._signalStreams.remove(this);
  }
}

/// Exception thrown when a D-Bus method call returns values that don't match the expected signature.
class DBusReplySignatureException implements Exception {
  /// The name of the method call.
  final String methodName;

  /// The response that generated the exception.
  final DBusMethodSuccessResponse response;

  DBusReplySignatureException(this.methodName, this.response);

  @override
  String toString() {
    return '$methodName returned invalid values: ${response.returnValues}';
  }
}

/// Exception thrown when a D-Bus signal contains values that don't match the expected signature.
class DBusSignalSignatureException implements Exception {
  /// The name of the signal.
  final String signalName;

  /// The signal that generated the exception.
  final DBusSignal signal;

  DBusSignalSignatureException(this.signalName, this.signal);

  @override
  String toString() {
    return '$signalName received with invalid values: ${signal.values}';
  }
}

/// A client connection to a D-Bus server.
class DBusClient {
  final DBusAddress _address;
  Socket? _socket;
  final _readBuffer = DBusReadBuffer();
  final _authClient = DBusAuthClient();
  Completer? _connectCompleter;
  var _lastSerial = 0;
  final _methodCalls = <int, Completer<DBusMethodResponse>>{};
  final _signalStreams = <DBusSignalStream>[];
  StreamSubscription<DBusSignal>? _nameAcquiredSubscription;
  StreamSubscription<DBusSignal>? _nameLostSubscription;
  StreamSubscription<DBusSignal>? _nameOwnerSubscription;
  final _objectTree = DBusObjectTree();
  final _matchRules = <String, int>{};

  // Maps D-Bus names (e.g. 'org.freedesktop.DBus') to unique names (e.g. ':1').
  final _nameOwners = <DBusBusName, DBusBusName>{};

  // Names owned by this client. e.g. [ 'com.example.Foo', 'com.example.Bar' ].
  final _ownedNames = <DBusBusName>{};

  // Unique name of this client, e.g. ':42'.
  DBusBusName? _uniqueName;
  final _nameAcquiredController = StreamController<String>();
  final _nameLostController = StreamController<String>();

  /// True if this client allows other clients to introspect it.
  final bool introspectable;

  /// Creates a new DBus client to connect on [address].
  DBusClient(DBusAddress address, {this.introspectable = true})
      : _address = address;

  /// Creates a new DBus client to communicate with the system bus.
  factory DBusClient.system({bool introspectable = true}) {
    var address = Platform.environment['DBUS_SYSTEM_BUS_ADDRESS'];
    return DBusClient(
        DBusAddress(address ??= 'unix:path=/var/run/dbus/system_bus_socket'),
        introspectable: introspectable);
  }

  /// Creates a new DBus client to communicate with the session bus.
  factory DBusClient.session({bool introspectable = true}) {
    var address = Platform.environment['DBUS_SESSION_BUS_ADDRESS'];
    if (address == null) {
      var runtimeDir = Platform.environment['XDG_USER_DIR'];
      if (runtimeDir == null) {
        var uid = getuid();
        runtimeDir = '/run/user/$uid';
      }
      address = 'unix:path=$runtimeDir/bus';
    }
    return DBusClient(DBusAddress(address), introspectable: introspectable);
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
  String get uniqueName => _uniqueName?.value ?? '';

  /// Gets the names owned by this connection.
  Iterable<String> get ownedNames => _ownedNames.map((name) => name.value);

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
        name: 'RequestName',
        values: [DBusString(name), DBusUint32(flagsValue)],
        replySignature: DBusSignature('u'));
    var returnCode = (result.returnValues[0] as DBusUint32).value;
    switch (returnCode) {
      case 1:
        _ownedNames.add(DBusBusName(name));
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
        name: 'ReleaseName',
        values: [DBusString(name)],
        replySignature: DBusSignature('u'));
    var returnCode = (result.returnValues[0] as DBusUint32).value;
    switch (returnCode) {
      case 1:
        _ownedNames.remove(DBusBusName(name));
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
        name: 'ListQueuedOwners',
        values: [DBusString(name)],
        replySignature: DBusSignature('as'));
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
        name: 'ListNames',
        replySignature: DBusSignature('as'));
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
        name: 'ListActivatableNames',
        replySignature: DBusSignature('as'));
    return (result.returnValues[0] as DBusArray)
        .children
        .map((v) => (v as DBusString).value)
        .toList();
  }

  /// Starts the service with [name].
  Future<DBusStartServiceByNameReply> startServiceByName(String name) async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        name: 'StartServiceByName',
        values: [DBusString(name), DBusUint32(0)],
        replySignature: DBusSignature('u'));
    var returnCode = (result.returnValues[0] as DBusUint32).value;
    switch (returnCode) {
      case 1:
        return DBusStartServiceByNameReply.success;
      case 2:
        return DBusStartServiceByNameReply.alreadyRunning;
      default:
        throw 'org.freedesktop.DBus.StartServiceByName returned unknown return code: $returnCode';
    }
  }

  /// Returns true if the [name] is currently registered on the bus.
  Future<bool> nameHasOwner(String name) async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        name: 'NameHasOwner',
        values: [DBusString(name)],
        replySignature: DBusSignature('b'));
    return (result.returnValues[0] as DBusBoolean).value;
  }

  /// Returns the unique connection name of the client that owns [name].
  Future<String?> getNameOwner(String name) async {
    DBusMethodSuccessResponse result;
    try {
      result = await callMethod(
          destination: 'org.freedesktop.DBus',
          path: DBusObjectPath('/org/freedesktop/DBus'),
          interface: 'org.freedesktop.DBus',
          name: 'GetNameOwner',
          values: [DBusString(name)],
          replySignature: DBusSignature('s'));
    } on DBusMethodResponseException catch (e) {
      if (e.response.errorName == 'org.freedesktop.DBus.Error.NameHasNoOwner') {
        return null;
      }
      rethrow;
    }
    return (result.returnValues[0] as DBusString).value;
  }

  /// Returns the Unix user ID of the process running the client that owns [name].
  Future<int> getConnectionUnixUser(String name) async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        name: 'GetConnectionUnixUser',
        values: [DBusString(name)],
        replySignature: DBusSignature('u'));
    return (result.returnValues[0] as DBusUint32).value;
  }

  /// Returns the Unix process ID of the process running the client that owns [name].
  Future<int> getConnectionUnixProcessId(String name) async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        name: 'GetConnectionUnixProcessID',
        values: [DBusString(name)],
        replySignature: DBusSignature('u'));
    return (result.returnValues[0] as DBusUint32).value;
  }

  /// Returns credentials for the process running the client that owns [name].
  Future<DBusProcessCredentials> getConnectionCredentials(String name) async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        name: 'GetConnectionCredentials',
        values: [DBusString(name)],
        replySignature: DBusSignature('a{sv}'));
    var credentials = (result.returnValues[0] as DBusDict)
        .children
        .map((key, value) => MapEntry((key as DBusString).value, value));
    int? unixUserId;
    List<int>? unixGroupIds;
    int? processId;
    String? windowsSid;
    List<int>? linuxSecurityLabel;
    var otherCredentials = <String, DBusValue>{};
    credentials.forEach((key, v) {
      var value = (v as DBusVariant).value;
      switch (key) {
        case 'UnixUserID':
          if (value.signature != DBusSignature('u')) {
            throw 'org.freedesktop.DBus.GetConnectionCredentials returned invalid signature on UnixUserID: ${value.signature.value}';
          }
          unixUserId = (value as DBusUint32).value;
          break;
        case 'UnixGroupIDs':
          if (value.signature != DBusSignature('au')) {
            throw 'org.freedesktop.DBus.GetConnectionCredentials returned invalid signature on UnixGroupIDs: ${value.signature.value}';
          }
          unixGroupIds = (value as DBusArray)
              .children
              .map((v) => (v as DBusUint32).value)
              .toList();
          break;
        case 'ProcessID':
          if (value.signature != DBusSignature('u')) {
            throw 'org.freedesktop.DBus.GetConnectionCredentials returned invalid signature on ProcessID: ${value.signature.value}';
          }
          processId = (value as DBusUint32).value;
          break;
        case 'WindowsSID':
          if (value.signature != DBusSignature('s')) {
            throw 'org.freedesktop.DBus.GetConnectionCredentials returned invalid signature on WindowsSID: ${value.signature.value}';
          }
          windowsSid = (value as DBusString).value;
          break;
        case 'LinuxSecurityLabel':
          if (value.signature != DBusSignature('ay')) {
            throw 'org.freedesktop.DBus.GetConnectionCredentials returned invalid signature on LinuxSecurityLabel: ${value.signature.value}';
          }
          linuxSecurityLabel = (value as DBusArray)
              .children
              .map((v) => (v as DBusByte).value)
              .toList();
          break;
        default:
          otherCredentials[key] = value;
          break;
      }
    });
    return DBusProcessCredentials(
        unixUserId: unixUserId,
        unixGroupIds: unixGroupIds,
        processId: processId,
        windowsSid: windowsSid,
        linuxSecurityLabel: linuxSecurityLabel,
        otherCredentials: otherCredentials);
  }

  /// Gets the unique ID of the bus.
  Future<String> getId() async {
    var result = await callMethod(
        destination: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        name: 'GetId',
        replySignature: DBusSignature('s'));
    return (result.returnValues[0] as DBusString).value;
  }

  /// Sends a ping request to the client at the given [destination].
  /// If [destination] is not set, pings the D-Bus server.
  Future<void> ping([String destination = 'org.freedesktop.DBus']) async {
    await callMethod(
        destination: destination,
        path: DBusObjectPath('/'),
        interface: 'org.freedesktop.DBus.Peer',
        name: 'Ping',
        replySignature: DBusSignature(''));
  }

  /// Gets the machine ID of the client at the given [destination].
  /// If [destination] is not set, gets the machine the D-Bus server is running on.
  Future<String> getMachineId(
      [String destination = 'org.freedesktop.DBus']) async {
    var result = await callMethod(
        destination: destination,
        path: DBusObjectPath('/'),
        interface: 'org.freedesktop.DBus.Peer',
        name: 'GetMachineId',
        replySignature: DBusSignature('s'));
    return (result.returnValues[0] as DBusString).value;
  }

  /// Invokes a method on a D-Bus object.
  /// Throws [DBusMethodResponseException] if the remote side returns an error.
  ///
  /// If [replySignature] is provided this causes this method to throw a
  /// [DBusReplySignatureException] if the result is successful but the returned
  /// values do not match the provided signature.
  Future<DBusMethodSuccessResponse> callMethod(
      {String? destination,
      required DBusObjectPath path,
      String? interface,
      required String name,
      Iterable<DBusValue> values = const [],
      DBusSignature? replySignature,
      bool noReplyExpected = false,
      bool noAutoStart = false,
      bool allowInteractiveAuthorization = false}) async {
    await _connect();
    return await _callMethod(
        destination: destination != null ? DBusBusName(destination) : null,
        path: path,
        interface: interface != null ? DBusInterfaceName(interface) : null,
        name: DBusMemberName(name),
        values: values,
        replySignature: replySignature,
        noReplyExpected: noReplyExpected,
        noAutoStart: noAutoStart,
        allowInteractiveAuthorization: allowInteractiveAuthorization);
  }

  /// Find the unique name for a D-Bus client.
  Future<DBusBusName?> _findUniqueName(DBusBusName name) async {
    if (_nameOwners.containsValue(name)) return _nameOwners[name];

    var uniqueName = await getNameOwner(name.value);
    if (uniqueName == null) {
      return null;
    }

    var uniqueName_ = DBusBusName(uniqueName);
    _nameOwners[name] = uniqueName_;
    return uniqueName_;
  }

  /// Emits a signal from a D-Bus object.
  Future<void> emitSignal(
      {String? destination,
      required DBusObjectPath path,
      required String interface,
      required String name,
      Iterable<DBusValue> values = const []}) async {
    await _connect();
    await _sendSignal(destination != null ? DBusBusName(destination) : null,
        path, DBusInterfaceName(interface), DBusMemberName(name), values);
  }

  /// Searches for an object manager in [node] or any of its parents.
  DBusObject? _findObjectManager(DBusObjectTreeNode? node) {
    if (node == null) {
      return null;
    }

    var object = node.object;
    if (object != null) {
      if (object.isObjectManager) {
        return object;
      }
    }

    return _findObjectManager(node.parent);
  }

  /// Registers an [object] on the bus.
  Future<void> registerObject(DBusObject object) async {
    if (object.client != null) {
      if (object.client == this) {
        throw 'Object already registered';
      } else {
        throw 'Object already registered on other client';
      }
    }
    object.client = this;
    var node = _objectTree.add(object.path, object);
    await _connect();

    // If has an object manager as a parent, emit a signal to indicate this was added.
    var objectManager = _findObjectManager(node.parent);
    if (objectManager != null) {
      var interfacesAndProperties = expandObjectInterfaceAndProperties(object,
          introspectable: introspectable);
      objectManager.emitInterfacesAdded(object.path, interfacesAndProperties);
    }
  }

  /// Unregisters an [object] on the bus.
  Future<void> unregisterObject(DBusObject object) async {
    if (object.client == null) {
      throw 'Object not registered';
    }
    if (object.client != this) {
      throw 'Object registered on other client';
    }

    var node = _objectTree.lookup(object.path);
    if (node == null) {
      return;
    }

    // If has an object manager as a parent, emit a signal to indicate this was removed.
    var objectManager = _findObjectManager(node.parent);
    if (objectManager != null) {
      var interfacesAndProperties = expandObjectInterfaceAndProperties(object,
          introspectable: introspectable);
      objectManager.emitInterfacesRemoved(
          object.path, interfacesAndProperties.keys);
    }
  }

  /// Open a socket connection to the D-Bus server.
  Future<void> _openSocket() async {
    InternetAddress socketAddress;
    var port = 0;
    switch (_address.transport) {
      case 'unix':
        var path = _address.properties['path'];
        if (path == null) {
          path = _address.properties['abstract'];
          if (path == null) {
            throw "Unable to determine D-Bus unix address path from address '$_address'";
          }
          // Dart expects abstract unix socket paths to be prepended with '@'.
          path = '@$path';
        }

        socketAddress = InternetAddress(path, type: InternetAddressType.unix);
        break;
      case 'tcp':
        var host = _address.properties['host'];
        if (host == null) {
          throw "'Unable to determine hostname from address '$_address'";
        }

        InternetAddressType type;
        var family = _address.properties['family'];
        switch (family) {
          case null:
            type = InternetAddressType.any;
            break;
          case 'ipv4':
            type = InternetAddressType.IPv4;
            break;
          case 'ipv6':
            type = InternetAddressType.IPv6;
            break;
          default:
            throw "Invalid D-Bus address family: '$family'";
        }

        try {
          port = int.parse(_address.properties['port'] ?? '0');
        } on FormatException {
          throw "Invalid port number in address '$_address'";
        }

        var addresses = await InternetAddress.lookup(host, type: type);
        if (addresses.isEmpty) {
          throw "Failed to resolve host '$host'";
        }

        socketAddress = addresses[0];
        break;
      default:
        throw 'D-Bus address transport not supported: $_address';
    }

    _socket = await Socket.connect(socketAddress, port);
    _socket?.listen(_processData);
  }

  /// Performs authentication with D-Bus server.
  Future<bool> _authenticate() async {
    _authClient.requests.listen((message) => _socket?.write(message + '\r\n'));
    await _authClient.done;

    return _authClient.isAuthenticated;
  }

  /// Connects to the D-Bus server.
  Future<void> _connect() async {
    // If already connecting, wait for that to complete.
    if (_connectCompleter != null) {
      return _connectCompleter?.future;
    }
    _connectCompleter = Completer();

    await _openSocket();
    if (!await _authenticate()) {
      await _socket?.close();
      return;
    }

    // The first message to the bus must be this call, note requireConnect is
    // false as the _connect call hasn't yet completed and would otherwise have
    // been called again.
    var result = await _callMethod(
        destination: DBusBusName('org.freedesktop.DBus'),
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: DBusInterfaceName('org.freedesktop.DBus'),
        name: DBusMemberName('Hello'),
        replySignature: DBusSignature('s'));
    _uniqueName = DBusBusName((result.returnValues[0] as DBusString).value);

    // Notify anyone else awaiting connection.
    _connectCompleter?.complete();

    // Monitor name ownership so we know what names we have, and can match incoming signals from other clients.
    var nameAcquiredSignals = DBusSignalStream(this,
        sender: 'org.freedesktop.DBus',
        interface: 'org.freedesktop.DBus',
        name: 'NameAcquired');
    _nameAcquiredSubscription = nameAcquiredSignals.listen(_handleNameAcquired);
    var nameLostSignals = DBusSignalStream(this,
        sender: 'org.freedesktop.DBus',
        interface: 'org.freedesktop.DBus',
        name: 'NameLost');
    _nameLostSubscription = nameLostSignals.listen(_handleNameLost);
    var nameOwnerChangedSignals = DBusSignalStream(this,
        sender: 'org.freedesktop.DBus',
        interface: 'org.freedesktop.DBus',
        name: 'NameOwnerChanged');
    _nameOwnerSubscription =
        nameOwnerChangedSignals.listen(_handleNameOwnerChanged);
  }

  /// Handles the org.freedesktop.DBus.NameAcquired signal.
  void _handleNameAcquired(DBusSignal signal) {
    if (signal.signature != DBusSignature('s')) {
      throw 'org.freedesktop.DBus.NameAcquired received with invalid arguments: ${signal.values}';
    }

    var name = DBusBusName((signal.values[0] as DBusString).value);

    _nameOwners[name] = _uniqueName!;
    _ownedNames.add(name);

    _nameAcquiredController.add(name.value);
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

    var name = DBusBusName((signal.values[0] as DBusString).value);
    var newOwner = (signal.values[2] as DBusString).value;
    if (newOwner != '') {
      _nameOwners[name] = DBusBusName(newOwner);
    } else {
      _nameOwners.remove(name);
    }
  }

  /// Adds a rule to match which messages to receive.
  Future<void> _addMatch(String rule) async {
    var count = _matchRules[rule];
    if (count == null) {
      _matchRules[rule] = 1;
      await callMethod(
          destination: 'org.freedesktop.DBus',
          path: DBusObjectPath('/org/freedesktop/DBus'),
          interface: 'org.freedesktop.DBus',
          name: 'AddMatch',
          values: [DBusString(rule)],
          replySignature: DBusSignature(''));
    } else {
      _matchRules[rule] = count + 1;
    }
  }

  /// Removes an existing rule to match which messages to receive.
  Future<void> _removeMatch(String rule) async {
    var count = _matchRules[rule];
    if (count == null) {
      throw 'Attempted to remove match that is not added: $rule';
    }

    if (count == 1) {
      await callMethod(
          destination: 'org.freedesktop.DBus',
          path: DBusObjectPath('/org/freedesktop/DBus'),
          interface: 'org.freedesktop.DBus',
          name: 'RemoveMatch',
          values: [DBusString(rule)],
          replySignature: DBusSignature(''));
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
      if (!_authClient.isAuthenticated) {
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

    _authClient.processResponse(line);
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
    DBusObjectTreeNode? node;
    if (message.path != null) {
      node = _objectTree.lookup(message.path!);
    }
    var object = node?.object;

    var methodCall = DBusMethodCall(message.sender?.value ?? '',
        message.interface?.value, message.member?.value ?? '', message.values,
        noReplyExpected:
            message.flags.contains(DBusMessageFlag.noReplyExpected),
        noAutoStart: message.flags.contains(DBusMessageFlag.noAutoStart),
        allowInteractiveAuthorization: message.flags
            .contains(DBusMessageFlag.allowInteractiveAuthorization));

    DBusMethodResponse response;
    if (message.member == null) {
      response = DBusMethodErrorResponse.unknownMethod();
    } else if (message.interface?.value == 'org.freedesktop.DBus.Peer') {
      response = await handlePeerMethodCall(methodCall);
    } else if (introspectable &&
        message.interface?.value == 'org.freedesktop.DBus.Introspectable') {
      response = handleIntrospectableMethodCall(node, methodCall);
    } else if (object == null) {
      response = DBusMethodErrorResponse.unknownObject();
    } else if (message.interface?.value == 'org.freedesktop.DBus.Properties') {
      response = await handlePropertiesMethodCall(object, methodCall);
    } else if (object.isObjectManager &&
        message.interface?.value == 'org.freedesktop.DBus.ObjectManager') {
      response = handleObjectManagerMethodCall(_objectTree, methodCall,
          introspectable: introspectable);
    } else {
      response = await object.handleMethodCall(methodCall);
    }

    if (message.flags.contains(DBusMessageFlag.noReplyExpected)) {
      return;
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
          message.errorName?.value ?? '(missing error name)', message.values);
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

    for (var stream in _signalStreams) {
      // If the stream is for an owned name, check if that matches the unique name in the message.
      var sender = message.sender;
      if (_nameOwners[stream._rule.sender] == sender) {
        sender = stream._rule.sender;
      }

      if (!stream._rule.match(
          type: DBusMessageType.signal,
          sender: sender,
          interface: message.interface,
          member: message.member,
          path: message.path)) {
        continue;
      }

      var signal = DBusSignal(
          message.sender?.value ?? '',
          message.path ?? DBusObjectPath('/'),
          message.interface?.value ?? '',
          message.member?.value ?? '',
          message.values);
      if (stream._signature != null && message.signature != stream._signature) {
        stream._controller.addError(DBusSignalSignatureException(
            '${message.interface?.value}.${message.member?.value}', signal));
      } else {
        stream._controller.add(signal);
      }
    }
  }

  /// Invokes a method on a D-Bus object.
  Future<DBusMethodSuccessResponse> _callMethod(
      {DBusBusName? destination,
      required DBusObjectPath path,
      DBusInterfaceName? interface,
      required DBusMemberName name,
      Iterable<DBusValue> values = const {},
      DBusSignature? replySignature,
      bool noReplyExpected = false,
      bool noAutoStart = false,
      bool allowInteractiveAuthorization = false}) async {
    _lastSerial++;
    var serial = _lastSerial;
    Future<DBusMethodResponse> response;
    if (noReplyExpected) {
      response = Future<DBusMethodResponse>.value(DBusMethodSuccessResponse());
    } else {
      var completer = Completer<DBusMethodResponse>();
      _methodCalls[serial] = completer;
      response = completer.future;
    }

    var flags = <DBusMessageFlag>{};
    if (noReplyExpected) {
      flags.add(DBusMessageFlag.noReplyExpected);
    }
    if (noAutoStart) {
      flags.add(DBusMessageFlag.noAutoStart);
    }
    if (allowInteractiveAuthorization) {
      flags.add(DBusMessageFlag.allowInteractiveAuthorization);
    }
    var message = DBusMessage(DBusMessageType.methodCall,
        serial: _lastSerial,
        destination: destination,
        path: path,
        interface: interface,
        member: name,
        values: values.toList(),
        flags: flags);
    await _sendMessage(message);

    var r = await response;
    if (r is DBusMethodSuccessResponse) {
      /// Check returned values match expected signature.
      if (replySignature != null && r.signature != replySignature) {
        var fullName =
            interface != null ? '${interface.value}.${name.value}' : name.value;
        throw DBusReplySignatureException(fullName, r);
      }

      return r;
    } else if (r is DBusMethodErrorResponse) {
      throw DBusMethodResponseException(r);
    } else {
      throw 'Unknown response type';
    }
  }

  /// Sends a method return to the D-Bus server.
  Future<void> _sendReturn(
      int serial, DBusBusName? destination, Iterable<DBusValue> values) async {
    _lastSerial++;
    var message = DBusMessage(DBusMessageType.methodReturn,
        serial: _lastSerial,
        replySerial: serial,
        destination: destination,
        values: values.toList());
    await _sendMessage(message);
  }

  /// Sends an error to the D-Bus server.
  Future<void> _sendError(int serial, DBusBusName? destination,
      String errorName, Iterable<DBusValue> values) async {
    _lastSerial++;
    var message = DBusMessage(DBusMessageType.error,
        serial: _lastSerial,
        errorName: DBusErrorName(errorName),
        replySerial: serial,
        destination: destination,
        values: values.toList());
    await _sendMessage(message);
  }

  /// Sends a signal to the D-Bus server.
  Future<void> _sendSignal(
      DBusBusName? destination,
      DBusObjectPath path,
      DBusInterfaceName interface,
      DBusMemberName name,
      Iterable<DBusValue> values) async {
    _lastSerial++;
    var message = DBusMessage(DBusMessageType.signal,
        serial: _lastSerial,
        destination: destination,
        path: path,
        interface: interface,
        member: name,
        values: values.toList());
    await _sendMessage(message);
  }

  /// Sends a message (method call/return/error/signal) to the D-Bus server.
  Future<void> _sendMessage(DBusMessage message) async {
    var buffer = DBusWriteBuffer();
    buffer.writeMessage(message);
    _socket?.add(buffer.data);
  }

  @override
  String toString() {
    return "DBusClient('$_address')";
  }
}
