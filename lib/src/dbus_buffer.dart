import 'dbus_value.dart';

/// Contains common functionality used in [DBusReadBuffer] and [DBusWriteBuffer].
class DBusBuffer {
  final int BYTE_ALIGNMENT = 1;
  final int BOOLEAN_ALIGNMENT = 4;
  final int INT16_ALIGNMENT = 2;
  final int UINT16_ALIGNMENT = 2;
  final int INT32_ALIGNMENT = 4;
  final int UINT32_ALIGNMENT = 4;
  final int INT64_ALIGNMENT = 8;
  final int UINT64_ALIGNMENT = 8;
  final int DOUBLE_ALIGNMENT = 8;
  final int STRING_ALIGNMENT = 4;
  final int OBJECT_PATH_ALIGNMENT = 4;
  final int SIGNATURE_ALIGNMENT = 1;
  final int VARIANT_ALIGNMENT = 1;
  final int STRUCT_ALIGNMENT = 8;
  final int ARRAY_ALIGNMENT = 4;
  final int DICT_ENTRY_ALIGNMENT = 8;

  /// Returns the alignment of a [DBusValue] with the given [signature].
  int getAlignment(DBusSignature signature) {
    if (signature.value == 'y') {
      return BYTE_ALIGNMENT;
    } else if (signature.value == 'b') {
      return BOOLEAN_ALIGNMENT;
    } else if (signature.value == 'n') {
      return INT16_ALIGNMENT;
    } else if (signature.value == 'q') {
      return UINT16_ALIGNMENT;
    } else if (signature.value == 'i') {
      return INT32_ALIGNMENT;
    } else if (signature.value == 'u') {
      return UINT32_ALIGNMENT;
    } else if (signature.value == 'x') {
      return INT64_ALIGNMENT;
    } else if (signature.value == 't') {
      return UINT64_ALIGNMENT;
    } else if (signature.value == 'd') {
      return DOUBLE_ALIGNMENT;
    } else if (signature.value == 's') {
      return STRING_ALIGNMENT;
    } else if (signature.value == 'o') {
      return OBJECT_PATH_ALIGNMENT;
    } else if (signature.value == 'h') {
      return SIGNATURE_ALIGNMENT;
    } else if (signature.value == 'v') {
      return VARIANT_ALIGNMENT;
    } else if (signature.value.startsWith('(')) {
      return STRUCT_ALIGNMENT;
    } else if (signature.value.startsWith('a')) {
      return ARRAY_ALIGNMENT;
    } else {
      return 1;
    }
  }
}
