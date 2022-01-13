import 'dbus_value.dart';

/// Contains common functionality used in [DBusReadBuffer] and [DBusWriteBuffer].
class DBusBuffer {
  final int byteAlignment = 1;
  final int booleanAlignment = 4;
  final int int16Alignment = 2;
  final int uint16Alignment = 2;
  final int int32Alignment = 4;
  final int uint32Alignment = 4;
  final int int64Alignment = 8;
  final int uint64Alignment = 8;
  final int doubleAlignment = 8;
  final int stringAlignment = 4;
  final int objectPathAlignment = 4;
  final int signatureAlignment = 1;
  final int variantAlignment = 1;
  final int structAlignment = 8;
  final int arrayAlignment = 4;
  final int dictEntryAlignment = 8;
  final int unixFdAlignment = 4;

  /// Returns the alignment of a [DBusValue] with the given [signature].
  int getAlignment(DBusSignature signature) {
    if (signature.value == 'y') {
      return byteAlignment;
    } else if (signature.value == 'b') {
      return booleanAlignment;
    } else if (signature.value == 'n') {
      return int16Alignment;
    } else if (signature.value == 'q') {
      return uint16Alignment;
    } else if (signature.value == 'i') {
      return int32Alignment;
    } else if (signature.value == 'u') {
      return uint32Alignment;
    } else if (signature.value == 'x') {
      return int64Alignment;
    } else if (signature.value == 't') {
      return uint64Alignment;
    } else if (signature.value == 'd') {
      return doubleAlignment;
    } else if (signature.value == 's') {
      return stringAlignment;
    } else if (signature.value == 'o') {
      return objectPathAlignment;
    } else if (signature.value == 'g') {
      return signatureAlignment;
    } else if (signature.value == 'v') {
      return variantAlignment;
    } else if (signature.value == 'h') {
      return unixFdAlignment;
    } else if (signature.value.startsWith('(')) {
      return structAlignment;
    } else if (signature.value.startsWith('a')) {
      return arrayAlignment;
    } else {
      return 1;
    }
  }
}
