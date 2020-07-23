import "dbus_value.dart";

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
  final int SIGNATURE_ALIGNMENT = 1;
  final int VARIANT_ALIGNMENT = 1;
  final int STRUCT_ALIGNMENT = 8;
  final int ARRAY_ALIGNMENT = 4;
  final int DICT_ALIGNMENT = 8;
}
