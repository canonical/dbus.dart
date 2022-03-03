import 'dbus_message.dart';
import 'dbus_value.dart';

class DBusWSMessage extends DBusMessage {
  DBusWSMessage(type,
      {flags = const {},
      serial,
      path,
      interface,
      member,
      errorName,
      replySerial,
      destination,
      sender,
      this.replySignature,
      values = const []})
      : super(type,
            flags: flags,
            serial: serial,
            path: path,
            interface: interface,
            member: member,
            errorName: errorName,
            replySerial: replySerial,
            destination: destination,
            sender: sender,
            values: values) {}

  DBusSignature? replySignature = null;
}
