import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatProvider with ChangeNotifier {
  final String _baseUrl = 'http://127.0.0.1:5003';
  Map<int, List<dynamic>> _chatHistories = {};
  Map<int, bool> _typingStatuses = {};
  List<dynamic> _conversations = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<dynamic> get conversations => _conversations;
  List<dynamic> getMessages(int otherId) => _chatHistories[otherId] ?? [];
  bool isTyping(int otherId) => _typingStatuses[otherId] ?? false;

  int get totalUnreadCount {
    int count = 0;
    for (var conv in _conversations) {
      count += (conv['unread_count'] as int? ?? 0);
    }
    return count;
  }

  Future<void> fetchConversations(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/chat/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _conversations = json.decode(response.body);
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching conversations: $e');
    }
  }

  void setTypingStatus(int otherId, bool isTyping) {
    _typingStatuses[otherId] = isTyping;
    notifyListeners();
  }

  Future<void> markMessagesAsRead(String token, int otherId) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/chat/read/$otherId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Update local state: messages we received from otherId are now read
        if (_chatHistories.containsKey(otherId)) {
          for (var msg in _chatHistories[otherId]!) {
            if (msg['receiver_id'] != otherId) { // If I am the receiver
              msg['is_read'] = true;
            }
          }
        }
        
        // Update conversation list unread count
        final index = _conversations.indexWhere((c) => c['other_user_id'] == otherId);
        if (index != -1) {
          _conversations[index]['unread_count'] = 0;
        }
        notifyListeners();
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  void handleMessagesRead(int readerId) {
    // The other user (readerId) has read messages I sent
    if (_chatHistories.containsKey(readerId)) {
      for (var msg in _chatHistories[readerId]!) {
        if (msg['sender_id'] != readerId) { // If I am the sender
          msg['is_read'] = true;
        }
      }
      notifyListeners();
    }
  }

  Future<void> fetchChatHistory(String token, int otherId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/chat/history/$otherId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _chatHistories[otherId] = json.decode(response.body);
      }
    } catch (e) {
      print('Error fetching chat history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage(String token, int receiverId, String message) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'receiver_id': receiverId,
          'message': message,
        }),
      );

      if (response.statusCode == 201) {
        final newMsg = json.decode(response.body);
        _addMessageLocally(receiverId, newMsg);
        return true;
      }
      return false;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  Future<bool> sendVoiceMessage(String token, int receiverId, String filePath) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/chat/upload/voice'));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['receiver_id'] = receiverId.toString();
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final newMsg = json.decode(response.body);
        _addMessageLocally(receiverId, newMsg);
        return true;
      }
      return false;
    } catch (e) {
      print('Error sending voice message: $e');
      return false;
    }
  }

  Future<bool> sendImageMessage(String token, int receiverId, String filePath) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/chat/upload/image'));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['receiver_id'] = receiverId.toString();
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final newMsg = json.decode(response.body);
        _addMessageLocally(receiverId, newMsg);
        return true;
      }
      return false;
    } catch (e) {
      print('Error sending image message: $e');
      return false;
    }
  }

  Future<bool> sendProductCard(String token, int receiverId, int productId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/send-product'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'receiver_id': receiverId,
          'product_id': productId,
        }),
      );

      if (response.statusCode == 201) {
        final newMsg = json.decode(response.body);
        _addMessageLocally(receiverId, newMsg);
        return true;
      }
      return false;
    } catch (e) {
      print('Error sending product card: $e');
      return false;
    }
  }

  void _addMessageLocally(int otherId, dynamic message) {
    if (!_chatHistories.containsKey(otherId)) {
      _chatHistories[otherId] = [];
    }
    
    // Check if message already exists (to avoid duplicates from socket)
    final exists = _chatHistories[otherId]!.any((m) => m['id'] == message['id']);
    if (!exists) {
      _chatHistories[otherId]!.add(message);
      notifyListeners();
    }
  }

  void handleIncomingMessage(dynamic message, {String? token}) {
    int otherId = message['sender_id'];
    _addMessageLocally(otherId, message);
    
    // Update conversation list locally
    final index = _conversations.indexWhere((c) => c['other_user_id'] == otherId);
    if (index != -1) {
      _conversations[index]['last_message'] = message['message'];
      _conversations[index]['last_time'] = message['created_at'];
      _conversations[index]['unread_count'] = (_conversations[index]['unread_count'] ?? 0) + 1;
      // Move to top
      final conv = _conversations.removeAt(index);
      _conversations.insert(0, conv);
      notifyListeners();
    } else if (token != null) {
      // New conversation, fetch list again
      fetchConversations(token);
    }
  }
}
