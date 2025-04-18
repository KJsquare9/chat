import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_chat_bubble/chat_bubble.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/chat_service_provider.dart';
import '../services/api_service.dart'; // Add this import for ApiService

// Chat messages data model
class Message {
  final String text;
  final String senderId;
  final bool isSender;
  final DateTime timestamp;
  final MessageStatus? status;

  Message({
    required this.text,
    required this.senderId,
    required this.isSender,
    required this.timestamp,
    this.status,
  });

  Message copyWith({
    String? text,
    String? senderId,
    bool? isSender,
    DateTime? timestamp,
    MessageStatus? status,
  }) {
    return Message(
      text: text ?? this.text,
      senderId: senderId ?? this.senderId,
      isSender: isSender ?? this.isSender,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Logger logger = Logger();
  bool _isTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();

    // Set the active conversation in the ChatServiceProvider
    final provider = Provider.of<ChatServiceProvider>(context, listen: false);

    // Ensure we have a valid user before setting active chat
    _ensureValidUserAndInitialize();

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _ensureValidUserAndInitialize() async {
    try {
      final apiService = ApiService(); // Create an instance of ApiService
      final isLoggedIn = await apiService.isLoggedIn();

      if (!isLoggedIn) {
        logger.e('User not logged in when trying to initialize chat screen');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to access chat')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // Ensure we have current user ID
      await Provider.of<ChatServiceProvider>(
        context,
        listen: false,
      ).loadCurrentUserId();

      // Now set active chat
      final provider = Provider.of<ChatServiceProvider>(context, listen: false);
      provider.setActiveChat(widget.conversationId, widget.receiverId);

      // Also manually fetch messages if needed
      _fetchMessagesViaApiService();
    } catch (e) {
      logger.e('Error initializing chat: $e');
    }
  }

  Future<void> _fetchMessagesViaApiService() async {
    try {
      // Use ApiService as a backup if ChatServiceProvider isn't working
      final apiService = ApiService(); // Create an instance of ApiService
      final messages = await apiService.fetchConversationMessages(
        widget.conversationId,
      );

      // Log the fetched messages for debugging
      logger.d('Fetched ${messages.length} messages via ApiService');

      // Re-trigger the ChatServiceProvider to fetch messages after a short delay
      if (mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          final provider = Provider.of<ChatServiceProvider>(
            context,
            listen: false,
          );
          if (provider.activeMessages.isEmpty) {
            provider.fetchMessages(widget.conversationId, forceRefresh: true);
          }
        });
      }
    } catch (e) {
      logger.e('Error fetching messages via API service: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleTyping() {
    final provider = Provider.of<ChatServiceProvider>(context, listen: false);

    if (!_isTyping) {
      _isTyping = true;
      provider.sendTypingEvent(widget.receiverId);
    }

    // Reset the timer each time the user types
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      setState(() {
        _isTyping = false;
        provider.sendStopTypingEvent(widget.receiverId);
      });
    });
  }

  void _sendMessage(String text) {
    if (text.isEmpty) return;

    final provider = Provider.of<ChatServiceProvider>(context, listen: false);

    // Cancel any typing indicators
    _isTyping = false;
    _typingTimer?.cancel();
    provider.sendStopTypingEvent(widget.receiverId);

    // Clear the text input field
    final messageText = _messageController.text;
    _messageController.clear();

    // Send the message via the provider (WebSocket)
    provider.sendMessage(widget.receiverId, messageText);

    // Also persist the message in the database using API service
    _persistMessageToDatabase(messageText);

    _scrollToBottom();
  }

  // New method to persist messages to the database
  Future<void> _persistMessageToDatabase(String text) async {
    try {
      final apiService = ApiService();
      final result = await apiService.sendMessage(
        conversationId: widget.conversationId,
        receiverId: widget.receiverId,
        text: text,
      );

      if (!result) {
        logger.e('Failed to persist message to database');
      }
    } catch (e) {
      logger.e('Error persisting message to database: $e');
    }
  }

  Future<void> _pickFile() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.isNotEmpty) {
        String fileName = result.files.first.name;
        logger.i('Picked file: $fileName');
        // TODO: Implement file sending
      }
    } catch (e) {
      logger.e('Error picking file: $e', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF093466),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Consumer<ChatServiceProvider>(
          builder: (context, provider, child) {
            final isTyping = provider.typingUsers.containsKey(
              widget.receiverId,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.receiverName,
                  style: const TextStyle(color: Colors.white),
                ),
                if (isTyping)
                  Text(
                    'typing...',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
              ],
            );
          },
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatServiceProvider>(
              builder: (context, provider, child) {
                final messages = provider.activeMessages;

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Start the conversation!'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isSender = message.senderId == provider.currentUserId;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Column(
                        crossAxisAlignment:
                            isSender
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                        children: [
                          ChatBubble(
                            clipper: ChatBubbleClipper3(
                              type:
                                  isSender
                                      ? BubbleType.sendBubble
                                      : BubbleType.receiverBubble,
                            ),
                            alignment:
                                isSender
                                    ? Alignment.topRight
                                    : Alignment.topLeft,
                            margin: const EdgeInsets.only(top: 2),
                            backGroundColor:
                                isSender
                                    ? const Color(0xFFFF5002)
                                    : const Color.fromARGB(255, 112, 112, 112),
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.7,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    message.text ?? '',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  if (isSender) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getStatusIcon(
                                            message
                                                .status!, // Ensure `message.status` is non-null
                                          ),
                                          size: 12,
                                          color: Colors.white70,
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: Text(
                              DateFormat(
                                'yyyy-MM-dd HH:mm',
                              ).format(message.timestamp),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: const BoxDecoration(color: Colors.white),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _pickFile,
                  color: const Color(0xFFFF5002),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onChanged: (_) => _handleTyping(),
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(_messageController.text),
                  color: const Color(0xFFFF5002),
                ),
              ],
            ),
          ),
          Container(height: 10, color: Colors.white),
        ],
      ),
    );
  }

  IconData _getStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Icons.access_time;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.read:
        return Icons.done_all; // Usually with a different color
      case MessageStatus.failed:
        return Icons.error_outline;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();

    // Clear the active chat when leaving
    if (context.mounted) {
      final provider = Provider.of<ChatServiceProvider>(context, listen: false);
      provider.clearActiveChat();
    }

    super.dispose();
  }
}
