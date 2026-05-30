import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import 'chat_provider.dart';
import 'chat_screen.dart';
import 'app_theme.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<ChatProvider>(context, listen: false).fetchConversations(auth.token!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final conversations = chatProvider.conversations;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Percakapan', style: TextStyle(fontWeight: FontWeight.bold))),
      body: conversations.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Belum ada pesan.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                final unreadCount = conv['unread_count'] ?? 0;
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.brandPrimary.withValues(alpha: 0.1),
                    child: Text(conv['other_username'][0].toUpperCase()),
                  ),
                  title: Text(conv['other_username'], style: TextStyle(fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text(
                    conv['last_message'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(conv['last_time']),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        receiverId: conv['other_user_id'],
                        receiverName: conv['other_username'],
                      ),
                    ));
                  },
                );
              },
            ),
    );
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return "";
    final date = DateTime.parse(isoTime).toLocal();
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    }
    return "${date.day}/${date.month}";
  }
}
