part of 'dbus_client.dart';

/// A client connection to a D-Bus over websocket server.
class DBusWSClient extends DBusClient {
  WebSocketChannel? _channel;
  final _readJsonBuffer = DBusWSReadBuffer();
  final Uri _uri;
  DBusWSClient(this._uri) : super(DBusAddress("unix:path=/bus")) {}


  /// Terminates all active connections. If a client remains unclosed, the Dart process may not terminate.
  @override
  Future<void> close() async {
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
      _connectCompleter = null;
    }
  }

  /// Open a socket connection to the D-Bus server.
  @override
  Future<void> _openSocket() async {
    // print("> openSocket");
    _channel = WebSocketChannel.connect(_uri);
    _channel?.stream.listen(_processDataJson);
  }

  /// Performs authentication with D-Bus server.
  @override
  Future<bool> _authenticate() async {
    return true;
  }

  /// Connects to the D-Bus server.
  @override
  Future<void> _connect() async {
    // If already connecting, wait for that to complete.
    if (_connectCompleter != null) {
      return _connectCompleter?.future;
    }
    _connectCompleter = Completer();
    await _openSocket();
    _connectCompleter?.complete();
  }

  /// Adds a rule to match which messages to receive.
  @override
  Future<void> _addMatch(String rule) async {
    var count = _matchRules[rule];
    // print("> _addMatch $rule");
    if (count == null) {
      // print("> _addMatch callMethod: $rule");
      _matchRules[rule] = 1;
      await callMethod(
          destination: 'org.freedesktop.DBus',
          path: DBusObjectPath('/org/freedesktop/DBus'),
          interface: 'org.freedesktop.DBus',
          name: 'AddMatch',
          values: [DBusString(rule)],
          replySignature: DBusSignature(''));
      // print("> _addMatch callMethod end");
    } else {
      _matchRules[rule] = count + 1;
    }
  }

  /// Processes incoming data from the D-Bus server.
  void _processDataJson(dynamic data) {
    // print("_processDataJson: $data");
    _readJsonBuffer.setResponseData(data);

    var complete = false;
    while (!complete) {
      complete = _processMessages();
      _readJsonBuffer.flush();
    }
  }

  /// Processes messages (method calls/returns/errors/signals) received from the D-Bus server.
  @override
  bool _processMessages() {
    var message = _readJsonBuffer.readMessage();
    if (message == null) {
      return true;
    }

    // print("> _processMessages: type: ${message.type}");
    if (message.type == DBusMessageType.methodReturn ||
        message.type == DBusMessageType.error) {
      _processMethodResponse(message);
    } else if (message.type == DBusMessageType.signal) {
      _processSignal(message);
    }

    return true;
  }

  /// Processes a method return or error result from the D-Bus server.
  @override
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
  @override
  void _processSignal(DBusMessage message) {
    // print("> _processSignal: $message");
    // Check has required fields.
    if (message.path == null ||
        message.interface == null ||
        message.member == null) {
      return;
    }

    for (var stream in _signalStreams) {
      // If the stream is for an owned name, check if that matches the unique name in the message.
      var sender = message.sender;
      // print("> _processSignal ${message.sender}");
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
          sender: message.sender?.value ?? '',
          path: message.path ?? DBusObjectPath('/'),
          interface: message.interface?.value ?? '',
          name: message.member?.value ?? '',
          values: message.values);

      // print("_processSignal: message: $message");
      // print("_processSignal: values: ${message.values}");
      if (stream._signature != null && message.signature != stream._signature) {
        stream._controller.addError(DBusSignalSignatureException(
            '${message.interface?.value}.${message.member?.value}', signal));
      } else {
        stream._controller.add(signal);
      }
    }
  }

  /// Invokes a method on a D-Bus object.
  @override
  Future<DBusMethodSuccessResponse> _callMethod(
      {DBusBusName? destination,
      required DBusObjectPath path,
      DBusInterfaceName? interface,
      required DBusMemberName name,
      Iterable<DBusValue> values = const {},
      DBusSignature? replySignature,
      bool noReplyExpected = false,
      bool noAutoStart = false,
      bool allowInteractiveAuthorization = false,
      bool requireConnect = true}) async {

    // print(">> BEGIN _callMethod ${name}");
    _lastSerial++;
    var serial = _lastSerial;
    Future<DBusMethodResponse> response;
    if (noReplyExpected) {
      response = Future<DBusMethodResponse>.value(DBusMethodSuccessResponse());
    } else {
      var completer = Completer<DBusMethodResponse>();
      // print("_callMethod completer: $serial");
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
    var message = DBusWSMessage(DBusMessageType.methodCall,
        serial: _lastSerial,
        destination: destination,
        path: path,
        interface: interface,
        member: name,
        values: values.toList(),
        flags: flags,
        replySignature : replySignature
        );

    await _sendMessage(message, requireConnect: requireConnect);

    var r = await response;
    if (r is DBusMethodSuccessResponse) {
      /// Check returned values match expected signature.
      // print("_callMethod: END ${name} r.signature ${r.signature}");
      if (replySignature != null && r.signature != replySignature) {
        var fullName =
            interface != null ? '${interface.value}.${name.value}' : name.value;
        throw DBusReplySignatureException(fullName, r);
      }

      return r;
    } else if (r is DBusMethodErrorResponse) {
      // print("_callMethod: END throw $r");
      throw DBusMethodResponseException(r);
    } else {
      throw 'Unknown response type';
    }
  }

  /// Sends a message (method call/return/error/signal) to the D-Bus server.
  @override
  Future<void> _sendMessage(DBusMessage message,
      {bool requireConnect = true}) async {
    assert(message is DBusWSMessage);
    if (requireConnect) {
      await _connect();
    }
    // print('_sendMessage > ${message.toString()}');
    var buffer = DBusWSWriteBuffer();
    buffer.writeMessage(message as DBusWSMessage);
    _channel?.sink.add(buffer.data);
  }

  @override
  String toString() {
    return "DBusWSClient('$_address')";
  }
}
