import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CustomerProvider with ChangeNotifier {
  List<dynamic> _nearbyVendors = [];
  bool _isLoading = false;
  final String _baseUrl = 'http://127.0.0.1:5003';

  List<dynamic> get nearbyVendors => _nearbyVendors;
  bool get isLoading => _isLoading;

  Future<void> fetchNearbyVendors(String token) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/customer/nearby-vendors'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _nearbyVendors = json.decode(response.body);
      }
    } catch (e) {
      print('Error fetching nearby vendors: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateVendorLocation(Map<String, dynamic> data) {
    final index = _nearbyVendors.indexWhere((v) => v['username'] == data['username']);
    if (index != -1) {
      _nearbyVendors[index]['latitude'] = data['lat'];
      _nearbyVendors[index]['longitude'] = data['lng'];
      notifyListeners();
    } else if (data['is_active'] == true && data['is_verified'] == true) {
      // Add new vendor if not in list but active and verified
      _nearbyVendors.add({
        'id': data['id'],
        'username': data['username'],
        'latitude': data['lat'],
        'longitude': data['lng'],
        'is_active': data['is_active'],
        'is_verified': data['is_verified'],
      });
      notifyListeners();
    }
  }

  Future<List<dynamic>> fetchVendorStock(String token, int vendorId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/customer/vendor-stock/$vendorId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error fetching vendor stock: $e');
    }
    return [];
  }

  Future<List<dynamic>> fetchOrderHistory(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/order/history'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error fetching order history: $e');
    }
    return [];
  }

  Future<bool> completeOrder(String token, int orderId) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/order/$orderId/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error completing order: $e');
      return false;
    }
  }

  Future<bool> submitReview(String token, int orderId, int rating, String comment) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/customer/review'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'order_id': orderId,
          'rating': rating,
          'comment': comment,
        }),
      );

      return response.statusCode == 201;
    } catch (e) {
      print('Error submitting review: $e');
      return false;
    }
  }

  Future<List<dynamic>> fetchVendorReviews(String token, int vendorId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/customer/vendor-reviews/$vendorId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error fetching vendor reviews: $e');
    }
    return [];
  }
}
