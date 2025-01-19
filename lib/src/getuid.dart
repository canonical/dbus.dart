// Conditionally import the FFI version, so this doesn't break web builds.
export 'getuid_stub.dart' if (dart.library.io) 'getuid_linux.dart';
