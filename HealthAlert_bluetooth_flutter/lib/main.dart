import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sms_maintained/sms.dart';


void main() {
  runApp(MyApp());
}
String recipientNum = "";
bool sent = false;
class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Arduino Temperature'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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
        requireLocationServicesEnabled: true
    ).listen((device) {
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
                temperatureStr = 'Temperature: ' + temperature.toString() + '°C' ;
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
                humidityStr = 'Humidity: ' + humidityResponse[0].toString() + '%' ;
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
              if(data[0]==1){
                dangerResponse = "Danger - User has fallen and has not moved for more than 10 seconds";
                if(!sent){
                  SmsSender sender = new SmsSender();
                  String address = recipientNum;
                  String msg = "From HealthAlert: I have fallen and have not moved for more than 10 seconds.";
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
                  
              }else{
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
              if(data[0]==1){
                tremorResponse = "Danger - User is experiencing severe tremors that may indicate a seizure";
                if(!sent){
                  SmsSender sender = new SmsSender();
                  String address = recipientNum;
                  String msg = "From HealthAlert: I am experiencing severe tremors that may indicate a seizure.";
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
                  
              }else{
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
                colors: [const Color(0xff3498eb), const Color(0xffc55dfc)]
            )
            )
          ),
          Align(
            alignment: Alignment(0.0, -0.7),
            child: Text(
              temperatureStr,
              style: GoogleFonts.poppins(
                  textStyle: Theme.of(context)
                      .textTheme
                      .headline5
                      .copyWith(color: Colors.white)),
            )
          ),
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
                colors: [const Color(0xff3498eb), const Color(0xffc55dfc)]
            )
        ),
          ),
          Align(
            alignment: Alignment(-0.5, -0.7),
            child: Text(
              'Enter the phone number to send alerts to: ',
              style: GoogleFonts.poppins(
                  textStyle: Theme.of(context)
                      .textTheme
                      .bodyText1
                      .copyWith(color: Colors.white)))
          ),
          Align(
          alignment: Alignment(-0.5, -0.5),
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: TextFormField(
              controller: myController,
              decoration: InputDecoration(
                labelText: "Current Recipient: " + recipientNum,
                labelStyle: TextStyle(
                    color: Colors.white,
                    fontFamily: "Poppins",
                    fontSize: 20),
                    
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