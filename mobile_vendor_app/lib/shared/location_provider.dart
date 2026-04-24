import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationProvider with ChangeNotifier {
  Timer? _timer;
  final String _baseUrl = 'http://127.0.0.1:5002';

  void startTracking(String token) {
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      final position = await _determinePosition();
      if (position != null) {
        _sendLocation(token, position.latitude, position.longitude);
      }
    });
  }

  void stopTracking() {
    _timer?.cancel();
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _sendLocation(String token, double lat, double lon) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/vendor/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'latitude': lat,
          'longitude': lon,
          'is_active': true,
        }),
      );
      print('Location sent: $lat, $lon');
    } catch (e) {
      print('Error sending location: $e');
    }
  }
}
