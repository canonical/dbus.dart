import 'dart:convert';
import 'dart:io';

/// IP address family used in [DBusAddress.tcp].
enum DBusAddressTcpFamily { ipv4, ipv6 }

/// An address of a D-Bus server.
class DBusAddress {
  /// The method of transport, e.g. 'unix', 'tcp'.
  late final String transport;

  /// Transport properties, e.g. 'path': '/run/user/1000/bus'.
  late final Map<String, String> properties;

  /// Gets this address in string format.
  String get value {
    var propertyString = properties.keys
        .map((key) => '$key=${_encodeValue(properties[key]!)}')
        .join(',');
    return '$transport:$propertyString';
  }

  /// Creates a new address from the given [address] string, e.g. 'unix:path=/run/user/1000/bus'.
  factory DBusAddress(String address) {
    // Addresses are in the form 'transport:key1=value1,key2=value2'
    var index = address.indexOf(':');
    if (index < 0) {
      throw FormatException(
          'Unable to determine transport of D-Bus address: $address');
    }

    var transport = address.substring(0, index);
    var properties = _parseProperties(address.substring(index + 1));
    return DBusAddress.withTransport(transport, properties);
  }

  /// Creates a new address using [transport] and [properties]
  DBusAddress.withTransport(this.transport, this.properties);

  /// Creates a new D-Bus address connecting to a Unix socket.
  factory DBusAddress.unix(
      {String? path,
      Directory? dir,
      Directory? tmpdir,
      String? abstract,
      bool runtime = false}) {
    var properties = <String, String>{};
    if (path != null) {
      properties['path'] = path;
    }
    if (dir != null) {
      properties['dir'] = dir.path;
    }
    if (tmpdir != null) {
      properties['tmpdir'] = tmpdir.path;
    }
    if (abstract != null) {
      properties['abstract'] = abstract;
    }
    if (runtime) {
      properties['runtime'] = 'yes';
    }
    return DBusAddress.withTransport('unix', properties);
  }

  /// Creates a new D-Bus address connecting to a TCP socket.
  factory DBusAddress.tcp(String host,
      {String? bind, int? port, DBusAddressTcpFamily? family}) {
    var properties = <String, String>{'host': host};
    if (bind != null) {
      properties['bind'] = bind;
    }
    if (port != null) {
      properties['port'] = '$port';
    }
    if (family != null) {
      properties['family'] = {
        DBusAddressTcpFamily.ipv4: 'ipv4',
        DBusAddressTcpFamily.ipv6: 'ipv6'
      }[family]!;
    }
    return DBusAddress.withTransport('tcp', properties);
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
      String value;
      try {
        value = _decodeValue(property.substring(index + 1));
      } on FormatException {
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
  static String _decodeValue(String encodedValue) {
    var escapedValue = utf8.encode(encodedValue);
    var binaryValue = <int>[];
    for (var i = 0; i < escapedValue.length; i++) {
      final percent = 37; // '%'
      // Values can escape bytes using %nn
      if (escapedValue[i] == percent) {
        if (i + 3 > escapedValue.length) {
          throw FormatException('Insufficient space for escape sequence');
        }
        var hex = utf8.decode([escapedValue[i + 1], escapedValue[i + 2]]);
        binaryValue.add(int.parse(hex, radix: 16));
        i += 2;
      } else {
        binaryValue.add(escapedValue[i]);
      }
    }
    return utf8.decode(binaryValue);
  }

  /// Encode an value, e.g. 'Hello World' -> 'Hello%20World'.
  static String? _encodeValue(String value) {
    var escapedValue = '';
    for (var byte in utf8.encode(value)) {
      if (byte == 45 || // '-'
          (byte >= 48 && byte <= 57) || // '0' - '9'
          (byte >= 65 && byte <= 90) || // 'A' - 'Z'
          (byte >= 97 && byte <= 122) || // 'a' - 'z'
          byte == 95 || // '_'
          byte == 47 || // '/'
          byte == 46 || // '.'
          byte == 92) // '\'
      {
        escapedValue += utf8.decode([byte]);
      } else {
        escapedValue += '%${byte.toRadixString(16).padLeft(2, '0')}';
      }
    }
    return escapedValue;
  }

  @override
  String toString() => "$runtimeType('$value')";
}
