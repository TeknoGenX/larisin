import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/material.dart';

class SocketService with ChangeNotifier {
  IO.Socket? _socket;
  final String _baseUrl = 'http://127.0.0.1:5003';

  IO.Socket? get socket => _socket;

  void connect(int userId) {
    if (_socket != null && _socket!.connected) return;

    _socket = IO.io(_baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 2000,
    });

    _socket!.onConnect((_) {
      print('Socket connected: ${_socket!.id}');
      if (userId != 0) {
        _socket!.emit('join', {'user_id': userId});
      }
    });

    _socket!.onReconnect((_) => print('Socket reconnected'));
    _socket!.onReconnectAttempt((attempt) => print('Reconnection attempt: $attempt'));

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
    });

    _socket!.onConnectError((err) => print('Connect Error: $err'));
    _socket!.onError((err) => print('Socket Error: $err'));
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
  }
}
