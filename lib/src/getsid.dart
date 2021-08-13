// Conditionally import the FFI version, so this doesn't break web builds.
export 'getsid_stub.dart' if (dart.library.ffi) 'getsid_windows.dart';
