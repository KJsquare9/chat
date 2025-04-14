import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../services/api_service.dart';
// import 'dart:convert';
import 'package:logger/logger.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String receiverName;

  const ChatScreen({
    Key? key,
    required this.conversationId,
    required this.receiverName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();

  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // Set current conversation ID in the chat service
    context.read<ChatService>().currentConversationId = widget.conversationId;

    // Load initial messages
    _loadMessages();

    // Listen for new messages from the chat service
    context.read<ChatService>().messageStream.listen(_handleIncomingMessage);
  }

  @override
  void dispose() {
    // Clear current conversation when leaving
    context.read<ChatService>().currentConversationId = null;
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Handle incoming message from Firebase
  void _handleIncomingMessage(Map<String, dynamic> messageData) {
    // Only process if this message belongs to the current conversation
    if (messageData['conversationId'] == widget.conversationId) {
      _logger.i(
        'Received message for current conversation: ${messageData['text']}',
      );

      // Refresh messages to include the new one
      _loadMessages();

      // You could alternatively just add the new message to the list
      // if you have all the required fields in the notification data
    }
  }

  // Load messages from the API
  Future<void> _loadMessages() async {
    try {
      setState(() => isLoading = true);

      // This is a placeholder - you'll need to implement the actual API call
      // based on your backend structure
      final response = await _apiService.getMessages(widget.conversationId);

      setState(() {
        messages = response; // Assuming this returns a list of message objects
        isLoading = false;
      });

      // Scroll to bottom after messages load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      _logger.e('Error loading messages: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.receiverName)),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : messages.isEmpty
                    ? const Center(child: Text('No messages yet'))
                    : ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return _buildMessageItem(message);
                      },
                    ),
          ),

          // Message input field
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> message) {
    final bool isMe = message['senderId'] == _apiService.getSellerId();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Text(
          message['text'] ?? '',
          style: TextStyle(color: isMe ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  void _sendMessage() {
    // Implementation for sending messages
    // You'll need to integrate with your socket.io or API
  }
}
