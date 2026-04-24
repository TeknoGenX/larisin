import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CartItem {
  final int productId;
  final String name;
  final int price;
  int quantity;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.quantity = 1,
  });
}

class CartProvider with ChangeNotifier {
  Map<int, CartItem> _items = {};
  final String _baseUrl = 'http://127.0.0.1:5002';

  Map<int, CartItem> get items => _items;

  int get totalAmount {
    var total = 0;
    _items.forEach((key, cartItem) {
      total += cartItem.price * cartItem.quantity;
    });
    return total;
  }

  int get itemCount => _items.length;

  void addItem(int productId, String name, int price) {
    if (_items.containsKey(productId)) {
      _items.update(
        productId,
        (existing) => CartItem(
          productId: existing.productId,
          name: existing.name,
          price: existing.price,
          quantity: existing.quantity + 1,
        ),
      );
    } else {
      _items.putIfAbsent(
        productId,
        () => CartItem(productId: productId, name: name, price: price),
      );
    }
    notifyListeners();
  }

  void removeItem(int productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    _items = {};
    notifyListeners();
  }

  Future<bool> checkout(String token, int vendorId) async {
    try {
      final List<Map<String, dynamic>> orderItems = _items.values.map((item) {
        return {
          'product_id': item.productId,
          'quantity': item.quantity,
        };
      }).toList();

      final response = await http.post(
        Uri.parse('$_baseUrl/order/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'vendor_id': vendorId,
          'items': orderItems,
        }),
      );

      if (response.statusCode == 201) {
        clearCart();
        return true;
      }
      return false;
    } catch (e) {
      print('Checkout error: $e');
      return false;
    }
  }
}
