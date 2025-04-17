// chat_list.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'dart:convert'; // For JSON decoding
import 'package:http/http.dart' as http; // For API calls
import '../services/api_service.dart'; // Import API service for token management
import 'chat.dart'; // Import the chat page
import '../widgets/custom_navbar.dart'; // Import the bottom navbar

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  ChatListPageState createState() => ChatListPageState();
}

class ChatContact {
  final String name;
  final String lastMessage;
  final DateTime lastMessageTime;
  final bool unread;

  ChatContact({
    required this.name,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unread,
  });
}

class ChatListPageState extends State<ChatListPage> {
  double _scrollOffset = 0.0;
  List<ChatContact> contacts = []; // Initialize as an empty list

  @override
  void initState() {
    super.initState();
    _fetchConversations(); // Fetch conversations on initialization
  }

  Future<void> _fetchConversations() async {
    try {
      final apiService = ApiService();
      final conversations =
          await apiService.fetchConversations(); // Use updated method

      setState(() {
        contacts =
            conversations.map((conversation) {
              final lastMessage = conversation['lastMessage'];
              return ChatContact(
                name: conversation['participants'][0]['full_name'] ?? 'Unknown',
                lastMessage: lastMessage?['text'] ?? 'No messages yet',
                lastMessageTime: DateTime.parse(
                  lastMessage?['timestamp'] ?? DateTime.now().toIso8601String(),
                ),
                unread: lastMessage?['status'] != 'read',
              );
            }).toList();
      });
    } catch (e) {
      debugPrint('Error fetching conversations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (scrollNotification) {
              setState(() {
                _scrollOffset = scrollNotification.metrics.pixels;
              });
              return true;
            },
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 120.0,
                  backgroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  forceElevated: false,
                  iconTheme: const IconThemeData(color: Colors.black),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(color: Colors.white),
                    centerTitle: true,
                    title: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 80 - _scrollOffset.clamp(0, 40),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Chats',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((
                    BuildContext context,
                    int index,
                  ) {
                    if (index == contacts.length) {
                      return SizedBox(height: 80); // Empty space at the end
                    }
                    final contact = contacts[index];
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ChatScreen(
                                  conversationId:
                                      contact
                                          .name, // Replace with actual conversation ID
                                  receiverId:
                                      contact
                                          .name, // Replace with actual receiver ID
                                ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    contact.lastMessage,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  DateFormat(
                                    'HH:mm',
                                  ).format(contact.lastMessageTime),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (contact.unread)
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.deepOrange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }, childCount: contacts.length + 1), // Add 1 for the empty space
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomNavBar(
              activeIndex: 3,
            ), // Ensure the navbar doesn't scroll
          ),
        ],
      ),
    );
  }
}
