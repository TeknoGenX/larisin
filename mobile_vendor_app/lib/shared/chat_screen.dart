import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'auth_provider.dart';
import 'chat_provider.dart';
import 'app_theme.dart';
import 'socket_service.dart';
import 'voice_message_bubble.dart';
import 'image_preview_screen.dart';
import 'product_card_bubble.dart';
import 'product_provider.dart';
import 'cart_provider.dart';

class ChatScreen extends StatefulWidget {
  final int receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _recorder = AudioRecorder();
  final ImagePicker _picker = ImagePicker();
  Timer? _typingTimer;
  bool _isMeTyping = false;
  bool _isRecording = false;
  final String _baseUrl = 'http://127.0.0.1:5003';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.fetchChatHistory(auth.token!, widget.receiverId).then((_) {
        chatProvider.markMessagesAsRead(auth.token!, widget.receiverId);
      });
    });
  }

  void _onTextChanged(String value) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final socketService = Provider.of<SocketService>(context, listen: false);

    if (!_isMeTyping && value.isNotEmpty) {
      _isMeTyping = true;
      socketService.socket?.emit('typing', {
        'receiver_id': widget.receiverId,
        'sender_id': auth.user!['id'],
      });
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isMeTyping) {
        _isMeTyping = false;
        socketService.socket?.emit('stop_typing', {
          'receiver_id': widget.receiverId,
          'sender_id': auth.user!['id'],
        });
      }
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    _typingTimer?.cancel();
    if (_isMeTyping) {
      _isMeTyping = false;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final socketService = Provider.of<SocketService>(context, listen: false);
      socketService.socket?.emit('stop_typing', {
        'receiver_id': widget.receiverId,
        'sender_id': auth.user!['id'],
      });
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    final message = _messageController.text.trim();
    _messageController.clear();

    await chatProvider.sendMessage(auth.token!, widget.receiverId, message);
    _scrollToBottom();
  }

  void _buyProduct(dynamic product) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    cart.addItem(product['id'], product['name'], product['price']);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['name']} ditambahkan ke keranjang'),
        action: SnackBarAction(
          label: 'CEK KERANJANG',
          onPressed: () {
            // For prototype, simple confirmation
          },
        ),
      ),
    );
  }

  void _showProductPicker() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    await productProvider.fetchProducts(auth.token!);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pilih Produk untuk Dikirim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: productProvider.products.length,
                  itemBuilder: (context, index) {
                    final p = productProvider.products[index];
                    return ListTile(
                      leading: const Icon(Icons.local_drink, color: AppTheme.brandPrimary),
                      title: Text(p['name']),
                      subtitle: Text('Rp ${p['price']}'),
                      onTap: () {
                        Navigator.pop(context);
                        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                        chatProvider.sendProductCard(auth.token!, widget.receiverId, p['id']);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      await chatProvider.sendImageMessage(auth.token!, widget.receiverId, image.path);
      _scrollToBottom();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = p.join(dir.path, 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
        
        const config = RecordConfig();
        await _recorder.start(config, path: path);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      
      if (path != null) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        await chatProvider.sendVoiceMessage(auth.token!, widget.receiverId, path);
        _scrollToBottom();
      }
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final messages = chatProvider.getMessages(widget.receiverId);
    final isOtherTyping = chatProvider.isTyping(widget.receiverId);

    bool hasUnread = messages.any((m) => m['sender_id'] == widget.receiverId && m['is_read'] == false);
    if (hasUnread) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        chatProvider.markMessagesAsRead(auth.token!, widget.receiverId);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.receiverName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              isOtherTyping ? 'Sedang mengetik...' : 'Online',
              style: TextStyle(
                fontSize: 12,
                color: isOtherTyping ? Colors.blue : AppTheme.brandAccent,
                fontStyle: isOtherTyping ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chatProvider.isLoading && messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + (isOtherTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return _buildTypingIndicator();
                      }
                      final msg = messages[index];
                      final isMe = msg['sender_id'] == auth.user!['id'];
                      return _buildMessageBubble(msg, isMe);
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 30,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CircleAvatar(radius: 2, backgroundColor: Colors.grey),
              CircleAvatar(radius: 2, backgroundColor: Colors.grey),
              CircleAvatar(radius: 2, backgroundColor: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(dynamic msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: (msg['message_type'] == 'image' || msg['message_type'] == 'product') ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.brandPrimary : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (msg['message_type'] == 'voice')
              VoiceMessageBubble(url: msg['media_url'], isMe: isMe)
            else if (msg['message_type'] == 'product')
              ProductCardBubble(
                product: msg['product'],
                isMe: isMe,
                onBuyPressed: () => _buyProduct(msg['product']),
              )
            else if (msg['message_type'] == 'image')
              GestureDetector(
                onTap: () {
                  String fullUrl = msg['media_url'].startsWith('http') ? msg['media_url'] : '$_baseUrl${msg['media_url']}';
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ImagePreviewScreen(imageUrl: fullUrl),
                  ));
                },
                child: Hero(
                  tag: msg['media_url'].startsWith('http') ? msg['media_url'] : '$_baseUrl${msg['media_url']}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      msg['media_url'].startsWith('http') ? msg['media_url'] : '$_baseUrl${msg['media_url']}',
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 200, height: 200,
                          color: Colors.black12,
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                  ),
                ),
              )
            else
              Text(
                msg['message'] ?? "",
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 4, bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(msg['created_at']),
                    style: TextStyle(fontSize: 9, color: isMe ? Colors.white70 : Colors.grey),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.done_all,
                      size: 14,
                      color: msg['is_read'] == true ? Colors.blueAccent : Colors.white60,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String isoTime) {
    final date = DateTime.parse(isoTime).toLocal();
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildMessageInput() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isVendor = auth.user?['role'] == 'vendor';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: _isRecording 
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.mic, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Text('Merekam suara...', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                : TextField(
                    controller: _messageController,
                    onChanged: _onTextChanged,
                    decoration: InputDecoration(
                      hintText: 'Tulis pesan...',
                      prefixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.image_outlined, color: AppTheme.brandPrimary),
                            onPressed: () => _showImageSourceActionSheet(context),
                          ),
                          if (isVendor)
                            IconButton(
                              icon: const Icon(Icons.shopping_bag_outlined, color: AppTheme.brandPrimary),
                              onPressed: _showProductPicker,
                            ),
                        ],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onLongPress: _startRecording,
              onLongPressUp: _stopRecording,
              child: CircleAvatar(
                backgroundColor: _isRecording ? Colors.red : AppTheme.brandPrimary,
                child: Icon(
                  _messageController.text.isNotEmpty ? Icons.send : Icons.mic, 
                  color: Colors.white
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }
}
