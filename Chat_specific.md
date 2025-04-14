Okay, let's outline the detailed steps to implement the real-time messaging part in your Flutter app using the `socket_io_client` package, connecting to the Node.js backend we've designed.

This complements the Firebase setup (which handles *notifications* when the app is inactive). This Socket.IO implementation handles the *live message exchange* when the app is active.

**Phase 1: Installation & Basic Setup**

1.  **Add Dependency:**
    *   Open your `pubspec.yaml` file.
    *   Add the Socket.IO client package under `dependencies`:
        ```yaml
        dependencies:
          flutter:
            sdk: flutter
          # ... other dependencies (firebase_core, firebase_messaging, etc.) ...
          socket_io_client: ^2.0.3 # Use the latest compatible version
          provider: ^6.1.2        # Or your preferred state management solution
          shared_preferences: ^2.2.2 # Likely already have this for token storage
        ```
    *   Run `flutter pub get` in your terminal.

2.  **Configure Backend URL:**
    *   Store your backend's URL (e.g., `http://your-domain.com` or `http://10.0.2.2:5000` for Android emulator accessing localhost) in a configuration file or using environment variables (recommended for production). For simplicity here, we'll assume a constant.
    *   **Example (config file `lib/config.dart`):**
        ```dart
        class AppConfig {
          // Use wss://your-domain.com in production with HTTPS/WSS
          static const String socketUrl = 'http://10.0.2.2:5000'; // Android emulator localhost alias
          // static const String socketUrl = 'http://localhost:5000'; // iOS simulator localhost
          // static const String socketUrl = 'https://your-production-backend.com'; // Production
        }
        ```

**Phase 2: Create a Chat Service/Provider**

This service will manage the Socket.IO connection, state, and communication logic. Using `Provider` is a common approach.

1.  **Create `ChatServiceProvider`:**
    *   Create a new file (e.g., `lib/providers/chat_service_provider.dart`).
    *   Implement a `ChangeNotifier` to hold the state and logic.

    ```dart
    import 'dart:async';
    import 'dart:convert'; // For decoding JWT if needed (usually not)
    import 'package:flutter/foundation.dart'; // For ChangeNotifier
    import 'package:socket_io_client/socket_io_client.dart' as IO;
    import 'package:shared_preferences/shared_preferences.dart'; // To get token

    // --- Import your Message and Conversation models ---
    // import '../models/message.dart';
    // import '../models/conversation.dart';
    import '../config.dart'; // Import your config

    // --- Define Message Status Enum ---
    enum MessageStatus { sending, sent, delivered, read, failed }

    // --- Define your Message Class (Simplified Example) ---
    // TODO: Replace with your actual Message model structure
    class ChatMessage {
      final String? id; // Nullable for temporary messages
      final String? tempId; // Client-side temporary ID
      final String conversationId;
      final String senderId;
      final String receiverId;
      final String text;
      final String type; // 'text', 'image', etc.
      final String? mediaUrl;
      final DateTime timestamp;
      MessageStatus status; // Use the enum

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

      // Factory constructor to parse data from Socket.IO events
      factory ChatMessage.fromJson(Map<String, dynamic> json) {
         // Helper function to safely parse status string to enum
         MessageStatus parseStatus(String? statusStr) {
            switch (statusStr) {
                case 'sent': return MessageStatus.sent;
                case 'delivered': return MessageStatus.delivered;
                case 'read': return MessageStatus.read;
                default: return MessageStatus.sent; // Default if unknown/null
            }
         }

        return ChatMessage(
            id: json['_id'],
            conversationId: json['conversationId'],
            senderId: json['senderId'] ?? json['sender']?['_id'], // Handle different sender structures
            receiverId: json['receiverId'], // Ensure backend sends this
            text: json['text'] ?? '',
            type: json['type'] ?? 'text',
            mediaUrl: json['mediaUrl'],
            timestamp: DateTime.parse(json['timestamp']).toLocal(), // Parse and convert to local time
            status: parseStatus(json['status']),
        );
      }
    }


    // --- Chat Service Provider ---
    class ChatServiceProvider with ChangeNotifier {
      IO.Socket? _socket;
      bool _isConnected = false;
      String? _currentUserId; // Store logged-in user ID
      String? _activeConversationId; // Track the currently viewed chat

      // State for the active chat screen
      List<ChatMessage> _messages = [];
      bool _isLoadingMessages = false;
      final Map<String, bool> _typingUsers = {}; // Map<userId, isTyping> for current convo

      // State for conversation list (simplified - often fetched via API initially)
      // List<Conversation> _conversations = [];

      // Getters for UI
      bool get isConnected => _isConnected;
      List<ChatMessage> get messages => _messages;
      bool get isLoadingMessages => _isLoadingMessages;
      Map<String, bool> get typingUsers => _typingUsers; // Provides map {userId: true}

      // --- Connection Management ---
      Future<void> connect() async {
        if (_isConnected && _socket != null) {
          print('Already connected.');
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        _currentUserId = prefs.getString('userId'); // Assuming you store userId too

        if (token == null || _currentUserId == null) {
          print('Error: Cannot connect socket. Token or UserID missing.');
          return;
        }

        print('Connecting to Socket Server...');

        // Disconnect previous socket if exists
        disconnect();

        try {
          _socket = IO.io(AppConfig.socketUrl, <String, dynamic>{
            'transports': ['websocket'], // Force WebSocket transport
            'autoConnect': true, // Connect automatically
            'forceNew': true, // Ensure a new connection
            'auth': {
              'token': token // Send JWT token for authentication
            }
          });

          // --- Register Event Listeners ---
          _registerSocketListeners();

          // Note: autoConnect is true, connection attempt starts implicitly
          // _socket?.connect(); // Explicit connect if autoConnect is false

        } catch (e) {
          print("Error initializing socket: $e");
        }
      }

      void disconnect() {
        _socket?.dispose(); // Dispose of the socket instance
        _socket = null;
        _isConnected = false;
        _messages = []; // Clear messages on disconnect
        _typingUsers.clear();
        _activeConversationId = null;
        print('Socket disconnected.');
        notifyListeners(); // Notify UI about disconnection
      }

      // --- Event Listeners Registration ---
      void _registerSocketListeners() {
        _socket?.onConnect((_) {
          _isConnected = true;
          print('Socket connected: ${_socket?.id}');
          notifyListeners();
          // Optional: Emit event to confirm connection or fetch initial data
        });

        _socket?.onDisconnect((reason) {
          _isConnected = false;
          _typingUsers.clear(); // Clear typing status on disconnect
          print('Socket disconnected: $reason');
          notifyListeners();
          // Optional: Implement reconnection logic or UI feedback
        });

        _socket?.onConnectError((data) {
          _isConnected = false;
          print('Socket connection error: $data');
          notifyListeners();
           // Optional: Show error message to user
        });

        _socket?.onError((data) {
          print('Socket error: $data');
          // Handle specific errors if needed
        });

        // --- Custom Event Listeners ---
        _socket?.on('receiveMessage', _handleReceiveMessage);
        _socket?.on('messageSent', _handleMessageSentAck);
        _socket?.on('sendMessageError', _handleSendMessageError);
        _socket?.on('typing', _handleTyping);
        _socket?.on('stopTyping', _handleStopTyping);
        _socket?.on('messagesRead', _handleMessagesRead); // Listen for read receipts
      }

      // --- Event Handlers ---
      void _handleReceiveMessage(dynamic data) {
        try {
          print('Message received: $data');
          final message = ChatMessage.fromJson(data as Map<String, dynamic>);

          // If this message belongs to the currently active chat screen
          if (message.conversationId == _activeConversationId) {
            // Add message to the list
            _messages.insert(0, message); // Insert at beginning for typical chat UI order
            _typingUsers.remove(message.senderId); // Stop showing typing if they sent a message
            notifyListeners();
            // Mark as read since the user is viewing this chat
            markAsRead(message.conversationId);
          } else {
            // TODO: Handle message for inactive chat (e.g., update conversation list preview, show badge)
            print('Received message for inactive chat: ${message.conversationId}');
          }
        } catch (e) {
          print("Error handling received message: $e | Data: $data");
        }
      }

      void _handleMessageSentAck(dynamic data) {
         try {
          print('Message Sent ACK received: $data');
          final String? tempId = data['tempId'];
          final serverMessageJson = data['message'] as Map<String, dynamic>;
          final serverMessage = ChatMessage.fromJson(serverMessageJson);

          // Find the temporary message by tempId and update it
          final index = _messages.indexWhere((msg) => msg.tempId == tempId);
          if (index != -1) {
            _messages[index] = serverMessage; // Replace temp message with server version
            notifyListeners();
          } else {
             print("Warning: Received ACK for unknown tempId: $tempId");
          }
         } catch (e) {
            print("Error handling message ACK: $e | Data: $data");
         }
      }

       void _handleSendMessageError(dynamic data) {
          try {
            print('Send Message Error received: $data');
            final String? tempId = data['tempId'];
            final String errorMsg = data['error'] ?? 'Unknown sending error';

            // Find the temporary message by tempId and mark as failed
            final index = _messages.indexWhere((msg) => msg.tempId == tempId);
            if (index != -1) {
              _messages[index].status = MessageStatus.failed;
              // Optional: Store the error message on the message object?
              notifyListeners();
               // TODO: Show error feedback to user (e.g., Snackbar)
            } else {
               print("Warning: Received error for unknown tempId: $tempId");
            }
          } catch (e) {
              print("Error handling send error event: $e | Data: $data");
          }
       }

        void _handleTyping(dynamic data) {
          try {
            final String conversationId = data['conversationId'];
            final String senderId = data['senderId'];

            // Only update typing status if it's for the active conversation
            if (conversationId == _activeConversationId && senderId != _currentUserId) {
              print('$senderId is typing in $conversationId');
              _typingUsers[senderId] = true;
              notifyListeners();

              // Optional: Set a timer to automatically remove typing status
              Timer(const Duration(seconds: 3), () {
                if (_typingUsers.containsKey(senderId)) {
                   _typingUsers.remove(senderId);
                   notifyListeners();
                }
              });
            }
          } catch (e) {
             print("Error handling typing event: $e | Data: $data");
          }
        }

        void _handleStopTyping(dynamic data) {
          try {
            final String conversationId = data['conversationId'];
            final String senderId = data['senderId'];

            if (conversationId == _activeConversationId) {
               print('$senderId stopped typing in $conversationId');
              _typingUsers.remove(senderId);
              notifyListeners();
            }
          } catch (e) {
             print("Error handling stop typing event: $e | Data: $data");
          }
        }

       void _handleMessagesRead(dynamic data) {
          try {
            final String conversationId = data['conversationId'];
            final String readerId = data['readerId']; // The user who read the messages

            print('MessagesRead event received for convo $conversationId by $readerId');

            // If the event is for the currently active chat
            if (conversationId == _activeConversationId) {
              bool changed = false;
              // Update status of messages sent BY the current user that were read by the reader
              for (var msg in _messages) {
                if (msg.senderId == _currentUserId && msg.receiverId == readerId && msg.status != MessageStatus.read) {
                  msg.status = MessageStatus.read;
                  changed = true;
                }
              }
              if (changed) {
                notifyListeners();
              }
            } else {
               // Optional: Update conversation list indication if needed
            }
          } catch (e) {
             print("Error handling messagesRead event: $e | Data: $data");
          }
       }


      // --- Actions Triggered by UI ---

      // Call this when entering a chat screen
      void setActiveChat(String conversationId) {
        if (_activeConversationId == conversationId) return; // No change

        _activeConversationId = conversationId;
        _messages = []; // Clear previous messages
        _typingUsers.clear(); // Clear typing indicators
        _isLoadingMessages = true;
        notifyListeners();

        // TODO: Fetch initial messages for this conversation via API
        // Example: _fetchMessagesFromApi(conversationId);
        // For now, just clear and indicate loading
        _isLoadingMessages = false; // Remove this line after implementing API fetch
        notifyListeners();

        // Mark messages as read when entering the chat
        markAsRead(conversationId);
      }

      // Call this when leaving a chat screen
      void clearActiveChat() {
        _activeConversationId = null;
        _messages = [];
        _typingUsers.clear();
        notifyListeners();
      }

      // Send a message
      void sendMessage(String receiverId, String text, {String type = 'text', String? mediaUrl}) {
        if (_socket == null || !_isConnected || _currentUserId == null || _activeConversationId == null) {
          print('Cannot send message: Socket not connected or user/convo not set.');
          // TODO: Handle error, maybe show snackbar
          return;
        }

        final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
        final timestamp = DateTime.now();

        // Create temporary message object for immediate UI update
        final tempMessage = ChatMessage(
          tempId: tempId,
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
        _messages.insert(0, tempMessage);
        notifyListeners();

        // Prepare data for socket emission
        final messageData = {
          'receiverId': receiverId,
          'text': text,
          'type': type,
          'mediaUrl': mediaUrl,
          'tempId': tempId, // Include tempId for ACK matching
        };

        // Emit the message
        _socket?.emit('sendMessage', messageData);
      }

      // Emit typing event
      void sendTypingEvent(String receiverId) {
         if (_socket == null || !_isConnected || _activeConversationId == null) return;
         _socket?.emit('typing', {
           'conversationId': _activeConversationId,
           'receiverId': receiverId,
         });
      }

      // Emit stop typing event
      void sendStopTypingEvent(String receiverId) {
        if (_socket == null || !_isConnected || _activeConversationId == null) return;
        _socket?.emit('stopTyping', {
           'conversationId': _activeConversationId,
           'receiverId': receiverId,
         });
      }

      // Mark messages in the current conversation as read
      void markAsRead(String conversationId) {
         if (_socket == null || !_isConnected || _activeConversationId == null || conversationId != _activeConversationId) return;

         // Check if there are actually unread messages received by the current user before emitting
         bool hasUnread = _messages.any((msg) => msg.receiverId == _currentUserId && msg.status != MessageStatus.read);

         if (hasUnread) {
            print("Emitting markAsRead for conversation: $conversationId");
            _socket?.emit('markAsRead', {
              'conversationId': conversationId,
            });
            // Optimistically update UI immediately (optional, backend confirms via messagesRead event)
            // for (var msg in _messages) {
            //    if (msg.receiverId == _currentUserId && msg.status != MessageStatus.read) {
            //       msg.status = MessageStatus.read; // Or maybe MessageStatus.delivered?
            //    }
            // }
            // notifyListeners();
         }
      }

      // --- TODO: API Call Implementation ---
      // Future<void> _fetchMessagesFromApi(String conversationId) async {
      //   _isLoadingMessages = true;
      //   notifyListeners();
      //   try {
      //      // Use http or dio to call your backend GET /api/conversations/:conversationId/messages
      //      // Parse the response into List<ChatMessage>
      //      // final fetchedMessages = ...
      //      // _messages = fetchedMessages.reversed.toList(); // Assuming API returns oldest first
      //   } catch (e) {
      //       print("Error fetching messages from API: $e");
      //       // Handle error state
      //   } finally {
      //       _isLoadingMessages = false;
      //       notifyListeners();
      //   }
      // }

      // --- Cleanup ---
      @override
      void dispose() {
        print("Disposing ChatServiceProvider");
        disconnect(); // Ensure socket is disconnected when provider is disposed
        super.dispose();
      }
    }
    ```

**Phase 3: Integrate Provider and Connect**

1.  **Provide the Service:**
    *   In your `main.dart` (or above the part of your widget tree that needs chat access), wrap your `MyApp` (or relevant widget) with `ChangeNotifierProvider`.

    ```dart
    // main.dart
    import 'package:provider/provider.dart';
    import 'providers/chat_service_provider.dart'; // Import the provider

    void main() async {
      // ... (existing setup: WidgetsBinding, Firebase init, local notifications) ...

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      runApp(
        ChangeNotifierProvider(
          create: (_) => ChatServiceProvider(), // Create instance of provider
          child: MyApp(isLoggedIn: token != null),
        ),
      );
    }
    ```

2.  **Connect on Login:**
    *   After a user successfully logs in and you have their JWT token and user ID:
        *   Store the token and user ID in `SharedPreferences`.
        *   Get an instance of your `ChatServiceProvider` using `context.read<ChatServiceProvider>()`.
        *   Call the `connect()` method.

    ```dart
    // Example within your LoginScreen logic after successful login
    void handleSuccessfulLogin(BuildContext context, String token, String userId) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('userId', userId); // Store user ID

        // Connect Socket.IO
        // Use context.read inside methods, context.watch in build methods
        Provider.of<ChatServiceProvider>(context, listen: false).connect();

        // Navigate to the main app screen (e.g., NewsFeedScreen or a Home Screen)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const NewsFeedScreen()), // Or your main screen
        );
    }
    ```

3.  **Disconnect on Logout:**
    *   When the user logs out:
        *   Clear the token/userId from `SharedPreferences`.
        *   Call `disconnect()` on the provider.

    ```dart
    // Example logout function
    void handleLogout(BuildContext context) async {
        // Disconnect Socket.IO
        Provider.of<ChatServiceProvider>(context, listen: false).disconnect();

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        await prefs.remove('userId');

        // Navigate back to LoginScreen
        Navigator.pushAndRemoveUntil(
           context,
           MaterialPageRoute(builder: (context) => const LoginScreen()),
           (Route<dynamic> route) => false, // Remove all previous routes
        );
    }
    ```

**Phase 4: Build the Chat UI**

1.  **Conversation List Screen (Conceptual):**
    *   Fetch conversations via an API call (using `http`, `dio`).
    *   Use `Consumer<ChatServiceProvider>` or `context.watch<ChatServiceProvider>()` in the `build` method to listen for potential updates pushed via socket (like last message changes - requires backend to emit updates on new messages).
    *   Display the list. On tap, navigate to `ChatScreen`.

2.  **Chat Screen (`ChatScreen.dart` - Conceptual):**
    *   Requires `conversationId` and `receiverId` passed as arguments.
    *   **`initState`:**
        *   Get the provider: `final chatProvider = context.read<ChatServiceProvider>();`
        *   Tell the provider this chat is active: `chatProvider.setActiveChat(widget.conversationId);` (This should ideally trigger fetching initial messages via API).
    *   **`dispose`:**
        *   Tell the provider the chat is no longer active: `context.read<ChatServiceProvider>().clearActiveChat();`
    *   **`build` Method:**
        *   Use `Consumer<ChatServiceProvider>` or `context.watch<ChatServiceProvider>()` to get access to `messages`, `isConnected`, `isLoadingMessages`, `typingUsers`.
        *   Display messages in a `ListView.builder` (often reversed).
        *   Show loading indicator based on `isLoadingMessages`.
        *   Show connection status.
        *   Implement the message input `TextField` and send `IconButton`.
            *   On text change, potentially emit `typing` event (use debouncing).
            *   On send button press, call `chatProvider.sendMessage(widget.receiverId, _textController.text);`.
        *   Display typing indicators based on `typingUsers`.
        *   Display message status (sending, sent, read) based on `ChatMessage.status`.
        *   Call `chatProvider.markAsRead(widget.conversationId)` when the user views the latest messages (e.g., using scroll listeners or visibility detectors).

**Example Snippet for ChatScreen Build:**

```dart
// Inside ChatScreen build method
Consumer<ChatServiceProvider>(
  builder: (context, chatProvider, child) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chat with ${widget.receiverName}"), // Pass receiver name too
        // Display connection status or typing indicator here
        subtitle: chatProvider.typingUsers.isNotEmpty
          ? Text("${chatProvider.typingUsers.keys.first} is typing...") // Simplified
          : chatProvider.isConnected
              ? const Text("Connected", style: TextStyle(color: Colors.green))
              : const Text("Disconnected", style: TextStyle(color: Colors.red)),
      ),
      body: Column(
        children: [
          Expanded(
            child: chatProvider.isLoadingMessages
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    reverse: true, // Show latest messages at the bottom
                    itemCount: chatProvider.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatProvider.messages[index];
                      final isMe = message.senderId == chatProvider._currentUserId; // Check if message is sent by current user
                      // Build your Message Bubble widget here
                      return MessageBubble(message: message, isMe: isMe);
                    },
                  ),
          ),
          // Input area
          _buildMessageInput(context, chatProvider),
        ],
      ),
    );
  },
)

// Helper for input area
Widget _buildMessageInput(BuildContext context, ChatServiceProvider chatProvider) {
  final _textController = TextEditingController(); // Manage controller state properly

  return Container(
    padding: const EdgeInsets.all(8.0),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            decoration: const InputDecoration(hintText: 'Enter message...'),
            // TODO: Add onChanged for typing indicators
            onChanged: (text) {
               if (text.isNotEmpty) {
                  chatProvider.sendTypingEvent(widget.receiverId);
               } else {
                  chatProvider.sendStopTypingEvent(widget.receiverId);
               }
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.send),
          onPressed: () {
            if (_textController.text.trim().isNotEmpty) {
              chatProvider.sendMessage(widget.receiverId, _textController.text.trim());
              _textController.clear();
              chatProvider.sendStopTypingEvent(widget.receiverId); // Stop typing after send
            }
          },
        ),
      ],
    ),
  );
}

// Placeholder MessageBubble widget
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  const MessageBubble({Key? key, required this.message, required this.isMe}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Basic bubble styling - implement your own design
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
         margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
         padding: const EdgeInsets.all(12),
         decoration: BoxDecoration(
           color: isMe ? Colors.blue[300] : Colors.grey[300],
           borderRadius: BorderRadius.circular(12),
         ),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.end,
          children: [
             Text(message.text),
             const SizedBox(height: 4),
             Row( // For timestamp and status
               mainAxisSize: MainAxisSize.min,
               children: [
                  Text(
                    '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2,'0')}',
                     style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                  ),
                  if (isMe) ...[ // Show status only for messages sent by 'me'
                      const SizedBox(width: 4),
                      _buildStatusIcon(message.status),
                  ]
               ],
             )
          ],
        ),
      ),
    );
  }

   Widget _buildStatusIcon(MessageStatus status) {
      IconData iconData;
      Color color = Colors.grey; // Default
      switch (status) {
         case MessageStatus.sending:
            iconData = Icons.access_time; // Clock icon
            break;
         case MessageStatus.sent:
            iconData = Icons.done; // Single check
            break;
         case MessageStatus.delivered: // You might not implement 'delivered' status easily without ACKs
             iconData = Icons.done_all; // Double check
             break;
         case MessageStatus.read:
             iconData = Icons.done_all; // Double check, blue
             color = Colors.lightBlueAccent;
             break;
         case MessageStatus.failed:
             iconData = Icons.error_outline; // Error icon
             color = Colors.red;
             break;
      }
      return Icon(iconData, size: 12, color: color);
   }
}


```

This provides a comprehensive structure for integrating Socket.IO for real-time chat features in your Flutter app, working alongside the Firebase setup for notifications. Remember to replace placeholder models and implement proper API fetching and error handling for a production-ready solution.