part of 'dbus_client.dart';

/// A client connection to a D-Bus over websocket server.
class DBusWSClient extends DBusClient {
  StreamChannel? _channel;
  final _readJsonBuffer = DBusWSReadBuffer();
  final Uri? _uri;
  DBusWSClient(this._uri) : super(DBusAddress("unix:path=/bus")) {}

  @visibleForTesting
  DBusWSClient.test(StreamChannel this._channel)
      : _uri = null,
        super(DBusAddress("unix:path=/bus")) {}

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
    // _channel can be injected with test construction, so skip connecting if already set.
    if (_channel == null) {
      _channel = WebSocketChannel.connect(_uri!);
    }
    _channel?.stream.listen(_processDataJson);
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
    var message = DBusWSMessage(DBusMessageType.methodCall,
        serial: _lastSerial,
        destination: destination,
        path: path,
        interface: interface,
        member: name,
        values: values.toList(),
        flags: flags,
        replySignature: replySignature);

    _sendMessage(message, requireConnect: requireConnect);

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
