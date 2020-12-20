import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

import 'dart:async';
import 'dart:isolate';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sms_maintained/sms.dart';

//background packages
//import 'package:shared_preferences/shared_preferences.dart';
//import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

//geo packages
import 'package:geolocator/geolocator.dart';
import 'package:geofencing/geofencing.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

void main() {
  runApp(MyApp());
}

const reminder = "reminder";
const remind_later = "remind_later";
const remind_short = "remind_short";
const check_location = "check_location";
Position _currentPos;
List<String> registeredGeofences = [];
//A list of lists. each element stores a Geofence id and a message to display
List<List<String>> geoReminders = [];

String geofenceState = 'N/A';

double latitude = 30;
double longitude = 30;
double radius = 150.0;
String gfName = "default";
ReceivePort port = ReceivePort();
final List<GeofenceEvent> triggers = <GeofenceEvent>[
  GeofenceEvent.enter,
  GeofenceEvent.dwell,
  GeofenceEvent.exit
];
final AndroidGeofencingSettings androidSettings = AndroidGeofencingSettings(
    initialTrigger: <GeofenceEvent>[
      GeofenceEvent.enter,
      GeofenceEvent.exit,
      GeofenceEvent.dwell
    ],
    loiteringDelay: 1000 * 60);

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void callbackDispatcher() {
  // Workmanager.executeTask((task, inputData) async {
  //   switch (task) {
  //     case reminder:
  //       print("$reminder executed");
  //       break;
  //     case remind_later:
  //       print("$remind_later executed");
  //       break;
  //     case remind_short:
  //       print("$remind_short executed");
  //       break;
  //     case Workmanager.iOSBackgroundTask:
  //       print("The iOS background fetch was triggered");
  //       Directory tempDir = await getTemporaryDirectory();
  //       String tempPath = tempDir.path;
  //       print(
  //           "You can access other plugins in the background, for example Directory.getTemporaryDirectory(): $tempPath");
  //       break;
}

//where WorkManager tasks are executed. Deprecated
// void callbackDispatcher() {
//   Workmanager.executeTask((task, inputData) async {
//     switch (task) {
//       case reminder:
//         print("$reminder executed");
//         break;
//       case remind_later:
//         print("$remind_later executed");
//         break;
//       case remind_short:
//         print("$remind_short executed");
//         break;
//       case Workmanager.iOSBackgroundTask:
//         print("The iOS background fetch was triggered");
//         Directory tempDir = await getTemporaryDirectory();
//         String tempPath = tempDir.path;
//         print(
//             "You can access other plugins in the background, for example Directory.getTemporaryDirectory(): $tempPath");
//         break;
//     }

//     return Future.value(true);
//   });
// }

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

//This page sets up notifications and serves as the base from which other pages spawn from.
class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    var initializationSettingsAndroid =
        AndroidInitializationSettings('healthalert128');
    var initializationSettingsIOs = IOSInitializationSettings();
    var initSetttings = InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOs);

    flutterLocalNotificationsPlugin.initialize(initSetttings,
        onSelectNotification: onSelectNotification);
  }

  Future onSelectNotification(String payload) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      return NewScreen(
        payload: payload,
      );
    }));
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

//This is the home page and sets up geofencing functions of this app.
class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    IsolateNameServer.registerPortWithName(
        port.sendPort, 'geofencing_send_port');
    port.listen((dynamic data) {
      print('Event: $data');
      setState(() {
        geofenceState = data;
      });
    });
    initPlatformState();
  }

  //Method takes in GeoFencing events, connected to when the user enters or leaves a GeoRegion
  static void callback(List<String> ids, Location l, GeofenceEvent e) async {
    print('Fences: $ids Location $l Event: $e');
    geoFenceNotification(ids, e);
    final SendPort send =
        IsolateNameServer.lookupPortByName('geofencing_send_port');
    send?.send(e.toString());
  }

  //Method takes in Geofence data to send out customized notifications based on
  //which event was triggered and for which geofence.
  static Future<void> geoFenceNotification(
      List<String> ids, GeofenceEvent e) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'media channel id',
      'media channel name',
      'media channel description',
      color: Colors.red,
      enableLights: true,
      largeIcon: DrawableResourceAndroidBitmap("healthalert128"),
      styleInformation: MediaStyleInformation(),
    );

    String whichEvent = e.toString();
    String message = "";
    if (geoReminders.isNotEmpty) {
      for (int i = 0; i < geoReminders.length; i++) {
        if (geoReminders
                .elementAt(i)
                .elementAt(0)
                .compareTo(ids.elementAt(0)) ==
            0) {
          if (geoReminders.elementAt(i).elementAt(2).compareTo(whichEvent) ==
              0) {
            message += geoReminders.elementAt(i).elementAt(1) + "/n";
          }
        }
      }
    }
    if (message.compareTo("") == 0) {
      message = "Here is your scheduled reminder to smile!";
    }

    var platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        0, 'Health Alerts Geo', message, platformChannelSpecifics);
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    print('Initializing...');
    await GeofencingManager.initialize();
    print('Initialization done');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Align(
                alignment: Alignment(0.0, -0.5),
                child: Image.asset("assets/images/hai.png"),
                heightFactor: 1.0,
                widthFactor: 1.0),
            Align(
              alignment: Alignment.center,
              child: FlatButton(
                child: Text(
                  'HealthAlert',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 40,
                    //fontFamily: 'JosefinSans',
                    fontStyle: FontStyle.italic,
                  ),
                ),

                //change this to ontap
                onPressed: () {
                  // Workmanager.initialize(
                  //   callbackDispatcher,
                  //   isInDebugMode: true,
                  // );
                  // print("WorkManager Online");
                  Navigator.push(
                      context,
                      PageTransition(
                          type: PageTransitionType.fade,
                          duration: Duration(seconds: 1),
                          child: MainMenu()));
                },
              ),
            ),
          ],
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class MainMenu extends StatefulWidget {
  @override
  _MainMenuState createState() => _MainMenuState();
}

//This is the main terminal where other pages can be accessed. It also contains
//a function to access the current location.
class _MainMenuState extends State<MainMenu> {
  _getCurrentLocation() {
    Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best)
        .then((Position position) {
      setState(() {
        _currentPos = position;
        print(position);
      });
    }).catchError((e) {
      print(e);
    });
  }

  //Method pushes a notification that shows the current location of the user.
  Future<void> showGeoNote() async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'media channel id',
      'media channel name',
      'media channel description',
      color: Colors.red,
      enableLights: true,
      largeIcon: DrawableResourceAndroidBitmap("healthalert128"),
      styleInformation: MediaStyleInformation(),
    );

    String message;
    if (_currentPos != null) {
      message = "LAT: ${_currentPos.latitude}, LNG: ${_currentPos.longitude}";
    } else {
      message = "Something went wrong here";
      print(_currentPos);
    }

    var platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        0, 'Health Alert', message, platformChannelSpecifics);
  }

  //Method sends out reminders according to a passed in message.
  Future reminderNotifications(String remind) async {
    var aPCS = AndroidNotificationDetails(
      'media channel id',
      'media channel name',
      'media channel description',
      color: Colors.blue,
      enableLights: true,
      enableVibration: true,
      largeIcon: DrawableResourceAndroidBitmap("healthalert128"),
      styleInformation: MediaStyleInformation(),
    );
    String message = remind;
    var platformChannelSpecifics = NotificationDetails(android: aPCS);
    await flutterLocalNotificationsPlugin.show(
        0, 'HA Reminders', message, platformChannelSpecifics);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
      children: <Widget>[
        Align(
          alignment: Alignment(-1, 1),
          child: FlatButton(
            child: Text("START LOCATION TRACKING",
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 10,
                )),
            onPressed: () {
              _getCurrentLocation();
            },
          ),
        ),
        Align(
            alignment: Alignment(0.0, 0.7),
            child: FlatButton(
              child: Image.asset(
                "assets/images/GeoReminderIcon.png",
                width: 125,
                height: 125,
              ),
              onPressed: () {
                Navigator.push(
                    context,
                    PageTransition(
                        type: PageTransitionType.fade,
                        duration: Duration(seconds: 1),
                        child: GeoReminders()));
              },
            )),
        Align(
          alignment: Alignment(0.0, 0.89),
          child: FlatButton(
            child: Text("SET LOCATION REMINDERS",
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 25,
                )),
            onPressed: () {
              Navigator.push(
                  context,
                  PageTransition(
                      type: PageTransitionType.fade,
                      duration: Duration(seconds: 1),
                      child: GeoReminders()));
            },
          ),
        ),
        Align(
          alignment: Alignment(-.70, -.95),
          child: Text(
            "HealthAlert",
            style: TextStyle(
              fontSize: 50,
              color: Colors.red,
            ),
          ),
        ),
        Align(
            alignment: Alignment(0.8, 0.05),
            child: FlatButton(
              child: Image.asset(
                "assets/images/GeofencingIcon.png",
                width: 125,
                height: 125,
              ),
              onPressed: () {
                Navigator.push(
                    context,
                    PageTransition(
                        type: PageTransitionType.fade,
                        duration: Duration(seconds: 1),
                        child: GeoInputPage()));
              },
            )),
        Align(
          alignment: Alignment(0.90, .35),
          child: FlatButton(
            child: Text("    SET UP\nGEOFENCES",
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 25,
                )),
            onPressed: () {
              Navigator.push(
                  context,
                  PageTransition(
                      type: PageTransitionType.fade,
                      duration: Duration(seconds: 1),
                      child: GeoInputPage()));
            },
          ),
        ),
        Align(
            alignment: Alignment(-0.8, 0.05),
            child: FlatButton(
              child: Image.asset(
                "assets/images/ReminderIcon.png",
                width: 150,
                height: 150,
              ),
              onPressed: () {
                Navigator.push(
                    context,
                    PageTransition(
                        type: PageTransitionType.fade,
                        duration: Duration(seconds: 1),
                        child: ReminderPage()));
              },
            )),
        Align(
          alignment: Alignment(-0.8, 0.29),
          child: FlatButton(
            child: Text("REMINDERS",
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 25,
                )),
            onPressed: () {
              Navigator.push(
                  context,
                  PageTransition(
                      type: PageTransitionType.fade,
                      duration: Duration(seconds: 1),
                      child: ReminderPage()));
            },
          ),
        ),
        Align(
            alignment: Alignment(0.0, -0.6),
            child: FlatButton(
              child: Image.asset(
                "assets/images/hai.png",
                width: 150,
                height: 150,
              ),
              onPressed: () {
                Navigator.push(
                    context,
                    PageTransition(
                        type: PageTransitionType.fade,
                        duration: Duration(seconds: 1),
                        child: StatusPage()));
              },
            )),
        Align(
          alignment: Alignment(0.0, 0 - .25),
          child: FlatButton(
            child: Text("STATUS",
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 30,
                )),
            onPressed: () {
              Navigator.push(
                  context,
                  PageTransition(
                      type: PageTransitionType.fade,
                      duration: Duration(seconds: 1),
                      child: StatusPage()));
            },
          ),
        ),
      ],
    ));
  }
}

class ReminderPage extends StatefulWidget {
  @override
  _ReminderPageState createState() => _ReminderPageState();
}

//This page allows the user to create messages and have them send at specified
//times over the span of a desired amount of days.
class _ReminderPageState extends State<ReminderPage> {
  String messageToRemind = "";
  String interval = "1:00";
  //this is in hours and assumes times assiciated with daylight unless indicated

  int numDaysToSend = 1;

  //Method takes in a string(in the digital or military format) and translates
  //it into minutes
  int parseStringIntoTime(String toParse) {
    List<int> comp = [];
    int translatedTime = 0;
    if (toParse.contains(":")) {
      List<String> components = toParse.split(":");
      for (int i = 0; i < components.length; i++) {
        comp.add(int.tryParse(components.elementAt(i)));
      }
    } else {
      comp.add(int.tryParse(toParse));
    }

    //break down into hours and minutes
    if (comp.length > 1) {
      translatedTime += comp.elementAt(1);
    } else {
      translatedTime += comp.elementAt(0) * 60;
    }
    return translatedTime;
  }

  //method process the interval textfield and creates that many notifications accordingly
  void scheduleNotificationsConsecutively() {
    List<String> times = interval.split(" ");
    int dayMinutes = 1440;
    for (int j = 0; j < numDaysToSend; j++) {
      for (int i = 0; i < times.length; i++) {
        int timeToAdd = parseStringIntoTime(times.elementAt(i)) + dayMinutes;
        scheduleNotification(timeToAdd);
        print("Reminder made");
      }
      dayMinutes += 1440;
    }
  }

  //method sets up a notification a given time later.
  Future<void> scheduleNotification(int timeAway) async {
    var scheduledNotificationDateTime =
        //DateTime.now().add(Duration(hours: interval));
        DateTime.now().add(Duration(seconds: 5));
    //DateTime.now().add(Duration(minutes: timeAway));
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'channel id',
      'channel name',
      'channel description',
      icon: 'healthalert128',
      largeIcon: DrawableResourceAndroidBitmap('healthalert128'),
    );
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics);
    // ignore: deprecated_member_use
    await flutterLocalNotificationsPlugin.schedule(
        0,
        'Health Alert Reminder',
        messageToRemind,
        scheduledNotificationDateTime,
        platformChannelSpecifics);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
      children: <Widget>[
        Align(
          alignment: Alignment(0.0, -0.85),
          child: Text(
            "Set up a reminder",
            style: TextStyle(
              color: Colors.blue,
              fontSize: 25,
            ),
          ),
        ),
        Align(
          alignment: Alignment(-.9, -0.7),
          child: Text(
            "Type Message Below",
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 13,
            ),
          ),
        ),
        Align(
          alignment: Alignment(0.0, -0.6),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'A message you want to see in the future',
            ),
            keyboardType: TextInputType.text,
            controller: TextEditingController(text: messageToRemind.toString()),
            onChanged: (String s) {
              messageToRemind = s;
            },
          ),
        ),
        Align(
          alignment: Alignment(0.0, -0.42),
          child: Text(
            "Type in the times (in Military or Digital) you would like tobe reminded(spaces in between each time)",
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 13,
            ),
          ),
        ),
        Align(
            alignment: Alignment(0.0, -0.17),
            child: Text(
              "How many days would you like this reminder to go on for?",
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 13,
              ),
            )),
        Align(
          alignment: Alignment(0.0, -0.3),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'When would you like to be reminded?',
            ),
            keyboardType: TextInputType.text,
            controller: TextEditingController(text: interval),
            onChanged: (String s) {
              interval = s;
            },
          ),
        ),
        Align(
          alignment: Alignment(0.0, -0.1),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'For how many days?',
            ),
            keyboardType: TextInputType.number,
            controller: TextEditingController(text: numDaysToSend.toString()),
            onChanged: (String s) {
              numDaysToSend = int.tryParse(s);
            },
          ),
        ),
        Align(
            alignment: Alignment(0.0, 0.1),
            child: RaisedButton(
              child: Text(
                "Create notification",
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 15,
                ),
              ),
              onPressed: () {
                scheduleNotificationsConsecutively();
              },
            )),
        Align(
          alignment: Alignment(1, 1),
          child: FlatButton(
            child: Text("Back", style: TextStyle(color: Colors.blue)),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ],
    ));
  }
}

//This allows any notifications to go to the app.
class NewScreen extends StatelessWidget {
  String payload;

  NewScreen({
    @required this.payload,
  });

  @override
  Widget build(BuildContext context) {
    return MyApp();
  }
}

class GeoReminders extends StatefulWidget {
  @override
  _GeoRemindersState createState() => _GeoRemindersState();
}

//This page allows the user to create GeoFence based reminders.
class _GeoRemindersState extends State<GeoReminders> {
  String dropDownVal = registeredGeofences.elementAt(0);
  String geominder = "";
  String state = "Enter";

  //Method stores the submitted message into a List<List<String>> for later use
  //when activated by GeoFencing Events
  void storeGeoMessage() {
    List<String> elementToAdd = [];
    elementToAdd.add(dropDownVal);
    elementToAdd.add(geominder);
    elementToAdd.add(state);
    geoReminders.add(elementToAdd);
    print("geoReminder added");
    print(elementToAdd.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment(0.0, -0.85),
            child: Text(
              "Set reminders for a location",
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 25,
              ),
            ),
          ),
          Align(
              alignment: Alignment(0.0, -0.7),
              child: DropdownButton<String>(
                value: dropDownVal,
                onChanged: (String newValue) {
                  setState(() {
                    dropDownVal = newValue;
                  });
                },
                items: registeredGeofences
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 15,
                      ),
                    ),
                  );
                }).toList(),
              )),
          Align(
            alignment: Alignment(0.0, -0.5),
            child: TextField(
              decoration: const InputDecoration(
                hintText:
                    'Write a reminder you want when you enter or leave the area',
              ),
              keyboardType: TextInputType.text,
              controller: TextEditingController(text: geominder),
              onChanged: (String s) {
                geominder = s;
              },
            ),
          ),
          Align(
              alignment: Alignment(0.0, -0.3),
              child: DropdownButton<String>(
                value: state,
                onChanged: (String newValue) {
                  setState(() {
                    state = newValue;
                  });
                },
                items: <String>["Enter", "Exit", "Dwell"]
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 15,
                      ),
                    ),
                  );
                }).toList(),
              )),
          Align(
            alignment: Alignment(0.0, 0.0),
            child: RaisedButton(
              child: Text(
                "Set reminder",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 15,
                ),
              ),
              onPressed: () {
                storeGeoMessage();
              },
            ),
          ),
          Align(
            alignment: Alignment(1, 1),
            child: FlatButton(
              child: Text("Back", style: TextStyle(color: Colors.blue)),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class GeoInputPage extends StatefulWidget {
  @override
  _GeoInputPageState createState() => _GeoInputPageState();
}

//This page allows the user to establish geofences for later use in reminders.
class _GeoInputPageState extends State<GeoInputPage> {
  //note: make sure, registered geofences is global

  String numberValidator(String value) {
    if (value == null) {
      return null;
    }
    final num a = num.tryParse(value);
    if (a == null) {
      return '"$value" is not a valid number';
    }
    return null;
  }

  String address = "266 4th St NW, Atlanta, GA 30313";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
            padding: const EdgeInsets.all(20.0),
            child: Stack(children: <Widget>[
              Align(
                alignment: Alignment(0.0, -.92),
                child: Text(
                  "Input coordinates below",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 25,
                  ),
                ),
              ),
              Align(
                alignment: Alignment(0.0, 0.05),
                child: RaisedButton(
                  child: const Text(
                    'Register',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 15,
                    ),
                  ),
                  onPressed: () {
                    if (latitude == null) {
                      setState(() => latitude = 0.0);
                    }
                    if (longitude == null) {
                      setState(() => longitude = 0.0);
                    }
                    if (radius == null) {
                      setState(() => radius = 0.0);
                    }
                    GeofencingManager.registerGeofence(
                            GeofenceRegion(
                                gfName, latitude, longitude, radius, triggers,
                                androidSettings: androidSettings),
                            _MyHomePageState.callback)
                        .then((_) {
                      GeofencingManager.getRegisteredGeofenceIds()
                          .then((value) {
                        setState(() {
                          registeredGeofences = value;
                        });
                      });
                    });
                  },
                ),
              ),
              Align(
                alignment: Alignment(0.0, 0.8),
                child: Text('Registered Geofences: $registeredGeofences'),
              ),
              Align(
                alignment: Alignment(-1.0, -0.8),
                child: Text(
                  "Latitude",
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 15,
                  ),
                ),
              ),
              Align(
                alignment: Alignment(0.0, -0.75),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Latitude',
                  ),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: latitude.toString()),
                  onChanged: (String s) {
                    latitude = double.tryParse(s);
                  },
                ),
              ),
              Align(
                alignment: Alignment(-1.0, -.6),
                child: Text(
                  "Longitude",
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 15,
                  ),
                ),
              ),
              Align(
                alignment: Alignment(0.0, -.55),
                child: TextField(
                    decoration: const InputDecoration(hintText: 'Longitude'),
                    keyboardType: TextInputType.number,
                    controller:
                        TextEditingController(text: longitude.toString()),
                    onChanged: (String s) {
                      longitude = double.tryParse(s);
                    }),
              ),
              Align(
                alignment: Alignment(-1.0, -.4),
                child: Text(
                  "Radius",
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 15,
                  ),
                ),
              ),
              Align(
                alignment: Alignment(0.0, -.35),
                child: TextField(
                    decoration: const InputDecoration(hintText: 'Radius'),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: radius.toString()),
                    onChanged: (String s) {
                      radius = double.tryParse(s);
                    }),
              ),
              Align(
                alignment: Alignment(-1.0, -.2),
                child: Text(
                  "Name of Location",
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 15,
                  ),
                ),
              ),
              Align(
                alignment: Alignment(0.0, -.13),
                child: TextField(
                    decoration: const InputDecoration(hintText: 'Name'),
                    keyboardType: TextInputType.name,
                    controller: TextEditingController(text: gfName),
                    onChanged: (String s) {
                      gfName = s;
                    }),
              ),
              Align(
                alignment: Alignment(-1.0, 1.0),
                child: RaisedButton(
                    child: Text(
                      "Remove all geofences",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 15,
                      ),
                    ),
                    onPressed: () {
                      print("button pressed");
                      _removeAllFences();
                    }),
              ),
              Align(
                alignment: Alignment(-1.0, 0.2),
                child: Text(
                  "If not using coordinates, input address below",
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 15,
                  ),
                ),
              ),
              Align(
                alignment: Alignment(0.0, 0.3),
                child: TextField(
                    decoration:
                        const InputDecoration(hintText: 'Input Address'),
                    keyboardType: TextInputType.name,
                    controller: TextEditingController(text: address),
                    onChanged: (String s) {
                      address = s;
                    }),
              ),
              Align(
                alignment: Alignment(0.0, .47),
                child: RaisedButton(
                  child: Text(
                    "Register from address",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 15,
                    ),
                  ),
                  onPressed: () => _addGeofenceFromAddress(address, radius),
                ),
              ),
              Align(
                alignment: Alignment(1, 1),
                child: FlatButton(
                  child: Text("Back", style: TextStyle(color: Colors.blue)),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ])));
  }

  double lat;
  double long;
  double tradius;

  void _addGeofenceFromAddress(String address, double radius) {
    Future<List<geocoding.Location>> lolist =
        geocoding.locationFromAddress(address);
    lolist.then((List<geocoding.Location> lo) {
      geocoding.Location closest = lo.elementAt(0);
      print(closest.toString());
      lat = closest.latitude;
      long = closest.longitude;
      tradius = radius; //this is the default

      GeofencingManager.registerGeofence(
              GeofenceRegion(gfName, lat, long, tradius, triggers,
                  androidSettings: androidSettings),
              _MyHomePageState.callback)
          .then((_) {
        GeofencingManager.getRegisteredGeofenceIds().then((value) {
          setState(() {
            registeredGeofences = value;
          });
        });
      });
    });
  }

  //method works
  void _removeAllFences() {
    geoReminders = [];
    Future<List<String>> fids = GeofencingManager.getRegisteredGeofenceIds();
    fids.then((List<String> newList) {
      for (int i = 0; i < newList.length; i++) {
        GeofencingManager.removeGeofenceById(newList.elementAt(i)).then((_) {
          GeofencingManager.getRegisteredGeofenceIds().then((value) {
            setState(() {
              registeredGeofences = value;
              print(value);
            });
          });
        });
      }
    });
  }
}

String recipientNum = "";
bool sent = false;

class StatusPage extends StatefulWidget {
  StatusPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _StatusPageState createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription _subscription;
  StreamSubscription<ConnectionStateUpdate> _connection;
  int temperature;
  String temperatureStr = "Hello";
  String humidityStr = "Hola";
  String imuStr = "Welcome";

  void _disconnect() async {
    _subscription?.cancel();
    if (_connection != null) {
      await _connection.cancel();
    }
  }

  void _connectBLE() {
    setState(() {
      temperatureStr = 'Loading';
      humidityStr = 'Loading';
      imuStr = 'Loading';
    });
    _disconnect();
    _subscription = _ble.scanForDevices(
        withServices: [],
        scanMode: ScanMode.lowLatency,
        requireLocationServicesEnabled: true).listen((device) {
      if (device.name == 'Nano33BLESENSE') {
        print('Nano33BLESENSE found!');
        _connection = _ble
            .connectToDevice(
          id: device.id,
        )
            .listen((connectionState) async {
          // Handle connection state updates
          print('connection state:');
          print(connectionState.connectionState);
          if (connectionState.connectionState ==
              DeviceConnectionState.connected) {
            // final characteristic1 = QualifiedCharacteristic(
            //     serviceId: Uuid.parse("181A"),
            //     characteristicId: Uuid.parse("2A6E"),
            //     deviceId: device.id);
            // final response1 = await _ble.readCharacteristic(characteristic1);
            // print(response1);

            // final characteristic2 = QualifiedCharacteristic(
            //     serviceId: Uuid.parse("281A"),
            //     characteristicId: Uuid.parse("4A6E"),
            //     deviceId: device.id);
            // final response2 = await _ble.readCharacteristic(characteristic2);
            // print(response2);
            final tempChar = QualifiedCharacteristic(
                serviceId: Uuid.parse("181A"),
                characteristicId: Uuid.parse("2A6E"),
                deviceId: device.id);
            _ble.subscribeToCharacteristic(tempChar).listen((data) {
              print(data);
              final tempResponse = data;
              setState(() {
                temperature = tempResponse[0];
                temperatureStr =
                    'Temperature: ' + temperature.toString() + '°C';
              });
            }, onError: (dynamic error) {
              print("error updating temp status");
            });

            final humidityChar = QualifiedCharacteristic(
                serviceId: Uuid.parse("181A"),
                characteristicId: Uuid.parse("2A6F"),
                deviceId: device.id);
            _ble.subscribeToCharacteristic(humidityChar).listen((data) {
              print(data);
              final humidityResponse = data;
              setState(() {
                humidityStr =
                    'Humidity: ' + humidityResponse[0].toString() + '%';
              });
            }, onError: (dynamic error) {
              print("error updating humidity status");
            });

            final dangerChar = QualifiedCharacteristic(
                serviceId: Uuid.parse("281A"),
                characteristicId: Uuid.parse("4A6E"),
                deviceId: device.id);
            _ble.subscribeToCharacteristic(dangerChar).listen((data) {
              print(data);
              var dangerResponse;
              if (data[0] == 1) {
                dangerResponse =
                    "Danger - User has fallen and has not moved for more than 10 seconds";
                if (!sent) {
                  SmsSender sender = new SmsSender();
                  String address = recipientNum;
                  String msg =
                      "From HealthAlert: I have fallen and have not moved for more than 10 seconds.";
                  print(address);
                  print(msg);
                  SmsMessage message = new SmsMessage(address, msg);
                  message.onStateChanged.listen((state) {
                    if (state == SmsMessageState.Sent) {
                      print("SMS is sent!");
                    } else if (state == SmsMessageState.Delivered) {
                      print("SMS is delivered!");
                    }
                  });
                  sender.sendSms(message);
                  sent = true;
                }
              } else {
                dangerResponse = "Normal";
                sent = false;
              }
              setState(() {
                imuStr = 'Activity: ' + dangerResponse;
              });
            }, onError: (dynamic error) {
              print("error updating fall status");
            });

            final tremorChar = QualifiedCharacteristic(
                serviceId: Uuid.parse("281A"),
                characteristicId: Uuid.parse("4A6F"),
                deviceId: device.id);
            _ble.subscribeToCharacteristic(tremorChar).listen((data) {
              print(data);
              var tremorResponse;
              if (data[0] == 1) {
                tremorResponse =
                    "Danger - User is experiencing severe tremors that may indicate a seizure";
                if (!sent) {
                  SmsSender sender = new SmsSender();
                  String address = recipientNum;
                  String msg =
                      "From HealthAlert: I am experiencing severe tremors that may indicate a seizure.";
                  print(address);
                  print(msg);
                  SmsMessage message = new SmsMessage(address, msg);
                  message.onStateChanged.listen((state) {
                    if (state == SmsMessageState.Sent) {
                      print("SMS is sent!");
                    } else if (state == SmsMessageState.Delivered) {
                      print("SMS is delivered!");
                    }
                  });
                  sender.sendSms(message);
                  sent = true;
                }
              } else {
                tremorResponse = "Normal";
                sent = false;
              }
              setState(() {
                imuStr = 'Activity: ' + tremorResponse;
              });
            }, onError: (dynamic error) {
              print("error updating tremor status");
            });

            // setState(() {
            //   temperature = response1[0];
            //   temperatureStr = temperature.toString() + '°' ;
            // });
            // _disconnect();
            // print('disconnected');
          }
        }, onError: (dynamic error) {
          // Handle a possible error
          print(error.toString());
        });
      }
    }, onError: (error) {
      print('error!');
      print(error.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                const Color(0xff3498eb),
                const Color(0xffc55dfc)
              ]))),
          Align(
              alignment: Alignment(0.0, -0.7),
              child: Text(
                temperatureStr,
                style: GoogleFonts.poppins(
                    textStyle: Theme.of(context)
                        .textTheme
                        .headline5
                        .copyWith(color: Colors.white)),
              )),
          Align(
            alignment: Alignment(0.0, -0.5),
            child: Text(
              humidityStr,
              style: GoogleFonts.poppins(
                  textStyle: Theme.of(context)
                      .textTheme
                      .headline5
                      .copyWith(color: Colors.white)),
            ),
          ),
          Align(
            alignment: Alignment(0.0, -0.3),
            child: Text(
              imuStr,
              style: GoogleFonts.poppins(
                  textStyle: Theme.of(context)
                      .textTheme
                      .headline5
                      .copyWith(color: Colors.white)),
            ),
          ),
          Align(
            alignment: Alignment(0.0, 0.8),
            child: FlatButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Settings()),
                );
              },
              child: Text(
                "Settings",
                style: GoogleFonts.poppins(
                    textStyle: Theme.of(context)
                        .textTheme
                        .headline5
                        .copyWith(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _connectBLE,
        tooltip: 'Increment',
        backgroundColor: Color(0xFF74A4BC),
        child: Icon(Icons.loop),
      ),
    );
  }
}

class Settings extends StatefulWidget {
  @override
  _Settings createState() => _Settings();
}

class _Settings extends State<Settings> {
  final myController = TextEditingController();

  @override
  void dispose() {
    myController.dispose();
    super.dispose();
  }

  String input;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                  const Color(0xff3498eb),
                  const Color(0xffc55dfc)
                ])),
          ),
          Align(
              alignment: Alignment(-0.5, -0.7),
              child: Text('Enter the phone number to send alerts to: ',
                  style: GoogleFonts.poppins(
                      textStyle: Theme.of(context)
                          .textTheme
                          .bodyText1
                          .copyWith(color: Colors.white)))),
          Align(
            alignment: Alignment(-0.5, -0.5),
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: TextFormField(
                controller: myController,
                decoration: InputDecoration(
                  labelText: "Current Recipient: " + recipientNum,
                  labelStyle: TextStyle(
                      color: Colors.white, fontFamily: "Poppins", fontSize: 20),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment(0.0, -0.1),
            child: FlatButton(
              onPressed: () {
                recipientNum = myController.text;
                print(recipientNum);
              },
              child: Text(
                "Save",
                style: GoogleFonts.poppins(
                    textStyle: Theme.of(context)
                        .textTheme
                        .headline5
                        .copyWith(color: Colors.white)),
              ),
            ),
          ),
          Align(
            alignment: Alignment(1.0, 1.0),
            child: FlatButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                "Back",
                style: GoogleFonts.poppins(
                    textStyle: Theme.of(context)
                        .textTheme
                        .headline5
                        .copyWith(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
