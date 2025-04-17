import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Changed from material.dart to foundation.dart initially, but Material needed for WidgetsBinding
import 'package:flutter/scheduler.dart'; // Added for SchedulerPhase
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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
          json['conversationId']?.toString() ??
          'unknown_conversation', // Provide default
      senderId: parsedSenderId,
      receiverId: parsedReceiverId,
      text: json['text']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      mediaUrl: json['mediaUrl']?.toString(),
      timestamp:
          DateTime.tryParse(json['timestamp'] ?? '')?.toLocal() ??
          DateTime.now(), // Safer parsing
      status: parseStatus(json['status']?.toString()),
    );
  }

  // Add toJson for potential caching or sending pending messages if needed
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
      'timestamp': timestamp.toUtc().toIso8601String(), // Store in UTC
      'status': status.name, // Store enum name as string
    };
  }
}

class Conversation {
  final String id;
  final List<dynamic> participants; // Consider creating a User model
  final ChatMessage? lastMessage;
  final DateTime updatedAt;
  // Add unread count if needed
  // int unreadCount = 0;

  Conversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['_id'],
      participants: List<dynamic>.from(
        json['participants'] ?? [],
      ), // Ensure it's a list
      lastMessage:
          json['lastMessage'] != null && json['lastMessage'] is Map
              ? ChatMessage.fromJson(
                Map<String, dynamic>.from(json['lastMessage']),
              )
              : null,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] ?? '')?.toLocal() ??
          DateTime.now(), // Safer parsing
    );
  }
}

// --- Chat Service Provider ---
class ChatServiceProvider with ChangeNotifier {
  IO.Socket? _socket;
  String? _currentUserId;
  String? _activeConversationId;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;

  // State
  final Map<String, List<ChatMessage>> _messagesMap = {};
  List<ChatMessage> _activeConversationMessages = [];
  List<Conversation> _conversations = [];
  bool _isLoadingMessages = false;
  bool _isLoadingConversations = false;
  String? _error;
  final Map<String, bool> _typingUsers = {}; // Map<senderId, isTyping>

  // Pending messages (consider persisting these)
  final List<ChatMessage> _pendingMessages = []; // Store ChatMessage objects
  Timer? _reconnectionTimer;
  int _retryAttempts = 0;
  static const int _maxRetryAttempts = 5;

  // Configuration
  // Use const for URL if it's truly constant
  static const String _socketUrl =
      'http://10.0.2.2:5000'; // Android emulator loopback
  // static const String _socketUrl = 'http://localhost:5000'; // iOS Simulator / Desktop
  // static const String _socketUrl = 'YOUR_DEPLOYED_BACKEND_URL'; // Deployed backend

  // Getters
  String get currentUserId => _currentUserId ?? '';
  bool get isConnected => _connectionStatus == ConnectionStatus.connected;
  ConnectionStatus get connectionStatus => _connectionStatus;
  List<ChatMessage> get activeMessages => _activeConversationMessages;
  List<Conversation> get conversations =>
      List.unmodifiable(_conversations); // Return unmodifiable list
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isLoadingConversations => _isLoadingConversations;
  String? get error => _error;
  Map<String, bool> get typingUsers =>
      Map.unmodifiable(_typingUsers); // Return unmodifiable map
  String? get activeConversationId => _activeConversationId;

  // Initialization and Connection
  Future<void> initialize() async {
    await loadCurrentUserId();
    // Optionally load pending messages from storage here
    if (_currentUserId != null) {
      connect();
    }
  }

  Future<void> loadCurrentUserId() async {
    if (_currentUserId != null && _currentUserId!.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId != null && userId.isNotEmpty) {
        _currentUserId = userId;
        log('Current User ID loaded: $_currentUserId');
        // Don't notify here, let initialize or connect handle it
      } else {
        log('No User ID found in SharedPreferences.');
        _error = 'User not logged in.'; // Set error if needed
        // No notifyListeners needed here, state isn't changing visually yet
      }
    } catch (e) {
      log('Error loading current user ID: $e');
      _error = 'Failed to load user data.';
      // No notifyListeners needed here
    }
  }

  Future<void> connect() async {
    if (_connectionStatus == ConnectionStatus.connected ||
        _connectionStatus == ConnectionStatus.connecting) {
      log('Already connected or connecting.');
      return;
    }

    // Ensure user ID is loaded
    if (_currentUserId == null) {
      await loadCurrentUserId();
      if (_currentUserId == null) {
        _error = 'Cannot connect: User ID not available.';
        _connectionStatus = ConnectionStatus.disconnected;
        log(_error!);
        _safelyNotifyListeners(); // Notify if state changed (error set)
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      _error = 'Cannot connect: Authentication token missing.';
      _connectionStatus = ConnectionStatus.disconnected;
      log(_error!);
      _safelyNotifyListeners(); // Notify if state changed
      return;
    }

    log('Attempting to connect to Socket Server...');
    _connectionStatus = ConnectionStatus.connecting;
    _error = null; // Clear previous errors
    _safelyNotifyListeners();

    // Clean up existing socket and timer before creating a new one
    disconnect(notify: false); // Disconnect silently

    try {
      _socket = IO.io(_socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false, // Connect manually after setting up listeners
        'forceNew': true, // Ensure a new connection
        'auth': {'token': token},
        // Add reconnection options if needed, though we handle manually
        // 'reconnection': false,
      });

      _registerSocketListeners();
      _socket?.connect(); // Manually initiate connection
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
    _socket?.dispose(); // Release resources
    _socket = null;
    _connectionStatus = ConnectionStatus.disconnected;
    // _isConnected is derived from _connectionStatus now
    _typingUsers.clear(); // Clear typing status on disconnect
    // Don't clear _activeConversationId here, user might still be viewing the screen

    if (notify) {
      _safelyNotifyListeners();
    }
    log('Socket disconnected.');
  }

  // Socket Event Listeners Registration
  void _registerSocketListeners() {
    _socket?.onConnect((_) {
      log('Socket connected: ${_socket?.id}');
      _connectionStatus = ConnectionStatus.connected;
      _error = null;
      _retryAttempts = 0; // Reset retry attempts on successful connection
      _reconnectionTimer?.cancel(); // Cancel any pending reconnection attempts
      _safelyNotifyListeners();
      _retryPendingMessages(); // Send any messages that failed while offline
      // Optionally re-fetch conversations or active chat messages if needed
      if (_activeConversationId != null) {
        fetchMessages(
          _activeConversationId!,
          forceRefresh: true,
        ); // Refresh active chat
      }
      fetchConversations(); // Refresh conversation list
    });

    _socket?.onDisconnect((reason) {
      log('Socket disconnected: $reason');
      _connectionStatus = ConnectionStatus.disconnected;
      _typingUsers.clear();
      _safelyNotifyListeners();
      // Attempt reconnection only if it wasn't a manual disconnect (e.g., logout)
      if (reason != 'io client disconnect') {
        _attemptReconnection();
      }
    });

    _socket?.onConnectError((data) {
      log('Socket connection error: $data');
      _connectionStatus = ConnectionStatus.disconnected;
      // Don't set _error here, let reconnect logic handle it
      _safelyNotifyListeners();
      _attemptReconnection(); // Attempt to reconnect on connection errors
    });

    _socket?.onError((data) {
      log('Socket error: $data');
      // Handle specific errors if needed, maybe update _error state
      // _error = 'A socket error occurred: $data';
      // _safelyNotifyListeners();
    });

    // Custom App Event Listeners
    _socket?.on('receiveMessage', _handleReceiveMessage);
    _socket?.on(
      'messageSent',
      _handleMessageSentConfirmation,
    ); // Renamed for clarity
    _socket?.on('sendMessageError', _handleSendMessageError);
    _socket?.on('messagesRead', _handleMessagesRead);
    _socket?.on('typing', _handleTyping);
    _socket?.on('stopTyping', _handleStopTyping);
    _socket?.on(
      'conversationUpdate',
      _handleConversationUpdate,
    ); // Example: For last message updates
  }

  // Socket Event Handlers
  void _handleReceiveMessage(dynamic data) {
    log('Received message data: $data');
    if (data == null || data is! Map) {
      log('Error: Invalid message data received.');
      return;
    }
    try {
      final message = ChatMessage.fromJson(Map<String, dynamic>.from(data));

      // Add message to the specific conversation's list in the map
      _addMessageToMap(message);

      // If it's for the currently active chat, update the active list
      if (message.conversationId == _activeConversationId) {
        // Avoid duplicates in active list too
        if (!_activeConversationMessages.any(
          (m) => m.id != null && m.id == message.id,
        )) {
          _activeConversationMessages.insert(0, message);
          // Mark as read immediately if received while chat is active
          if (message.senderId != _currentUserId) {
            markAsRead(message.conversationId);
          }
          // Clear typing indicator for the sender
          _typingUsers.remove(message.senderId);
        }
      } else {
        // TODO: Increment unread count for the conversation message.conversationId
        // You'll need to add unread counts to your Conversation model or track separately
      }

      // Update the conversation list (last message, timestamp)
      _updateConversationList(message.conversationId, message);

      _safelyNotifyListeners(); // Notify about the new message and potential conversation update
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

      // Update the temporary message with the confirmed one (with ID, final timestamp, status)
      _updateTempMessageInMapAndActiveList(tempId, confirmedMessage);

      // Update conversation list as well
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

      // Mark the specific message as failed using its tempId
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
      final readerId =
          data['readerId']?.toString(); // The user who read the messages

      if (conversationId == null || readerId == null) {
        log('Error: Missing conversationId or readerId in messagesRead data.');
        return;
      }

      // We only care if someone *else* read *our* messages.
      if (readerId != _currentUserId) {
        bool changed = false;
        // Update status in the main map
        if (_messagesMap.containsKey(conversationId)) {
          final messagesInConv = _messagesMap[conversationId]!;
          for (int i = 0; i < messagesInConv.length; i++) {
            // If message was sent by me and receiver was the reader, mark as read
            if (messagesInConv[i].senderId == _currentUserId &&
                messagesInConv[i].receiverId == readerId &&
                messagesInConv[i].status != MessageStatus.read) {
              messagesInConv[i].status = MessageStatus.read;
              changed = true;
            }
          }
        }

        // Update status in the active conversation list if it matches
        if (conversationId == _activeConversationId) {
          for (int i = 0; i < _activeConversationMessages.length; i++) {
            if (_activeConversationMessages[i].senderId == _currentUserId &&
                _activeConversationMessages[i].receiverId == readerId &&
                _activeConversationMessages[i].status != MessageStatus.read) {
              _activeConversationMessages[i].status = MessageStatus.read;
              // 'changed' should already be true if map was updated
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

        // Auto-clear typing after a delay (e.g., 3 seconds)
        // Use a Timer associated with the senderId to handle overlapping events
        _typingTimers[senderId]
            ?.cancel(); // Cancel previous timer for this user
        _typingTimers[senderId] = Timer(const Duration(seconds: 3), () {
          if (_typingUsers.remove(senderId) == true) {
            // Check if it was actually removed
            _safelyNotifyListeners();
          }
          _typingTimers.remove(senderId);
        });
      }
    } catch (e) {
      log('Error handling typing: $e');
    }
  }

  final Map<String, Timer> _typingTimers = {}; // Store timers for typing

  void _handleStopTyping(dynamic data) {
    if (data == null || data is! Map) return;
    try {
      final conversationId = data['conversationId']?.toString();
      final senderId = data['senderId']?.toString();

      if (conversationId == _activeConversationId && senderId != null) {
        _typingTimers[senderId]?.cancel(); // Cancel the auto-clear timer
        _typingTimers.remove(senderId);
        if (_typingUsers.remove(senderId) == true) {
          // Check if it was actually removed
          _safelyNotifyListeners();
        }
      }
    } catch (e) {
      log('Error handling stop typing: $e');
    }
  }

  // Example handler for generic conversation updates (e.g., last message)
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
          // Maybe add it if it's a new conversation for the user?
          _conversations.insert(0, updatedConv);
          _safelyNotifyListeners();
        }
      }
    } catch (e, stackTrace) {
      log('Error handling conversation update: $e\n$stackTrace');
    }
  }

  // --- Helper Methods ---

  // Safely notify listeners, potentially deferring if in a problematic state
  void _safelyNotifyListeners() {
    // Check if Flutter is building/rendering. This is a basic check.
    // Using addPostFrameCallback is safer for handlers responding to async events.
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      // We are likely in a build phase or similar. Defer the notification.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      // Not in a build phase, safe to notify immediately.
      notifyListeners();
    }
  }

  // Adds or updates a message in the _messagesMap
  void _addMessageToMap(ChatMessage message) {
    final conversationId = message.conversationId;
    if (!_messagesMap.containsKey(conversationId)) {
      _messagesMap[conversationId] = [];
    }

    final messageList = _messagesMap[conversationId]!;

    // Check if message with this ID or tempId already exists
    final existingIndex = messageList.indexWhere(
      (m) =>
          (message.id != null && m.id == message.id) ||
          (message.tempId != null && m.tempId == message.tempId),
    );

    if (existingIndex == -1) {
      // New message, insert at the beginning (latest first)
      messageList.insert(0, message);
    } else {
      // Message exists, update it (e.g., tempId replaced by ID, status update)
      // Important: Preserve original timestamp if only status/ID changes
      final existingMessage = messageList[existingIndex];
      messageList[existingIndex] = ChatMessage(
        id: message.id ?? existingMessage.id, // Prefer new ID
        tempId:
            message.id != null
                ? null
                : (message.tempId ??
                    existingMessage.tempId), // Clear tempId if real ID exists
        conversationId: message.conversationId,
        senderId: message.senderId,
        receiverId: message.receiverId,
        text: message.text,
        type: message.type,
        mediaUrl: message.mediaUrl,
        timestamp: existingMessage.timestamp, // Keep original timestamp usually
        status: message.status, // Update status
      );
      log("Updated existing message in map: ${message.id ?? message.tempId}");
    }

    // Optional: Limit messages per conversation in memory
    // if (messageList.length > 100) {
    //   messageList.removeRange(100, messageList.length);
    // }
  }

  // Updates a message identified by tempId with a confirmed message (having a real ID)
  void _updateTempMessageInMapAndActiveList(
    String tempId,
    ChatMessage confirmedMessage,
  ) {
    bool changed = false;
    final conversationId = confirmedMessage.conversationId;

    // Update in the main map
    if (_messagesMap.containsKey(conversationId)) {
      final messageList = _messagesMap[conversationId]!;
      final index = messageList.indexWhere((m) => m.tempId == tempId);
      if (index != -1) {
        // Replace the temporary message with the confirmed one
        messageList[index] = confirmedMessage;
        changed = true;
        log(
          "Updated message in map (tempId: $tempId -> id: ${confirmedMessage.id})",
        );
      }
    }

    // Update in the active conversation list if it matches
    if (conversationId == _activeConversationId) {
      final index = _activeConversationMessages.indexWhere(
        (m) => m.tempId == tempId,
      );
      if (index != -1) {
        _activeConversationMessages[index] = confirmedMessage;
        changed = true; // Change should already be true
        log(
          "Updated message in active list (tempId: $tempId -> id: ${confirmedMessage.id})",
        );
      }
    }

    // No separate notifyListeners here, handled by the calling event handler (_handleMessageSentConfirmation)
  }

  // Updates the status of a message identified by its temporary ID
  void _updateMessageStatusByTempId(String tempId, MessageStatus status) {
    bool changed = false;
    String? targetConversationId;

    // Find and update in the main map
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
        break; // Found it, no need to check other conversations
      }
    }

    // Find and update in the active list if applicable
    if (targetConversationId != null &&
        targetConversationId == _activeConversationId) {
      final index = _activeConversationMessages.indexWhere(
        (m) => m.tempId == tempId,
      );
      if (index != -1 && _activeConversationMessages[index].status != status) {
        _activeConversationMessages[index].status = status;
        // changed should already be true
        log(
          "Updated message status in active list (tempId: $tempId, status: $status)",
        );
      }
    }

    // No separate notifyListeners here, handled by the calling event handler (_handleSendMessageError)
  }

  // Updates the conversation list (last message, timestamp)
  void _updateConversationList(String conversationId, ChatMessage message) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      // Update existing conversation
      final oldConv = _conversations[index];
      // Only update if the new message is newer than the current last message
      if (oldConv.lastMessage == null ||
          message.timestamp.isAfter(oldConv.lastMessage!.timestamp)) {
        _conversations[index] = Conversation(
          id: oldConv.id,
          participants: oldConv.participants,
          lastMessage: message,
          updatedAt: message.timestamp, // Update conversation timestamp
        );
        // Sort conversations by updated time (most recent first)
        _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        // _safelyNotifyListeners(); // Notify is handled by the calling handler
      }
    } else {
      // If conversation not found, fetch it or handle as needed
      // This might indicate a new conversation starting
      log(
        "Received message for unknown conversation $conversationId. Fetching conversations might be needed.",
      );
      // Optionally trigger fetchConversations() here if required
    }
  }

  void _attemptReconnection() {
    // Don't attempt if already connected or connecting, or if max attempts reached
    if (_connectionStatus == ConnectionStatus.connected ||
        _connectionStatus == ConnectionStatus.connecting ||
        _retryAttempts >= _maxRetryAttempts) {
      if (_retryAttempts >= _maxRetryAttempts) {
        log("Max reconnection attempts reached.");
        _error = 'Connection failed after multiple attempts.';
        _safelyNotifyListeners(); // Show final error
      }
      return;
    }

    // Cancel previous timer if any
    _reconnectionTimer?.cancel();

    final delay = Duration(
      seconds: 1 << _retryAttempts,
    ); // Exponential backoff: 1, 2, 4, 8, 16
    log(
      'Attempting reconnection in ${delay.inSeconds} seconds (attempt ${_retryAttempts + 1})...',
    );

    _reconnectionTimer = Timer(delay, () {
      if (_connectionStatus != ConnectionStatus.connected) {
        // Check again before connecting
        log('Executing reconnection attempt ${_retryAttempts + 1}');
        _socket?.connect(); // Attempt to connect
        // Note: _retryAttempts is incremented *after* a failed attempt (in onConnectError/onDisconnect)
        _retryAttempts++; // Increment attempts *before* the connection attempt
      } else {
        log("Reconnection attempt cancelled, already connected.");
        _retryAttempts = 0; // Reset if connection was established meanwhile
      }
    });
  }

  // Retry sending messages that were added to _pendingMessages
  void _retryPendingMessages() {
    if (!isConnected || _pendingMessages.isEmpty) return;

    log('Retrying ${_pendingMessages.length} pending messages...');

    // Take ownership of pending messages to avoid race conditions
    final messagesToRetry = List<ChatMessage>.from(_pendingMessages);
    _pendingMessages.clear();

    for (final message in messagesToRetry) {
      // Re-validate necessary fields before sending
      if (message.tempId != null && message.receiverId.isNotEmpty) {
        log('Retrying message: ${message.tempId} to ${message.receiverId}');
        // Emit the message again
        _socket?.emit('sendMessage', {
          'receiverId': message.receiverId,
          'text': message.text,
          'type': message.type,
          'mediaUrl': message.mediaUrl,
          'tempId': message.tempId, // Use the original tempId
        });
        // Keep the message status as 'sending' or update UI if needed
        _updateMessageStatusByTempId(message.tempId!, MessageStatus.sending);
      } else {
        log('Skipping retry for invalid pending message: ${message.toJson()}');
      }
    }
    if (messagesToRetry.isNotEmpty) {
      _safelyNotifyListeners(); // Notify UI about status changes to 'sending'
    }
  }

  // --- Public Methods ---

  // Send a message
  void sendMessage(
    String receiverId,
    String text, {
    String type = 'text',
    String? mediaUrl,
    // conversationId is usually determined by the backend or setActiveChat
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
      // Or alternatively, you could find/create the conversation ID based on receiverId
      return;
    }

    final timestamp = DateTime.now();
    // Generate a unique temporary ID for client-side tracking
    final tempId = 'temp_${_currentUserId}_${timestamp.millisecondsSinceEpoch}';

    final tempMessage = ChatMessage(
      tempId: tempId,
      // Use the currently active conversation ID when sending
      conversationId: _activeConversationId!,
      senderId: _currentUserId!,
      receiverId: receiverId,
      text: text,
      type: type,
      mediaUrl: mediaUrl,
      timestamp: timestamp,
      status: MessageStatus.sending, // Initial status
    );

    // Add to UI immediately
    _addMessageToMap(tempMessage);
    // Add to active messages list
    if (tempMessage.conversationId == _activeConversationId) {
      _activeConversationMessages.insert(0, tempMessage);
    }
    // Update conversation list's last message optimistically
    _updateConversationList(tempMessage.conversationId, tempMessage);

    _safelyNotifyListeners(); // Update UI to show the "sending" message

    // Send via socket if connected
    if (isConnected && _socket != null) {
      log('Emitting sendMessage event for tempId: $tempId');
      _socket?.emit('sendMessage', {
        'receiverId': receiverId,
        'text': text,
        'type': type,
        'mediaUrl': mediaUrl,
        'tempId': tempId,
        // Send conversationId if your backend expects/uses it for routing
        // 'conversationId': _activeConversationId,
      });
    } else {
      // Not connected: Mark as failed and add to pending list
      log('Socket not connected. Adding message $tempId to pending queue.');
      _updateMessageStatusByTempId(tempId, MessageStatus.failed);
      _pendingMessages.add(tempMessage); // Add the full message object
      _safelyNotifyListeners(); // Update UI to show failed status
      _attemptReconnection(); // Try to reconnect if not already trying
    }
  }

  // Set the currently active chat screen
  void setActiveChat(
    String conversationId,
    String otherUserId /* Added otherUserId */,
  ) {
    log("Setting active chat: $conversationId");
    if (_activeConversationId == conversationId) {
      log("Conversation $conversationId is already active.");
      // Optionally force refresh if needed
      // fetchMessages(conversationId, forceRefresh: true);
      return;
    }

    // Clear previous typing indicators
    _typingUsers.clear();
    _activeConversationId = conversationId;

    // Load messages from map if available, otherwise fetch
    if (_messagesMap.containsKey(conversationId)) {
      _activeConversationMessages = List.from(_messagesMap[conversationId]!);
      log(
        "Loaded ${_activeConversationMessages.length} messages from cache for $conversationId",
      );
      // Mark as read right away if loaded from cache
      markAsRead(conversationId);
      _safelyNotifyListeners(); // Notify UI about the change
    } else {
      log("No messages in cache for $conversationId. Fetching...");
      _activeConversationMessages = []; // Clear old messages if any
      _safelyNotifyListeners(); // Show empty list initially
      fetchMessages(
        conversationId,
      ); // Fetch and this will notify upon completion
    }

    // TODO: Reset unread count for this conversationId
  }

  // Clear the active chat (e.g., when navigating away)
  void clearActiveChat() {
    log("Clearing active chat.");
    if (_activeConversationId != null) {
      _activeConversationId = null;
      _activeConversationMessages = [];
      _typingUsers.clear();
      _safelyNotifyListeners();
    }
  }

  // Send typing indicators
  void sendTypingEvent(String receiverId) {
    if (!isConnected || _activeConversationId == null || _currentUserId == null)
      return;
    // log('Sending typing event to $receiverId in $_activeConversationId');
    _socket?.emit('typing', {
      'conversationId': _activeConversationId,
      'receiverId': receiverId, // Backend needs to know who to notify
      'senderId': _currentUserId, // Backend needs to know who is typing
    });
  }

  void sendStopTypingEvent(String receiverId) {
    if (!isConnected || _activeConversationId == null || _currentUserId == null)
      return;
    // log('Sending stop typing event to $receiverId in $_activeConversationId');
    _socket?.emit('stopTyping', {
      'conversationId': _activeConversationId,
      'receiverId': receiverId,
      'senderId': _currentUserId,
    });
  }

  // Mark messages in a conversation as read by the current user
  void markAsRead(String conversationId) {
    if (!isConnected || _currentUserId == null || conversationId.isEmpty)
      return;

    bool needsServerUpdate = false;
    bool uiChanged = false;

    // Update locally first for immediate UI feedback
    final messagesInConv = _messagesMap[conversationId];
    if (messagesInConv != null) {
      for (var msg in messagesInConv) {
        // If message was received by me and is not already read
        if (msg.receiverId == _currentUserId &&
            msg.status != MessageStatus.read) {
          msg.status = MessageStatus.read;
          needsServerUpdate = true; // We need to tell the server we read these
          uiChanged = true;
        }
      }
    }
    // Also update active messages list if it's the current one
    if (conversationId == _activeConversationId) {
      for (var msg in _activeConversationMessages) {
        if (msg.receiverId == _currentUserId &&
            msg.status != MessageStatus.read) {
          msg.status = MessageStatus.read;
          // uiChanged should already be true if map was updated
        }
      }
    }

    if (needsServerUpdate) {
      log("Emitting markAsRead for conversation $conversationId");
      _socket?.emit('markAsRead', {
        'conversationId': conversationId,
        'readerId': _currentUserId, // Send who read the messages
      });
    }

    if (uiChanged) {
      _safelyNotifyListeners(); // Update UI to show messages as read
    } else {
      // log("No unread messages found locally to mark as read for $conversationId");
    }
  }

  // --- API Methods ---

  // Fetch messages for a specific conversation
  Future<void> fetchMessages(
    String conversationId, {
    bool forceRefresh = false,
  }) async {
    if (_isLoadingMessages && !forceRefresh)
      return; // Avoid concurrent fetches unless forced

    // If messages exist and not forcing refresh, maybe don't fetch?
    // Decide based on your app's logic (e.g., fetch if older than X minutes)
    // if (_messagesMap.containsKey(conversationId) && !forceRefresh) {
    //   log("Messages for $conversationId already in cache. Not fetching.");
    //   // Ensure active list is updated if needed (might happen if setActiveChat loads from cache)
    //   if (_activeConversationId == conversationId && _activeConversationMessages.isEmpty) {
    //     _activeConversationMessages = List.from(_messagesMap[conversationId]!);
    //      _safelyNotifyListeners();
    //   }
    //   return;
    // }

    log("Fetching messages for conversation: $conversationId");
    _isLoadingMessages = true;
    _error = null; // Clear previous errors
    // Notify loading state only if it's the active conversation
    if (_activeConversationId == conversationId) {
      _safelyNotifyListeners();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception('Authentication token not found.');

      final response = await http
          .get(
            Uri.parse(
              '$_socketUrl/api/conversations/$conversationId/messages',
            ), // Ensure API endpoint is correct
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15)); // Add timeout

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null &&
            data['success'] == true &&
            data['messages'] is List) {
          final List<dynamic> messagesJson = data['messages'];
          final messages =
              messagesJson
                  .map(
                    (json) =>
                        ChatMessage.fromJson(Map<String, dynamic>.from(json)),
                  )
                  .toList();

          // Update the map (replace existing messages for this conversation)
          _messagesMap[conversationId] = messages;
          log(
            "Fetched and stored ${messages.length} messages for $conversationId",
          );

          // Update active list ONLY if this is still the active conversation
          if (_activeConversationId == conversationId) {
            _activeConversationMessages = List.from(messages);
            // Mark fetched messages as read immediately after fetching if they are for the current user
            markAsRead(conversationId);
          }
        } else {
          throw Exception(
            data['message'] ?? 'Failed to parse messages response.',
          );
        }
      } else {
        throw Exception(
          'Failed to load messages: ${response.statusCode} ${response.reasonPhrase}',
        );
      }
      _error = null; // Clear error on success
    } catch (e, stackTrace) {
      log('Error fetching messages for $conversationId: $e\n$stackTrace');
      _error = 'Failed to load messages.';
      // Optionally clear messages on error? Or keep stale data?
      // _messagesMap.remove(conversationId);
      // if (_activeConversationId == conversationId) _activeConversationMessages = [];
    } finally {
      _isLoadingMessages = false;
      // Notify state change (data or error) only if it's the active conversation
      if (_activeConversationId == conversationId) {
        _safelyNotifyListeners();
      }
    }
  }

  // Fetch all conversations for the user
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
            Uri.parse(
              '$_socketUrl/api/conversations',
            ), // Ensure API endpoint is correct
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
          // Sort by last update time
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
      // Optionally clear conversations on error?
      // _conversations = [];
    } finally {
      _isLoadingConversations = false;
      _safelyNotifyListeners();
    }
  }

  // --- Utility / Other Public Methods ---

  // Call this on logout or when user context changes
  void clearUserSession() {
    log("Clearing user session data in ChatServiceProvider.");
    disconnect(); // Disconnect socket
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
    // Notify listeners to reflect the cleared state in UI
    _safelyNotifyListeners();
  }

  // Method to manually set user ID if not using SharedPreferences loading
  // Be careful with using this if `initialize` is also used.
  void setCurrentUserId(String userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      log("Current User ID manually set to: $userId");
      // Potentially trigger connect or fetch data if needed
      // connect();
      // fetchConversations();
      _safelyNotifyListeners();
    }
  }

  // --- Cleanup ---
  @override
  void dispose() {
    log('Disposing ChatServiceProvider.');
    disconnect(
      notify: false,
    ); // Disconnect without notifying listeners during disposal
    _reconnectionTimer?.cancel();
    _typingTimers.values.forEach((timer) => timer.cancel());
    super.dispose();
  }
}