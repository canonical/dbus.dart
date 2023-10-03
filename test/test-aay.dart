import 'package:dbus/code_generator.dart';
import 'package:dbus/dbus.dart';
import 'package:dbus/src/dbus_bus_name.dart';
import 'package:dbus/src/dbus_error_name.dart';
import 'package:dbus/src/dbus_interface_name.dart';
import 'package:dbus/src/dbus_match_rule.dart';
import 'package:dbus/src/dbus_member_name.dart';
import 'package:dbus/src/dbus_message.dart';
import 'package:dbus/src/dbus_write_buffer.dart';
import 'package:dbus/src/dbus_uuid.dart';
import 'package:dbus/src/getuid.dart';
import 'package:dbus/src/dbus_value.dart';

import 'dart:convert';
import 'dart:io';

DBusClient systemDBusClient = DBusClient.system();
//These get filled in in
late DBusRemoteObject serverObject;
late DBusRemoteObject entryGroupObject;
AvahiServiceConfig serviceConfig = AvahiServiceConfig('mycoolservice',8765);

void main() async {

  print('TEST new array of arrays DBus type by ADDING a NearbyShare service definition using DBus');
  print('This program first attaches to Avahi Server using the Dart DBus lib.');
  print('Next, it creates an Avahi EntryGroup object.');
  print('Next it adds a Nearby Share style service definition.');
  print('Then it polls the EntryGroup state until it is fully "Established".');
  print('Finally it uses the same service configuration to resolve its self.');
  print('BEGIN');
  print('Platform.hostname: ${Platform.localHostname}');

  await attachAvahiObjects();

  await testAddAvahiService();

  await testResolveAvahiService();

  print('DONE\n');
  print('''
  If there were no errors, You should be able see the Nearby Share named 
           ${serviceConfig.fullAdvertisedName} 
  from an android device or any Nearby Share client''');
  print('\nPRESS ENTER TO QUIT (removes service)...');

  var line = stdin.readLineSync(encoding: utf8);
  print('line: ${line}');
}

/* SAMPLE AVAHI SERVICE FILE
<service-group>

  <!-- Advertise ourselves using mDNS as a Google NearDrop Advertiser/Server
       (As Per  https://github.com/grishka/NearDrop/blob/master/PROTOCOL.md)
       **Client side service name comes from TXT record and will show us as
       "roxypuke" on client side.

       **mDNS advertised name is special format as per PROTOCOL.md and shows up as
       "I1NISVT8n14AAA"
       $ avahi-browse -r _FC9F5ED42C8A._tcp
    -->

  <!-- mDNS advertised name of service
       Hex or Char                Base64    | Base64URLSafe
       0x23,                      IW==      | Iw
       4 random chars "SHIT",     U0hJVA==  | U0hJVA
       3 chars 0xFC, 0x9F, 0x5E,  /J9e      | _J9e
       2 0x00 chars               AAA=      | AAA

       Full Hex: 23 53 48 49 54 FC 9F 5E 00 00
       Base64: I1NISVT8n14AAA==
       Base64url: I1NISVT8n14AAA
    -->

  <!--<name replace-wildcards="yes">Dog on %h</name>-->
  <name>I1NISVT8n14AAA</name>

  <service protocol="ipv4">

    <domain-name></domain-name><!--yes empty domain-name is necessary...-->
    <type>_FC9F5ED42C8A._tcp</type>
    <port>8088</port>
    <!--
       TXT record n="base64url encoded string"

       byte content:
       b1:000-version,0-visibility,011-laptop,0-reserved (00000110)=0x06
       b2..b17 random hex 0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09
       b18 (length of name of service as it will show up on the client nearby share screen "roxypuke")
       b19..b19+b18length user visible device name...roxypuke le 8

       Hex content:
       0x06,
       0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09,
       0x08,
       0x72,0x6f,0x78,0x79,0x70,0x75,0x6b,0x65

       Full Hex: 0x06,0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09,0x08,0x72,0x6f,0x78,0x79,0x70,0x75,0x6b,0x65
       b64: BgYJBgkGCQYJBgkGCQYJBgkIcm94eXB1a2U=
       b64Url: BgYJBgkGCQYJBgkGCQYJBgkIcm94eXB1a2U
      -->
    <txt-record>n="BgYJBgkGCQYJBgkGCQYJBgkIcm94eXB1a2U"</txt-record>
  </service>

</service-group>
*/

// This class AvahiServiceConfig Config is a placeholder for props used to Advertise
// our Nearby Share service using mDNS on Avahi daemon on local LAN.

class AvahiServiceConfig {
  AvahiServiceConfig(this.nearbyAdvertisedName,this.port,
      {this.domain='local',
        this.host='',
        this.interface=-1,
        this.protocol=0,
        this.flags=0}
      );

  final String serviceType = '_FC9F5ED42C8A._tcp';
  //The service Type is a fixed string. Check the PROTOCOL for why.
  final String serviceName = 'I1NISVT8n14AAA';
  // The service Name is fixed here but we could allow the configuration of the
  // four random characters...its not really worth it so I just use "SHIT"
  // Hex or Char                Base64    | Base64URLSafe
  // 0x23,                      IW==      | Iw
  // 4 random chars "SHIT",     U0hJVA==  | U0hJVA
  // 3 chars 0xFC, 0x9F, 0x5E,  /J9e      | _J9e
  // 2 0x00 chars               AAA=      | AAA
  // Full Hex: 23 53 48 49 54 FC 9F 5E 00 00
  // As Base64: I1NISVT8n14AAA==
  // As Base64url: I1NISVT8n14AAA

  int port; //Port number for nearby share server to listen on.
  String domain; //On a local linux lan this would be "local"
  String host; //fully qualified e.g. roxy.local
  int interface; //-1 all interfaces
  int protocol; //0 unspecified
  int flags; //0 unspecified

  String nearbyAdvertisedName; // see ctor.

  //If you pass a host name in, it needs to be fully qualified...e.g. myhost.local
  String get nearbyAdvertisedHost {
    if (this.host.trim().length == 0) {
      if (Platform.localHostname.contains('.')) return Platform.localHostname;
        else return Platform.localHostname+'.'+this.domain;
    } else return this.host.trim();
  }

  String get fullAdvertisedName {
    String s = this.nearbyAdvertisedHost+':'+this.nearbyAdvertisedName; //TODO add HOST
    //String s = this.nearbyAdvertisedName; //Dont include host
    return s;
  }
  // Return base64url encoded string of byte(val=0x06) + random bytes + nearbyAdvertisedName
  // byte content:
  // b1:000-version,0-visibility,011-laptop,0-reserved (00000110)=0x06
  // b2..b17 random hex 0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09,0x06,0x09
  // b18 (length of name of service as it will show up on the client nearby share screen "roxypuke")
  // b19..(b19+b18) length = user visible device name...nearbyAdvertisedHost:nearbyAdvertisedName
  // Note that a TXT record is an array of arrays but for a NearbyShare service it is only
  // one string.
  // e.g. n="base64url encoded string based on byte(val=0x06) + random bytes + nearbyAdvertisedName"
  // There is no occassion (in this service definition) for actual array of array.
  // e.g. x=y,a=b
  // This method returns the string based on byte(val=0x06) + random bytes + nearbyAdvertisedName"

  String getSpecialEncodedFullAdvertisedName() {

    List<int> fan = utf8.encode(this.fullAdvertisedName);
    //cant be more than 256 bytes since length is single byte...
    List<int> byteArr = [6,6,9,6,9,6,9,6,9,6,9,6,9,6,9,6,9,fan.length];
    byteArr.addAll(fan);
    // Should have something like this....
    // 'BgYJBgkGCQYJBgkGCQYJBgkIcm94eXB1a2U=='
    return base64Url.encode(byteArr);
  }

  // TXT Record notes. 1st and ONLY byte array of the TXT record.
  //As per PROTOCOL.md from github NearDrop repo.
  //The TXT record of the mdns record contains the "Advertised Name" plus other
  //odd data as described above all globbed together and base64url'd.
  //We combine nearbyAdvertisedHost+':'+nearbyAdvertisedName as the
  // "Full Advertised Name" that a user connecting to us would see
  // e.g. "myhost.local:My Cool Nearby Share Name"
  // Should return something like n="BgYJBgkGCQYJBgkGCQYJBgkIcm94eXB1a2U=="
  String get txt {
    return('n="'+this.getSpecialEncodedFullAdvertisedName()+'"');
  }

  @override String toString() {
    return
      '''AvahiServiceConfig(
         fullAdvertiseName: '${fullAdvertisedName}',
         port: ${port}, serviceName: '${serviceName}', serviceType: '${serviceType}',
         domain: '${domain}', host: '${nearbyAdvertisedHost}',
         interface: ${interface}, protocol: ${protocol}, flags: ${flags},
         txt: '${this.txt}'
         )
      ''';
  }
  List<DBusValue> asAvahiAddServiceParamList() {
    List<int> txtAsBytes = utf8.encode(this.txt);
    List<DBusByte> txtAsByteList = [];
    txtAsBytes.forEach((bv) {
      txtAsByteList.add(DBusByte(bv));
    });
    DBusArray txtArr = DBusArray(DBusSignature('y'),txtAsByteList);

    var parmValues = [
      DBusInt32(this.interface), //interface 3
      DBusInt32(this.protocol), //protocol
      DBusUint32(this.flags), //flags 13
      DBusString(this.serviceName), //name
      DBusString(this.serviceType), //type [DO NOT CHANGE]
      DBusString(this.domain), // domain
      DBusString(this.nearbyAdvertisedHost), // host (TODO add domain?)
      DBusUint16(this.port), //8019), //port
      DBusArray(DBusSignature('a'),[txtArr]),
    ];

    return parmValues;
  }

  List<DBusValue> asAvahiResolveServiceParamList() {
    var parmValues = [
      DBusInt32(this.interface), //interface 3
      DBusInt32(this.protocol), //protocol
      DBusString(this.serviceName), //name
      DBusString(this.serviceType), //type [DO NOT CHANGE]
      DBusString(this.domain), // domain
      DBusInt32(-1), //aprotocol?
      DBusUint32(this.flags), //flags
    ];
    return parmValues;
  }

}


Future<void> testResolveAvahiService() async {
  print(" --< testResolveAvahiService");
  //Test ResolveService call
  //dbus-send --system --print-reply --type=method_call --dest=org.freedesktop.Avahi /
  // org.freedesktop.Avahi.Server.ResolveService int32:-1 int32:-1
  // string:"I1NISVT8n14AAA" string:"_FC9F5ED42C8A._tcp" string:"" int32:-1 uint32:0

  try {

    var res = await serverObjectInvoke('ResolveService',serviceConfig.asAvahiResolveServiceParamList());
    print('  --< ResolveService results: ${res}');

  } catch (ee) {
    print('--< RESOLVE SERVICE ERROR ${ee}');
  }
}

//From avahi source interface org.freedesktop.Avahi.EntryGroup
//<method name="AddService">
//<arg name="interface" type="i" direction="in"/>
//<arg name="protocol" type="i" direction="in"/>
//<arg name="flags" type="u" direction="in"/>
//<arg name="name" type="s" direction="in"/>
//<arg name="type" type="s" direction="in"/>
//<arg name="domain" type="s" direction="in"/>
//<arg name="host" type="s" direction="in"/>
//<arg name="port" type="q" direction="in"/>
//<arg name="txt" type="aay" direction="in"/>
//</method>
//Test adding a service to the Avahi daemon using DBus.
//This assumes that attachAvahiObjects has already run.

Future<void> testAddAvahiService() async {

  print('  --* Testing AddService to Entry Group ${entryGroupObject.path}');
  print('  --* AVAHI SERVICE CONFIG: ${serviceConfig}');
  print('  --* AVAHI ADD SERVICE PARMS: ${serviceConfig.asAvahiAddServiceParamList()}');

  try {
    //assume that an EntryGroup was already added in attachAvahiObjects()

    var aRes = await entryGroupObjectInvoke('GetState',<DBusValue>[]);
    print('  --* GetState results: ${aRes}');

    var bRes = await entryGroupObjectInvoke('AddService',serviceConfig.asAvahiAddServiceParamList());
    print('  --* AddService results: ${bRes}');

    var cRes = await entryGroupObjectInvoke('Commit',<DBusValue>[]);
    print('  --* Commit results: ${cRes}');

    var dRes = await entryGroupObjectInvoke('GetState',<DBusValue>[]);
    print('  --* GetState results: ${dRes}');

    var eRes = await entryGroupObjectInvoke('IsEmpty',<DBusValue>[]);
    print('  --* IsEmpty results: ${eRes}');

    //typedef enum {
    //  AVAHI_ENTRY_GROUP_UNCOMMITED,    /**< The group has not yet been committed, the user must still call avahi_entry_group_commit() */
    // AVAHI_ENTRY_GROUP_REGISTERING,   /**< The entries of the group are currently being registered */
    // AVAHI_ENTRY_GROUP_ESTABLISHED,   /**< The entries have successfully been established */
    // AVAHI_ENTRY_GROUP_COLLISION,     /**< A name collision for one of the entries in the group has been detected, the entries have been withdrawn */
    // AVAHI_ENTRY_GROUP_FAILURE        /**< Some kind of failure happened, the entries have been withdrawn */
    //} AvahiEntryGroupState;
    int curState = (dRes[0] as DBusInt32).value;
    while (curState<2) {
      print('     --* LOOP curState: ${curState}');
      var  lRes = await entryGroupObjectInvoke('GetState',<DBusValue>[]);
      curState = (lRes[0] as DBusInt32).value;
      await Future.delayed(Duration(seconds: 2));
    }
    print('  --* LOOP FINISHED STATE: ${curState}');
    print('  --* SERVICE ESTABLISHED');
  } catch (ee) {
    print('--* ADD SERVICE ERROR ${ee}');
  }
}


Future<void> attachAvahiObjects() async {
  try {
    print('--> Attaching Avahi Server and EntryGroup objects');
    serverObject = DBusRemoteObject(systemDBusClient,
        name: 'org.freedesktop.Avahi',
        path: DBusObjectPath('/')
    );

    //EntryGroupNew call
    //dbus-send --system --print-reply --type=method_call --dest=org.freedesktop.Avahi /
    // org.freedesktop.Avahi.Server.EntryGroupNew

    var nbs_results = await serverObjectInvoke('EntryGroupNew',<DBusValue>[]);
    print('  -->EntryGroupNew results: ${nbs_results}');

    DBusObjectPath entryGroupPath = nbs_results[0] as DBusObjectPath;
    print('  -->New EntryGroupPath: ${entryGroupPath}');

    entryGroupObject = DBusRemoteObject(systemDBusClient,
        name: 'org.freedesktop.Avahi',
        path: entryGroupPath
    );

    var eg_results = await entryGroupObjectInvoke('GetState',<DBusValue>[]);
    int egState = (eg_results[0] as DBusInt32).value;
    print('  -->GetState result: ${egState}');

    print('-->Avahi objects attached.');
  } catch (ae) {
    print('-->ATTACH ERROR: ${ae}');
  }
}

// UTILITY FUNCTIONS BELOW

Future<List<DBusValue>> serverObjectInvoke(methodName,args) async {
  final interfaceName = 'org.freedesktop.Avahi.Server';
  var result = await serverObject.callMethod(
      interfaceName, methodName, args
  );
  return result.returnValues;
}
Future<List<DBusValue>> entryGroupObjectInvoke(methodName,args) async {
  final interfaceName = 'org.freedesktop.Avahi.EntryGroup';
  var eg_result = await entryGroupObject.callMethod(
      interfaceName, methodName, args
  );
  //print('RAW RESULT ${eg_result}');
  return eg_result.returnValues;
}


