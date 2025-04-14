import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_chat_bubble/chat_bubble.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

// Chat messages data model
class Message {
  final String text;
  final bool isSender;
  final DateTime time;

  Message({required this.text, required this.isSender, required this.time});
}

class ChatPage extends StatefulWidget {
  final String sellerName;

  const ChatPage({super.key, required this.sellerName});

  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Logger logger = Logger();

  List<Message> messages = [];

  @override
  void initState() {
    super.initState();
    _generateMessages();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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

  void _generateMessages() {
    DateTime now = DateTime.now();
    for (int i = 0; i < 5; i++) {
      DateTime receiverTime = now.subtract(Duration(minutes: i));
      messages.add(
        Message(text: widget.sellerName, isSender: false, time: receiverTime),
      );

      DateTime senderTime = now.subtract(
        Duration(minutes: i + 1),
      ); // Offset the send time slightly
      messages.add(
        Message(text: widget.sellerName, isSender: true, time: senderTime),
      );
    }
  }

  void _sendMessage(String messageText) {
    DateTime now = DateTime.now();
    if (messageText.isNotEmpty) {
      setState(() {
        messages.add(Message(text: messageText, isSender: true, time: now));
        _messageController.clear();
      });
      _scrollToBottom();
      logger.i(
        'Sent message: $messageText at ${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)}',
      );
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
        title: Text(
          widget.sellerName,
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: messages.length,
              padding: const EdgeInsets.all(10),
              itemBuilder: (context, index) {
                final message = messages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 2.0,
                  ), // Add some vertical spacing
                  child: Column(
                    crossAxisAlignment:
                        message.isSender
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                    children: [
                      ChatBubble(
                        clipper: ChatBubbleClipper3(
                          type:
                              message.isSender
                                  ? BubbleType.sendBubble
                                  : BubbleType.receiverBubble,
                        ),
                        alignment:
                            message.isSender
                                ? Alignment.topRight
                                : Alignment.topLeft,
                        margin: const EdgeInsets.only(top: 2),
                        backGroundColor:
                            message.isSender
                                ? const Color(0xFFFF5002)
                                : const Color.fromARGB(255, 112, 112, 112),
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          child: Text(
                            message.text,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(message.time),
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
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    _sendMessage(_messageController.text);
                  },
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
