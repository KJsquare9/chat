import 'dart:async';
import 'dart:convert';
import 'dart:developer';
// import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Changed from material.dart to foundation.dart initially, but Material needed for WidgetsBinding
import 'package:flutter/scheduler.dart'; // Added for SchedulerPhase
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart'; // Add this import for ApiService

// --- Enums ---
enum MessageStatus { sending, sent, delivered, read, failed }

enum MessageType {
  text,
  image,
  video,
  file,
} // Assuming you might use this later

enum ConnectionStatus { connected, connecting, disconnected }

// --- Models ---
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
      switch (statusStr?.toLowerCase()) {
        // Added toLowerCase for robustness
        case 'sent':
          return MessageStatus.sent;
        case 'delivered':
          return MessageStatus.delivered;
        case 'read':
          return MessageStatus.read;
        case 'sending': // Handle potential 'sending' status from server/cache
          return MessageStatus.sending;
        case 'failed': // Handle potential 'failed' status from server/cache
          return MessageStatus.failed;
        default:
          // If ID exists, assume it was at least sent. Otherwise, maybe it's still pending.
          // Adjust this logic based on your backend's default status if needed.
          return json['_id'] != null
              ? MessageStatus.sent
              : MessageStatus.sending;
      }
    }

    // Robust handling for sender/receiver IDs
    String? parsedSenderId =
        json['senderId']?.toString() ?? json['sender']?['_id']?.toString();
    String? parsedReceiverId =
        json['receiverId']
            ?.toString(); // Assuming receiverId is always top-level

    if (parsedSenderId == null) {
      log(
        "Warning: ChatMessage.fromJson received null senderId for data: $json",
      );
      // Provide a default or handle error appropriately
      parsedSenderId = "unknown_sender";
    }
    if (parsedReceiverId == null) {
      log(
        "Warning: ChatMessage.fromJson received null receiverId for data: $json",
      );
      // Provide a default or handle error appropriately
      parsedReceiverId = "unknown_receiver";
    }

    return ChatMessage(
      id: json['_id']?.toString(),
      conversationId:
          json['conversationId']?.toString() ?? 'unknown_conversation',
      senderId: parsedSenderId,
      receiverId: parsedReceiverId,
      text: json['text']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      mediaUrl: json['mediaUrl']?.toString(),
      timestamp:
          DateTime.tryParse(json['timestamp'] ?? '')?.toLocal() ??
          DateTime.now(),
      status: parseStatus(json['status']?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'tempId': tempId,
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'type': type,
      'mediaUrl': mediaUrl,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'status': status.name,
    };
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
      participants: List<dynamic>.from(json['participants'] ?? []),
      lastMessage:
          json['lastMessage'] != null && json['lastMessage'] is Map
              ? ChatMessage.fromJson(
                Map<String, dynamic>.from(json['lastMessage']),
              )
              : null,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

// --- Chat Service Provider ---
class ChatServiceProvider with ChangeNotifier {
  IO.Socket? _socket;
  String? _currentUserId;
  String? _activeConversationId;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;

  final Map<String, List<ChatMessage>> _messagesMap = {};
  List<ChatMessage> _activeConversationMessages = [];
  List<Conversation> _conversations = [];
  bool _isLoadingMessages = false;
  bool _isLoadingConversations = false;
  String? _error;
  final Map<String, bool> _typingUsers = {};

  final List<ChatMessage> _pendingMessages = [];
  Timer? _reconnectionTimer;
  int _retryAttempts = 0;
  static const int _maxRetryAttempts = 5;

  static const String _socketUrl = 'http://10.0.2.2:5000';

  String get currentUserId => _currentUserId ?? '';
  bool get isConnected => _connectionStatus == ConnectionStatus.connected;
  ConnectionStatus get connectionStatus => _connectionStatus;
  List<ChatMessage> get activeMessages => _activeConversationMessages;
  List<Conversation> get conversations => List.unmodifiable(_conversations);
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isLoadingConversations => _isLoadingConversations;
  String? get error => _error;
  Map<String, bool> get typingUsers => Map.unmodifiable(_typingUsers);
  String? get activeConversationId => _activeConversationId;

  Future<void> initialize() async {
    await loadCurrentUserId();
    if (_currentUserId != null) {
      connect();
    }
  }

  Future<void> loadCurrentUserId() async {
    if (_currentUserId != null && _currentUserId!.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      final token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        log('No auth token found in SharedPreferences.');
        _error = 'Authentication token not found.';
        return;
      }

      if (userId != null && userId.isNotEmpty) {
        _currentUserId = userId;
        log('Current User ID loaded: $_currentUserId');
      } else {
        log('No User ID found in SharedPreferences.');
        _error = 'User not logged in.';
      }
    } catch (e) {
      log('Error loading current user ID: $e');
      _error = 'Failed to load user data.';
    }
  }

  Future<void> connect() async {
    if (_connectionStatus == ConnectionStatus.connected ||
        _connectionStatus == ConnectionStatus.connecting) {
      log('Already connected or connecting.');
      return;
    }

    if (_currentUserId == null) {
      await loadCurrentUserId();
      if (_currentUserId == null) {
        _error = 'Cannot connect: User ID not available.';
        _connectionStatus = ConnectionStatus.disconnected;
        log(_error!);
        _safelyNotifyListeners();
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      _error = 'Cannot connect: Authentication token missing.';
      _connectionStatus = ConnectionStatus.disconnected;
      log(_error!);
      _safelyNotifyListeners();
      return;
    }

    log('Attempting to connect to Socket Server...');
    _connectionStatus = ConnectionStatus.connecting;
    _error = null;
    _safelyNotifyListeners();

    disconnect(notify: false);

    try {
      _socket = IO.io(_socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'forceNew': true,
        'auth': {'token': token},
      });

      _registerSocketListeners();
      _socket?.connect();
    } catch (e) {
      log("Error initializing socket: $e");
      _error = 'Failed to initialize connection.';
      _connectionStatus = ConnectionStatus.disconnected;
      _safelyNotifyListeners();
    }
  }

  void disconnect({bool notify = true}) {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectionStatus = ConnectionStatus.disconnected;
    _typingUsers.clear();

    if (notify) {
      _safelyNotifyListeners();
    }
    log('Socket disconnected.');
  }

  void _registerSocketListeners() {
    _socket?.onConnect((_) {
      log('Socket connected: ${_socket?.id}');
      _connectionStatus = ConnectionStatus.connected;
      _error = null;
      _retryAttempts = 0;
      _reconnectionTimer?.cancel();
      _safelyNotifyListeners();
      _retryPendingMessages();
      if (_activeConversationId != null) {
        fetchMessages(_activeConversationId!, forceRefresh: true);
      }
      fetchConversations();
    });

    _socket?.onDisconnect((reason) {
      log('Socket disconnected: $reason');
      _connectionStatus = ConnectionStatus.disconnected;
      _typingUsers.clear();
      _safelyNotifyListeners();
      if (reason != 'io client disconnect') {
        _attemptReconnection();
      }
    });

    _socket?.onConnectError((data) {
      log('Socket connection error: $data');
      _connectionStatus = ConnectionStatus.disconnected;
      _safelyNotifyListeners();
      _attemptReconnection();
    });

    _socket?.onError((data) {
      log('Socket error: $data');
    });

    _socket?.on('receiveMessage', _handleReceiveMessage);
    _socket?.on('messageSent', _handleMessageSentConfirmation);
    _socket?.on('sendMessageError', _handleSendMessageError);
    _socket?.on('messagesRead', _handleMessagesRead);
    _socket?.on('typing', _handleTyping);
    _socket?.on('stopTyping', _handleStopTyping);
    _socket?.on('conversationUpdate', _handleConversationUpdate);
  }

  void _handleReceiveMessage(dynamic data) {
    log('Received message data: $data');
    if (data == null || data is! Map) {
      log('Error: Invalid message data received.');
      return;
    }
    try {
      final message = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      _addMessageToMap(message);

      if (message.conversationId == _activeConversationId) {
        if (!_activeConversationMessages.any(
          (m) => m.id != null && m.id == message.id,
        )) {
          _activeConversationMessages.insert(0, message);
          if (message.senderId != _currentUserId) {
            markAsRead(message.conversationId);
          }
          _typingUsers.remove(message.senderId);
        }
      } else {}

      _updateConversationList(message.conversationId, message);

      _safelyNotifyListeners();
    } catch (e, stackTrace) {
      log('Error handling received message: $e\n$stackTrace');
    }
  }

  void _handleMessageSentConfirmation(dynamic data) {
    log('Received messageSent confirmation: $data');
    if (data == null || data is! Map) {
      log('Error: Invalid messageSent data received.');
      return;
    }
    try {
      final tempId = data['tempId']?.toString();
      final messageData = data['message'];

      if (tempId == null || messageData == null || messageData is! Map) {
        log(
          'Error: Missing tempId or message data in messageSent confirmation.',
        );
        return;
      }

      final confirmedMessage = ChatMessage.fromJson(
        Map<String, dynamic>.from(messageData),
      );

      _updateTempMessageInMapAndActiveList(tempId, confirmedMessage);

      _updateConversationList(
        confirmedMessage.conversationId,
        confirmedMessage,
      );

      _safelyNotifyListeners();
    } catch (e, stackTrace) {
      log('Error handling message sent confirmation: $e\n$stackTrace');
    }
  }

  void _handleSendMessageError(dynamic data) {
    log('Received sendMessageError: $data');
    if (data == null || data is! Map) {
      log('Error: Invalid sendMessageError data received.');
      return;
    }
    try {
      final tempId = data['tempId']?.toString();
      final errorMsg = data['error']?.toString() ?? 'Unknown send error';

      if (tempId == null) {
        log('Error: Missing tempId in sendMessageError data.');
        return;
      }

      log('Message failed to send (tempId: $tempId): $errorMsg');

      _updateMessageStatusByTempId(tempId, MessageStatus.failed);

      _safelyNotifyListeners();
    } catch (e, stackTrace) {
      log('Error handling send message error: $e\n$stackTrace');
    }
  }

  void _handleMessagesRead(dynamic data) {
    log('Received messagesRead event: $data');
    if (data == null || data is! Map) {
      log('Error: Invalid messagesRead data received.');
      return;
    }
    try {
      final conversationId = data['conversationId']?.toString();
      final readerId = data['readerId']?.toString();

      if (conversationId == null || readerId == null) {
        log('Error: Missing conversationId or readerId in messagesRead data.');
        return;
      }

      if (readerId != _currentUserId) {
        bool changed = false;
        if (_messagesMap.containsKey(conversationId)) {
          final messagesInConv = _messagesMap[conversationId]!;
          for (int i = 0; i < messagesInConv.length; i++) {
            if (messagesInConv[i].senderId == _currentUserId &&
                messagesInConv[i].receiverId == readerId &&
                messagesInConv[i].status != MessageStatus.read) {
              messagesInConv[i].status = MessageStatus.read;
              changed = true;
            }
          }
        }

        if (conversationId == _activeConversationId) {
          for (int i = 0; i < _activeConversationMessages.length; i++) {
            if (_activeConversationMessages[i].senderId == _currentUserId &&
                _activeConversationMessages[i].receiverId == readerId &&
                _activeConversationMessages[i].status != MessageStatus.read) {
              _activeConversationMessages[i].status = MessageStatus.read;
            }
          }
        }

        if (changed) {
          _safelyNotifyListeners();
        }
      }
    } catch (e, stackTrace) {
      log('Error handling messages read: $e\n$stackTrace');
    }
  }

  void _handleTyping(dynamic data) {
    if (data == null || data is! Map) return;
    try {
      final conversationId = data['conversationId']?.toString();
      final senderId = data['senderId']?.toString();

      if (conversationId == _activeConversationId &&
          senderId != null &&
          senderId != _currentUserId) {
        _typingUsers[senderId] = true;
        _safelyNotifyListeners();

        _typingTimers[senderId]?.cancel();
        _typingTimers[senderId] = Timer(const Duration(seconds: 3), () {
          if (_typingUsers.remove(senderId) == true) {
            _safelyNotifyListeners();
          }
          _typingTimers.remove(senderId);
        });
      }
    } catch (e) {
      log('Error handling typing: $e');
    }
  }

  final Map<String, Timer> _typingTimers = {};

  void _handleStopTyping(dynamic data) {
    if (data == null || data is! Map) return;
    try {
      final conversationId = data['conversationId']?.toString();
      final senderId = data['senderId']?.toString();

      if (conversationId == _activeConversationId && senderId != null) {
        _typingTimers[senderId]?.cancel();
        _typingTimers.remove(senderId);
        if (_typingUsers.remove(senderId) == true) {
          _safelyNotifyListeners();
        }
      }
    } catch (e) {
      log('Error handling stop typing: $e');
    }
  }

  void _handleConversationUpdate(dynamic data) {
    log('Received conversationUpdate: $data');
    if (data == null || data is! Map) return;
    try {
      final conversationData = data['conversation'];
      if (conversationData != null && conversationData is Map) {
        final updatedConv = Conversation.fromJson(
          Map<String, dynamic>.from(conversationData),
        );
        final index = _conversations.indexWhere((c) => c.id == updatedConv.id);
        if (index != -1) {
          _conversations[index] = updatedConv;
          _safelyNotifyListeners();
        } else {
          _conversations.insert(0, updatedConv);
          _safelyNotifyListeners();
        }
      }
    } catch (e, stackTrace) {
      log('Error handling conversation update: $e\n$stackTrace');
    }
  }

  void _safelyNotifyListeners() {
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  void _addMessageToMap(ChatMessage message) {
    final conversationId = message.conversationId;
    if (!_messagesMap.containsKey(conversationId)) {
      _messagesMap[conversationId] = [];
    }

    final messageList = _messagesMap[conversationId]!;

    final existingIndex = messageList.indexWhere(
      (m) =>
          (message.id != null && m.id == message.id) ||
          (message.tempId != null && m.tempId == message.tempId),
    );

    if (existingIndex == -1) {
      messageList.insert(0, message);
    } else {
      final existingMessage = messageList[existingIndex];
      messageList[existingIndex] = ChatMessage(
        id: message.id ?? existingMessage.id,
        tempId:
            message.id != null
                ? null
                : (message.tempId ?? existingMessage.tempId),
        conversationId: message.conversationId,
        senderId: message.senderId,
        receiverId: message.receiverId,
        text: message.text,
        type: message.type,
        mediaUrl: message.mediaUrl,
        timestamp: existingMessage.timestamp,
        status: message.status,
      );
      log("Updated existing message in map: ${message.id ?? message.tempId}");
    }
  }

  void _updateTempMessageInMapAndActiveList(
    String tempId,
    ChatMessage confirmedMessage,
  ) {
    bool changed = false;
    final conversationId = confirmedMessage.conversationId;

    if (_messagesMap.containsKey(conversationId)) {
      final messageList = _messagesMap[conversationId]!;
      final index = messageList.indexWhere((m) => m.tempId == tempId);
      if (index != -1) {
        messageList[index] = confirmedMessage;
        changed = true;
        log(
          "Updated message in map (tempId: $tempId -> id: ${confirmedMessage.id})",
        );
      }
    }

    if (conversationId == _activeConversationId) {
      final index = _activeConversationMessages.indexWhere(
        (m) => m.tempId == tempId,
      );
      if (index != -1) {
        _activeConversationMessages[index] = confirmedMessage;
        changed = true;
        log(
          "Updated message in active list (tempId: $tempId -> id: ${confirmedMessage.id})",
        );
      }
    }
  }

  void _updateMessageStatusByTempId(String tempId, MessageStatus status) {
    bool changed = false;
    String? targetConversationId;

    for (var entry in _messagesMap.entries) {
      final messageList = entry.value;
      final index = messageList.indexWhere((m) => m.tempId == tempId);
      if (index != -1) {
        if (messageList[index].status != status) {
          messageList[index].status = status;
          targetConversationId = entry.key;
          changed = true;
          log(
            "Updated message status in map (tempId: $tempId, status: $status)",
          );
        }
        break;
      }
    }

    if (targetConversationId != null &&
        targetConversationId == _activeConversationId) {
      final index = _activeConversationMessages.indexWhere(
        (m) => m.tempId == tempId,
      );
      if (index != -1 && _activeConversationMessages[index].status != status) {
        _activeConversationMessages[index].status = status;
        log(
          "Updated message status in active list (tempId: $tempId, status: $status)",
        );
      }
    }
  }

  void _updateConversationList(String conversationId, ChatMessage message) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final oldConv = _conversations[index];
      if (oldConv.lastMessage == null ||
          message.timestamp.isAfter(oldConv.lastMessage!.timestamp)) {
        _conversations[index] = Conversation(
          id: oldConv.id,
          participants: oldConv.participants,
          lastMessage: message,
          updatedAt: message.timestamp,
        );
        _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      }
    } else {
      log(
        "Received message for unknown conversation $conversationId. Fetching conversations might be needed.",
      );
    }
  }

  void _attemptReconnection() {
    if (_connectionStatus == ConnectionStatus.connected ||
        _connectionStatus == ConnectionStatus.connecting ||
        _retryAttempts >= _maxRetryAttempts) {
      if (_retryAttempts >= _maxRetryAttempts) {
        log("Max reconnection attempts reached.");
        _error = 'Connection failed after multiple attempts.';
        _safelyNotifyListeners();
      }
      return;
    }

    _reconnectionTimer?.cancel();

    final delay = Duration(seconds: 1 << _retryAttempts);
    log(
      'Attempting reconnection in ${delay.inSeconds} seconds (attempt ${_retryAttempts + 1})...',
    );

    _reconnectionTimer = Timer(delay, () {
      if (_connectionStatus != ConnectionStatus.connected) {
        log('Executing reconnection attempt ${_retryAttempts + 1}');
        _socket?.connect();
        _retryAttempts++;
      } else {
        log("Reconnection attempt cancelled, already connected.");
        _retryAttempts = 0;
      }
    });
  }

  void _retryPendingMessages() {
    if (!isConnected || _pendingMessages.isEmpty) return;

    log('Retrying ${_pendingMessages.length} pending messages...');

    final messagesToRetry = List<ChatMessage>.from(_pendingMessages);
    _pendingMessages.clear();

    for (final message in messagesToRetry) {
      if (message.tempId != null && message.receiverId.isNotEmpty) {
        log('Retrying message: ${message.tempId} to ${message.receiverId}');
        _socket?.emit('sendMessage', {
          'receiverId': message.receiverId,
          'text': message.text,
          'type': message.type,
          'mediaUrl': message.mediaUrl,
          'tempId': message.tempId,
        });
        _updateMessageStatusByTempId(message.tempId!, MessageStatus.sending);
      } else {
        log('Skipping retry for invalid pending message: ${message.toJson()}');
      }
    }
    if (messagesToRetry.isNotEmpty) {
      _safelyNotifyListeners();
    }
  }

  void sendMessage(
    String receiverId,
    String text, {
    String type = 'text',
    String? mediaUrl,
  }) {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      _error = 'Cannot send message: User ID not set.';
      _safelyNotifyListeners();
      log(_error!);
      return;
    }

    if (_activeConversationId == null) {
      _error = 'Cannot send message: No active conversation set.';
      _safelyNotifyListeners();
      log(_error!);
      return;
    }

    final timestamp = DateTime.now();
    final tempId = 'temp_${_currentUserId}_${timestamp.millisecondsSinceEpoch}';

    final tempMessage = ChatMessage(
      tempId: tempId,
      conversationId: _activeConversationId!,
      senderId: _currentUserId!,
      receiverId: receiverId,
      text: text,
      type: type,
      mediaUrl: mediaUrl,
      timestamp: timestamp,
      status: MessageStatus.sending,
    );

    _addMessageToMap(tempMessage);
    if (tempMessage.conversationId == _activeConversationId) {
      _activeConversationMessages.insert(0, tempMessage);
    }
    _updateConversationList(tempMessage.conversationId, tempMessage);

    _safelyNotifyListeners();

    if (isConnected && _socket != null) {
      log('Emitting sendMessage event for tempId: $tempId');
      _socket?.emit('sendMessage', {
        'receiverId': receiverId,
        'text': text,
        'type': type,
        'mediaUrl': mediaUrl,
        'tempId': tempId,
      });
    } else {
      log('Socket not connected, adding message to pending queue');
      _pendingMessages.add(tempMessage);
      _updateMessageStatusByTempId(tempId, MessageStatus.failed);

      // Attempt to persist message via HTTP API as fallback
      _persistMessageViaAPI(tempMessage);
    }
  }

  // Add a new method to persist messages via API when socket is unavailable
  Future<void> _persistMessageViaAPI(ChatMessage message) async {
    try {
      final apiService = ApiService();
      final success = await apiService.sendMessage(
        conversationId: message.conversationId,
        receiverId: message.receiverId,
        text: message.text,
        type: message.type,
        mediaUrl: message.mediaUrl,
      );

      if (success) {
        _updateMessageStatusByTempId(message.tempId!, MessageStatus.sent);
        log('Message persisted via API successfully');
      } else {
        log('Failed to persist message via API');
      }
    } catch (e) {
      log('Error persisting message via API: $e');
    }
  }

  Future<void> fetchMessages(
    String conversationId, {
    bool forceRefresh = false,
  }) async {
    if (_isLoadingMessages && !forceRefresh) return;

    log("Fetching messages for conversation: $conversationId");
    _isLoadingMessages = true;
    _error = null;
    if (_activeConversationId == conversationId) {
      _safelyNotifyListeners();
    }

    try {
      // First try using the socket-based approach for real-time functionality
      if (isConnected && _socket != null) {
        // Existing code for socket-based fetching
        // ...
      } else {
        // Fallback to REST API if socket is not connected
        log("Socket not connected, fetching messages via HTTP API");
        await _fetchMessagesViaAPI(conversationId);
      }
    } catch (e, stackTrace) {
      log('Error fetching messages for $conversationId: $e\n$stackTrace');
      _error = 'Failed to load messages.';

      // Try fallback method if first method fails
      try {
        await _fetchMessagesViaAPI(conversationId);
      } catch (fallbackError) {
        log('Fallback message fetching also failed: $fallbackError');
      }
    } finally {
      _isLoadingMessages = false;
      if (_activeConversationId == conversationId) {
        _safelyNotifyListeners();
      }
    }
  }

  // Add a new method to fetch messages via REST API
  Future<void> _fetchMessagesViaAPI(String conversationId) async {
    try {
      final apiService = ApiService();
      final messages = await apiService.fetchConversationMessagesWithLogging(
        conversationId,
      );

      if (messages.isNotEmpty) {
        // Convert the API response to ChatMessage objects
        final chatMessages =
            messages
                .map(
                  (json) =>
                      ChatMessage.fromJson(Map<String, dynamic>.from(json)),
                )
                .toList();

        // Update the message map
        _messagesMap[conversationId] = chatMessages;

        // Update active conversation messages if this is the active conversation
        if (_activeConversationId == conversationId) {
          _activeConversationMessages = List.from(chatMessages);
          markAsRead(conversationId);
        }

        log(
          "Fetched and stored ${chatMessages.length} messages for $conversationId via API",
        );
      } else {
        log("No messages found for conversation $conversationId via API");
      }
    } catch (e) {
      log('Error fetching messages via API: $e');
      throw e; // Re-throw to handle in the calling method
    }
  }

  void setActiveChat(String conversationId, String otherUserId) {
    log("Setting active chat: $conversationId");
    if (_activeConversationId == conversationId) {
      log("Conversation $conversationId is already active.");
      return;
    }

    _typingUsers.clear();
    _activeConversationId = conversationId;

    if (_messagesMap.containsKey(conversationId)) {
      _activeConversationMessages = List.from(_messagesMap[conversationId]!);
      log(
        "Loaded ${_activeConversationMessages.length} messages from cache for $conversationId",
      );
      markAsRead(conversationId);
      _safelyNotifyListeners();
    } else {
      log("No messages in cache for $conversationId. Fetching...");
      _activeConversationMessages = [];
      _safelyNotifyListeners();
      fetchMessages(conversationId);
    }
  }

  void clearActiveChat() {
    log("Clearing active chat.");
    if (_activeConversationId != null) {
      _activeConversationId = null;
      _activeConversationMessages = [];
      _typingUsers.clear();
      _safelyNotifyListeners();
    }
  }

  void sendTypingEvent(String receiverId) {
    if (!isConnected || _activeConversationId == null || _currentUserId == null)
      return;
    _socket?.emit('typing', {
      'conversationId': _activeConversationId,
      'receiverId': receiverId,
      'senderId': _currentUserId,
    });
  }

  void sendStopTypingEvent(String receiverId) {
    if (!isConnected || _activeConversationId == null || _currentUserId == null)
      return;
    _socket?.emit('stopTyping', {
      'conversationId': _activeConversationId,
      'receiverId': receiverId,
      'senderId': _currentUserId,
    });
  }

  void markAsRead(String conversationId) {
    if (!isConnected || _currentUserId == null || conversationId.isEmpty)
      return;

    bool needsServerUpdate = false;
    bool uiChanged = false;

    final messagesInConv = _messagesMap[conversationId];
    if (messagesInConv != null) {
      for (var msg in messagesInConv) {
        if (msg.receiverId == _currentUserId &&
            msg.status != MessageStatus.read) {
          msg.status = MessageStatus.read;
          needsServerUpdate = true;
          uiChanged = true;
        }
      }
    }
    if (conversationId == _activeConversationId) {
      for (var msg in _activeConversationMessages) {
        if (msg.receiverId == _currentUserId &&
            msg.status != MessageStatus.read) {
          msg.status = MessageStatus.read;
        }
      }
    }

    if (needsServerUpdate) {
      log("Emitting markAsRead for conversation $conversationId");
      _socket?.emit('markAsRead', {
        'conversationId': conversationId,
        'readerId': _currentUserId,
      });
    }

    if (uiChanged) {
      _safelyNotifyListeners();
    }
  }

  Future<void> fetchConversations({bool forceRefresh = false}) async {
    if (_isLoadingConversations && !forceRefresh) return;

    log("Fetching conversations...");
    _isLoadingConversations = true;
    _error = null;
    _safelyNotifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception('Authentication token not found.');

      final response = await http
          .get(
            Uri.parse('$_socketUrl/api/conversations'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null &&
            data['success'] == true &&
            data['conversations'] is List) {
          final List<dynamic> conversationsJson = data['conversations'];
          _conversations =
              conversationsJson
                  .map(
                    (json) =>
                        Conversation.fromJson(Map<String, dynamic>.from(json)),
                  )
                  .toList();
          _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          log("Fetched ${_conversations.length} conversations.");
        } else {
          throw Exception(
            data['message'] ?? 'Failed to parse conversations response.',
          );
        }
      } else {
        throw Exception(
          'Failed to load conversations: ${response.statusCode} ${response.reasonPhrase}',
        );
      }
      _error = null;
    } catch (e, stackTrace) {
      log('Error fetching conversations: $e\n$stackTrace');
      _error = 'Failed to load conversations.';
    } finally {
      _isLoadingConversations = false;
      _safelyNotifyListeners();
    }
  }

  void clearUserSession() {
    log("Clearing user session data in ChatServiceProvider.");
    disconnect();
    _currentUserId = null;
    _activeConversationId = null;
    _messagesMap.clear();
    _activeConversationMessages.clear();
    _conversations.clear();
    _typingUsers.clear();
    _pendingMessages.clear();
    _error = null;
    _retryAttempts = 0;
    _reconnectionTimer?.cancel();
    _typingTimers.values.forEach((timer) => timer.cancel());
    _typingTimers.clear();
    _safelyNotifyListeners();
  }

  void setCurrentUserId(String userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      log("Current User ID manually set to: $userId");
      _safelyNotifyListeners();
    }
  }

  @override
  void dispose() {
    log('Disposing ChatServiceProvider.');
    disconnect(notify: false);
    _reconnectionTimer?.cancel();
    _typingTimers.values.forEach((timer) => timer.cancel());
    super.dispose();
  }
}
