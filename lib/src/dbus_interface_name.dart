/// Interface name used by D-Bus.
/// Names must:
/// * Contain at least two elements separate by '.'.
/// * Only contain the characters a-z, A-Z, 0-9 and _.
/// * Must not begin with a digit.
/// * Must be between one and 255 characters.
class DBusInterfaceName {
  /// The value of this interface name, e.g. 'com.example'.
  final String value;

  /// Creates and validated a D-Bus interface name.
  DBusInterfaceName(this.value) {
    if (value.length > 255) {
      throw FormatException('Interface name too long');
    }
    if (!value.contains('.')) {
      throw FormatException('Interface name needs at least two elements');
    }
    for (var element in value.split('.')) {
      if (!element.contains(RegExp('^[a-zA-Z_][0-9a-zA-Z_]+\$'))) {
        throw FormatException('Invalid element in interface name');
      }
    }
  }

  @override
  bool operator ==(other) => other is DBusInterfaceName && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => "$runtimeType('$value')";
}
