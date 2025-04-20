import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
// import 'dart:convert';
import 'api_service.dart';

class ChatService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final Logger logger = Logger();

  // Stream controllers for different events
  final StreamController<Map<String, dynamic>> _messageStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Expose streams that UI components can listen to
  Stream<Map<String, dynamic>> get messageStream =>
      _messageStreamController.stream;

  // Current active conversation ID (set when user opens a specific chat)
  String? _currentConversationId;

  String? get currentConversationId => _currentConversationId;

  set currentConversationId(String? id) {
    _currentConversationId = id;
    notifyListeners();
  }

  // Constructor
  ChatService() {
    _initFirebaseMessaging();
  }

  // Initialize Firebase Messaging listeners
  void _initFirebaseMessaging() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  // Handle incoming messages while app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    logger.i('Got a message whilst in the foreground!');
    logger.i('Message data: ${message.data}');

    if (message.notification != null) {
      logger.i(
        'Message also contained a notification: ${message.notification}',
      );
    }

    // Process message data
    if (message.data.containsKey('type') &&
        message.data['type'] == 'newMessage') {
      final String? conversationId = message.data['conversationId'];
      final String? senderId = message.data['senderId'];

      // If we have necessary data and this is a chat message
      if (conversationId != null && senderId != null) {
        // Add to stream for UI updates - every subscriber will receive this
        _messageStreamController.add(message.data);

        // Check if this is for the currently active conversation
        if (conversationId == _currentConversationId) {
          logger.i('New message is for the active conversation');
        }

        // Emit the update with the conversation data
        notifyListeners();
      }
    }
  }

  // Handle when user taps on a notification when app is in background
  void _handleMessageOpenedApp(RemoteMessage message) {
    logger.i('User tapped on notification while app was in background');

    if (message.data.containsKey('conversationId')) {
      // This could be used by navigation service to navigate to specific chat
      // For now, just update current conversation ID
      currentConversationId = message.data['conversationId'];

      // Add to message stream for any listeners
      _messageStreamController.add(message.data);
    }
  }

  // Call this when widget is disposed
  void dispose() {
    _messageStreamController.close();
  }
}
