import 'dart:ffi';

typedef _getuidC = Int32 Function();
typedef _getuidDart = int Function();

/// Gets the user ID of the current user.
int getuid() {
  final dylib = DynamicLibrary.open('libc.so.6');
  final getuidP = dylib.lookupFunction<_getuidC, _getuidDart>('getuid');
  return getuidP();
}
