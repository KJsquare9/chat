import 'dart:convert';
// import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Import for navigatorKey

class FirebaseMessagingService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final String _apiUrl = 'http://10.0.2.2:5000'; // Update with your server URL

  // Initialize Firebase Messaging
  Future<void> initialize() async {
    // Request permission
    await _requestPermission();

    // Initialize FCM but don't send token yet
    await _initializeFCM();

    // Configure message handlers
    _configureMessageHandlers();
  }

  Future<void> _initializeFCM() async {
    try {
      // Get the FCM token
      String? token = await _messaging.getToken();

      if (token != null) {
        debugPrint('FCM Token: $token');

        // Save token locally (we'll send it when user is authenticated)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcmToken', token);

        // Listen for token refreshes
        _messaging.onTokenRefresh.listen((newToken) async {
          debugPrint('FCM Token refreshed: $newToken');
          await prefs.setString('fcmToken', newToken);
          await _sendTokenToBackend(newToken);
        });
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  // This method can be called after user login is complete
  Future<void> getAndSendFCMToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('fcmToken');

      // If no token in prefs, request a new one
      if (token == null) {
        token = await _messaging.getToken();
        if (token != null) {
          await prefs.setString('fcmToken', token);
        }
      }

      if (token != null) {
        // Send to backend
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('Error sending FCM token: $e');
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('User permission status: ${settings.authorizationStatus}');
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final authToken = prefs.getString('token');

      if (userId == null || authToken == null) {
        debugPrint('User ID or auth token not found, cannot update FCM token');
        return;
      }

      final response = await http.put(
        Uri.parse('$_apiUrl/api/users/me/updateFCMToken'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'fcmToken': token}),
      );

      if (response.statusCode == 200) {
        debugPrint('FCM token updated successfully on backend');
      } else {
        debugPrint('Failed to update FCM token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error sending FCM token to backend: $e');
    }
  }

  void _configureMessageHandlers() {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      final notification = message.notification;
      final data = message.data;

      if (notification != null) {
        _showLocalNotification(
          notification.hashCode,
          notification.title ?? 'New Message',
          notification.body ?? 'You have a new message',
          jsonEncode(data),
        );
      }
    });

    // Handle message opens when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('A message was opened from the background: ${message.data}');
      _handleNotificationTap(message.data);
    });

    // Check for initial message (app opened from terminated state)
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('App launched by clicking notification: ${message.data}');
        _handleNotificationTap(message.data);
      }
    });
  }

  Future<void> _showLocalNotification(
    int id,
    String title,
    String body,
    String payload,
  ) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'new_messages_channel',
          'New Messages',
          channelDescription: 'Notifications for new chat messages',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    // Handle navigation based on notification data
    if (data.containsKey('conversationId') && data.containsKey('senderId')) {
      // Navigate to chat screen
      navigatorKey.currentState?.pushNamed(
        '/chat',
        arguments: {
          'conversationId': data['conversationId'],
          'userId': data['senderId'],
          'name': data['senderName'] ?? 'Chat',
        },
      );
    }
  }
}
