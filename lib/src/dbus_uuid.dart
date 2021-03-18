import 'dart:math';

/// Unique ID used by D-Bus.
class DBusUUID {
  late final List<int> value;

  /// Creates a new random UUID.
  DBusUUID() {
    var random = Random();
    value =
        List<int>.generate(16, (index) => random.nextInt(256), growable: false);
  }

  /// Creates a new UUID from a hexadecimal encoded string.
  DBusUUID.fromHexString(String value) {
    if (!value.contains(RegExp('^[0-9a-fA-F]{32}\$'))) {
      throw FormatException('Invalid UUID');
    }
    this.value = List<int>.generate(
        16,
        (index) =>
            int.parse(value.substring(index * 2, index * 2 + 2), radix: 16),
        growable: false);
  }

  /// Converts the UUID into a hexadecimal encoded string.
  String toHexString() {
    return value.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  }
}
