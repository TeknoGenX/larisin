import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class VendorOrderProvider with ChangeNotifier {
  List<dynamic> _orders = [];
  bool _isLoading = false;
  final String _baseUrl = 'http://127.0.0.1:5003';

  List<dynamic> get orders => _orders;
  bool get isLoading => _isLoading;

  Future<void> fetchOrders(String token) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/vendor/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _orders = json.decode(response.body);
      }
    } catch (e) {
      print('Error fetching vendor orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void handleNewOrder(Map<String, dynamic> orderData, String token) {
    // We could either add it to the list or just re-fetch all for simplicity/correctness
    fetchOrders(token);
  }

  Future<bool> updateStatus(String token, int orderId, String newStatus) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/vendor/orders/$orderId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        await fetchOrders(token); // Refresh orders
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating order status: $e');
      return false;
    }
  }
}
