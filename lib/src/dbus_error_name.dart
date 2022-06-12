/// Error name used by D-Bus.
/// Names must:
/// * Contain at least two elements separate by '.'.
/// * Only contain the characters a-z, A-Z, 0-9 and _.
/// * Must not begin with a digit.
/// * Must be between one and 255 characters.
class DBusErrorName {
  /// The value of this error name, e.g. 'com.example.Error'.
  final String value;

  /// Creates and validated a D-Bus error name.
  DBusErrorName(this.value) {
    if (value.length > 255) {
      throw FormatException('Error name too long');
    }
    if (!value.contains('.')) {
      throw FormatException('Error name needs at least two elements');
    }
    for (var element in value.split('.')) {
      if (!element.contains(RegExp('^[a-zA-Z_][0-9a-zA-Z_]+\$'))) {
        throw FormatException('Invalid element in error name');
      }
    }
  }

  @override
  bool operator ==(other) => other is DBusErrorName && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => "$runtimeType('$value')";
}
