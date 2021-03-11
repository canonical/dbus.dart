# Changelog

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
