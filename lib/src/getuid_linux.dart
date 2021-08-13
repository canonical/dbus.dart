import 'dart:ffi';
import 'dart:io';

typedef _getuidC = Int32 Function();
typedef _getuidDart = int Function();

/// Gets the user ID of the current user.
int getuid() {
  if (!Platform.isLinux) {
    throw 'Unable to determine UID on this system';
  }

  final dylib = DynamicLibrary.open('libc.so.6');
  final getuidP = dylib.lookupFunction<_getuidC, _getuidDart>('getuid');
  return getuidP();
}
