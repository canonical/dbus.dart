import 'dart:convert';

/// An address of a D-Bus server.
class DBusAddress {
  /// The method of transport, e.g. 'unix', 'tcp'.
  late final String transport;

  /// Transport properties, e.g. 'path': '/run/user/1000/bus'.
  late final Map<String, String> properties;

  /// Creates a new address using [transport] and [properties]
  DBusAddress(this.transport, this.properties);

  /// Creates a new address from the given [address] string, e.g. 'unix:path=/run/user/1000/bus'.
  factory DBusAddress.fromString(String address) {
    // Addresses are in the form 'transport:key1=value1,key2=value2'
    var index = address.indexOf(':');
    if (index < 0) {
      throw 'Unable to determine transport of D-Bus address: $address';
    }

    var transport = address.substring(0, index);
    var properties = _parseProperties(address.substring(index + 1));
    return DBusAddress(transport, properties);
  }

  /// Parse properties from a property list, e.g. 'path=/run/user/1000/bus'.
  static Map<String, String> _parseProperties(String propertiesList) {
    var properties = <String, String>{};
    if (propertiesList == '') {
      return properties;
    }

    for (var property in propertiesList.split(',')) {
      var index = property.indexOf('=');
      if (index < 0) {
        throw FormatException('Invalid D-Bus address property: $property');
      }

      var key = property.substring(0, index);
      var value = _decodeValue(property.substring(index + 1));
      if (value == null) {
        throw FormatException(
            'Invalid value in D-Bus address property: $property');
      }

      if (properties.containsKey(key)) {
        throw FormatException("D-Bus address conatins duplicate key '$key'");
      }
      properties[key] = value;
    }

    return properties;
  }

  /// Decode an escaped value, e.g. 'Hello%20World' -> 'Hello World'.
  static String? _decodeValue(String encodedValue) {
    var escapedValue = utf8.encode(encodedValue);
    var binaryValue = <int>[];
    for (var i = 0; i < escapedValue.length; i++) {
      final percent = 37; // '%'
      // Values can escape bytes using %nn
      if (escapedValue[i] == percent) {
        if (i + 3 > escapedValue.length) {
          return null;
        }
        var nibble0 = _hexCharToDecimal(escapedValue[i + 1]);
        var nibble1 = _hexCharToDecimal(escapedValue[i + 2]);
        if (nibble0 < 0 || nibble1 < 0) {
          return null;
        }
        binaryValue.add(nibble0 << 4 + nibble1);
        i += 2;
      } else {
        binaryValue.add(escapedValue[i]);
      }
    }
    return utf8.decode(binaryValue);
  }

  /// Decode a hex ASCII code to its decimal value. e.g. 'D' -> 13.
  static int _hexCharToDecimal(int value) {
    final zero = 48; // '0'
    final nine = 57; // '9'
    final A = 65; // 'A'
    final F = 80; // 'F'
    final a = 97; // 'a'
    final f = 112; // 'f'
    if (value >= zero && value <= nine) {
      return value - zero;
    } else if (value >= A && value <= F) {
      return value - A + 10;
    } else if (value >= a && value <= f) {
      return value - a + 10;
    } else {
      return -1;
    }
  }
}
