import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

class _SID_AND_ATTRIBUTES extends Struct {
  external Pointer<Void> Sid;
  @Uint32()
  external int Attributes;
}

class _TOKEN_USER extends Struct {
  external _SID_AND_ATTRIBUTES User;
}

/// Gets the Windows security ID.
String getsid() {
  if (!Platform.isWindows) {
    throw 'Unable to determine SID on this system';
  }

  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final GetCurrentProcess = kernel32
      .lookupFunction<IntPtr Function(), int Function()>('GetCurrentProcess');
  final CloseHandle = kernel32.lookupFunction<Int32 Function(IntPtr hObject),
      int Function(int hObject)>('CloseHandle');
  final GetLastError = kernel32
      .lookupFunction<Uint32 Function(), int Function()>('GetLastError');
  final LocalFree = kernel32.lookupFunction<IntPtr Function(IntPtr hMem),
      int Function(int hMem)>('LocalFree');

  final advapi32 = DynamicLibrary.open('advapi32.dll');
  final OpenProcessToken = advapi32.lookupFunction<
      Int32 Function(IntPtr ProcessHandle, Uint32 DesiredAccess,
          Pointer<IntPtr> TokenHandle),
      int Function(int ProcessHandle, int DesiredAccess,
          Pointer<IntPtr> TokenHandle)>('OpenProcessToken');
  final GetTokenInformation = advapi32.lookupFunction<
      Int32 Function(
          IntPtr TokenHandle,
          Uint32 TokenInformationClass,
          Pointer TokenInformation,
          Uint32 TokenInformationLength,
          Pointer<Uint32> ReturnLength),
      int Function(
          int TokenHandle,
          int TokenInformationClass,
          Pointer TokenInformation,
          int TokenInformationLength,
          Pointer<Uint32> ReturnLength)>('GetTokenInformation');
  final ConvertSidToStringSidA = advapi32.lookupFunction<
      Int32 Function(Pointer<Void> Sid, Pointer<Pointer<Utf8>> StringSid),
      int Function(Pointer<Void> Sid,
          Pointer<Pointer<Utf8>> StringSid)>('ConvertSidToStringSidA');

  const TOKEN_QUERY = 0x0008;
  var h = calloc<IntPtr>();
  if (OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, h) == 0) {
    throw 'Failed to call OpenProcessToken: ${GetLastError()}';
  }
  var handle = h.value;
  calloc.free(h);

  const TokenUser = 1;
  const ERROR_INSUFFICIENT_BUFFER = 122;
  var length = calloc<Uint32>();
  if (GetTokenInformation(handle, TokenUser, nullptr, 0, length) == 0) {
    if (GetLastError() != ERROR_INSUFFICIENT_BUFFER) {
      throw 'Failed to call GetTokenInformation: ${GetLastError()}';
    }
  }
  var user = calloc.allocate<_TOKEN_USER>(length.value);
  if (GetTokenInformation(handle, TokenUser, user, length.value, length) == 0) {
    throw 'Failed to call GetTokenInformation: ${GetLastError()}';
  }
  calloc.free(length);

  var sidString = calloc<Pointer<Utf8>>();
  if (ConvertSidToStringSidA(user.ref.User.Sid, sidString) == 0) {
    throw 'Failed to call ConvertSidToStringSidA: ${GetLastError()}';
  }
  var sid = sidString.value.toDartString();
  LocalFree(sidString.value.address);
  calloc.free(user);
  calloc.free(sidString);

  CloseHandle(handle);

  return sid;
}
