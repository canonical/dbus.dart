class DBusReplySignature {
    final String signature;
    final List<String> fieldNames;
    const DBusReplySignature(this.signature, this.fieldNames);
}

class DBusSignalSignature {
    final String signature;
    final String interface;
    const DBusSignalSignature(this.signature, this.interface);
}

class DBusAPI {
  const DBusAPI();
}
