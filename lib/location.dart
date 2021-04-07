import 'package:geolocator/geolocator.dart';
import 'dart:async';

class Location {
  static final Location _singleton = new Location._internal();

  factory Location() {
    return _singleton;
  }

  Location._internal();

  StreamSubscription<Position> _positionStreamSubscription;
  StreamController<PositionEvent> _accuracyStreamController;

  double _lastLatitude;
  double _lastLongitude;

  void _initiatePositionStream() {
    LocationOptions locationOptions = LocationOptions(accuracy: LocationAccuracy.best);
    final Stream<Position> positionStream = Geolocator().getPositionStream(locationOptions);

    _positionStreamSubscription = positionStream.listen((Position position) {
      _lastLatitude = position.latitude;
      _lastLongitude = position.longitude;
    });
    Timer.periodic(Duration(milliseconds: 10100), (Timer timer) {
      if (_accuracyStreamController != null && _accuracyStreamController.hasListener) {
        _accuracyStreamController.sink.add(PositionEvent(_lastLatitude, _lastLongitude));
      } else if (_accuracyStreamController != null) {
        _accuracyStreamController.close();
        _accuracyStreamController = null;
        timer.cancel();
      }

      if (_accuracyStreamController == null) {
        _positionStreamSubscription.cancel();
        _positionStreamSubscription = null;
      }
    });
  }

  cancelPositionStream() {
    _positionStreamSubscription.cancel();
    _positionStreamSubscription = null;
  }

  Stream<PositionEvent> getAccuracyStream() {
    if (_positionStreamSubscription == null) {
      _initiatePositionStream();
    }

    if (_accuracyStreamController == null) {
      _accuracyStreamController = StreamController.broadcast();
    }

    return _accuracyStreamController.stream;
  }

}

class PositionEvent {
  final double latitude;
  final double longitude;

  PositionEvent(this.latitude, this.longitude);
}