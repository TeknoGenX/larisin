import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;
  final String _baseUrl = 'http://127.0.0.1:5003';

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _token != null;

  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['access_token'];
        _user = data['user'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('user', json.encode(_user));
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<bool> updateStoreImage(String filePath) async {
    if (_token == null) return false;
    
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/vendor/upload-store-image'));
      request.headers['Authorization'] = 'Bearer $_token';
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _user!['store_image_url'] = data['store_image_url'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(_user));
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error uploading store image: $e');
      return false;
    }
  }

  Future<bool> syncFCMToken(String fcmToken) async {
    if (_token == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode({'fcm_token': fcmToken}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error syncing FCM token: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  Future<bool> register(String username, String password, String role, {String? ktpImageUrl}) async {
    try {
      final body = {
        'username': username,
        'password': password,
        'role': role,
      };
      if (ktpImageUrl != null) body['ktp_image_url'] = ktpImageUrl;

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      return response.statusCode == 201;
    } catch (e) {
      print(e);
      return false;
    }
  }
}
