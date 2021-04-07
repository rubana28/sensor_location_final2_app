import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';

class LocationMap extends StatefulWidget{
  @override
  _LocationMapState createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap>{
  MapController controller = new MapController();

  double _latitude = 0.0;
  double _longitude = 0.0;

  setLatitudeLongitude(double latitude, double longitude) {
    this._latitude = latitude;
    this._longitude = longitude;
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Map'),
      ),
      body: new FlutterMap(
        mapController: controller,
        options: new MapOptions(center: setLatitudeLongitude(_latitude, _longitude), minZoom: 15.0),
        layers: [
          new TileLayerOptions(
              urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
              subdomains: ['a','b','c']
          ),
        ],
      ),
    );
  }
}
