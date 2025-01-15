import 'dart:async';
import 'dart:io';

import 'dbus_uuid.dart';
import 'getsid.dart';
import 'getuid.dart';

/// A client for D-Bus authentication.
class DBusAuthClient {
  final _doneCompleter = Completer();
  final _requestsController = StreamController<String>();
  var _attemptedExternal = false;
  var _isAuthenticated = false;
  final bool _requestUnixFd;
  var _unixFdSupported = false;
  DBusUUID? _uuid;
  String? _errorMessage;
  final String? _uid;

  /// Stream of requests to send to the authentication server.
  Stream<String> get requests => _requestsController.stream;

  /// A future that is completed when the authentication process is complete.
  Future<void> get done => _doneCompleter.future;

  /// True if was successfully authenticated.
  bool get isAuthenticated => _isAuthenticated;

  /// The UUID of the connection. Only available if successfully authenticated.
  DBusUUID get uuid => _uuid!;

  /// True if Unix file descriptor passing is supported.
  bool get unixFdSupported => _unixFdSupported;

  /// Error message received by the server.
  String? get errorMessage => _errorMessage;

  /// Creates a new authentication client.
  DBusAuthClient({bool requestUnixFd = true, String? uid})
      : _requestUnixFd = requestUnixFd,
        _uid = uid {
    // On start, end an empty byte, as this is required if sending the credentials as a socket control message.
    // We rely on the server using SO_PEERCRED to check out credentials.
    // Then request the supported mechanisms.
    _requestsController.onListen = () => _send('\x00AUTH');
  }

  /// Process a response [message] received from the server.
  void processResponse(String message) {
    // Validate is ASCII.
    if (message.contains(RegExp(r'[^\x00-\x7F]+'))) {
      _fail('Message contains non-ASCII characters');
      return;
    }

    // First word is a command.
    var index = message.indexOf(' ');
    String command, args;
    if (index >= 0) {
      command = message.substring(0, index);
      args = message.substring(index + 1);
    } else {
      command = message;
      args = '';
    }

    switch (command) {
      case 'REJECTED':
        if (!_attemptedExternal) {
          var mechanisms = args.split(' ');
          if (mechanisms.contains('EXTERNAL')) {
            _attemptedExternal = true;
            _authenticateExternal();
          } else {
            _fail('No supported mechanism');
          }
        } else {
          _errorMessage = args;
          _doneCompleter.complete();
        }
        break;
      case 'OK':
        try {
          _uuid = DBusUUID.fromHexString(args);
        } on FormatException {
          _fail('Invalid UUID in OK');
          return;
        }
        _isAuthenticated = true;
        if (_requestUnixFd) {
          _send('NEGOTIATE_UNIX_FD');
        } else {
          _begin();
        }
        break;
      case 'DATA':
        _fail('Unable to handle DATA command');
        break;
      case 'ERROR':
        if (isAuthenticated) {
          // Error was from NEGOTIATE_UNIX_FD, can continue without this.
          _begin();
        } else {
          _errorMessage = args;
          _doneCompleter.complete();
        }
        break;
      case 'AGREE_UNIX_FD':
        _unixFdSupported = true;
        _begin();
        break;
      default:
        _fail("Unknown command '$command'");
        break;
    }
  }

  /// Sends a [message] to the server.
  void _send(String message) {
    _requestsController.add(message);
  }

  /// Fails authentication, sending an error to the server and completing.
  void _fail(String message) {
    _send('ERROR $message');
    _doneCompleter.complete();
  }

  /// Start authentication using the EXTERNAL mechanism.
  void _authenticateExternal() {
    String authId;
    if (_uid != null) {
      authId = _uid!;
    } else if (Platform.isLinux) {
      authId = getuid().toString();
    } else if (Platform.isWindows) {
      authId = getsid();
    } else {
      throw 'Authentication not supported on ${Platform.operatingSystem}';
    }

    var authIdHex = '';
    for (var c in authId.runes) {
      authIdHex += c.toRadixString(16).padLeft(2, '0');
    }
    _send('AUTH EXTERNAL $authIdHex');
  }

  /// Complete authentication.
  void _begin() {
    _send('BEGIN');
    _doneCompleter.complete();
  }
}
