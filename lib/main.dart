import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:motion_sensors/motion_sensors.dart';
import 'package:sensor_location_final2_app/accelerometergraph.dart';
import 'package:sensor_location_final2_app/gyroscopegraph.dart';
import 'package:sensor_location_final2_app/locationmap.dart';
import 'package:sensor_location_final2_app/magnetometergraph.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:amazon_cognito_identity_dart/cognito.dart';
import 'package:amazon_cognito_identity_dart/sig_v4.dart';

import 'internalStorage.dart';
import 'location.dart';
import 'locationmap.dart';
//import 'aws_s3_identity.dart';
//import 'log.dart';

void main(){
  runApp(MyApp());
}

class MyApp extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Folder Storage',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      //home: MyHomePage(),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>{
  final TextEditingController titleController = new TextEditingController();
  final GlobalKey<FormState> _keyDialogForm = new GlobalKey<FormState>();

  Icon buttonIcon;
  String buttonText;
  Color buttonColor;

  bool isLocating;
  bool isLogging;

  Vector3 _accelerometer = Vector3.zero();
  Vector3 _gyroscope = Vector3.zero();
  Vector3 _magnetometer = Vector3.zero();

  double latitude = 0.0;
  double longitude = 0.0;

  StreamSubscription<PositionEvent> accuracyStreamSubscription;
  StreamSubscription _accelerometerSubscription;
  StreamSubscription _gyroscopeSubscription;
  StreamSubscription _magnetometerSubscription;

  int _groupValue = 0;

  bool checkboxValue = false;

  final TextEditingController accesskeyController = new TextEditingController();
  final TextEditingController secretkeyController = new TextEditingController();
  final TextEditingController regionController = new TextEditingController();
  final TextEditingController bucketnameController = new TextEditingController();
  final TextEditingController s3endpointController = new TextEditingController();

  List _entriesAcc = [];
  List _entriesGyro = [];
  List _entriesMag = [];
  List _entriesGeo = [];

  @override
  void initState(){
    super.initState();

    toggleLogging();

    _accelerometerSubscription = motionSensors.accelerometer.listen((AccelerometerEvent event) {
      setState(() {
        _accelerometer.setValues(event.x, event.y, event.z);
      });
      InternalStorage().setAccelerometerDataInternal(_accelerometer.x, _accelerometer.y, _accelerometer.z);
      if(isLogging){
        InternalStorage().addAccelerometerEntryInternal();
        _entriesAcc.add("${DateTime.now().toString()}, $_accelerometer");
      }
    });

    _gyroscopeSubscription = motionSensors.gyroscope.listen((GyroscopeEvent event) {
      setState(() {
        _gyroscope.setValues(event.x, event.y, event.z);
      });
      InternalStorage().setGyroscopeDataInternal(_gyroscope.x, _gyroscope.y, _gyroscope.z);
      if(isLogging){
        InternalStorage().addGyroscopeEntryInternal();
        _entriesGyro.add("${DateTime.now().toString()}, $_gyroscope");
      }
    });

    _magnetometerSubscription = motionSensors.magnetometer.listen((MagnetometerEvent event) {
      setState(() {
        _magnetometer.setValues(event.x, event.y, event.z);
      });
      InternalStorage().setMagnetometerDataInternal(_magnetometer.x, _magnetometer.y, _magnetometer.z);
      if(isLogging){
        InternalStorage().addMagnetometerEntryInternal();
        _entriesMag.add("${DateTime.now().toString()}, $_magnetometer");
      }
    });

    accuracyStreamSubscription = Location().getAccuracyStream().listen((PositionEvent positionEvent) {
      setState(() {
        this.latitude = positionEvent.latitude;
        this.longitude = positionEvent.longitude;
      });
      InternalStorage().setLatitudeLongitudeInternal(latitude, longitude);
      if(isLogging){
        InternalStorage().addGeolocatorEntryInternal();
        _entriesGeo.add("${DateTime.now().toString()},$latitude,$longitude");
      }
    });
  }

  toggleLogging() {
    setState(() {
      if (isLocating == null || isLogging) {
        buttonIcon = Icon(Icons.location_on);
        buttonText = "Start Locating";
        buttonColor = Colors.blue;
        isLocating = false;
        isLogging = false;
        if (accuracyStreamSubscription != null) {
          Location().cancelPositionStream();
          accuracyStreamSubscription.cancel();
          accuracyStreamSubscription = null;
          _accelerometerSubscription.pause();
          //_gyroscopeSubscription.pause();
          //_magnetometerSubscription.pause();
          //askToSendLog();
          //checkForStorage();
          storageOption();
        }
      } else if (!isLocating) {
        accuracyStreamSubscription = Location()
            .getAccuracyStream()
            .listen((PositionEvent positionEvent) {
          InternalStorage().setLatitudeLongitudeInternal(
              positionEvent.latitude, positionEvent.longitude);
        });
        isLocating = true;
        buttonIcon = Icon(Icons.play_arrow);
        buttonText = "Start Logging";
        buttonColor = Colors.green;
        isLogging = false;
      } else if (!isLogging && isLocating) {
        buttonIcon = Icon(Icons.stop);
        buttonText = "Stop Logging";
        buttonColor = Colors.red;
        isLogging = true;
      }
    });
  }

  void setUpdateInterval(int groupValue, int interval) {
    motionSensors.accelerometerUpdateInterval = interval;
    motionSensors.gyroscopeUpdateInterval = interval;
    motionSensors.magnetometerUpdateInterval = interval;
    setState(() {
      _groupValue = groupValue;
    });
  }

  clearEntries() {
    _entriesAcc.clear();
    _entriesGyro.clear();
    _entriesMag.clear();
    _entriesGeo.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('mHealth'),
        backgroundColor: Colors.black45,
      ),
      body: Container(
        constraints: BoxConstraints.expand(),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            colors: [
              Colors.black87,
              Colors.black45,
              Colors.black87,
            ],
          ),
        ),
        child: ListView(
          children: <Widget>[
            Card(
              color: Colors.white38,
              margin: EdgeInsets.only(top: 50.0, left: 10.0, right: 10.0),
              child: Column(
                children: <Widget>[
                  Divider(height: 5.0),
                  Text('Update', style: TextStyle(color: Colors.white, fontSize: 14)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Radio(value: 1, groupValue: _groupValue, onChanged: (dynamic value) => setUpdateInterval(value, Duration.microsecondsPerSecond ~/ 1),),
                      Text("1 FPS", style: TextStyle(color: Colors.white, fontSize: 14)),
                      Radio(value: 2, groupValue: _groupValue, onChanged: (dynamic value) => setUpdateInterval(value, Duration.microsecondsPerSecond ~/ 30),),
                      Text("30 FPS", style: TextStyle(color: Colors.white, fontSize: 14)),
                      Radio(value: 3, groupValue: _groupValue, onChanged: (dynamic value) => setUpdateInterval(value, Duration.microsecondsPerSecond ~/ 60),),
                      Text("60 FPS", style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
            Card(
              color: Colors.white38,
              margin: EdgeInsets.only(top: 20.0, left: 10.0, right: 10.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.05,
                      child: ImageIcon(
                        AssetImage('images/accelerometeicon.png'),
                        size: 80.0,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.60,
                      child: Column(
                        children: <Widget>[
                          Text(
                            "ACCELEROMETER",
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          Divider(height: 5.0),
                          Text(
                            "X-Axis: ${_accelerometer.x.toStringAsFixed(4)}",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            "Y-Axis: ${_accelerometer.y.toStringAsFixed(4)}",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            "Z-Axis: ${_accelerometer.z.toStringAsFixed(4)}",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.05,
                      child: IconButton(
                        icon: Icon(Icons.insert_chart),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AccelerometerGraph()),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Card(
              color: Colors.white38,
              margin: EdgeInsets.only(top: 20.0, left: 10.0, right: 10.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.05,
                      child: ImageIcon(
                        AssetImage('images/gyroscopeicon3.png'),
                        size: 80.0,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.60,
                      child: Column(
                        children: <Widget>[
                          Text(
                            "GYROSCOPE",
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          Divider(height: 5.0),
                          Text(
                            "X-Axis: ${_gyroscope.x.toStringAsFixed(4)}",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            "Y-Axis: ${_gyroscope.y.toStringAsFixed(4)}",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            "Z-Axis: ${_gyroscope.z.toStringAsFixed(4)}",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.05,
                      child: IconButton(
                        icon: Icon(Icons.insert_chart),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => GyroscopeGraph()),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Card(
              color: Colors.white38,
              margin: EdgeInsets.only(top: 20.0, left: 10.0, right: 10.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.05,
                      child: ImageIcon(
                        AssetImage('images/magnetometerIcon5.png'),
                        size: 80.0,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.60,
                      child: Column(
                        children: <Widget>[
                          Text(
                            "MAGNETOMETER",
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          Divider(height: 5.0),
                          Text(
                            "X-Axis: ${_magnetometer.x.toStringAsFixed(4)}",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            "Y-Axis: ${_magnetometer.y.toStringAsFixed(4)}",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            "Z-Axis: ${_magnetometer.z.toStringAsFixed(4)}",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.05,
                      child: IconButton(
                        icon: Icon(Icons.insert_chart),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => MagnetometerGraph()),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Card(
              color: Colors.white38,
              margin: EdgeInsets.only(top: 20.0, left: 10.0, right: 10.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.05,
                      child: Icon(
                        Icons.location_on,
                        size: 80.0,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.60,
                      child: Column(
                        children: <Widget>[
                          Text(
                            "LOCATION",
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          Divider(height: 5.0),
                          Text(
                            "X-Axis: ${latitude.toStringAsFixed(4)}",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            "Y-Axis: ${longitude.toStringAsFixed(4)}",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.05,
                      child: IconButton(
                        icon: Icon(Icons.map),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => LocationMap()),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: toggleLogging,
        icon: buttonIcon,
        label: Text(buttonText),
        backgroundColor: buttonColor,
      ),
    );
  }

  void storageOption(){
    showDialog(
        context: context,
        builder: (BuildContext context){
          return AlertDialog(
            title: new Text("Storage Option"),
            insetPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10.0)),
            ),
            actions: <Widget>[
              Divider(height: 20.0,),
              new FlatButton(
                child: Column(
                  children: <Widget>[
                    Text("Cancel", style: TextStyle(color: Colors.black),),
                  ],
                ),
                color: Colors.white70,
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
            contentPadding: EdgeInsets.zero,
            content: Container(
              height: 100.0,
              decoration: BoxDecoration(border: Border.all(color: Colors.white38)),
              child: Column(
                children: <Widget>[
                  FlatButton(
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.storage),
                        Text("Internal", style: TextStyle(color: Colors.black),),
                      ],
                    ),
                    onPressed: askToSndFileInternalStorageTwo,
                  ),
                  FlatButton(
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.cloud),
                        Text("AWS S3", style: TextStyle(color: Colors.black),),
                      ],
                    ),
                    onPressed: awsCredentialForm,
                    /*onPressed: (){
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AWSS3Identity()),);
                  },*/
                  ),
                ],
              ),
            ),
          );
        }
    );
  }

  void askToSndFileInternalStorageTwo(){
    //checkboxValue = newValue;
    //String notes = "";

    showDialog(context: context, builder: (BuildContext context){
      return AlertDialog(
        title: new Text("Send log?"),
        actions: <Widget>[
          new FlatButton(
            child: new Text("Cancel"),
            onPressed: () {
              InternalStorage().clearEntries();
              _accelerometerSubscription.resume();
              _gyroscopeSubscription.resume();
              _magnetometerSubscription.resume();
              Navigator.of(context).pop();
            },
          ),
          new FlatButton(
            child: new Text("Send"),
            onPressed: () {
              asynchronouslySendFileTwo();
              Navigator.of(context).pop();
            },
          )
        ],
      );
    });
  }

  asynchronouslySendFileTwo() async{
    bool result = await InternalStorage().saveFile();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: new Text(result ? "Success" : "Error"),
          actions: <Widget>[
            new FlatButton(
              child: new Text("Okay"),
              onPressed: () {
                Navigator.of(context).pop();
                if (!result) {
                  askToSndFileInternalStorageTwo();
                } else {
                  _accelerometerSubscription.resume();
                  _gyroscopeSubscription.resume();
                  _magnetometerSubscription.resume();
                }
              },
            )
          ],
        );
      },
    );
  }

  void awsCredentialForm(){
    //checkboxValue = newValue;

    showDialog(context: context, builder: (BuildContext context){
      return AlertDialog(
        title: Form(
          key: _keyDialogForm,
          child: Column(
            children: <Widget>[
              TextFormField(
                enableInteractiveSelection: true,
                decoration: const InputDecoration(
                  hintText: "Access Key ID",
                  //icon: Icon(Icons.accessibility),
                  //labelText: "Access Key",
                ),
                maxLength: 20,
                textAlign: TextAlign.center,
                onSaved: (val){
                  accesskeyController.text = val;
                  setState(() {});
                },
                validator: (value){
                  if(value.isEmpty){
                    return 'Access key ID is required';
                  }
                  if(value.length < 20){
                    return 'Access key ID is too short';
                  }
                  return null;
                },
              ),
              TextFormField(
                enableInteractiveSelection: true,
                decoration: const InputDecoration(
                  hintText: "Secret Access Key ",
                  //icon: Icon(Icons.accessibility),
                  //labelText: "Access Key",
                ),
                maxLength: 40,
                textAlign: TextAlign.center,
                onSaved: (val){
                  secretkeyController.text = val;
                  setState(() {});
                },
                validator: (value){
                  if(value.isEmpty){
                    return 'Secret access key is required';
                  }
                  if(value.length < 40){
                    return 'Secret access key is too short';
                  }
                  return null;
                },
              ),
              TextFormField(
                enableInteractiveSelection: true,
                decoration: const InputDecoration(
                  hintText: "Region",
                  //icon: Icon(Icons.accessibility),
                  //labelText: "Access Key",
                ),
                //maxLength: 40,
                textAlign: TextAlign.center,
                onSaved: (val){
                  regionController.text = val;
                  setState(() {});
                },
                validator: (value){
                  if(value.isEmpty){
                    return 'Region is required';
                  }
                  return null;
                },
              ),
              TextFormField(
                enableInteractiveSelection: true,
                decoration: const InputDecoration(
                  hintText: "Bucket Name",
                  //icon: Icon(Icons.accessibility),
                  //labelText: "Access Key",
                ),
                //maxLength: 40,
                textAlign: TextAlign.center,
                onSaved: (val){
                  bucketnameController.text = val;
                  setState(() {});
                },
                validator: (value){
                  if(value.isEmpty){
                    return 'Bucket name is required';
                  }
                  return null;
                },
              ),
              TextFormField(
                enableInteractiveSelection: true,
                decoration: const InputDecoration(
                  hintText: "S3 Endpoint",
                  //icon: Icon(Icons.accessibility),
                  //labelText: "Access Key",
                ),
                //maxLength: 40,
                maxLines: 1,
                textAlign: TextAlign.center,
                onSaved: (val){
                  s3endpointController.text = val;
                  setState(() {});
                },
                validator: (value){
                  if(value.isEmpty){
                    return 'S3 endpoint is required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: <Widget>[
          FlatButton(
            onPressed: (){
              if(_keyDialogForm.currentState.validate()){
                _keyDialogForm.currentState.save();
                uploadAccelerometerFile(accesskeyController.text, secretkeyController.text, regionController.text, bucketnameController.text, s3endpointController.text);
                uploadGyroscopeFile(accesskeyController.text, secretkeyController.text, regionController.text, bucketnameController.text, s3endpointController.text);
                uploadMagnetometerFile(accesskeyController.text, secretkeyController.text, regionController.text, bucketnameController.text, s3endpointController.text);
                uploadLocationFile(accesskeyController.text, secretkeyController.text, regionController.text, bucketnameController.text, s3endpointController.text);
                Navigator.pop(context);
              }
            },
            child: Text('Send'),
            color: Colors.blue,
          ),
          FlatButton(
            onPressed: (){
              Navigator.pop(context);
            },
            child: Text('Cancel'),
          ),
        ],
      );
    });
  }

  void uploadAccelerometerFile(String accesskeyController, String secretkeyController, String regionController, String bucketnameController, String s3endpointController) async{
    print("Access Key: $accesskeyController");
    print("Secret Key: $secretkeyController");
    print("Region: $regionController");
    print("Bucket name: $bucketnameController");
    print("S3 Endpoint: $s3endpointController");

    //ACCELEROMETER
    String csvAccelerometer = _entriesAcc.join("\n");
    print("ACCELEROMETER CSV: $csvAccelerometer");

    final accelerometerDirectory = await getApplicationDocumentsDirectory();
    final accelrometerPath = await accelerometerDirectory;
    print("Accelerometer Path: $accelrometerPath");
    File accelerometerFile = new File('$accelrometerPath/Accelerometer.csv');
    accelerometerFile.writeAsString(csvAccelerometer);
    Uint8List data = accelerometerFile.readAsBytesSync();

    final length = _entriesAcc.length;
    final uri = Uri.parse(s3endpointController);
    final req = http.MultipartRequest("POST", uri);
    //final multipartFileAccelerometer = http.MultipartFile.fromString('fAccelerometer', csvAccelerometer);
    final multipartFileAccelerometer = http.MultipartFile('file', http.ByteStream.fromBytes(data), length, filename: 'accelerometerFile');
    //final multipartFileAccelerometer = http.MultipartFile(dirAcce+'/'+ 'Accelerometer.csv', http.ByteStream.fromBytes(data), length, filename: 'fAccelerometer');

    final policyAccelerometer = Policy.fromS3PresignedPost('accelerometerFile', bucketnameController, accesskeyController, 15, length, region: regionController);
    //final policyAccelerometer = Policy.fromS3PresignedPost('flAccelerometer', bucketnameController, accesskeyController, 15, region: regionController);
    final keyAccelerometer = SigV4.calculateSigningKey(secretkeyController, policyAccelerometer.datetime, regionController, 's3');
    final signatureAccelerometer = SigV4.calculateSignature(keyAccelerometer, policyAccelerometer.encode());

    req.files.add(multipartFileAccelerometer);
    req.fields['key'] = policyAccelerometer.key;
    req.fields['acl'] = 'public-read';
    req.fields['X-Amz-Credential'] = policyAccelerometer.credential;
    req.fields['X-Amz-Algorithm'] = 'AWS4-HMAC-SHA256';
    req.fields['X-Amz-Date'] = policyAccelerometer.datetime;
    req.fields['Policy'] = policyAccelerometer.encode();
    req.fields['X-Amz-Signature'] = signatureAccelerometer;

    try {
      final res = await req.send();
      await for (var value in res.stream.transform(utf8.decoder)) {
        print(value);
      }
    } catch (e) {
      print(e.toString());
      return e;
    }
  }

  void uploadGyroscopeFile(String accesskeyController, String secretkeyController, String regionController, String bucketnameController, String s3endpointController) async{

    String csvGyroscope = _entriesGyro.join("\n");
    print("Gyroscope CSV: $csvGyroscope");

    final gyroscopeDirectory = await getApplicationDocumentsDirectory();
    final gyroscopePath = await gyroscopeDirectory;
    print("Gyroscope Path: $gyroscopePath");
    File gyroscopeFile = new File('$gyroscopePath/Gyroscope.csv');
    gyroscopeFile.writeAsString(csvGyroscope);
    Uint8List data = gyroscopeFile.readAsBytesSync();

    final length = _entriesGyro.length;
    final uri = Uri.parse(s3endpointController);
    final req = http.MultipartRequest("POST", uri);
    //final multipartFileAccelerometer = http.MultipartFile.fromString('fAccelerometer', csvAccelerometer);
    final multipartFileGyroscope = http.MultipartFile('file', http.ByteStream.fromBytes(data), length, filename: 'gyroscopeFile');
    //final multipartFileAccelerometer = http.MultipartFile(dirAcce+'/'+ 'Accelerometer.csv', http.ByteStream.fromBytes(data), length, filename: 'fAccelerometer');

    final policyGyroscope = Policy.fromS3PresignedPost('gyroscopeFile', bucketnameController, accesskeyController, 15, length, region: regionController);
    //final policyAccelerometer = Policy.fromS3PresignedPost('flAccelerometer', bucketnameController, accesskeyController, 15, region: regionController);
    final keyGyroscope = SigV4.calculateSigningKey(secretkeyController, policyGyroscope.datetime, regionController, 's3');
    final signatureAccelerometer = SigV4.calculateSignature(keyGyroscope, policyGyroscope.encode());

    req.files.add(multipartFileGyroscope);
    req.fields['key'] = policyGyroscope.key;
    req.fields['acl'] = 'public-read';
    req.fields['X-Amz-Credential'] = policyGyroscope.credential;
    req.fields['X-Amz-Algorithm'] = 'AWS4-HMAC-SHA256';
    req.fields['X-Amz-Date'] = policyGyroscope.datetime;
    req.fields['Policy'] = policyGyroscope.encode();
    req.fields['X-Amz-Signature'] = signatureAccelerometer;

    try {
      final res = await req.send();
      await for (var value in res.stream.transform(utf8.decoder)) {
        print(value);
      }
    } catch (e) {
      print(e.toString());
      return e;
    }
  }

  void uploadMagnetometerFile(String accesskeyController, String secretkeyController, String regionController, String bucketnameController, String s3endpointController) async{

    String csvMagnetometer = _entriesMag.join("\n");
    print("Magnetometer CSV: $csvMagnetometer");

    final magnetometerDirectory = await getApplicationDocumentsDirectory();
    final magnetometerPath = await magnetometerDirectory;
    print("Magnetometer Path: $magnetometerPath");
    File magnetometerFile = new File('$magnetometerPath/Magnetometer.csv');
    magnetometerFile.writeAsString(csvMagnetometer);
    Uint8List data = magnetometerFile.readAsBytesSync();

    final length = _entriesMag.length;
    final uri = Uri.parse(s3endpointController);
    final req = http.MultipartRequest("POST", uri);
    //final multipartFileAccelerometer = http.MultipartFile.fromString('fAccelerometer', csvAccelerometer);
    final multipartFile = http.MultipartFile('file', http.ByteStream.fromBytes(data), length, filename: 'magnetometerFile');
    //final multipartFileAccelerometer = http.MultipartFile(dirAcce+'/'+ 'Accelerometer.csv', http.ByteStream.fromBytes(data), length, filename: 'fAccelerometer');

    final policy = Policy.fromS3PresignedPost('magnetometerFile', bucketnameController, accesskeyController, 15, length, region: regionController);
    //final policyAccelerometer = Policy.fromS3PresignedPost('flAccelerometer', bucketnameController, accesskeyController, 15, region: regionController);
    final key = SigV4.calculateSigningKey(secretkeyController, policy.datetime, regionController, 's3');
    final signature = SigV4.calculateSignature(key, policy.encode());

    req.files.add(multipartFile);
    req.fields['key'] = policy.key;
    req.fields['acl'] = 'public-read';
    req.fields['X-Amz-Credential'] = policy.credential;
    req.fields['X-Amz-Algorithm'] = 'AWS4-HMAC-SHA256';
    req.fields['X-Amz-Date'] = policy.datetime;
    req.fields['Policy'] = policy.encode();
    req.fields['X-Amz-Signature'] = signature;

    try {
      final res = await req.send();
      await for (var value in res.stream.transform(utf8.decoder)) {
        print(value);
      }
    } catch (e) {
      print(e.toString());
      return e;
    }
  }

  void uploadLocationFile(String accesskeyController, String secretkeyController, String regionController, String bucketnameController, String s3endpointController) async{

    String csvGeolocator = _entriesGeo.join("\n");
    print("GEOLOCATOR CSV: $csvGeolocator");

    final geolocatorDirectory = await getApplicationDocumentsDirectory();
    final geolocatorPath = await geolocatorDirectory;
    print("Geolocator Path: $geolocatorPath");
    File geolocatorFile = new File('$geolocatorPath/Location.csv');
    geolocatorFile.writeAsString(csvGeolocator);
    Uint8List data = geolocatorFile.readAsBytesSync();

    final length = _entriesGyro.length;
    final uri = Uri.parse(s3endpointController);
    final req = http.MultipartRequest("POST", uri);
    //final multipartFileAccelerometer = http.MultipartFile.fromString('fAccelerometer', csvAccelerometer);
    final multipartFile = http.MultipartFile('file', http.ByteStream.fromBytes(data), length, filename: 'geolocatorFile');
    //final multipartFileAccelerometer = http.MultipartFile(dirAcce+'/'+ 'Accelerometer.csv', http.ByteStream.fromBytes(data), length, filename: 'fAccelerometer');

    final policy = Policy.fromS3PresignedPost('geolocatorFile', bucketnameController, accesskeyController, 15, length, region: regionController);
    //final policyAccelerometer = Policy.fromS3PresignedPost('flAccelerometer', bucketnameController, accesskeyController, 15, region: regionController);
    final key = SigV4.calculateSigningKey(secretkeyController, policy.datetime, regionController, 's3');
    final signature= SigV4.calculateSignature(key, policy.encode());

    req.files.add(multipartFile);
    req.fields['key'] = policy.key;
    req.fields['acl'] = 'public-read';
    req.fields['X-Amz-Credential'] = policy.credential;
    req.fields['X-Amz-Algorithm'] = 'AWS4-HMAC-SHA256';
    req.fields['X-Amz-Date'] = policy.datetime;
    req.fields['Policy'] = policy.encode();
    req.fields['X-Amz-Signature'] = signature;

    try {
      final res = await req.send();
      await for (var value in res.stream.transform(utf8.decoder)) {
        print(value);
      }
    } catch (e) {
      print(e.toString());
      return e;
    }
  }

  @override
  void dispose() {
    if (accuracyStreamSubscription != null) {
      accuracyStreamSubscription.cancel();
      accuracyStreamSubscription = null;
    }

    if (_accelerometerSubscription != null) {
      _accelerometerSubscription.cancel();
      _accelerometerSubscription = null;
    }

    super.dispose();
  }
}

class Policy {
  String expiration;
  String region;
  String bucket;
  String key;
  String credential;
  String datetime;
  int maxFileSize;

  Policy(this.key, this.bucket, this.datetime, this.expiration, this.credential,
      this.maxFileSize,
      {this.region = 'us-east-1'});

  factory Policy.fromS3PresignedPost(
      String key,
      String bucket,
      String accessKeyId,
      int expiryMinutes,
      int maxFileSize, {
        String region,
      }) {
    final datetime = SigV4.generateDatetime();
    final expiration = (DateTime.now())
        .add(Duration(minutes: expiryMinutes))
        .toUtc()
        .toString()
        .split(' ')
        .join('T');
    final cred =
        '$accessKeyId/${SigV4.buildCredentialScope(datetime, region, 's3')}';
    final p = Policy(key, bucket, datetime, expiration, cred, maxFileSize,
        region: region);
    //final p = Policy(key, bucket, datetime, expiration, cred, region: region);
    return p;
  }

  String encode() {
    final bytes = utf8.encode(toString());
    return base64.encode(bytes);
  }

  @override
  String toString() {
    return '''
 { "expiration": "${this.expiration}",
  "conditions": [
    {"bucket": "${this.bucket}"},
    ["starts-with", "\$key", "${this.key}"],
    {"acl": "public-read"},
    ["content-length-range", 1, ${this.maxFileSize}],
    {"x-amz-credential": "${this.credential}"},
    {"x-amz-algorithm": "AWS4-HMAC-SHA256"},
    {"x-amz-date": "${this.datetime}" }
  ]
}
''';
  }
}