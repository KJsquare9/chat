import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// Message status enum
enum MessageStatus { sending, sent, delivered, read, failed }

// Message type enum
enum MessageType { text, image, video, file }

// Connection status enum
enum ConnectionStatus { connected, connecting, disconnected }

class ChatMessage {
  final String? id; // Nullable for pending messages
  final String? tempId; // Client-side temporary ID
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String text;
  final String type;
  final String? mediaUrl;
  final DateTime timestamp;
  MessageStatus status;

  ChatMessage({
    this.id,
    this.tempId,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.type = 'text',
    this.mediaUrl,
    required this.timestamp,
    this.status = MessageStatus.sending,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Helper function to parse status string to enum
    MessageStatus parseStatus(String? statusStr) {
      switch (statusStr) {
        case 'sent':
          return MessageStatus.sent;
        case 'delivered':
          return MessageStatus.delivered;
        case 'read':
          return MessageStatus.read;
        default:
          return MessageStatus.sent;
      }
    }

    return ChatMessage(
      id: json['_id'],
      conversationId: json['conversationId'],
      senderId: json['senderId'] ?? json['sender']?['_id'],
      receiverId: json['receiverId'],
      text: json['text'] ?? '',
      type: json['type'] ?? 'text',
      mediaUrl: json['mediaUrl'],
      timestamp: DateTime.parse(json['timestamp']).toLocal(),
      status: parseStatus(json['status']),
    );
  }
}

class Conversation {
  final String id;
  final List<dynamic> participants;
  final ChatMessage? lastMessage;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['_id'],
      participants: json['participants'],
      lastMessage:
          json['lastMessage'] != null
              ? ChatMessage.fromJson(json['lastMessage'])
              : null,
      updatedAt: DateTime.parse(json['updatedAt']).toLocal(),
    );
  }
}

class ChatServiceProvider with ChangeNotifier {
  IO.Socket? _socket;
  String? _currentUserId;
  String get currentUserId => _currentUserId ?? '';
  String? _activeConversationId;
  bool _isConnected = false;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;

  // State for managing messages and conversations
  final Map<String, List<ChatMessage>> _messagesMap = {};
  List<ChatMessage> _activeConversationMessages = [];
  List<Conversation> _conversations = [];
  bool _isLoadingMessages = false;
  bool _isLoadingConversations = false;
  String? _error;
  final Map<String, bool> _typingUsers = {};

  // List of messages pending to be sent due to connection issues
  final List<Map<String, dynamic>> _pendingMessages = [];
  int _retryAttempts = 0;

  // Getters
  bool get isConnected => _isConnected;
  ConnectionStatus get connectionStatus => _connectionStatus;
  List<ChatMessage> get messages => _activeConversationMessages;
  List<Conversation> get conversations => _conversations;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isLoadingConversations => _isLoadingConversations;
  String? get error => _error;
  Map<String, bool> get typingUsers => _typingUsers;

  // Configuration
  final String _socketUrl =
      'http://10.0.2.2:5000'; // Update this with your server URL

  // Load current user ID from SharedPreferences
  Future<void> loadCurrentUserId() async {
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      // Already loaded
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId != null && userId.isNotEmpty) {
        _currentUserId = userId;
        notifyListeners();
      }
    } catch (e) {
      log('Error loading current user ID: $e');
    }
  }

  // Connect to socket server
  Future<void> connect() async {
    if (_isConnected && _socket != null) {
      log('Already connected.');
      return;
    }

    // Ensure user ID is loaded first
    await loadCurrentUserId();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || _currentUserId == null || _currentUserId!.isEmpty) {
      _error = 'Cannot connect: authentication required';
      notifyListeners();
      return;
    }

    log('Connecting to Socket Server...');
    _connectionStatus = ConnectionStatus.connecting;
    notifyListeners();

    // Disconnect previous socket if exists
    disconnect();

    try {
      _socket = IO.io(_socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'forceNew': true,
        'auth': {'token': token},
      });

      _registerSocketListeners();
    } catch (e) {
      log("Error initializing socket: $e");
      _error = 'Failed to connect to chat server';
      _connectionStatus = ConnectionStatus.disconnected;
      notifyListeners();
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _connectionStatus = ConnectionStatus.disconnected;
    _activeConversationId = null;
    _typingUsers.clear();
    notifyListeners();
  }

  // Register all socket event listeners
  void _registerSocketListeners() {
    _socket?.onConnect((_) {
      log('Socket connected: ${_socket?.id}');
      _isConnected = true;
      _connectionStatus = ConnectionStatus.connected;
      _retryAttempts = 0;
      _retryFailedMessages();
      notifyListeners();
    });

    _socket?.onDisconnect((_) {
      log('Socket disconnected');
      _isConnected = false;
      _connectionStatus = ConnectionStatus.disconnected;
      _typingUsers.clear();
      notifyListeners();
    });

    _socket?.onConnectError((data) {
      log('Socket connection error: $data');
      _isConnected = false;
      _connectionStatus = ConnectionStatus.disconnected;
      notifyListeners();
      _attemptReconnection();
    });

    _socket?.onError((data) {
      log('Socket error: $data');
    });

    // Message events
    _socket?.on('receiveMessage', _handleReceiveMessage);
    _socket?.on('messageSent', _handleMessageSent);
    _socket?.on('sendMessageError', _handleSendMessageError);
    _socket?.on('messagesRead', _handleMessagesRead);

    // Typing events
    _socket?.on('typing', _handleTyping);
    _socket?.on('stopTyping', _handleStopTyping);
  }

  // Event handlers
  void _handleReceiveMessage(dynamic data) {
    try {
      final message = ChatMessage.fromJson(data);

      // Add to conversation map
      _addMessageToMap(message);

      // If this is the active conversation, update the view
      if (message.conversationId == _activeConversationId) {
        _activeConversationMessages.insert(0, message);

        // Mark as read if this is the active conversation
        markAsRead(message.conversationId);

        // Clear typing indicator
        _typingUsers.remove(message.senderId);

        notifyListeners();
      } else {
        // Update unread messages count
        // This would need to be implemented depending on how you track unread messages
      }
    } catch (e) {
      log('Error handling received message: $e');
    }
  }

  void _handleMessageSent(dynamic data) {
    try {
      final tempId = data['tempId'];
      final message = ChatMessage.fromJson(data['message']);

      // Update the message in maps and lists
      _updateTempMessage(tempId, message);
      notifyListeners();
    } catch (e) {
      log('Error handling message sent: $e');
    }
  }

  void _handleSendMessageError(dynamic data) {
    try {
      final tempId = data['tempId'];
      final error = data['error'];

      // Mark message as failed
      for (var conversationId in _messagesMap.keys) {
        final index = _messagesMap[conversationId]!.indexWhere(
          (m) => m.tempId == tempId,
        );
        if (index != -1) {
          _messagesMap[conversationId]![index].status = MessageStatus.failed;

          if (conversationId == _activeConversationId) {
            final activeIndex = _activeConversationMessages.indexWhere(
              (m) => m.tempId == tempId,
            );
            if (activeIndex != -1) {
              _activeConversationMessages[activeIndex].status =
                  MessageStatus.failed;
            }
          }
        }
      }

      log('Message send error: $error');
      notifyListeners();
    } catch (e) {
      log('Error handling send message error: $e');
    }
  }

  void _handleMessagesRead(dynamic data) {
    try {
      final conversationId = data['conversationId'];
      final readerId = data['readerId'];

      // Update message status for all messages in this conversation sent by current user
      if (_messagesMap.containsKey(conversationId)) {
        for (var i = 0; i < _messagesMap[conversationId]!.length; i++) {
          final message = _messagesMap[conversationId]![i];
          if (message.senderId == _currentUserId &&
              message.receiverId == readerId &&
              message.status != MessageStatus.read) {
            _messagesMap[conversationId]![i].status = MessageStatus.read;
          }
        }

        // Also update active conversation messages if this is the current conversation
        if (conversationId == _activeConversationId) {
          for (var i = 0; i < _activeConversationMessages.length; i++) {
            final message = _activeConversationMessages[i];
            if (message.senderId == _currentUserId &&
                message.receiverId == readerId &&
                message.status != MessageStatus.read) {
              _activeConversationMessages[i].status = MessageStatus.read;
            }
          }
          notifyListeners();
        }
      }
    } catch (e) {
      log('Error handling messages read: $e');
    }
  }

  void _handleTyping(dynamic data) {
    try {
      final conversationId = data['conversationId'];
      final senderId = data['senderId'];

      if (conversationId == _activeConversationId) {
        _typingUsers[senderId] = true;
        notifyListeners();

        // Auto-clear typing after 3 seconds if no stopTyping event received
        Future.delayed(const Duration(seconds: 3), () {
          if (_typingUsers.containsKey(senderId)) {
            _typingUsers.remove(senderId);
            notifyListeners();
          }
        });
      }
    } catch (e) {
      log('Error handling typing: $e');
    }
  }

  void _handleStopTyping(dynamic data) {
    try {
      final conversationId = data['conversationId'];
      final senderId = data['senderId'];

      if (conversationId == _activeConversationId &&
          _typingUsers.containsKey(senderId)) {
        _typingUsers.remove(senderId);
        notifyListeners();
      }
    } catch (e) {
      log('Error handling stop typing: $e');
    }
  }

  // Helper methods
  void _addMessageToMap(ChatMessage message) {
    if (!_messagesMap.containsKey(message.conversationId)) {
      _messagesMap[message.conversationId] = [];
    }

    // Avoid duplicates
    final isDuplicate = _messagesMap[message.conversationId]!.any(
      (m) => m.id != null && m.id == message.id,
    );

    if (!isDuplicate) {
      _messagesMap[message.conversationId]!.insert(0, message);
    }
  }

  void _updateTempMessage(String tempId, ChatMessage message) {
    // Update in message map
    for (var conversationId in _messagesMap.keys) {
      final index = _messagesMap[conversationId]!.indexWhere(
        (m) => m.tempId == tempId,
      );
      if (index != -1) {
        _messagesMap[conversationId]![index] = message;
      }
    }

    // Update in active conversation if applicable
    if (_activeConversationId != null) {
      final index = _activeConversationMessages.indexWhere(
        (m) => m.tempId == tempId,
      );
      if (index != -1) {
        _activeConversationMessages[index] = message;
      }
    }
  }

  void _attemptReconnection() {
    if (_retryAttempts < 5) {
      final delay = Duration(
        seconds: 1 << _retryAttempts,
      ); // Exponential backoff: 1, 2, 4, 8, 16 seconds
      Future.delayed(delay, () {
        log('Attempting to reconnect (attempt ${_retryAttempts + 1})');
        _socket?.connect();
        _retryAttempts++;
      });
    } else {
      _error = 'Failed to connect after multiple attempts';
      notifyListeners();
    }
  }

  void _retryFailedMessages() {
    if (_pendingMessages.isEmpty) return;

    log('Retrying ${_pendingMessages.length} failed messages');

    // Clone the list to avoid modification during iteration
    final pending = List<Map<String, dynamic>>.from(_pendingMessages);
    _pendingMessages.clear();

    for (final message in pending) {
      sendMessage(
        message['receiverId'],
        message['text'],
        type: message['type'],
        mediaUrl: message['mediaUrl'],
        conversationId: message['conversationId'],
        tempId: message['tempId'],
      );
    }
  }

  // Public methods for sending messages
  void sendMessage(
    String receiverId,
    String text, {
    String type = 'text',
    String? mediaUrl,
    String? conversationId,
    String? tempId,
  }) {
    if (!_isConnected || _currentUserId == null) {
      _error = 'Cannot send message: not connected';
      notifyListeners();
      return;
    }

    final timestamp = DateTime.now();
    tempId ??= 'temp_${timestamp.millisecondsSinceEpoch}';

    // If no conversationId is provided, use the active one or create a temporary one
    final actualConversationId =
        conversationId ??
        _activeConversationId ??
        'temp_${_currentUserId}_$receiverId';

    // Create temporary message
    final tempMessage = ChatMessage(
      tempId: tempId,
      conversationId: actualConversationId,
      senderId: _currentUserId!,
      receiverId: receiverId,
      text: text,
      type: type,
      mediaUrl: mediaUrl,
      timestamp: timestamp,
      status: MessageStatus.sending,
    );

    // Add to maps and lists for immediate UI update
    _addMessageToMap(tempMessage);

    if (actualConversationId == _activeConversationId) {
      _activeConversationMessages.insert(0, tempMessage);
    }

    notifyListeners();

    // Send via socket
    if (_isConnected) {
      _socket?.emit('sendMessage', {
        'receiverId': receiverId,
        'text': text,
        'type': type,
        'mediaUrl': mediaUrl,
        'tempId': tempId,
      });
    } else {
      // Save for sending when connection is restored
      _pendingMessages.add({
        'receiverId': receiverId,
        'text': text,
        'type': type,
        'mediaUrl': mediaUrl,
        'conversationId': actualConversationId,
        'tempId': tempId,
      });

      // Update UI to show failed status
      _updateMessageStatus(actualConversationId, tempId, MessageStatus.failed);
    }
  }

  void _updateMessageStatus(
    String conversationId,
    String tempId,
    MessageStatus status,
  ) {
    // Update in message map
    if (_messagesMap.containsKey(conversationId)) {
      final index = _messagesMap[conversationId]!.indexWhere(
        (m) => m.tempId == tempId,
      );
      if (index != -1) {
        _messagesMap[conversationId]![index].status = status;
      }
    }

    // Update in active conversation if applicable
    if (conversationId == _activeConversationId) {
      final index = _activeConversationMessages.indexWhere(
        (m) => m.tempId == tempId,
      );
      if (index != -1) {
        _activeConversationMessages[index].status = status;
        notifyListeners();
      }
    }
  }

  // Methods for active chat management
  void setActiveChat(String conversationId) {
    _activeConversationId = conversationId;

    // Load messages from map if available
    if (_messagesMap.containsKey(conversationId)) {
      _activeConversationMessages = List.from(_messagesMap[conversationId]!);
    } else {
      _activeConversationMessages = [];
      // Fetch messages from API
      fetchMessages(conversationId);
    }

    // Clear typing indicators
    _typingUsers.clear();

    // Mark messages as read
    markAsRead(conversationId);

    notifyListeners();
  }

  void clearActiveChat() {
    _activeConversationId = null;
    _activeConversationMessages = [];
    _typingUsers.clear();
    notifyListeners();
  }

  // Typing indicators
  void sendTypingEvent(String receiverId) {
    if (!_isConnected || _activeConversationId == null) return;

    _socket?.emit('typing', {
      'conversationId': _activeConversationId,
      'receiverId': receiverId,
    });
  }

  void sendStopTypingEvent(String receiverId) {
    if (!_isConnected || _activeConversationId == null) return;

    _socket?.emit('stopTyping', {
      'conversationId': _activeConversationId,
      'receiverId': receiverId,
    });
  }

  // Mark messages as read
  void markAsRead(String conversationId) {
    if (!_isConnected || _currentUserId == null) return;

    bool hasUnread = false;

    // Check if there are unread messages
    if (_messagesMap.containsKey(conversationId)) {
      hasUnread = _messagesMap[conversationId]!.any(
        (msg) =>
            msg.receiverId == _currentUserId &&
            msg.status != MessageStatus.read,
      );
    }

    if (hasUnread) {
      _socket?.emit('markAsRead', {'conversationId': conversationId});
    }
  }

  // API methods
  Future<void> fetchMessages(String conversationId) async {
    _isLoadingMessages = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        _error = 'Authentication required';
        _isLoadingMessages = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('$_socketUrl/api/conversations/$conversationId/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> messagesJson = data['messages'];
          final messages =
              messagesJson.map((json) => ChatMessage.fromJson(json)).toList();

          // Update the messages map
          _messagesMap[conversationId] = messages;

          // Update active conversation messages if this is still the active conversation
          if (_activeConversationId == conversationId) {
            _activeConversationMessages = List.from(messages);
          }
        } else {
          _error = 'Failed to load messages';
        }
      } else {
        _error = 'Failed to load messages: ${response.statusCode}';
      }
    } catch (e) {
      log('Error fetching messages: $e');
      _error = 'Network error while loading messages';
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  Future<void> fetchConversations() async {
    _isLoadingConversations = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        _error = 'Authentication required';
        _isLoadingConversations = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('$_socketUrl/api/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> conversationsJson = data['conversations'];
          _conversations =
              conversationsJson
                  .map((json) => Conversation.fromJson(json))
                  .toList();
        } else {
          _error = 'Failed to load conversations';
        }
      } else {
        _error = 'Failed to load conversations: ${response.statusCode}';
      }
    } catch (e) {
      log('Error fetching conversations: $e');
      _error = 'Network error while loading conversations';
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  // Method to set current user ID (call this during initialization)
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
