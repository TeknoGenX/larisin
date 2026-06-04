import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ProductProvider with ChangeNotifier {
  List<dynamic> _products = [];
  String _selectedCategory = 'Semua';
  bool _isLoading = false;
  final String _baseUrl = 'http://127.0.0.1:5003';

  List<dynamic> get products => _products;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;

  List<String> get categories => ['Semua', 'Haus!', 'Ganjel Roti', 'Pedes Cyin', 'Lainnya'];

  void setCategory(String category, String token) {
    _selectedCategory = category;
    fetchProducts(token);
  }

  Future<void> fetchProducts(String token) async {
    _isLoading = true;
    notifyListeners();
    try {
      final uri = Uri.parse('$_baseUrl/vendor/products').replace(
        queryParameters: _selectedCategory != 'Semua' ? {'category': _selectedCategory} : {},
      );
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _products = json.decode(response.body);
      }
    } catch (e) {
      print(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateStock(String token, List<Map<String, dynamic>> stockData) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/vendor/stock'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(stockData),
      );

      return response.statusCode == 200;
    } catch (e) {
      print(e);
      return false;
    }
  }
}
