import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pedantic/pedantic.dart';

import 'dbus_introspect.dart';
import 'dbus_introspectable.dart';
import 'dbus_match_rule.dart';
import 'dbus_message.dart';
import 'dbus_method_response.dart';
import 'dbus_peer.dart';
import 'dbus_properties.dart';
import 'dbus_read_buffer.dart';
import 'dbus_value.dart';
import 'dbus_write_buffer.dart';

/// A client connected to a D-Bus server.
class _DBusRemoteClient {
  /// The socket this client connected on.
  final _DBusServerSocket serverSocket;

  /// The socket this client is communicating on.
  final Socket _socket;

  /// Incoming data.
  final _readBuffer = DBusReadBuffer();

  /// True once authentication is complete.
  bool isAuthenticated = false;
  bool readSocketControlMessage = false;

  /// True when have received a Hello message.
  bool receivedHello = false;

  /// Names owned by this client.
  final names = <String>[];

  /// Unique name of this client.
  String get uniqueName => names[0];

  /// Message match rules.
  final matchRules = <DBusMatchRule>[];

  _DBusRemoteClient(this.serverSocket, this._socket, String uniqueName) {
    names.add(uniqueName);
    _socket.listen(_processData);
  }

  /// True if this client wants to receive [message].
  bool matchMessage(DBusMessage message) {
    if (message.destination == uniqueName) {
      return true;
    }
    for (var rule in matchRules) {
      // FIXME(robert-ancell): Check if sender matches unique name like in client
      if (rule.match(
          type: message.type,
          sender: message.sender,
          interface: message.interface,
          member: message.member,
          path: message.path)) return true;
    }
    return false;
  }

  /// Send [message] to this client.
  void sendMessage(DBusMessage message) {
    var buffer = DBusWriteBuffer();
    buffer.writeMessage(message);
    _socket.add(buffer.data);
  }

  Future<void> close() async {
    await _socket.close();
  }

  /// Processes incoming data from this D-Bus client.
  void _processData(Uint8List data) {
    _readBuffer.writeBytes(data);

    var complete = false;
    while (!complete) {
      if (!isAuthenticated) {
        complete = _processAuth();
      } else {
        complete = _processMessages();
      }
      _readBuffer.flush();
    }
  }

  /// Send an authentication response to the client.
  void _writeAuthResponse(String message) {
    _socket.write(message + '\r\n');
  }

  /// Processes authentication messages received from the D-Bus client.
  bool _processAuth() {
    // Skip the empty byte sent if the client used a socket control message to send credentials.
    if (!readSocketControlMessage) {
      _readBuffer.readByte();
      readSocketControlMessage = true;
    }

    var line = _readBuffer.readLine();
    if (line == null) {
      return true;
    }

    var words = line.split(' ');
    var command = words.isEmpty ? '' : words[0];
    var args = words.skip(1).toList();
    switch (command) {
      case 'AUTH':
        if (args.isEmpty) {
          /// Respond with the mechanisms we support
          _writeAuthResponse('REJECTED EXTERNAL');
        } else {
          var mechanism = args[0];
          if (mechanism == 'EXTERNAL' && args.length == 2) {
            //var uid = args[1];
            _writeAuthResponse('OK ${serverSocket.uuid.toHexString()}');
          } else {
            _writeAuthResponse('REJECTED');
          }
        }
        break;
      case 'CANCEL':
        _writeAuthResponse('REJECTED');
        break;
      case 'BEGIN':
        isAuthenticated = true;
        break;
      case 'DATA':
        _writeAuthResponse('REJECTED');
        break;
      case 'ERROR':
        _writeAuthResponse('REJECTED');
        break;
      case 'NEGOTIATE_UNIX_FD':
        _writeAuthResponse('ERROR Unix fd not supported');
        break;
      default:
        _writeAuthResponse('ERROR Unknown command');
        break;
    }

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
    serverSocket.server._processMessage(m);

    return false;
  }
}

/// Unique ID used by D-Bus.
class _DBusUUID {
  late final List<int> value;

  /// Creates a new random UUID.
  _DBusUUID() {
    var random = Random();
    value =
        List<int>.generate(16, (index) => random.nextInt(256), growable: false);
  }

  /// Converts the
  String toHexString() {
    return value.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// A socket for incoming D-Bus server connections.
class _DBusServerSocket {
  /// The server this socket is listening for.
  final DBusServer server;

  /// Socket being listened on.
  final ServerSocket socket;

  /// Unique ID for this socket.
  final uuid = _DBusUUID();

  /// Connected clients.
  final _clients = <_DBusRemoteClient>[];

  _DBusServerSocket(this.server, this.socket) {
    socket.listen((clientSocket) {
      var uniqueName = ':${server._nextClientId}';
      server._nextClientId++;
      _clients.add(_DBusRemoteClient(this, clientSocket, uniqueName));
    });
  }

  Future<void> close() async {
    await socket.close();

    /// Delete the file used by Unix sockets.
    if (socket.address.type == InternetAddressType.unix) {
      await File(socket.address.host).delete();
    }
  }
}

/// A D-Bus server.
class DBusServer {
  /// Sockets being listened on.
  final _sockets = <_DBusServerSocket>[];

  /// Connected clients.
  Iterable<_DBusRemoteClient> get _clients =>
      _sockets.map((s) => s._clients).expand((c) => c);

  /// Next Id to use to generate a unique name for each client.
  int _nextClientId = 1;

  /// Next serial number to use for messages from the server.
  int _nextSerial = 1;

  /// Feature flags exposed by the server.
  final _features = <String>[];

  /// Interfaces supported by the server.
  final _interfaces = <String>[];

  /// Creates a new DBus server.
  DBusServer();

  /// Listens for connections on a Unix socket at [path].
  /// If [path] is not provided a random path is chosen.
  /// Returns the D-Bus address for clients to connect to this socket.
  Future<String> listenUnixSocket([String? path]) async {
    if (path == null) {
      var directory = await Directory.systemTemp.createTemp();
      path = '${directory.path}/dbus-socket';
    }
    var address = InternetAddress(path, type: InternetAddressType.unix);
    var socket = await ServerSocket.bind(address, 0);
    _sockets.add(_DBusServerSocket(this, socket));
    return 'unix:path=$path';
  }

  /// Terminates all active connections. If a server remains unclosed, the Dart process may not terminate.
  Future<void> close() async {
    for (var socket in _sockets) {
      await socket.close();
    }
  }

  /// Get the client that is currently owning [name].
  _DBusRemoteClient? _getClientByName(String name) {
    for (var client in _clients) {
      if (client.names.contains(name)) {
        return client;
      }
    }
    return null;
  }

  /// Process an incoming message.
  Future<void> _processMessage(DBusMessage message) async {
    // Forward to any clients that are listening to this message.
    for (var client in _clients) {
      if (client.matchMessage(message)) {
        client.sendMessage(message);
      }
    }

    // Process requests for the server.
    DBusMethodResponse? response;
    var client = _getClientByName(message.sender!);
    if (client != null &&
        !client.receivedHello &&
        !(message.destination == 'org.freedesktop.DBus' &&
            message.interface == 'org.freedesktop.DBus' &&
            message.member == 'Hello')) {
      await client.close();
      response =
          DBusMethodErrorResponse('org.freedesktop.DBus.Error.AccessDenied', [
        DBusString(
            'Client tried to send a message other than Hello without being registered')
      ]);
    } else if (message.destination == 'org.freedesktop.DBus') {
      if (message.type == DBusMessageType.methodCall) {
        response = await _processServerMethodCall(message);
      }
    } else {
      // No-one is going to handle this message.
      if (message.destination != null &&
          _getClientByName(message.destination!) == null) {
        response = DBusMethodErrorResponse(
            'org.freedesktop.DBus.Error.ServiceUnknown',
            [DBusString('The name ${message.destination} is not registered')]);
      }
    }

    // Send a response message if one generated.
    if (response != null) {
      var type = DBusMessageType.methodReturn;
      String? errorName;
      var values = const <DBusValue>[];
      if (response is DBusMethodSuccessResponse) {
        values = response.values;
      } else if (response is DBusMethodErrorResponse) {
        type = DBusMessageType.error;
        errorName = response.errorName;
        values = response.values;
      }
      var responseMessage = DBusMessage(type,
          flags: {DBusMessageFlag.noReplyExpected},
          serial: _nextSerial,
          errorName: errorName,
          replySerial: message.serial,
          destination: message.sender,
          sender: 'org.freedesktop.DBus',
          values: values);
      _nextSerial++;
      unawaited(_processMessage(responseMessage));
    }
  }

  /// Process a method call requested on the D-Bus server.
  Future<DBusMethodResponse> _processServerMethodCall(
      DBusMessage message) async {
    if (message.interface == 'org.freedesktop.DBus') {
      switch (message.member) {
        case 'Hello':
          return _hello(message);
        case 'RequestName':
          if (message.signature != DBusSignature('su')) {
            return DBusMethodErrorResponse(
                'org.freedesktop.DBus.Error.InvalidArgs', []);
          }
          var name = (message.values[0] as DBusString).value;
          var flags = (message.values[1] as DBusUint32).value;
          var allowReplacement = (flags & 0x01) != 0;
          var replaceExisting = (flags & 0x02) != 0;
          var doNotQueue = (flags & 0x04) != 0;
          return _requestName(
              message, name, allowReplacement, replaceExisting, doNotQueue);
        case 'ReleaseName':
          if (message.signature != DBusSignature('s')) {
            return DBusMethodErrorResponse(
                'org.freedesktop.DBus.Error.InvalidArgs', []);
          }
          var name = (message.values[0] as DBusString).value;
          return _releaseName(message, name);
        case 'ListQueuedOwners':
          if (message.signature != DBusSignature('s')) {
            return DBusMethodErrorResponse(
                'org.freedesktop.DBus.Error.InvalidArgs', []);
          }
          var name = (message.values[0] as DBusString).value;
          return _listQueuedOwners(message, name);
        case 'ListNames':
          if (message.values.isNotEmpty) {
            return DBusMethodErrorResponse(
                'org.freedesktop.DBus.Error.InvalidArgs', []);
          }
          return _listNames(message);
        case 'ListActivatableNames':
          if (message.values.isNotEmpty) {
            return DBusMethodErrorResponse(
                'org.freedesktop.DBus.Error.InvalidArgs', []);
          }
          return _listActivatableNames(message);
        case 'NameHasOwner':
          if (message.signature != DBusSignature('s')) {
            return DBusMethodErrorResponse(
                'org.freedesktop.DBus.Error.InvalidArgs', []);
          }
          var name = (message.values[0] as DBusString).value;
          return _nameHasOwner(message, name);
        case 'StartServiceByName':
          if (message.signature != DBusSignature('su')) {
            return DBusMethodErrorResponse(
                'org.freedesktop.DBus.Error.InvalidArgs', []);
          }
          var name = (message.values[0] as DBusString).value;
          var flags = (message.values[1] as DBusUint32).value;
          return _startServiceByName(message, name, flags);
        case 'GetNameOwner':
          if (message.signature != DBusSignature('s')) {
            return DBusMethodErrorResponse(
                'org.freedesktop.DBus.Error.InvalidArgs', []);
          }
          var name = (message.values[0] as DBusString).value;
          return _getNameOwner(message, name);
        case 'AddMatch':
          if (message.signature != DBusSignature('s')) {
            return DBusMethodErrorResponse(
                'org.freedesktop.DBus.Error.InvalidArgs', []);
          }
          var rule = (message.values[0] as DBusString).value;
          return _addMatch(message, rule);
        case 'RemoveMatch':
          if (message.signature != DBusSignature('s')) {
            return DBusMethodErrorResponse(
                'org.freedesktop.DBus.Error.InvalidArgs', []);
          }
          var rule = (message.values[0] as DBusString).value;
          return _removeMatch(message, rule);
        case 'GetId':
          if (message.values.isNotEmpty) {
            return DBusMethodErrorResponse(
                'org.freedesktop.DBus.Error.InvalidArgs', []);
          }
          return _getId(message);
        default:
          return DBusMethodErrorResponse(
              'org.freedesktop.DBus.Error.UnknownMethod', [
            DBusString(
                'Method ${message.interface}.${message.member} not provided')
          ]);
      }
    } else if (message.interface == 'org.freedesktop.DBus.Introspectable') {
      switch (message.member) {
        case 'Introspect':
          if (message.values.isNotEmpty) {
            return DBusMethodErrorResponse(
                'org.freedesktop.DBus.Error.InvalidArgs', []);
          }
          return _introspect(message);
        default:
          return DBusMethodErrorResponse(
              'org.freedesktop.DBus.Error.UnknownMethod', [
            DBusString(
                'Method ${message.interface}.${message.member} not provided')
          ]);
      }
    } else if (message.interface == 'org.freedesktop.DBus.Peer') {
      switch (message.member) {
        case 'Ping':
          if (message.values.isNotEmpty) {
            return DBusMethodErrorResponse(
                'org.freedesktop.DBus.Error.InvalidArgs', []);
          }
          return _ping(message);
        case 'GetMachineId':
          if (message.values.isNotEmpty) {
            return DBusMethodErrorResponse(
                'org.freedesktop.DBus.Error.InvalidArgs', []);
          }
          return _getMachineId(message);
        default:
          return DBusMethodErrorResponse(
              'org.freedesktop.DBus.Error.UnknownMethod', [
            DBusString(
                'Method ${message.interface}.${message.member} not provided')
          ]);
      }
    } else if (message.interface == 'org.freedesktop.DBus.Properties') {
      switch (message.member) {
        case 'Get':
          if (message.signature != DBusSignature('ss')) {
            return DBusMethodErrorResponse(
                'org.freedesktop.DBus.Error.InvalidArgs', []);
          }
          var interfaceName = (message.values[0] as DBusString).value;
          var name = (message.values[1] as DBusString).value;
          return _propertiesGet(message, interfaceName, name);
        case 'Set':
          if (message.signature != DBusSignature('ssv')) {
            return DBusMethodErrorResponse(
                'org.freedesktop.DBus.Error.InvalidArgs', []);
          }
          var interfaceName = (message.values[0] as DBusString).value;
          var name = (message.values[1] as DBusString).value;
          var value = (message.values[2] as DBusVariant).value;
          return _propertiesSet(message, interfaceName, name, value);
        case 'GetAll':
          if (message.signature != DBusSignature('s')) {
            return DBusMethodErrorResponse(
                'org.freedesktop.DBus.Error.InvalidArgs', []);
          }
          var interfaceName = (message.values[0] as DBusString).value;
          return _propertiesGetAll(message, interfaceName);
        default:
          return DBusMethodErrorResponse(
              'org.freedesktop.DBus.Error.UnknownMethod', [
            DBusString(
                'Method ${message.interface}.${message.member} not provided')
          ]);
      }
    } else {
      return DBusMethodErrorResponse(
          'org.freedesktop.DBus.Error.UnknownInterface',
          [DBusString('Interface ${message.interface} not provided')]);
    }
  }

  // Implementation of org.freedesktop.DBus.Hello
  DBusMethodResponse _hello(DBusMessage message) {
    var client = _getClientByName(message.sender!)!;
    if (client.receivedHello) {
      return DBusMethodErrorResponse('org.freedesktop.DBus.Error.Failed',
          [DBusString('Already handled Hello message')]);
    } else {
      client.receivedHello = true;
      return DBusMethodSuccessResponse([DBusString(message.sender!)]);
    }
  }

  // Implementation of org.freedesktop.DBus.RequestName
  DBusMethodResponse _requestName(DBusMessage message, String name,
      bool allowReplacement, bool replaceExisting, bool doNotQueue) {
    var client = _getClientByName(message.sender!)!;
    var owningClient = _getClientByName(name);
    int returnValue;
    if (owningClient == null) {
      /// FIXME(robert-ancell): Implement a name queue and honor replaceExisting/doNotQueue
      client.names.add(name);
      _emitNameOwnerChanged(name, '', client.uniqueName);
      _emitNameAcquired(client.uniqueName, name);
      returnValue = 1; // primaryOwner
    } else if (owningClient == client) {
      returnValue = 4; // alreadyOwner
    } else {
      if (doNotQueue) {
        returnValue = 3; // exists
      } else {
        returnValue = 2; // inQueue
      }
    }
    return DBusMethodSuccessResponse([DBusUint32(returnValue)]);
  }

  // Implementation of org.freedesktop.DBus.ReleaseName
  DBusMethodResponse _releaseName(DBusMessage message, String name) {
    var client = _getClientByName(message.sender!)!;
    int returnValue;
    if (client.names.remove(name)) {
      returnValue = 1; // released
    } else {
      if (_getClientByName(name) == null) {
        returnValue = 2; // nonEsistant
      } else {
        returnValue = 3; // notOwned
      }
    }
    return DBusMethodSuccessResponse([DBusUint32(returnValue)]);
  }

  // Implementation of org.freedesktop.DBus.ListQueuedOwners
  DBusMethodResponse _listQueuedOwners(DBusMessage message, String name) {
    return DBusMethodSuccessResponse([DBusArray(DBusSignature('s'), [])]);
  }

  // Implementation of org.freedesktop.DBus.ListNames
  DBusMethodResponse _listNames(DBusMessage message) {
    var names = <DBusValue>[DBusString('org.freedesktop.DBus')];
    for (var client in _clients) {
      names.addAll(client.names.map((name) => DBusString(name)));
    }
    return DBusMethodSuccessResponse([DBusArray(DBusSignature('s'), names)]);
  }

  // Implementation of org.freedesktop.DBus.ListActivatableNames
  DBusMethodResponse _listActivatableNames(DBusMessage message) {
    return DBusMethodSuccessResponse([DBusArray(DBusSignature('s'), [])]);
  }

  // Implementation of org.freedesktop.DBus.NameHasOwner
  DBusMethodResponse _nameHasOwner(DBusMessage message, String name) {
    bool returnValue;
    if (name == 'org.freedesktop.DBus') {
      returnValue = true;
    } else {
      returnValue = _getClientByName(name) != null;
    }
    return DBusMethodSuccessResponse([DBusBoolean(returnValue)]);
  }

  // Implementation of org.freedesktop.DBus.StartServiceByName
  DBusMethodResponse _startServiceByName(
      DBusMessage message, String name, int flags) {
    int returnValue;
    var client = _getClientByName(name);
    if (client != null || name == 'org.freedesktop.DBus') {
      returnValue = 2; // alreadyRunning
    } else {
      // TODO(robert-ancell): Support launching of services.
      return DBusMethodErrorResponse(
          'org.freedesktop.DBus.Error.ServiceNotFound');
    }
    return DBusMethodSuccessResponse([DBusUint32(returnValue)]);
  }

  // Implementation of org.freedesktop.DBus.GetNameOwner
  DBusMethodResponse _getNameOwner(DBusMessage message, String name) {
    String? owner;
    if (name == 'org.freedesktop.DBus') {
      owner = 'org.freedesktop.DBus';
    } else {
      var client = _getClientByName(name);
      if (client != null) {
        owner = client.uniqueName;
      }
    }
    if (owner != null) {
      return DBusMethodSuccessResponse([DBusString(owner)]);
    } else {
      return DBusMethodErrorResponse(
          'org.freedesktop.DBus.Error.NameHasNoOwner',
          [DBusString('Name $name not owned')]);
    }
  }

  // Implementation of org.freedesktop.DBus.AddMatch
  DBusMethodResponse _addMatch(DBusMessage message, String ruleString) {
    var client = _getClientByName(message.sender!)!;
    DBusMatchRule rule;
    try {
      rule = DBusMatchRule.fromDBusString(ruleString);
    } on Exception {
      return DBusMethodErrorResponse(
          'org.freedesktop.DBus.Error.MatchRuleInvalid');
    }
    client.matchRules.add(rule);
    return DBusMethodSuccessResponse([]);
  }

  // Implementation of org.freedesktop.DBus.RemoveMatch
  DBusMethodResponse _removeMatch(DBusMessage message, String ruleString) {
    var client = _getClientByName(message.sender!)!;
    DBusMatchRule rule;
    try {
      rule = DBusMatchRule.fromDBusString(ruleString);
    } on Exception {
      return DBusMethodErrorResponse(
          'org.freedesktop.DBus.Error.MatchRuleInvalid');
    }
    if (!client.matchRules.remove(rule)) {
      return DBusMethodErrorResponse(
          'org.freedesktop.DBus.Error.MatchRuleNotFound');
    }
    return DBusMethodSuccessResponse([]);
  }

  // Implementation of org.freedesktop.DBus.GetId
  DBusMethodResponse _getId(DBusMessage message) {
    var client = _getClientByName(message.sender!)!;
    return DBusMethodSuccessResponse(
        [DBusString(client.serverSocket.uuid.toHexString())]);
  }

  // Implementation of org.freedesktop.DBus.Introspectable.Introspect
  DBusMethodResponse _introspect(DBusMessage message) {
    var dbusInterface =
        DBusIntrospectInterface('org.freedesktop.DBus', methods: [
      DBusIntrospectMethod('Hello', args: [
        DBusIntrospectArgument(
            'unique_name', DBusSignature('s'), DBusArgumentDirection.out)
      ]),
      DBusIntrospectMethod('RequestName', args: [
        DBusIntrospectArgument(
            'name', DBusSignature('s'), DBusArgumentDirection.in_),
        DBusIntrospectArgument(
            'flags', DBusSignature('u'), DBusArgumentDirection.in_),
        DBusIntrospectArgument(
            'result', DBusSignature('u'), DBusArgumentDirection.out)
      ]),
      DBusIntrospectMethod('ReleaseName', args: [
        DBusIntrospectArgument(
            'name', DBusSignature('s'), DBusArgumentDirection.in_),
        DBusIntrospectArgument(
            'result', DBusSignature('u'), DBusArgumentDirection.out)
      ]),
      DBusIntrospectMethod('ListQueuedOwners', args: [
        DBusIntrospectArgument(
            'name', DBusSignature('s'), DBusArgumentDirection.in_),
        DBusIntrospectArgument(
            'names', DBusSignature('as'), DBusArgumentDirection.out)
      ]),
      DBusIntrospectMethod('ListNames', args: [
        DBusIntrospectArgument(
            'names', DBusSignature('as'), DBusArgumentDirection.out)
      ]),
      DBusIntrospectMethod('ListActivatableNames', args: [
        DBusIntrospectArgument(
            'names', DBusSignature('as'), DBusArgumentDirection.out)
      ]),
      DBusIntrospectMethod('NameHasOwner', args: [
        DBusIntrospectArgument(
            'name', DBusSignature('s'), DBusArgumentDirection.in_),
        DBusIntrospectArgument(
            'result', DBusSignature('b'), DBusArgumentDirection.out)
      ]),
      DBusIntrospectMethod('StartServiceByName', args: [
        DBusIntrospectArgument(
            'name', DBusSignature('s'), DBusArgumentDirection.in_),
        DBusIntrospectArgument(
            'flags', DBusSignature('u'), DBusArgumentDirection.in_),
        DBusIntrospectArgument(
            'result', DBusSignature('u'), DBusArgumentDirection.out)
      ]),
      DBusIntrospectMethod('GetNameOwner', args: [
        DBusIntrospectArgument(
            'name', DBusSignature('s'), DBusArgumentDirection.in_),
        DBusIntrospectArgument(
            'owner', DBusSignature('s'), DBusArgumentDirection.out)
      ]),
      DBusIntrospectMethod('AddMatch', args: [
        DBusIntrospectArgument(
            'rule', DBusSignature('s'), DBusArgumentDirection.in_)
      ]),
      DBusIntrospectMethod('RemoveMatch', args: [
        DBusIntrospectArgument(
            'rule', DBusSignature('s'), DBusArgumentDirection.in_)
      ]),
      DBusIntrospectMethod('GetId', args: [
        DBusIntrospectArgument(
            'id', DBusSignature('s'), DBusArgumentDirection.out)
      ])
    ], signals: [
      DBusIntrospectSignal('NameOwnerChanged', args: [
        DBusIntrospectArgument(
            'name', DBusSignature('s'), DBusArgumentDirection.out),
        DBusIntrospectArgument(
            'old_owner', DBusSignature('s'), DBusArgumentDirection.out),
        DBusIntrospectArgument(
            'new_owner', DBusSignature('s'), DBusArgumentDirection.out)
      ]),
      DBusIntrospectSignal('NameLost', args: [
        DBusIntrospectArgument(
            'name', DBusSignature('s'), DBusArgumentDirection.out),
      ]),
      DBusIntrospectSignal('NameAcquired', args: [
        DBusIntrospectArgument(
            'name', DBusSignature('s'), DBusArgumentDirection.out),
      ])
    ], properties: [
      DBusIntrospectProperty('Features', DBusSignature('as'),
          access: DBusPropertyAccess.read),
      DBusIntrospectProperty('Interfaces', DBusSignature('as'),
          access: DBusPropertyAccess.read)
    ]);
    var children = <DBusIntrospectNode>[];
    var serverPath = DBusObjectPath('/org/freedesktop/DBus');
    if (message.path != null && serverPath.isInNamespace(message.path!)) {
      children.add(DBusIntrospectNode(
          serverPath.value.substring(message.path!.value.length)));
    }
    var node = DBusIntrospectNode(
        null,
        <DBusIntrospectInterface>[
          dbusInterface,
          introspectIntrospectable(),
          introspectPeer(),
          introspectProperties()
        ],
        children);
    return DBusMethodSuccessResponse([DBusString(node.toXml().toXmlString())]);
  }

  // Implementation of org.freedesktop.DBus.Peer.Ping
  DBusMethodResponse _ping(DBusMessage message) {
    return DBusMethodSuccessResponse();
  }

  // Implementation of org.freedesktop.DBus.Peer.GetMachineId
  Future<DBusMethodResponse> _getMachineId(DBusMessage message) async {
    return DBusMethodSuccessResponse([DBusString(await getMachineId())]);
  }

  // Implementation of org.freedesktop.DBus.Properties.Get
  DBusMethodResponse _propertiesGet(
      DBusMessage message, String interfaceName, String name) {
    if (interfaceName == 'org.freedesktop.DBus') {
      switch (name) {
        case 'Features':
          return DBusGetPropertyResponse(DBusArray(
              DBusSignature('s'), _features.map((value) => DBusString(value))));
        case 'Interfaces':
          return DBusGetPropertyResponse(DBusArray(DBusSignature('s'),
              _interfaces.map((value) => DBusString(value))));
      }
    }
    return DBusMethodErrorResponse('org.freedesktop.DBus.Error.UnknownProperty',
        [DBusString('Properies $interfaceName.$name does not exist')]);
  }

  // Implementation of org.freedesktop.DBus.Properties.Set
  DBusMethodResponse _propertiesSet(
      DBusMessage message, String interfaceName, String name, DBusValue value) {
    if (interfaceName == 'org.freedesktop.DBus') {
      switch (name) {
        case 'Features':
        case 'Interfaces':
          return DBusMethodErrorResponse(
              'org.freedesktop.DBus.Error.PropertyReadOnly');
      }
    }
    return DBusMethodErrorResponse('org.freedesktop.DBus.Error.UnknownProperty',
        [DBusString('Properies $interfaceName.$name does not exist')]);
  }

  // Implementation of org.freedesktop.DBus.Properties.GetAll
  DBusMethodResponse _propertiesGetAll(
      DBusMessage message, String interfaceName) {
    var properties = <String, DBusValue>{};
    if (interfaceName == 'org.freedesktop.DBus') {
      properties['Features'] = DBusArray(
          DBusSignature('s'), _features.map((value) => DBusString(value)));
      properties['Interfaces'] = DBusArray(
          DBusSignature('s'), _interfaces.map((value) => DBusString(value)));
    }
    return DBusGetAllPropertiesResponse(properties);
  }

  /// Emits org.freedesktop.DBus.NameOwnerChanged.
  void _emitNameOwnerChanged(String name, String oldOwner, String newOwner) {
    _emitSignal(DBusObjectPath('/org/freedesktop/DBus'), 'org.freedesktop.DBus',
        'NameOwnerChanged',
        values: [DBusString(name), DBusString(oldOwner), DBusString(newOwner)]);
  }

  /// Emits org.freedesktop.DBus.NameAcquired.
  void _emitNameAcquired(String destination, String name) {
    _emitSignal(DBusObjectPath('/org/freedesktop/DBus'), 'org.freedesktop.DBus',
        'NameAcquired',
        values: [DBusString(name)], destination: destination);
  }

  /// Emits a signal from the D-Bus server.
  void _emitSignal(DBusObjectPath path, String interface, String member,
      {String? destination, List<DBusValue> values = const []}) {
    var message = DBusMessage(DBusMessageType.signal,
        flags: {DBusMessageFlag.noReplyExpected},
        serial: _nextSerial,
        path: path,
        interface: interface,
        member: member,
        destination: destination,
        sender: 'org.freedesktop.DBus',
        values: values);
    _nextSerial++;
    unawaited(_processMessage(message));
  }

  @override
  String toString() {
    return 'DBusServer()';
  }
}
