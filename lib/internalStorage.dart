import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class InternalStorage{
  static final InternalStorage _singleton = new InternalStorage._internal();

  factory InternalStorage() {
    return _singleton;
  }

  InternalStorage._internal();

  List _entriesAcc = [];
  List _entriesGyro = [];
  List _entriesMag = [];
  List _entriesGeo = [];

  double _latitude = 0.0;
  double _longitude = 0.0;

  double _accelerometerX = 0.0;
  double _accelerometerY = 0.0;
  double _accelerometerZ = 0.0;

  double _gyroscopeX = 0.0;
  double _gyroscopeY = 0.0;
  double _gyroscopeZ = 0.0;

  double _magnetometerX = 0.0;
  double _magnetometerY = 0.0;
  double _magnetometerZ = 0.0;

  final Dio dio = Dio();
  bool loading = false;
  double progress = 0;

  setLatitudeLongitudeInternal(double latitude, double longitude) {
    this._latitude = latitude;
    this._longitude = longitude;
  }

  setAccelerometerDataInternal(double x, double y, double z){
    this._accelerometerX = x;
    this._accelerometerY = y;
    this._accelerometerZ = z;
  }

  setGyroscopeDataInternal(double x, double y, double z){
    this._gyroscopeX = x;
    this._gyroscopeY = y;
    this._gyroscopeZ = z;
  }

  setMagnetometerDataInternal(double x, double y, double z){
    this._magnetometerX = x;
    this._magnetometerY = y;
    this._magnetometerZ = z;
  }

  addAccelerometerEntryInternal() {
    _entriesAcc.add("${DateTime.now().toString()}, $_accelerometerX,$_accelerometerY,$_accelerometerZ");
    //print("Accelerometer :  $_entries");
  }

  addGyroscopeEntryInternal(){
    _entriesGyro.add("${DateTime.now().toString()}, $_gyroscopeX, $_gyroscopeY, $_gyroscopeZ");
    print("Gyroscope : $_entriesGyro");
  }

  addMagnetometerEntryInternal(){
    _entriesMag.add("${DateTime.now().toString()}, $_magnetometerX, $_magnetometerY, $_magnetometerZ");
    print("Magnetometer: $_entriesMag");
  }

  addGeolocatorEntryInternal(){
    _entriesGeo.add("${DateTime.now().toString()},$_latitude,$_longitude");
    //print(_entriesGeo);
  }

  clearEntries() {
    _latitude = 0.0;
    _longitude = 0.0;

    _accelerometerX = 0.0;
    _accelerometerY = 0.0;
    _accelerometerZ = 0.0;

    _gyroscopeX = 0.0;
    _gyroscopeY = 0.0;
    _gyroscopeZ = 0.0;

    _magnetometerX =0.0;
    _magnetometerY = 0.0;
    _magnetometerZ = 0.0;

    _entriesAcc.clear();
    _entriesGyro.clear();
    _entriesMag.clear();
    _entriesGeo.clear();
  }

  Future<bool> saveFile() async{
    Directory directory;
    try{
      if(Platform.isAndroid){
        if(await _requestPermission(Permission.storage)){
          directory = await getExternalStorageDirectory();
          String newPath = "";
          List<String> paths = directory.path.split("/");
          for(int x = 1; x < paths.length; x++){
            String folder = paths[x];
            if(folder != "Android"){
              newPath += "/" + folder;
            } else{
              break;
            }
          }
          newPath = newPath + "/mHealth2";
          directory = Directory(newPath);
          print(directory.path);
        } else{
          return false;
        }
      }else{
        if (await _requestPermission(Permission.storage)){
          directory = await getTemporaryDirectory();
        } else{
          return false;
        }
      }

      if(!await directory.exists()){
        await directory.create(recursive: true);
      }
      if(await directory.exists()){
        // ACCELEROMETER
        String csvAccelerometer = _entriesAcc.join("\n");
        print("Accelerometer Csv:  $csvAccelerometer");
        String accelerometerfilename = "Accelerometer";
        File accelerometer = File(directory.path + "/$accelerometerfilename");
        accelerometer.writeAsString(csvAccelerometer);
        //print(accelerometer);

        //GYROSCOPE
        String csvGyroscope = _entriesGyro.join("\n");
        print("Gyroscope Csv:  $csvGyroscope");
        String gyroscopefilename = "Gyroscope";
        File gyroscope = File(directory.path + "/$gyroscopefilename");
        gyroscope.writeAsString(csvGyroscope);
        //print(accelerometer);

        //MAGNETOMETER
        String csvMagnetometer = _entriesMag.join("\n");
        print("Magnetometer Csv:  $csvMagnetometer");
        String magnetometerfilename = "Magnetometer";
        File magnetometer = File(directory.path + "/$magnetometerfilename");
        magnetometer.writeAsString(csvMagnetometer);
        //print(accelerometer);

        //LOCATION
        String csvLocation = _entriesGeo.join("\n");
        print("Location Csv:  $csvLocation");
        String locationfilename = "Location";
        File location = File(directory.path + "/$locationfilename");
        location.writeAsString(csvLocation);
        //print(accelerometer);
      }
    }catch (e){
      print(e.toString());
    }
    return false;
  }

  Future<bool> _requestPermission(Permission permission) async{
    if(await permission.isGranted){
      return true;
    } else{
      var result = await permission.request();
      if(result == PermissionStatus.granted){
        return true;
      }
    }
    return false;
  }
}