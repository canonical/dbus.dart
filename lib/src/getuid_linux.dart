import 'dart:ffi';
import 'dart:io';

typedef _GetuidC = Int32 Function();
typedef _GetuidDart = int Function();

/// Gets the user ID of the current user.
int getuid() {
  if (!Platform.isLinux) {
    throw UnsupportedError(
        'Unable to determine UID on: ${Platform.operatingSystem}');
  }

  final dylib = DynamicLibrary.open('libc.so.6');
  final getuidP = dylib.lookupFunction<_GetuidC, _GetuidDart>('getuid');
  return getuidP();
}
