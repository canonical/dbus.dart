/// Member (i.e. method or signal) name used by D-Bus.
/// Names must:
/// * Only contain the characters a-z, A-Z, 0-9 and _.
/// * Must not begin with a digit.
/// * Must be between one and 255 characters.
class DBusMemberName {
  /// The value of this member name, e.g. 'Hello'.
  final String value;

  /// Creates and validated a D-Bus member name.
  DBusMemberName(this.value) {
    if (value.length > 255) {
      throw FormatException('Member name too long');
    }
    if (value.isEmpty) {
      throw FormatException('Member name too short');
    }
    if (!value.contains(RegExp('^[a-zA-Z_][0-9a-zA-Z_]*\$'))) {
      throw FormatException('Invalid characters in member name');
    }
  }

  @override
  bool operator ==(other) => other is DBusMemberName && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => "$runtimeType('$value')";
}
