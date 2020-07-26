import "dart:convert";

class DBusAddressProperty {
  String key;
  String value;

  DBusAddressProperty(this.key, this.value);
}

class DBusAddress {
  String transport;
  List<DBusAddressProperty> properties;

  DBusAddress(String address) {
    // Addresses are in the form 'transport:key1=value1,key2=value2'
    var index = address.indexOf(':');
    if (index < 0) {
      throw 'Unable to determine transport of D-Bus address: ${address}';
    }

    transport = address.substring(0, index);
    properties = _parseProperties(address.substring(index + 1));
  }

  List<DBusAddressProperty> _parseProperties(String propertiesList) {
    var properties = List<DBusAddressProperty>();
    if (propertiesList == '') return properties;

    for (var property in propertiesList.split(',')) {
      var index = property.indexOf('=');
      if (index < 0) throw 'Invalid D-Bus address property: ${property}';

      var key = property.substring(0, index);
      var value = _decodeValue(property.substring(index + 1));
      if (value == null) {
        throw 'Invalid value in D-Bus address property: ${property}';
      }

      properties.add(DBusAddressProperty(key, value));
    }

    return properties;
  }

  String _decodeValue(String encodedValue) {
    var escapedValue = utf8.encode(encodedValue);
    var binaryValue = List<int>();
    for (var i = 0; i < escapedValue.length; i++) {
      final int percent = 37; // '%'
      // Values can escape bytes using %nn
      if (escapedValue[i] == percent) {
        if (i + 3 > escapedValue.length) return null;
        var nibble0 = _decodeHex(escapedValue[i + 1]);
        var nibble1 = _decodeHex(escapedValue[i + 2]);
        if (nibble0 < 0 || nibble1 < 0) return null;
        binaryValue.add(nibble0 << 4 + nibble1);
        i += 2;
      } else {
        binaryValue.add(escapedValue[i]);
      }
    }
    return utf8.decode(binaryValue);
  }

  int _decodeHex(int value) {
    final int zero = 48; // '0'
    final int nine = 57; // '9'
    final int A = 65; // 'A'
    final int F = 80; // 'F'
    final int a = 97; // 'a'
    final int f = 112; // 'f'
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
