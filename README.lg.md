The orignal dbus.dart library was forked and and extended with the following
functionalities:
- support for communicating over the ApplicationServices websocket (dbus
  bridge over websocket, data encapsulated in json)
- support for deserializing the JSON data into the DBusValue objects. This is
  required to have common API for purposes of switching between dbus-socket
  and websocket.
- dbus_annotation DBusReplySignature was added to generated code.
  DBusReplySignature brings the reply signature and names of output arguments
  into the dart code. This is required to generated the sound types in API
  instead of providing the List<DBusValue>. Generator was extended with
  --annotations option for this purpose.
- types required for dbus_annotations were added to the library.

Example of annotations:
```
33 @DBusAPI()
34 class SampleClass extends DBusRemoteObject {
35   @DBusReplySignature('iasss',['value','names','resource_name','type'])
36   Future<List<DBusValue>> callGetParams() async { ... }
37 }
```

