import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:oscilloscope/oscilloscope.dart';
//import 'package:draw_graph/draw_graph.dart';
//import 'package:draw_graph/models/feature.dart';
import 'package:motion_sensors/motion_sensors.dart';

class GyroscopeGraph extends StatefulWidget{
  @override
  _GyroscopeGraphState createState() => _GyroscopeGraphState();
}

class _GyroscopeGraphState extends State<GyroscopeGraph>{
  List<double> traceX = List();
  List<double> traceY = List();
  List<double> traceZ = List();

  List<double> x_entries = List();
  List<double> y_entries = List();
  List<double> z_entries = List();

  double _gyroscopeX = 0.0;
  double _gyroscopeY = 0.0;
  double _gyroscopeZ = 0.0;

  setGyroscopeData(double x, double y, double z){
    this._gyroscopeX = x;
    this._gyroscopeY = y;
    this._gyroscopeZ = z;
  }

  graphDataEntry(){
    x_entries.add(_gyroscopeX);
    y_entries.add(_gyroscopeY);
    z_entries.add(_gyroscopeZ);
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    motionSensors.gyroscope.listen((GyroscopeEvent event){
      setState(() {
        traceX.add(event.x);
        traceY.add(event.y);
        traceZ.add(event.z);
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    graphDataEntry();
    // Create A Scope Display
    Oscilloscope scopeOne = Oscilloscope(
      padding: 20.0,
      backgroundColor: Colors.transparent,
      traceColor: Colors.green,
      yAxisMax: 10.0,
      yAxisMin: -10.0,
      dataSet: traceX,
    );

    Oscilloscope scopetwo = Oscilloscope(
      padding: 20.0,
      backgroundColor: Colors.transparent,
      traceColor: Colors.cyan,
      yAxisMax: 10.0,
      yAxisMin: -10.0,
      dataSet: traceY,
    );

    Oscilloscope scopethree = Oscilloscope(
      padding: 20.0,
      backgroundColor: Colors.transparent,
      traceColor: Colors.pinkAccent,
      yAxisMax: 10.0,
      yAxisMin: -10.0,
      dataSet: traceZ,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text("Gyroscope Graph"),
      ),
      body: Container(
        constraints: BoxConstraints.expand(),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            colors: [
              Colors.black87,
              Colors.black87,
              Colors.black87,
            ],
          ),
        ),
        child: Column(
          children: <Widget>[
            Divider(height: 5.0),
            Text("X-Axis", style: TextStyle(color: Colors.white, fontSize: 12)),
            Divider(height: 5.0),
            Expanded(flex: 1, child: scopeOne),
            Divider(height: 5.0),
            Text("Y-Axis", style: TextStyle(color: Colors.white, fontSize: 12)),
            Divider(height: 5.0),
            Expanded(flex: 1, child: scopetwo),
            Divider(height: 5.0),
            Text("Z-Axis", style: TextStyle(color: Colors.white, fontSize: 12)),
            Divider(height: 5.0),
            Expanded(flex: 1, child: scopethree),
            /*Divider(height: 5.0),
            Expanded(
              flex: 1,
              child: IconButton(
                iconSize: 100.0,
                icon: ImageIcon(
                  AssetImage('images/backIcon4.png'),
                ),
                onPressed: (){Navigator.pop(context);},
              ),
            ),*/
          ],
        ),
      ),
    );
  }
}