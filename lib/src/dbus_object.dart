import 'dbus_introspect.dart';
import 'dbus_method_response.dart';
import 'dbus_value.dart';

/// An object that is exported on the bus.
class DBusObject {
  /// Called to get introspection information about this object.
  List<DBusIntrospectInterface> introspect() {
    return [];
  }

  /// Called when a method call is received on this object.
  Future<DBusMethodResponse> handleMethodCall(
      String interface, String member, List<DBusValue> values) async {
    return DBusMethodErrorResponse.unknownInterface();
  }
}
