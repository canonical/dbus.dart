import 'dart:async';

import 'dbus_uuid.dart';

/// A server for D-Bus authentication.
class DBusAuthServer {
  final _responsesController = StreamController<String>();
  bool _readSocketControlMessage = false;
  var _externalDone = false;
  var _isAuthenticated = false;

  /// Unique ID for this connection.
  final DBusUUID uuid;

  /// Stream of responses to send to the authentication client.
  Stream<String> get responses => _responsesController.stream;

  /// True if was successfully authenticated.
  bool get isAuthenticated => _isAuthenticated;

  /// Creates a new authentication server.
  DBusAuthServer(this.uuid);

  /// Process a request [message] received from the client.
  void processRequest(String message) {
    // Skip the empty byte sent if the client used a socket control message to send credentials.
    if (!_readSocketControlMessage) {
      message = message.substring(1);
      _readSocketControlMessage = true;
    }

    // Validate is ASCII.
    if (message.contains(RegExp(r'[^\x00-\x7F]+'))) {
      _error('Message contains non-ASCII characters');
      return;
    }

    // First word is a command.
    var values = _splitOnSpace(message);
    var command = values[0];
    var args = values[1];

    switch (command) {
      case 'AUTH':
        if (args == '') {
          // Respond with the mechanisms we support
          _reject('EXTERNAL');
        } else {
          var values = _splitOnSpace(args);
          var mechanism = values[0];
          var initialResponse = values[1];
          switch (mechanism) {
            case 'EXTERNAL':
              _authenticateExternal(initialResponse);
              break;
            default:
              _reject("Mechanism '$mechanism' not supported");
              break;
          }
        }
        break;
      case 'CANCEL':
        _reject('Cancelled');
        break;
      case 'BEGIN':
        if (_externalDone) {
          _isAuthenticated = true;
        }
        break;
      case 'DATA':
        _reject('Unable to handle DATA command');
        break;
      case 'ERROR':
        _reject('Received error');
        break;
      case 'NEGOTIATE_UNIX_FD':
        break;
      default:
        _error("Unknown command '$command'");
        break;
    }
  }

  /// Sends a [message] to the server.
  void _send(String message) {
    _responsesController.add(message);
  }

  /// Rejects authentication.
  void _reject(String message) {
    _send('REJECTED $message');
  }

  /// Sends an error to the client.
  void _error(String message) {
    _send('ERROR $message');
  }

  /// Do authentication using the EXTERNAL mechanism.
  void _authenticateExternal(String uid) {
    // Note uid isn't checked.
    _externalDone = true;
    _send('OK ${uuid.toHexString()}');
  }

  List<String> _splitOnSpace(String value) {
    var index = value.indexOf(' ');
    if (index >= 0) {
      return [value.substring(0, index), value.substring(index + 1)];
    } else {
      return [value, ''];
    }
  }
}
