import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
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

    // Get and update FCM token
    await getAndSendFCMToken();

    // Configure message handlers
    _configureMessageHandlers();
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

    print('User permission status: ${settings.authorizationStatus}');
  }

  Future<void> getAndSendFCMToken() async {
    try {
      // Get the FCM token
      String? token = await _messaging.getToken();

      if (token != null) {
        print('FCM Token: $token');

        // Send to backend
        await _sendTokenToBackend(token);

        // Listen for token refreshes
        _messaging.onTokenRefresh.listen((newToken) async {
          print('FCM Token refreshed: $newToken');
          await _sendTokenToBackend(newToken);
        });
      }
    } catch (e) {
      print('Error getting/sending FCM token: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final authToken = prefs.getString('token');

      if (userId == null || authToken == null) {
        print('User ID or auth token not found, cannot update FCM token');
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
        print('FCM token updated successfully on backend');
      } else {
        print('Failed to update FCM token: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending FCM token to backend: $e');
    }
  }

  void _configureMessageHandlers() {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

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
      print('A message was opened from the background: ${message.data}');
      _handleNotificationTap(message.data);
    });

    // Check for initial message (app opened from terminated state)
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('App launched by clicking notification: ${message.data}');
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
