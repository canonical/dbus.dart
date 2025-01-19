# Changelog

## 0.7.11

* Work around a dbus-broker bug with path_namespace='/' match rules.
* Optionally pass auth client to dbus client.

## 0.7.10

* Fix generated code that uses DBusObjectPath.
* Add further fix for generated DBusStruct code.
* Import dart:io in generated code, required for file descriptors.

## 0.7.9

* Support unix fds in code generator.
* Support using D-Bus without a D-Bus message bus (i.e. point to point).
* Fix generated code that uses DBusStruct.

## 0.7.8

* Add helper methods for unix fd arrays.

## 0.7.7

* Use contents of DBusStruct/Array/Dict for hash codes.

## 0.7.6

* Add helper methods to DBusValue to reduce casting.
* Add helper methods for boolean arrays.

## 0.7.5

* depends on ffi 2.x

## 0.7.4

* Depend on xml 6.x

## 0.7.3

* Add missing cast in generated array code.
* Use const constructors for integer value types.
* Add DBusObjectPath.root constant.

## 0.7.2

* Add helper methods to map DBusArray and DBusDict.
* Add some convenience for working with D-Bus signatures.
* Use Object.hash for hashCode calculations.

## 0.7.1

* Only list as supporting Linux and Windows.
* Make a DBusArray.signature constructor.
* Fix type in generated code for D-Bus signatures.

## 0.7.0

* DBusSignalStream is now broadcast.
* Add support for sending/receiving unix file descriptors.
* Ensure a signal stream doesn't get recorded multiple times if listen() is called more than once.

## 0.6.8

* Fix missing semicolon on generated server property code.
* Fix generated server getAllProperties code.

## 0.6.7

* Fix exception when closing clients that have signals subscribed.
* Fix arrays of signatures not being correctly aligned.
* Fix invalid TimedOut exception name, and fix confusion with Timeout exception.
* Use DBusDict.stringVariant constructor in generated code.
* Don't generate empty methods in generated server code.
* Fix DBusMethodErrorResponse.toString typo.
* Improve match rule validation.
* Fix documentation for DBusBusName.isUnique.
* Test improvements.

## 0.6.6

* Remove unawaited calls that were making a depdendency on dart:async 2.14.
  This occurred after dropping pedantic in 0.6.4

## 0.6.5

* Fix invalid introspection generation for annotations.

## 0.6.4

* Fix generated code not using named constructor args.
* Make generated signal streams broadcast.
* Fix README.md example to use current API.
* Drop dependency on deprecated pedantic plugin.

## 0.6.3

* Fix ObjectManager still reporting unregistered objects.
* Fix incorrect introspection data for ObjectManager.
* Use FormatException for DBusAddress invalid format strings.
* Improvements to DBus address string escaping.
* Fix wrong ID returned from getId in DBusServer.

## 0.6.2

* Make classes for standard D-Bus exceptions.
* Handle exceptions on socket read/writes.
* Add DBusClient.nameOwnerChanged signal stream.
* D-Bus server now cleans up when clients disconnect from it.
* Fix wrong error returned from D-Bus server when accessing unknown service.

## 0.6.1

* Fix not everything being cleaned up when calling DBusServer.close().
* Correctly clean up in tests.

## 0.6.0

* Make emitSignal async, fixing an issue where signals from a method call may be handled after the call completes.
* Use named parameters in object constructors.

## 0.5.6

* Fix default system bus address - it is /var/run, not /run.

## 0.5.5

* Fix JS compilation due to large integer literals.
* Fix D-Bus message serial numbers being mixed up on connection, which was causing apps to fail inside Flatpaks.
* Implement D-Bus authentication on Windows.

## 0.5.4

* Fix validation of maybe type.
* Use type specific constructors in DBusArray.toString() and DBusDict.toString().

## 0.5.3

* Improve efficiency of DBusReadBuffer.
* Add DBusMaybe type (not used in D-Bus, but used in other code that used GVariant).
* Move DBusDict key checks to D-Bus en/decoding - GVariant code that uses dicts is allowed more key types.

## 0.5.2

* Support abstract unix domain addresses (requires Dart >= 2.14.0-170.0.dev).
* Fix message type not being written in DBusMessage.toString().

## 0.5.1

* Replace Iterable with List for children in DBusArray, DBusStruct.
* Add a signature check to DBusSignalStream/DBusRemoteSignalStream.
* Validate signatures of DBusDict and DBusArray.
* Send no reply flag in generated code with the org.freedesktop.DBus.Method.NoReply annotation.
* Add noAutoStart and allowInteractiveAuthorization flags to generated method calls.

## 0.5.0

* Make callMethod always return success and throw an exception on error.
* Add a response signature check parameter to method calls and getting properties.
* Fix equality operators for DBusStruct, DBusArray and DBusDict.
* Use DBusStruct class in generated code.
* Replace simple exceptions with ArgumentError/FormatException where appropiate.
* Validate D-Bus integer values.
* Add more validation for DBusSignature, DBusObjectPath.
* Validate more introspection XML.
* Break out code generation from dart-dbus to classes.
* Allow dart-dbus to read introspection XML from stdin.
* Rename test file so can just run 'dart test'.
* Add test for basic DBus types.
* Add tests for generted code.
* Add test for introspection XML parsing.

## 0.4.3

* Fix a race unsubscribing from signals which could trigger an exception if a DBusClient was closed very soon after creation or signal subscription.

## 0.4.2

* Add DBusArray factories for object paths and variants.
* Add DBusDict factory for the common string→variant mapping.

## 0.4.1

* Add DBusArray factories to create common simple arrays.

## 0.4.0

* Change DBusObject.path from a property to a constructor.
* Replaced DBusClient.subscribeSignals/DBusRemoteObject.subscribeSignal with new DBusSignalStream and DBusRemoteObjectSignalStream classes.
* Added DBusRemoteObjectManager class for easier use of D-Bus ObjectManager API.
* Fixed error messages in code generated by dart-dbus.
* Make able to disable introspection on exported objects.
* Fixed PropertiesChanged signal detection broken in 0.3.0.

## 0.3.3

* Fix DBusServer matching signals subscriptions with owned names

## 0.3.2

* Support building in Flutter web applications by conditionally importing dart:ffi.

## 0.3.1

* server: Fix messages not being forwarded to clients with owned names.
* Convert some inputs from List to Iterable

## 0.3.0

* DBusClient.registerObject now connects to the bus if it was disconnected.
* Add DBusMethodCall object to use when processing incoming method calls.
* Add signature checking on incoming method calls.
* Improve validation of D-Bus messages.
* Support messages received in big endian format
* Make DBusServer able to launch services by name.
* Support getting credentials of connections.
* Add flags (no reply, no autostart, allow interactive authorization) to method calls.
* Don't reply to requests if no reply was requested.
* Use DBusAddress class for addresses.
* Support connecting over TCP/IP.
* Fix invalid unique bus names assigned by DBusServer.
* Implement name queuing in DBusServer.
* Make ping() and getMachineId() contact the server by default.
* Add regression tests.

## 0.2.5

* Fixed namespace matching not working for the root namespace, could cause signals to be incorrectly subscribed.
* Added DBusServer.

## 0.2.4

* Fix regression subcribing to signals introduced in 0.2.1.

## 0.2.3

* Fix DBusClient blocking when cancelling signal streams.

## 0.2.2

* Fix regression in matching signals using pathNamespace, which affects ObjectManager usage.
* Code tidy ups to pass dart analyze in 1.12 final release.

## 0.2.1

* Use a meta version that works with the Dart 1.12 SDK.

## 0.2.0

* Add null safety support

## 0.1.2

* Ensure generated classes don't collide method/arg names.
* Add API to get owned names and subscribe to changes.
* Allow the class name to be provided for generated code.
* Generate a required parameter if D-Bus introspection doesn't contain a path.
* Implement DBusCkient.listQueuedOwners().

## 0.1.1

* Fix DBusClient blocking on close

## 0.1.0

* Initial release
