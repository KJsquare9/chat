import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_service_provider.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({Key? key}) : super(key: key);

  @override
  _ConversationsScreenState createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch conversations when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chatProvider = Provider.of<ChatServiceProvider>(
        context,
        listen: false,
      );

      // Ensure current user ID is loaded from SharedPreferences
      await chatProvider.loadCurrentUserId();

      // Then fetch conversations
      chatProvider.fetchConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Navigate to search/new chat screen
              // Navigator.push(context, MaterialPageRoute(builder: (context) => SearchUsersScreen()));
            },
          ),
        ],
      ),
      body: Consumer<ChatServiceProvider>(
        builder: (context, chatProvider, child) {
          // Show loading indicator
          if (chatProvider.isLoadingConversations) {
            return const Center(child: CircularProgressIndicator());
          }

          // Show error if any
          if (chatProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${chatProvider.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      chatProvider.fetchConversations();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Show empty state
          if (chatProvider.conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No conversations yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start a new chat to connect with people',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Navigate to search/new chat screen
                    },
                    child: const Text('Start New Chat'),
                  ),
                ],
              ),
            );
          }

          // Show conversations list
          return RefreshIndicator(
            onRefresh: () => chatProvider.fetchConversations(),
            child: ListView.builder(
              itemCount: chatProvider.conversations.length,
              itemBuilder: (context, index) {
                final conversation = chatProvider.conversations[index];

                // Find the other participant (not the current user)
                // This is simplified - you would need to extract the other user's data from your conversation structure
                final otherUser = conversation.participants.firstWhere(
                  (participant) =>
                      participant['_id'] != chatProvider.currentUserId,
                  orElse: () => {'_id': '', 'full_name': 'Unknown User'},
                );

                return ConversationListItem(
                  conversationId: conversation.id,
                  userId: otherUser['_id'],
                  name: otherUser['full_name'],
                  lastMessage:
                      conversation.lastMessage?.text ?? 'No messages yet',
                  time: conversation.updatedAt,
                  isUnread: false, // TODO: Implement unread status
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class ConversationListItem extends StatelessWidget {
  final String conversationId;
  final String userId;
  final String name;
  final String lastMessage;
  final DateTime time;
  final bool isUnread;

  const ConversationListItem({
    Key? key,
    required this.conversationId,
    required this.userId,
    required this.name,
    required this.lastMessage,
    required this.time,
    this.isUnread = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isUnread ? Colors.black : Colors.grey,
          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(time),
            style: TextStyle(
              fontSize: 12,
              color: isUnread ? Theme.of(context).primaryColor : Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          if (isUnread)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Text(
                '', // You could put the number of unread messages here
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ChatScreen(
                  conversationId: conversationId,
                  receiverId: userId,
                  receiverName: name,
                ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      // Today, just show time
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Yesterday
      return 'Yesterday';
    } else {
      // Show date
      return '${time.day}/${time.month}';
    }
  }
}
