/// A D-Bus bus name.
class DBusBusName {
  /// The bus name.
  final String value;

  /// True if this a unique bus name e.g. ':1.42'.
  bool get isUnique => value.startsWith(':');

  /// Creates a new bus name from [value].
  DBusBusName(this.value) {
    if (value.isEmpty) {
      throw FormatException('Empty bus name');
    }
    if (value.length > 255) {
      throw FormatException('Bus name too long');
    }

    var nameWithoutPrefix = value.substring(isUnique ? 1 : 0);
    var elementRegexp = isUnique
        ? RegExp('^[0-9a-zA-Z_-]+\$')
        : RegExp('^[a-zA-Z_-][0-9a-zA-Z_-]*\$');

    if (!nameWithoutPrefix.contains('.')) {
      throw FormatException('Bus name needs at least two elements');
    }
    for (var element in nameWithoutPrefix.split('.')) {
      if (!element.contains(elementRegexp)) {
        throw FormatException('Invalid element in bus name');
      }
    }
  }

  @override
  bool operator ==(other) => other is DBusBusName && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => "$runtimeType('$value')";
}
