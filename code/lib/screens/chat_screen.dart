import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Add this import
import '../providers/chat_service_provider.dart';

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
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chatProvider = Provider.of<ChatServiceProvider>(
        context,
        listen: false,
      );

      // Ensure current user ID is loaded
      await chatProvider.loadCurrentUserId();

      // Set active chat
      chatProvider.setActiveChat(widget.conversationId);
    });
  }

  @override
  void dispose() {
    // Clear active chat
    Provider.of<ChatServiceProvider>(context, listen: false).clearActiveChat();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.receiverName),
            Consumer<ChatServiceProvider>(
              builder: (context, chatProvider, child) {
                // Show typing indicator or connection status
                if (chatProvider.typingUsers.containsKey(widget.receiverId)) {
                  return const Text(
                    'typing...',
                    style: TextStyle(fontSize: 12),
                  );
                } else {
                  return Text(
                    _getConnectionStatusText(chatProvider.connectionStatus),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getConnectionStatusColor(
                        chatProvider.connectionStatus,
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Connection status indicator
          Consumer<ChatServiceProvider>(
            builder: (context, chatProvider, child) {
              if (chatProvider.connectionStatus != ConnectionStatus.connected) {
                return Container(
                  color:
                      chatProvider.connectionStatus ==
                              ConnectionStatus.connecting
                          ? Colors.amber
                          : Colors.red,
                  padding: const EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: 16,
                  ),
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        chatProvider.connectionStatus ==
                                ConnectionStatus.connecting
                            ? Icons.sync
                            : Icons.cloud_off,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        chatProvider.connectionStatus ==
                                ConnectionStatus.connecting
                            ? 'Connecting...'
                            : 'No connection',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          ),

          // Messages list
          Expanded(
            child: Consumer<ChatServiceProvider>(
              builder: (context, chatProvider, child) {
                if (chatProvider.isLoadingMessages) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (chatProvider.messages.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: chatProvider.messages.length,
                  itemBuilder: (context, index) {
                    final message = chatProvider.messages[index];
                    final isMe =
                        message.senderId ==
                        Provider.of<ChatServiceProvider>(
                          context,
                          listen: false,
                        ).currentUserId;

                    return MessageBubble(message: message, isMe: isMe);
                  },
                );
              },
            ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, -1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                // Attachment button
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _showAttachmentOptions,
                ),

                // Text input
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      border: InputBorder.none,
                    ),
                    onChanged: _handleTextChange,
                  ),
                ),

                // Send button
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).primaryColor,
                  onPressed: _sendTextMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getConnectionStatusText(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return 'Online';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.disconnected:
        return 'Offline';
    }
  }

  Color _getConnectionStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.connecting:
        return Colors.amber;
      case ConnectionStatus.disconnected:
        return Colors.red;
    }
  }

  void _handleTextChange(String text) {
    final chatProvider = Provider.of<ChatServiceProvider>(
      context,
      listen: false,
    );

    if (text.isNotEmpty && !_isTyping) {
      // Start typing
      _isTyping = true;
      chatProvider.sendTypingEvent(widget.receiverId);
    } else if (text.isEmpty && _isTyping) {
      // Stop typing
      _isTyping = false;
      chatProvider.sendStopTypingEvent(widget.receiverId);
    }
  }

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      final chatProvider = Provider.of<ChatServiceProvider>(
        context,
        listen: false,
      );
      chatProvider.sendMessage(widget.receiverId, text);
      _textController.clear();
      _isTyping = false;
      chatProvider.sendStopTypingEvent(widget.receiverId);
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              // Add more options as needed
            ],
          ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );

      if (image != null) {
        final imageUrl = await uploadImageToStorage(File(image.path));
        Provider.of<ChatServiceProvider>(context, listen: false).sendMessage(
          widget.receiverId,
          'Sent an image',
          type: 'image',
          mediaUrl: imageUrl,
        );
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error picking image')));
    }
  }

  // Add this function to upload images to Firebase Storage
  Future<String> uploadImageToStorage(File imageFile) async {
    try {
      // Create a unique filename
      final fileName =
          'chat_image_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Get a reference to the storage location
      final storageRef = FirebaseStorage.instance.ref().child(
        'chat_images/$fileName',
      );

      // Upload the file
      final uploadTask = storageRef.putFile(imageFile);

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      throw Exception('Failed to upload image');
    }
  }
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),

          const SizedBox(width: 4),

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color:
                    isMe
                        // ignore: deprecated_member_use
                        ? Theme.of(context).primaryColor.withOpacity(0.8)
                        : Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message content based on type
                  _buildMessageContent(context),

                  // Timestamp and status
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 4),

          if (isMe) const SizedBox(width: 32), // Balance with avatar space
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    switch (message.type) {
      case 'image':
        return GestureDetector(
          onTap: () {
            // TODO: Implement image viewer
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.mediaUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    message.mediaUrl!,
                    width: 200,
                    height: 150,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return SizedBox(
                        width: 200,
                        height: 150,
                        child: Center(
                          child: CircularProgressIndicator(
                            value:
                                loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 200,
                        height: 150,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image),
                      );
                    },
                  ),
                ),
              if (message.text.isNotEmpty && message.text != 'Sent an image')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    message.text,
                    style: TextStyle(color: isMe ? Colors.white : Colors.black),
                  ),
                ),
            ],
          ),
        );

      case 'video':
        // TODO: Implement video message
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.video_library),
            const SizedBox(width: 8),
            Text(
              'Video message',
              style: TextStyle(color: isMe ? Colors.white : Colors.black),
            ),
          ],
        );

      case 'file':
        // TODO: Implement file message
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file),
            const SizedBox(width: 8),
            Text(
              'File attachment',
              style: TextStyle(color: isMe ? Colors.white : Colors.black),
            ),
          ],
        );

      case 'text':
      default:
        return Text(
          message.text,
          style: TextStyle(color: isMe ? Colors.white : Colors.black),
        );
    }
  }

  Widget _buildStatusIcon() {
    IconData iconData;
    Color color;

    switch (message.status) {
      case MessageStatus.sending:
        iconData = Icons.access_time;
        color = Colors.white70;
        break;
      case MessageStatus.sent:
        iconData = Icons.check;
        color = Colors.white70;
        break;
      case MessageStatus.delivered:
        iconData = Icons.done_all;
        color = Colors.white70;
        break;
      case MessageStatus.read:
        iconData = Icons.done_all;
        color = Colors.blue[300]!;
        break;
      case MessageStatus.failed:
        iconData = Icons.error_outline;
        color = Colors.red;
        break;
    }

    return Icon(iconData, size: 12, color: color);
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      // Today, just show time
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      // Not today, show date and time
      return '${time.day}/${time.month} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
