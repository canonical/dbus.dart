import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

class _SidAndAttributes extends Struct {
  external Pointer<Void> sid;
  @Uint32()
  external int attributes;
}

class _TokenUser extends Struct {
  external _SidAndAttributes user;
}

/// Gets the Windows security ID.
String getsid() {
  if (!Platform.isWindows) {
    throw 'Unable to determine SID on this system';
  }

  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final getCurrentProcess = kernel32
      .lookupFunction<IntPtr Function(), int Function()>('GetCurrentProcess');
  final closeHandle = kernel32.lookupFunction<Int32 Function(IntPtr hObject),
      int Function(int hObject)>('CloseHandle');
  final getLastError = kernel32
      .lookupFunction<Uint32 Function(), int Function()>('GetLastError');
  final localFree = kernel32.lookupFunction<IntPtr Function(IntPtr hMem),
      int Function(int hMem)>('LocalFree');

  final advapi32 = DynamicLibrary.open('advapi32.dll');
  final openProcessToken = advapi32.lookupFunction<
      Int32 Function(IntPtr processHandle, Uint32 desiredAccess,
          Pointer<IntPtr> tokenHandle),
      int Function(int processHandle, int desiredAccess,
          Pointer<IntPtr> tokenHandle)>('OpenProcessToken');
  final getTokenInformation = advapi32.lookupFunction<
      Int32 Function(
          IntPtr tokenHandle,
          Uint32 tokenInformationClass,
          Pointer tokenInformation,
          Uint32 tokenInformationLength,
          Pointer<Uint32> returnLength),
      int Function(
          int tokenHandle,
          int tokenInformationClass,
          Pointer tokenInformation,
          int tokenInformationLength,
          Pointer<Uint32> returnLength)>('GetTokenInformation');
  final convertSidToStringSidA = advapi32.lookupFunction<
      Int32 Function(Pointer<Void> sid, Pointer<Pointer<Utf8>> stringSid),
      int Function(Pointer<Void> sid,
          Pointer<Pointer<Utf8>> stringSid)>('ConvertSidToStringSidA');

  const tokenQuery = 0x0008;
  var h = calloc<IntPtr>();
  if (openProcessToken(getCurrentProcess(), tokenQuery, h) == 0) {
    throw 'Failed to call OpenProcessToken: ${getLastError()}';
  }
  var handle = h.value;
  calloc.free(h);

  const tokenUser = 1;
  const errorInsufficientBuffer = 122;
  var length = calloc<Uint32>();
  if (getTokenInformation(handle, tokenUser, nullptr, 0, length) == 0) {
    if (getLastError() != errorInsufficientBuffer) {
      throw 'Failed to call GetTokenInformation: ${getLastError()}';
    }
  }
  var user = calloc.allocate<_TokenUser>(length.value);
  if (getTokenInformation(handle, tokenUser, user, length.value, length) == 0) {
    throw 'Failed to call GetTokenInformation: ${getLastError()}';
  }
  calloc.free(length);

  var sidString = calloc<Pointer<Utf8>>();
  if (convertSidToStringSidA(user.ref.user.sid, sidString) == 0) {
    throw 'Failed to call ConvertSidToStringSidA: ${getLastError()}';
  }
  var sid = sidString.value.toDartString();
  localFree(sidString.value.address);
  calloc.free(user);
  calloc.free(sidString);

  closeHandle(handle);

  return sid;
}
