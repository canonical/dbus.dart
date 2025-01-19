import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'dbus_address.dart';
import 'dbus_auth_server.dart';
import 'dbus_bus_name.dart';
import 'dbus_error_name.dart';
import 'dbus_interface_name.dart';
import 'dbus_introspect.dart';
import 'dbus_introspectable.dart';
import 'dbus_match_rule.dart';
import 'dbus_member_name.dart';
import 'dbus_message.dart';
import 'dbus_method_call.dart';
import 'dbus_method_response.dart';
import 'dbus_object.dart';
import 'dbus_object_tree.dart';
import 'dbus_peer.dart';
import 'dbus_properties.dart';
import 'dbus_read_buffer.dart';
import 'dbus_uuid.dart';
import 'dbus_value.dart';
import 'dbus_write_buffer.dart';
import 'getuid.dart';

/// Results of starting a service.
enum DBusServerStartServiceResult { success, alreadyRunning, notFound }

/// Server-only error responses.
class _DBusServerErrorResponse extends DBusMethodErrorResponse {
  _DBusServerErrorResponse.serviceUnknown([String? message])
      : super('org.freedesktop.DBus.Error.ServiceUnknown',
            message != null ? [DBusString(message)] : []);

  _DBusServerErrorResponse.nameHasNoOwner([String? message])
      : super('org.freedesktop.DBus.Error.NameHasNoOwner',
            message != null ? [DBusString(message)] : []);

  _DBusServerErrorResponse.matchRuleInvalid([String? message])
      : super('org.freedesktop.DBus.Error.MatchRuleInvalid',
            message != null ? [DBusString(message)] : []);

  _DBusServerErrorResponse.matchRuleNotFound([String? message])
      : super('org.freedesktop.DBus.Error.MatchRuleNotFound',
            message != null ? [DBusString(message)] : []);

  _DBusServerErrorResponse.notSupported([String? message])
      : super('org.freedesktop.DBus.Error.NotSupported',
            message != null ? [DBusString(message)] : []);
}

/// A client connected to a D-Bus server.
class _DBusRemoteClient {
  /// The socket this client connected on.
  final _DBusServerSocket serverSocket;

  /// The server this client is connected to.
  DBusServer get server => serverSocket.server;

  /// The socket this client is communicating on.
  final RawSocket _socket;

  /// Incoming data.
  final _readBuffer = DBusReadBuffer();

  /// Authentication server.
  final DBusAuthServer _authServer;

  /// True when have received a Hello message.
  bool receivedHello = false;

  /// Unique name of this client.
  final DBusBusName uniqueName;

  /// Message match rules.
  final matchRules = <DBusMatchRule>[];

  _DBusRemoteClient(this.serverSocket, this._socket, this.uniqueName)
      : _authServer = DBusAuthServer(serverSocket.uuid, unixFdSupported: true) {
    _authServer.responses
        .listen((message) => _socket.write(utf8.encode('$message\r\n')));
    _socket.listen((event) {
      if (event == RawSocketEvent.read) {
        _readData();
      } else if (event == RawSocketEvent.closed ||
          event == RawSocketEvent.readClosed) {
        serverSocket._clientDisconnected(this);
        _socket.close();
      }
    }, onError: (error) {});
  }

  /// True if this client has a rule that matches [message].
  bool matchMessage(DBusMessage message) {
    for (var rule in matchRules) {
      // If the subscription is for an owned name, check if that matches the unique name in the message.
      var sender = message.sender;
      if (rule.sender != null &&
          server._messageBusObject
                  ?._getClientByName(rule.sender!)
                  ?.uniqueName ==
              sender) {
        sender = rule.sender;
      }

      if (rule.match(
          type: message.type,
          sender: sender,
          interface: message.interface,
          member: message.member,
          path: message.path)) {
        return true;
      }
    }
    return false;
  }

  /// Send [message] to this client.
  void sendMessage(DBusMessage message) {
    var buffer = DBusWriteBuffer();
    buffer.writeMessage(message);
    var controlMessages = <SocketControlMessage>[];
    if (buffer.resourceHandles.isNotEmpty) {
      controlMessages
          .add(SocketControlMessage.fromHandles(buffer.resourceHandles));
    }

    _socket.sendMessage(controlMessages, buffer.data);
  }

  Future<void> close() async {
    await _socket.close();
  }

  /// Reads incoming data from this D-Bus client.
  void _readData() {
    var message = _socket.readMessage();
    if (message == null) {
      return;
    }
    _readBuffer.writeBytes(message.data);
    for (var message in message.controlMessages) {
      _readBuffer.addResourceHandles(message.extractHandles());
    }

    var complete = false;
    while (!complete) {
      if (!_authServer.isAuthenticated) {
        complete = _processAuth();
      } else {
        complete = _processMessages();
      }
      _readBuffer.flush();
    }
  }

  /// Processes authentication messages received from the D-Bus client.
  bool _processAuth() {
    var line = _readBuffer.readLine();
    if (line == null) {
      return true;
    }

    _authServer.processRequest(line);
    return false;
  }

  bool _processMessages() {
    var start = _readBuffer.readOffset;
    var message = _readBuffer.readMessage();
    if (message == null) {
      _readBuffer.readOffset = start;
      return true;
    }

    // Ensure the sender field is set and is correct.
    var m = DBusMessage(message.type,
        flags: message.flags,
        serial: message.serial,
        path: message.path,
        interface: message.interface,
        member: message.member,
        errorName: message.errorName,
        replySerial: message.replySerial,
        destination: message.destination,
        sender: uniqueName,
        values: message.values);
    server._processMessage(this, m);

    return false;
  }

  @override
  String toString() => '$runtimeType($uniqueName)';
}

/// A socket for incoming D-Bus server connections.
class _DBusServerSocket {
  /// The server this socket is listening for.
  final DBusServer server;

  /// Socket being listened on.
  final RawServerSocket socket;

  /// Id for this connection.
  final int connectionId;

  /// Next Id to use to generate a unique name for each client.
  int _nextClientId = 0;

  /// Unique ID for this socket.
  final uuid = DBusUUID();

  /// Connected clients.
  final _clients = <_DBusRemoteClient>[];

  _DBusServerSocket(this.server, this.socket, this.connectionId) {
    socket.listen((clientSocket) {
      var uniqueName = DBusBusName(':$connectionId.$_nextClientId');
      _nextClientId++;
      var client = _DBusRemoteClient(this, clientSocket, uniqueName);
      _clients.add(client);
    }, onError: (error) {}, onDone: () => socket.close());
  }

  /// Handle a client disconnecting.
  void _clientDisconnected(_DBusRemoteClient client) {
    _clients.remove(client);
    server._messageBusObject?._releaseAllNames(client);
  }

  Future<void> close() async {
    // Note the client list is copied, as it might be modified as clients close.
    for (var client in _clients.toList()) {
      await client.close();
    }
    await socket.close();
  }
}

/// Method call received on the server.
class _ServerMethodCall extends DBusMethodCall {
  /// Client that made the call.
  final _DBusRemoteClient client;

  _ServerMethodCall(this.client, DBusMessage message)
      : super(
            sender: message.sender?.value,
            interface: message.interface?.value,
            name: message.member!.value,
            values: message.values,
            noReplyExpected:
                message.flags.contains(DBusMessageFlag.noReplyExpected),
            noAutoStart: message.flags.contains(DBusMessageFlag.noAutoStart),
            allowInteractiveAuthorization: message.flags
                .contains(DBusMessageFlag.allowInteractiveAuthorization));
}

/// An open request for a name.
class _DBusNameRequest {
  /// True if this client allows another client to take this name.
  bool allowReplacement;

  /// True if this client will take a name off another client.
  bool replaceExisting;

  /// True if this client wants to be removed from the queue if not the owner.
  bool doNotQueue;

  _DBusNameRequest(
      this.allowReplacement, this.replaceExisting, this.doNotQueue);
}

/// A queue of clients requesting a name.
class _DBusNameQueue {
  /// The name being queued for.
  final DBusBusName name;

  /// Queued requests.
  final requests = <_DBusRemoteClient, _DBusNameRequest>{};

  /// The current owner of this name.
  _DBusRemoteClient? get owner =>
      requests.isNotEmpty ? requests.keys.first : null;

  /// Creates a new name queue for [name].
  _DBusNameQueue(this.name);

  /// Add/update a request from [client] for this name.
  void addRequest(_DBusRemoteClient client, bool allowReplacement,
      bool replaceExisting, bool doNotQueue) {
    var currentOwner = owner;

    var request = requests[client];
    if (request == null) {
      request = _DBusNameRequest(allowReplacement, replaceExisting, doNotQueue);
      requests[client] = request;
    }
    request.allowReplacement = allowReplacement;
    request.replaceExisting = replaceExisting;
    request.doNotQueue = doNotQueue;

    // If can take an existing name, move to the front of the queue
    if (currentOwner != null &&
        currentOwner != client &&
        requests[currentOwner]!.allowReplacement &&
        replaceExisting) {
      requests.remove(client);
      var otherRequests = requests.entries.toList();
      requests.clear();
      requests[client] = request;
      requests.addEntries(otherRequests);
    }

    /// Purge any do not queue requests.
    requests.removeWhere(
        (client, request) => client != owner && request.doNotQueue);
  }

  /// Returns true if [client] has a request on this name.
  bool hasRequest(_DBusRemoteClient client) => requests.containsKey(client);

  /// Remove a request from [client] for this name.
  /// Returns true if there was a request to remove.
  bool removeRequest(_DBusRemoteClient client) {
    return requests.remove(client) != null;
  }
}

/// A D-Bus server.
class DBusServer {
  /// Unique ID for this server;
  String get uuid => _uuid.toHexString();
  final _uuid = DBusUUID();

  /// Names of services that can be activated.
  /// Override this property to enable this feature.
  List<String> get activatableNames => [];

  /// Sockets being listened on.
  final _sockets = <_DBusServerSocket>[];

  /// Next Id to use for connections.
  int _nextConnectionId = 1;

  /// Connected clients.
  Iterable<_DBusRemoteClient> get _clients =>
      _sockets.map((s) => s._clients).expand((c) => c);

  /// Next serial number to use for messages from the server.
  int _nextSerial = 1;

  /// Feature flags exposed by the server.
  final _features = <String>[];

  /// Interfaces supported by the server.
  final _interfaces = <String>[];

  /// Message bus functionality.
  _MessageBusObject? _messageBusObject;

  /// Creates a new DBus server.
  DBusServer({bool messageBus = true}) {
    if (messageBus) {
      _messageBusObject = _MessageBusObject(this);
    }
  }

  /// Start a service that uses [name].
  /// Override this method to enable this feature.
  Future<DBusServerStartServiceResult> startServiceByName(String name) async {
    return DBusServerStartServiceResult.notFound;
  }

  /// Listen on the given D-Bus [address].
  /// Returns an address for clients to connnect on this connection.
  Future<DBusAddress> listenAddress(DBusAddress address) async {
    switch (address.transport) {
      case 'unix':
        return await _listenUnixSocket(address);
      case 'tcp':
        return await _listenTcpSocket(address);
      default:
        throw FormatException("Unknown D-Bus transport '${address.transport}'");
    }
  }

  /// Emits a signal from the D-Bus server.
  void emitSignal(
      {required DBusObjectPath path,
      required String interface,
      required String name,
      Iterable<DBusValue> values = const []}) {
    var message = DBusMessage(DBusMessageType.signal,
        flags: {DBusMessageFlag.noReplyExpected},
        serial: _nextSerial,
        path: path,
        interface: DBusInterfaceName(interface),
        member: DBusMemberName(name),
        values: values.toList());
    _nextSerial++;
    for (var client in _clients) {
      client.sendMessage(message);
    }
  }

  /// Listens for connections on a Unix socket.
  Future<DBusAddress> _listenUnixSocket(DBusAddress address) async {
    var path = address.properties['path'];
    var dir = address.properties['dir'];
    var tmpdir = address.properties['tmpdir'];
    var abstract = address.properties['abstract'];
    var runtime = address.properties['runtime'];
    if ([path, dir, tmpdir, abstract, runtime]
            .map((v) => v != null ? 1 : 0)
            .reduce((a, b) => a + b) !=
        1) {
      throw FormatException(
          'D-Bus Unix address requires one of path, dir, tmpdir, abstract or runtime');
    }
    if (runtime != null && runtime != 'yes') {
      throw FormatException("Runtime must only contain the value 'yes'");
    }

    String entryWithRandomSuffix(Directory dir) {
      var chars =
          'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
      var random = Random();
      var suffix =
          List<String>.generate(8, (i) => chars[random.nextInt(chars.length)])
              .join();
      return '${dir.path}/dbus-$suffix';
    }

    if (path == null) {
      Directory directory;
      if (dir != null) {
        directory = Directory(dir);
        path = entryWithRandomSuffix(directory);
      } else if (runtime != null) {
        var runtimeDir = Platform.environment['XDG_RUNTIME_DIR'];
        if (runtimeDir == null) {
          throw SocketException('Unable to determine runtime directory');
        }
        directory = Directory(runtimeDir);
        path = entryWithRandomSuffix(directory);
      } else if (tmpdir != null) {
        throw "Unix addresses with 'tmpdir' not supported";
      } else if (abstract != null) {
        // Dart expects abstract unix socket paths to be prepended with '@'.
        path = '@$abstract';
      } else {
        // Shouldn't be able to get here.
        throw 'Not able to determine Unix path';
      }
    }
    await _addServerSocket(
        InternetAddress(path, type: InternetAddressType.unix), 0);
    return DBusAddress.unix(path: path);
  }

  /// Listens for connections on a TCP/IP socket.
  Future<DBusAddress> _listenTcpSocket(DBusAddress address) async {
    var host = address.properties['host'];
    if (host == null) {
      throw FormatException('Missing host in TCP D-Bus address');
    }
    var bind = address.properties['bind'];
    var family = address.properties['family'];
    var type = InternetAddressType.any;
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
        throw FormatException("Invalid family '$family'");
    }
    int? port;
    if (address.properties.containsKey('port')) {
      try {
        port = int.parse(address.properties['port']!);
      } on FormatException {
        throw FormatException('Invalid port number in D-Bus address');
      }
    }

    InternetAddress internetAddress;
    if (bind == '*') {
      internetAddress = type == InternetAddressType.IPv6
          ? InternetAddress.anyIPv6
          : InternetAddress.anyIPv4;
    } else {
      var bindAddress = bind ?? host;
      var addresses = await InternetAddress.lookup(bindAddress, type: type);
      if (addresses.isEmpty) {
        throw "Failed to resolve host '$bindAddress'";
      }
      internetAddress = addresses[0];
    }
    port = port ?? 0;
    var serverSocket = await _addServerSocket(internetAddress, port);
    if (port == 0) {
      port = serverSocket.socket.port;
    }
    // Note the bind address is not provided, as the client doesn't need it for connecting.
    return DBusAddress.tcp(host,
        port: port,
        family: {
          InternetAddressType.IPv4: DBusAddressTcpFamily.ipv4,
          InternetAddressType.IPv6: DBusAddressTcpFamily.ipv6
        }[type]);
  }

  Future<_DBusServerSocket> _addServerSocket(
      InternetAddress address, int port) async {
    var socket = await RawServerSocket.bind(address, port);
    var serverSocket = _DBusServerSocket(this, socket, _nextConnectionId);
    _sockets.add(serverSocket);
    _nextConnectionId++;
    return serverSocket;
  }

  /// Terminates all active connections. If a server remains unclosed, the Dart process may not terminate.
  Future<void> close() async {
    for (var socket in _sockets) {
      await socket.close();
    }
  }

  /// Process an incoming message.
  Future<void> _processMessage(
      _DBusRemoteClient? client, DBusMessage message) async {
    // Forward to any clients that are listening to this message.
    if (_messageBusObject != null) {
      var targetClient = message.destination != null
          ? _messageBusObject!._getClientByName(message.destination!)
          : null;
      for (var client in _clients) {
        if (client == targetClient || client.matchMessage(message)) {
          client.sendMessage(message);
        }
      }
    }

    // Process requests for the server.
    DBusMethodResponse? response;
    if (_messageBusObject != null &&
        client != null &&
        !client.receivedHello &&
        !(message.destination?.value == 'org.freedesktop.DBus' &&
            message.interface?.value == 'org.freedesktop.DBus' &&
            message.member?.value == 'Hello')) {
      await client.close();
      response = DBusMethodErrorResponse.accessDenied(
          'Client tried to send a message other than Hello without being registered');
    } else if (message.destination?.value == 'org.freedesktop.DBus') {
      if (client != null && message.type == DBusMessageType.methodCall) {
        response = await _processServerMethodCall(client, message);
      }
    } else {
      // No-one is going to handle this message.
      if (message.destination != null &&
          _messageBusObject?._getClientByName(message.destination!) == null) {
        response = _DBusServerErrorResponse.serviceUnknown(
            'The name ${message.destination} is not registered');
      }
    }

    // Send a response message if one generated.
    if (response != null &&
        !message.flags.contains(DBusMessageFlag.noReplyExpected)) {
      var type = DBusMessageType.methodReturn;
      DBusErrorName? errorName;
      var values = const <DBusValue>[];
      if (response is DBusMethodSuccessResponse) {
        values = response.values;
      } else if (response is DBusMethodErrorResponse) {
        type = DBusMessageType.error;
        errorName = DBusErrorName(response.errorName);
        values = response.values;
      }
      var responseMessage = DBusMessage(type,
          flags: {DBusMessageFlag.noReplyExpected},
          serial: _nextSerial,
          errorName: errorName,
          replySerial: message.serial,
          destination: message.sender,
          sender: DBusBusName('org.freedesktop.DBus'),
          values: values);
      _nextSerial++;

      if (_messageBusObject != null) {
        // ignore: unawaited_futures
        _processMessage(null, responseMessage);
      } else {
        client?.sendMessage(responseMessage);
      }
    }
  }

  /// Process a method call requested on the D-Bus server.
  Future<DBusMethodResponse> _processServerMethodCall(
      _DBusRemoteClient client, DBusMessage message) async {
    if (message.member == null) {
      return DBusMethodErrorResponse.failed();
    }

    var methodCall = _ServerMethodCall(client, message);

    if (methodCall.interface == 'org.freedesktop.DBus.Peer') {
      return await handlePeerMethodCall(methodCall);
    } else if (methodCall.interface == 'org.freedesktop.DBus.Introspectable') {
      var objectTree = DBusObjectTree();
      if (_messageBusObject != null) {
        objectTree.add(message.path ?? DBusObjectPath('/'), _messageBusObject!);
      }
      return handleIntrospectableMethodCall(
          message.path != null ? objectTree.lookup(message.path!) : null,
          methodCall);
    } else if (_messageBusObject != null) {
      if (methodCall.interface == 'org.freedesktop.DBus.Properties') {
        return await handlePropertiesMethodCall(_messageBusObject!, methodCall);
      } else {
        return await _messageBusObject!.handleMethodCall(methodCall);
      }
    } else {
      return DBusMethodErrorResponse.unknownObject();
    }
  }

  /// Emits a signal from the D-Bus server.
  void _emitSignal(
      DBusObjectPath path, DBusInterfaceName interface, DBusMemberName name,
      {DBusBusName? destination, Iterable<DBusValue> values = const []}) {
    var message = DBusMessage(DBusMessageType.signal,
        flags: {DBusMessageFlag.noReplyExpected},
        serial: _nextSerial,
        path: path,
        interface: interface,
        member: name,
        destination: destination,
        sender: DBusBusName('org.freedesktop.DBus'),
        values: values.toList());
    _nextSerial++;
    _processMessage(null, message);
  }

  @override
  String toString() {
    return '$runtimeType()';
  }
}

/// Object implementing org.freedesktop.DBus
class _MessageBusObject extends DBusObject {
  final DBusServer server;

  /// Queues for name ownership.
  final _nameQueues = <DBusBusName, _DBusNameQueue>{};

  _MessageBusObject(this.server)
      : super(DBusObjectPath('/org/freedesktop/DBus'));

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    var client = (methodCall as _ServerMethodCall).client;
    if (methodCall.interface == 'org.freedesktop.DBus') {
      switch (methodCall.name) {
        case 'Hello':
          return _hello(client);
        case 'RequestName':
          if (methodCall.signature != DBusSignature('su')) {
            return DBusMethodErrorResponse.invalidArgs();
          }
          var name = methodCall.values[0].asString();
          var flags = methodCall.values[1].asUint32();
          var allowReplacement = (flags & 0x01) != 0;
          var replaceExisting = (flags & 0x02) != 0;
          var doNotQueue = (flags & 0x04) != 0;
          return _requestName(
              client, name, allowReplacement, replaceExisting, doNotQueue);
        case 'ReleaseName':
          if (methodCall.signature != DBusSignature('s')) {
            return DBusMethodErrorResponse.invalidArgs();
          }
          var name = methodCall.values[0].asString();
          return _releaseName(client, name);
        case 'ListQueuedOwners':
          if (methodCall.signature != DBusSignature('s')) {
            return DBusMethodErrorResponse.invalidArgs();
          }
          var name = methodCall.values[0].asString();
          return _listQueuedOwners(name);
        case 'ListNames':
          if (methodCall.values.isNotEmpty) {
            return DBusMethodErrorResponse.invalidArgs();
          }
          return _listNames();
        case 'ListActivatableNames':
          if (methodCall.values.isNotEmpty) {
            return DBusMethodErrorResponse.invalidArgs();
          }
          return _listActivatableNames();
        case 'NameHasOwner':
          if (methodCall.signature != DBusSignature('s')) {
            return DBusMethodErrorResponse.invalidArgs();
          }
          var name = methodCall.values[0].asString();
          return _nameHasOwner(name);
        case 'StartServiceByName':
          if (methodCall.signature != DBusSignature('su')) {
            return DBusMethodErrorResponse.invalidArgs();
          }
          var name = methodCall.values[0].asString();
          var flags = methodCall.values[1].asUint32();
          return await _startServiceByName(name, flags);
        case 'GetNameOwner':
          if (methodCall.signature != DBusSignature('s')) {
            return DBusMethodErrorResponse.invalidArgs();
          }
          var name = methodCall.values[0].asString();
          return _getNameOwner(name);
        case 'GetConnectionUnixUser':
          if (methodCall.signature != DBusSignature('s')) {
            return DBusMethodErrorResponse.invalidArgs();
          }
          var name = methodCall.values[0].asString();
          return _getConnectionUnixUser(name);
        case 'GetConnectionUnixProcessID':
          if (methodCall.signature != DBusSignature('s')) {
            return DBusMethodErrorResponse.invalidArgs();
          }
          var name = methodCall.values[0].asString();
          return _getConnectionUnixProcessId(name);
        case 'GetConnectionCredentials':
          if (methodCall.signature != DBusSignature('s')) {
            return DBusMethodErrorResponse.invalidArgs();
          }
          var name = methodCall.values[0].asString();
          return _getConnectionCredentials(name);
        case 'AddMatch':
          if (methodCall.signature != DBusSignature('s')) {
            return DBusMethodErrorResponse.invalidArgs();
          }
          var rule = methodCall.values[0].asString();
          return _addMatch(client, rule);
        case 'RemoveMatch':
          if (methodCall.signature != DBusSignature('s')) {
            return DBusMethodErrorResponse.invalidArgs();
          }
          var rule = methodCall.values[0].asString();
          return _removeMatch(client, rule);
        case 'GetId':
          if (methodCall.values.isNotEmpty) {
            return DBusMethodErrorResponse.invalidArgs();
          }
          return _getId(client);
        default:
          return DBusMethodErrorResponse.unknownMethod(
              'Method ${methodCall.interface}.${methodCall.name} not provided');
      }
    } else {
      return DBusMethodErrorResponse.unknownInterface(
          'Interface ${methodCall.interface} not provided');
    }
  }

  @override
  Future<DBusMethodResponse> getProperty(
      String interfaceName, String name) async {
    if (interfaceName == 'org.freedesktop.DBus') {
      switch (name) {
        case 'Features':
          return DBusGetPropertyResponse(DBusArray(DBusSignature('s'),
              server._features.map((value) => DBusString(value))));
        case 'Interfaces':
          return DBusGetPropertyResponse(DBusArray(DBusSignature('s'),
              server._interfaces.map((value) => DBusString(value))));
      }
    }
    return DBusMethodErrorResponse.unknownProperty(
        'Properies $interfaceName.$name does not exist');
  }

  @override
  Future<DBusMethodResponse> setProperty(
      String interfaceName, String name, DBusValue value) async {
    if (interfaceName == 'org.freedesktop.DBus') {
      switch (name) {
        case 'Features':
        case 'Interfaces':
          return DBusMethodErrorResponse.propertyReadOnly();
      }
    }
    return DBusMethodErrorResponse.unknownProperty(
        'Properies $interfaceName.$name does not exist');
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interfaceName) async {
    var properties = <String, DBusValue>{};
    if (interfaceName == 'org.freedesktop.DBus') {
      properties['Features'] = DBusArray(DBusSignature('s'),
          server._features.map((value) => DBusString(value)));
      properties['Interfaces'] = DBusArray(DBusSignature('s'),
          server._interfaces.map((value) => DBusString(value)));
    }
    return DBusGetAllPropertiesResponse(properties);
  }

  @override
  List<DBusIntrospectInterface> introspect() {
    return [
      DBusIntrospectInterface('org.freedesktop.DBus', methods: [
        DBusIntrospectMethod('Hello', args: [
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out,
              name: 'unique_name')
        ]),
        DBusIntrospectMethod('RequestName', args: [
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_,
              name: 'name'),
          DBusIntrospectArgument(DBusSignature('u'), DBusArgumentDirection.in_,
              name: 'flags'),
          DBusIntrospectArgument(DBusSignature('u'), DBusArgumentDirection.out,
              name: 'result')
        ]),
        DBusIntrospectMethod('ReleaseName', args: [
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_,
              name: 'name'),
          DBusIntrospectArgument(DBusSignature('u'), DBusArgumentDirection.out,
              name: 'result')
        ]),
        DBusIntrospectMethod('ListQueuedOwners', args: [
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_,
              name: 'name'),
          DBusIntrospectArgument(DBusSignature('as'), DBusArgumentDirection.out,
              name: 'names')
        ]),
        DBusIntrospectMethod('ListNames', args: [
          DBusIntrospectArgument(DBusSignature('as'), DBusArgumentDirection.out,
              name: 'names')
        ]),
        DBusIntrospectMethod('ListActivatableNames', args: [
          DBusIntrospectArgument(DBusSignature('as'), DBusArgumentDirection.out,
              name: 'names')
        ]),
        DBusIntrospectMethod('NameHasOwner', args: [
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_,
              name: 'name'),
          DBusIntrospectArgument(DBusSignature('b'), DBusArgumentDirection.out,
              name: 'result')
        ]),
        DBusIntrospectMethod('StartServiceByName', args: [
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_,
              name: 'name'),
          DBusIntrospectArgument(DBusSignature('u'), DBusArgumentDirection.in_,
              name: 'flags'),
          DBusIntrospectArgument(DBusSignature('u'), DBusArgumentDirection.out,
              name: 'result')
        ]),
        DBusIntrospectMethod('GetNameOwner', args: [
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_,
              name: 'name'),
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out,
              name: 'owner')
        ]),
        DBusIntrospectMethod('GetConnectionUnixUser', args: [
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_,
              name: 'name'),
          DBusIntrospectArgument(DBusSignature('u'), DBusArgumentDirection.out,
              name: 'unix_user_id')
        ]),
        DBusIntrospectMethod('GetConnectionUnixProcessID', args: [
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_,
              name: 'name'),
          DBusIntrospectArgument(DBusSignature('u'), DBusArgumentDirection.out,
              name: 'unix_process_id')
        ]),
        DBusIntrospectMethod('GetConnectionCredentials', args: [
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_,
              name: 'name'),
          DBusIntrospectArgument(
              DBusSignature('a{sv}'), DBusArgumentDirection.out,
              name: 'credentials')
        ]),
        DBusIntrospectMethod('AddMatch', args: [
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_,
              name: 'rule')
        ]),
        DBusIntrospectMethod('RemoveMatch', args: [
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_,
              name: 'rule')
        ]),
        DBusIntrospectMethod('GetId', args: [
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out,
              name: 'id')
        ])
      ], signals: [
        DBusIntrospectSignal('NameOwnerChanged', args: [
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out,
              name: 'name'),
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out,
              name: 'old_owner'),
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out,
              name: 'new_owner')
        ]),
        DBusIntrospectSignal('NameLost', args: [
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out,
              name: 'name'),
        ]),
        DBusIntrospectSignal('NameAcquired', args: [
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out,
              name: 'name'),
        ])
      ], properties: [
        DBusIntrospectProperty('Features', DBusSignature('as'),
            access: DBusPropertyAccess.read),
        DBusIntrospectProperty('Interfaces', DBusSignature('as'),
            access: DBusPropertyAccess.read)
      ])
    ];
  }

  /// Get the client that is currently owning [name].
  _DBusRemoteClient? _getClientByName(DBusBusName name) {
    for (var client in server._clients) {
      if (client.uniqueName == name) {
        return client;
      }
    }
    return _nameQueues[name]?.owner;
  }

  // Implementation of org.freedesktop.DBus.Hello
  DBusMethodResponse _hello(_DBusRemoteClient client) {
    if (client.receivedHello) {
      return DBusMethodErrorResponse.failed('Already handled Hello message');
    } else {
      client.receivedHello = true;
      return DBusMethodSuccessResponse([DBusString(client.uniqueName.value)]);
    }
  }

  // Implementation of org.freedesktop.DBus.RequestName
  DBusMethodResponse _requestName(_DBusRemoteClient client, String name,
      bool allowReplacement, bool replaceExisting, bool doNotQueue) {
    DBusBusName name_;
    try {
      name_ = DBusBusName(name);
    } on FormatException {
      return DBusMethodErrorResponse.invalidArgs("Bus name '$name' not valid");
    }
    if (name_.isUnique) {
      return DBusMethodErrorResponse.invalidArgs(
          'Not allowed to request a unique bus name');
    }

    var queue = _nameQueues[name_];
    var oldOwner = queue?.owner;
    if (queue == null) {
      queue = _DBusNameQueue(name_);
      _nameQueues[name_] = queue;
    }
    queue.addRequest(client, allowReplacement, replaceExisting, doNotQueue);

    int returnValue;
    if (queue.owner == client) {
      if (oldOwner == client) {
        returnValue = 4; // alreadyOwner
      } else {
        returnValue = 1; // primaryOwner
      }
    } else if (queue.hasRequest(client)) {
      returnValue = 2; // inQueue
    } else {
      returnValue = 3; // exists
    }

    _emitNameSignals(name_, oldOwner);

    return DBusMethodSuccessResponse([DBusUint32(returnValue)]);
  }

  // Implementation of org.freedesktop.DBus.ReleaseName
  DBusMethodResponse _releaseName(_DBusRemoteClient client, String name) {
    DBusBusName name_;
    try {
      name_ = DBusBusName(name);
    } on FormatException {
      return DBusMethodErrorResponse.invalidArgs("Bus name '$name' not valid");
    }
    if (name_.isUnique) {
      return DBusMethodErrorResponse.invalidArgs(
          'Not allowed to release a unique bus name');
    }

    var queue = _nameQueues[name_];
    var oldOwner = queue?.owner;
    int returnValue;
    if (queue == null) {
      returnValue = 2; // nonExistant
    } else if (_removeRequest(name_, client)) {
      returnValue = 1; // released
    } else {
      returnValue = 3; // notOwned
    }

    _emitNameSignals(name_, oldOwner);

    return DBusMethodSuccessResponse([DBusUint32(returnValue)]);
  }

  /// Release all names owned by [client].
  void _releaseAllNames(_DBusRemoteClient client) {
    var names = _nameQueues.keys.toList();
    for (var name in names) {
      var queue = _nameQueues[name]!;
      var oldOwner = queue.owner;
      _removeRequest(name, client);
      _emitNameSignals(name, oldOwner);
    }
  }

  /// Removes a request of [name] by [client].
  /// Returns true if a request was removed.
  bool _removeRequest(DBusBusName name, _DBusRemoteClient client) {
    var queue = _nameQueues[name];
    if (queue == null) {
      return false;
    }

    var removed = queue.removeRequest(client);

    // Remove empty queues.
    if (queue.requests.isEmpty) {
      _nameQueues.remove(name);
    }

    return removed;
  }

  /// Emit signals if [name] is no longer owned by [oldOwner].
  void _emitNameSignals(DBusBusName name, _DBusRemoteClient? oldOwner) {
    var queue = _nameQueues[name];
    var newOwner = queue?.owner;
    if (oldOwner == newOwner) {
      return;
    }

    _emitNameOwnerChanged(name, oldOwner?.uniqueName, newOwner?.uniqueName);
    if (oldOwner != null) {
      _emitNameLost(oldOwner.uniqueName, name);
    }
    if (newOwner != null) {
      _emitNameAcquired(newOwner.uniqueName, name);
    }
  }

  // Implementation of org.freedesktop.DBus.ListQueuedOwners
  DBusMethodResponse _listQueuedOwners(String name) {
    DBusBusName name_;
    try {
      name_ = DBusBusName(name);
    } on FormatException {
      return DBusMethodErrorResponse.invalidArgs("Bus name '$name' not valid");
    }
    var queue = _nameQueues[name_];
    var names = queue != null
        ? queue.requests.keys
            .map((client) => DBusString(client.uniqueName.value))
        : <DBusString>[];
    return DBusMethodSuccessResponse([DBusArray(DBusSignature('s'), names)]);
  }

  // Implementation of org.freedesktop.DBus.ListNames
  DBusMethodResponse _listNames() {
    var names = <DBusValue>[DBusString('org.freedesktop.DBus')];
    names.addAll(
        server._clients.map((client) => DBusString(client.uniqueName.value)));
    names.addAll(_nameQueues.keys.map((name) => DBusString(name.value)));
    return DBusMethodSuccessResponse([DBusArray(DBusSignature('s'), names)]);
  }

  // Implementation of org.freedesktop.DBus.ListActivatableNames
  DBusMethodResponse _listActivatableNames() {
    return DBusMethodSuccessResponse([
      DBusArray(
          DBusSignature('s'),
          (['org.freedesktop.DBus'] + server.activatableNames)
              .map((name) => DBusString(name)))
    ]);
  }

  // Implementation of org.freedesktop.DBus.NameHasOwner
  DBusMethodResponse _nameHasOwner(String name) {
    DBusBusName name_;
    try {
      name_ = DBusBusName(name);
    } on FormatException {
      return DBusMethodErrorResponse.invalidArgs("Bus name '$name' not valid");
    }
    bool returnValue;
    if (name == 'org.freedesktop.DBus') {
      returnValue = true;
    } else {
      returnValue = _getClientByName(name_) != null;
    }
    return DBusMethodSuccessResponse([DBusBoolean(returnValue)]);
  }

  // Implementation of org.freedesktop.DBus.StartServiceByName
  Future<DBusMethodResponse> _startServiceByName(String name, int flags) async {
    DBusBusName name_;
    try {
      name_ = DBusBusName(name);
    } on FormatException {
      return DBusMethodErrorResponse.invalidArgs("Bus name '$name' not valid");
    }
    DBusServerStartServiceResult result;
    if (_getClientByName(name_) != null || name == 'org.freedesktop.DBus') {
      result = DBusServerStartServiceResult.alreadyRunning;
    } else {
      result = await server.startServiceByName(name);
    }
    switch (result) {
      case DBusServerStartServiceResult.success:
        return DBusMethodSuccessResponse([DBusUint32(1)]);
      case DBusServerStartServiceResult.alreadyRunning:
        return DBusMethodSuccessResponse([DBusUint32(2)]);
      case DBusServerStartServiceResult.notFound:
        return _DBusServerErrorResponse.serviceUnknown();
    }
  }

  // Implementation of org.freedesktop.DBus.GetNameOwner
  DBusMethodResponse _getNameOwner(String name) {
    DBusBusName name_;
    try {
      name_ = DBusBusName(name);
    } on FormatException {
      return DBusMethodErrorResponse.invalidArgs("Bus name '$name' not valid");
    }
    DBusBusName? owner;
    if (name == 'org.freedesktop.DBus') {
      owner = DBusBusName('org.freedesktop.DBus');
    } else {
      var client = _getClientByName(name_);
      if (client != null) {
        owner = client.uniqueName;
      }
    }
    if (owner != null) {
      return DBusMethodSuccessResponse([DBusString(owner.value)]);
    } else {
      return _DBusServerErrorResponse.nameHasNoOwner('Name $name not owned');
    }
  }

  // Implementation of org.freedesktop.DBus.GetConnectionUnixUser
  DBusMethodResponse _getConnectionUnixUser(String name) {
    int uid;
    if (name == 'org.freedesktop.DBus') {
      uid = getuid();
    } else {
      DBusBusName name_;
      try {
        name_ = DBusBusName(name);
      } on FormatException {
        return DBusMethodErrorResponse.invalidArgs(
            "Bus name '$name' not valid");
      }
      var client = _getClientByName(name_);
      if (client == null) {
        return _DBusServerErrorResponse.nameHasNoOwner('Name $name not owned');
      }
      return _DBusServerErrorResponse.notSupported(
          "Can't determine client credentials");
    }

    return DBusMethodSuccessResponse([DBusUint32(uid)]);
  }

  // Implementation of org.freedesktop.DBus.GetConnectionUnixProcessId
  DBusMethodResponse _getConnectionUnixProcessId(String name) {
    int clientPid;
    if (name == 'org.freedesktop.DBus') {
      clientPid = pid;
    } else {
      DBusBusName name_;
      try {
        name_ = DBusBusName(name);
      } on FormatException {
        return DBusMethodErrorResponse.invalidArgs(
            "Bus name '$name' not valid");
      }
      var client = _getClientByName(name_);
      if (client == null) {
        return _DBusServerErrorResponse.nameHasNoOwner('Name $name not owned');
      }
      return _DBusServerErrorResponse.notSupported(
          "Can't determine client credentials");
    }

    return DBusMethodSuccessResponse([DBusUint32(clientPid)]);
  }

  // Implementation of org.freedesktop.DBus.GetConnectionCredentials
  DBusMethodResponse _getConnectionCredentials(String name) {
    var credentials = <String, DBusValue>{};
    if (name == 'org.freedesktop.DBus') {
      credentials['UnixUserID'] = DBusUint32(getuid());
      credentials['ProcessID'] = DBusUint32(pid);
    } else {
      DBusBusName name_;
      try {
        name_ = DBusBusName(name);
      } on FormatException {
        return DBusMethodErrorResponse.invalidArgs(
            "Bus name '$name' not valid");
      }
      var client = _getClientByName(name_);
      if (client == null) {
        return _DBusServerErrorResponse.nameHasNoOwner('Name $name not owned');
      }

      return _DBusServerErrorResponse.notSupported(
          "Can't determine client credentials");
    }

    return DBusMethodSuccessResponse([
      DBusDict(
          DBusSignature('s'),
          DBusSignature('v'),
          credentials.map(
              (key, value) => MapEntry(DBusString(key), DBusVariant(value))))
    ]);
  }

  // Implementation of org.freedesktop.DBus.AddMatch
  DBusMethodResponse _addMatch(_DBusRemoteClient client, String ruleString) {
    DBusMatchRule rule;
    try {
      rule = DBusMatchRule.fromDBusString(ruleString);
    } on DBusMatchRuleException {
      return _DBusServerErrorResponse.matchRuleInvalid();
    }
    client.matchRules.add(rule);
    return DBusMethodSuccessResponse([]);
  }

  // Implementation of org.freedesktop.DBus.RemoveMatch
  DBusMethodResponse _removeMatch(_DBusRemoteClient client, String ruleString) {
    DBusMatchRule rule;
    try {
      rule = DBusMatchRule.fromDBusString(ruleString);
    } on DBusMatchRuleException {
      return _DBusServerErrorResponse.matchRuleInvalid();
    }
    if (!client.matchRules.remove(rule)) {
      return _DBusServerErrorResponse.matchRuleNotFound();
    }
    return DBusMethodSuccessResponse([]);
  }

  // Implementation of org.freedesktop.DBus.GetId
  DBusMethodResponse _getId(_DBusRemoteClient client) {
    return DBusMethodSuccessResponse([DBusString(server.uuid)]);
  }

  /// Emits org.freedesktop.DBus.NameOwnerChanged.
  void _emitNameOwnerChanged(
      DBusBusName name, DBusBusName? oldOwner, DBusBusName? newOwner) {
    server._emitSignal(
        DBusObjectPath('/org/freedesktop/DBus'),
        DBusInterfaceName('org.freedesktop.DBus'),
        DBusMemberName('NameOwnerChanged'),
        values: [
          DBusString(name.value),
          DBusString(oldOwner?.value ?? ''),
          DBusString(newOwner?.value ?? '')
        ]);
  }

  /// Emits org.freedesktop.DBus.NameAcquired.
  void _emitNameAcquired(DBusBusName destination, DBusBusName name) {
    server._emitSignal(
        DBusObjectPath('/org/freedesktop/DBus'),
        DBusInterfaceName('org.freedesktop.DBus'),
        DBusMemberName('NameAcquired'),
        values: [DBusString(name.value)],
        destination: destination);
  }

  /// Emits org.freedesktop.DBus.NameLost.
  void _emitNameLost(DBusBusName destination, DBusBusName name) {
    server._emitSignal(DBusObjectPath('/org/freedesktop/DBus'),
        DBusInterfaceName('org.freedesktop.DBus'), DBusMemberName('NameLost'),
        values: [DBusString(name.value)], destination: destination);
  }
}
