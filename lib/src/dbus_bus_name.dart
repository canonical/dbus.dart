/// Exception thrown for invalid bus names.
class DBusBusNameException implements Exception {
  final String message;

  DBusBusNameException(this.message);
}

/// A D-Bus bus name.
class DBusBusName {
  /// The bus name.
  final String value;

  /// True if this a unique bus name e.g. ':42'.
  bool get isUnique => value.startsWith(':');

  /// Creates a new bus name from [value].
  DBusBusName(this.value) {
    if (value.isEmpty) {
      throw DBusBusNameException('Empty bus name');
    }
    if (value.length > 255) {
      throw DBusBusNameException('Name longer than 255 characters');
    }

    var nameWithoutPrefix = value.substring(isUnique ? 1 : 0);

    if (nameWithoutPrefix.contains(RegExp('[^A-Za-z0-9_\\-.]'))) {
      throw DBusBusNameException(
          'Invalid characters in bus name: $nameWithoutPrefix');
    }

    // Non-unique connection names have more restrictions.
    if (!isUnique) {
      if (nameWithoutPrefix.startsWith(RegExp('[0-9]'))) {
        throw DBusBusNameException('Bus names cannot start with digit');
      }
      if (!nameWithoutPrefix.contains('.') ||
          nameWithoutPrefix.startsWith('.') ||
          nameWithoutPrefix.endsWith('.') ||
          nameWithoutPrefix.contains('..')) {
        throw DBusBusNameException(
            'Need at least two non-empty elements in bus name');
      }
    }
  }
}
