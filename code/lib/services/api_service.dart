// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';
import 'package:logger/logger.dart';
import '../models/article.dart'; // Import the Article model
import 'package:firebase_messaging/firebase_messaging.dart'; // Add this import
import 'package:flutter/foundation.dart'; // For debugPrint

class ApiService {
  final String baseUrl = 'http://10.0.2.2:5000';
  final String widgetId = "35637a656b6e313137373339";
  final String authToken = "444836TBOiBsWxra0H67e6305fP1";
  final Logger logger = Logger();
  ApiService() {
    OTPWidget.initializeWidget(widgetId, authToken);
    initializeFCM(); // Add this line to initialize FCM when the service is created
  }

  Future<bool?> checkUserExists(String phoneNumber) async {
    final String formattedPhoneNo = "+91$phoneNumber";
    final url = Uri.parse("$baseUrl/api/check-user");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone_no": formattedPhoneNo}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData["success"];
      } else if (response.statusCode == 404) {
        return false;
      } else {
        throw Exception("Failed to check user existence");
      }
    } catch (error) {
      return null;
    }
  }

  Future<String?> sendOTP(String phoneNumber) async {
    try {
      if (phoneNumber.startsWith("+91")) {
        phoneNumber = phoneNumber.replaceFirst("+91", "");
      }
      final data = {"identifier": "91$phoneNumber"};
      final response = await OTPWidget.sendOTP(data);
      if (response != null && response["type"] == "success") {
        return response["message"];
      } else {
        return null;
      }
    } catch (error) {
      return null;
    }
  }

  Future<bool> verifyOTP(String reqId, String otp) async {
    try {
      final data = {"reqId": reqId, "otp": otp};

      final response = await OTPWidget.verifyOTP(data);

      return response != null && response["type"] == "success";
    } catch (error) {
      return false;
    }
  }

  Future<bool> login(String phoneNo) async {
    final String formattedPhoneNo = "+91$phoneNo";
    final response = await http.post(
      Uri.parse('$baseUrl/api/users/login'),
      body: json.encode({'phone_no': formattedPhoneNo}),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await saveToken(data['token']);

      // Extract and save userId from the response
      if (data['userId'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', data['userId']);
      }

      // Send FCM token to backend now that we're authenticated
      await _getAndSendFCMToken(data['userId'] ?? '');

      return true;
    } else {
      throw Exception(json.decode(response.body)['message']);
    }
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<String?> getSellerId() async {
    String? token = await getToken();
    if (token != null) {
      try {
        Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
        return decodedToken['id'];
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  Future<String?> getUserPhoneNumber() async {
    String? token = await getToken();
    if (token == null) throw Exception('User not logged in');

    String? sellerId = await getSellerId();
    if (sellerId == null) throw Exception('Failed to extract seller ID');
    final url = Uri.parse("$baseUrl/api/users/$sellerId/phone");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData["phone_no"];
      } else {
        throw Exception("Failed to fetch phone number");
      }
    } catch (error) {
      return null;
    }
  }

  Future<void> createUser({
    required String fullName,
    required String phoneNumber,
    required String pinCode,
    required String villageName,
    required String district,
    List<String>? topics,
  }) async {
    final String formattedPhoneNo = '+91$phoneNumber';
    final body = {
      'full_name': fullName,
      'phone_no': formattedPhoneNo,
      'pincode': pinCode,
      'village_name': villageName,
      'district': district,
      'topic_of_interests': topics,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/api/users/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      await saveToken(data['token']);
    } else {
      final data = json.decode(response.body);
      throw Exception(data['message'] ?? 'Failed to create user');
    }
  }

  Future<bool> createProduct({
    required String name,
    required String description,
    required double price,
    required int quantity,
    required String category,
    required String condition,
    required DateTime availableFromDate,
    File? image,
  }) async {
    try {
      String? token = await getToken();
      if (token == null) throw Exception('User not logged in');

      String? sellerId = await getSellerId();
      if (sellerId == null) throw Exception('Failed to extract seller ID');

      String? base64Image;
      String? fileType;

      if (image != null) {
        List<int> imageBytes = await image.readAsBytes();
        base64Image = base64Encode(imageBytes);
        fileType = image.path.split('.').last;
      }

      final Map<String, dynamic> data = {
        "name": name,
        "description": description,
        "price": price,
        "quantity": quantity,
        "category": category,
        "condition": condition,
        "available_from_date": availableFromDate.toIso8601String(),
        "images":
            base64Image != null
                ? [
                  {"data": base64Image, "contentType": "image/$fileType"},
                ]
                : [],
        "seller_id": sellerId,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/products'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      String? token = await getToken();
      if (token == null) throw Exception('User not logged in');

      String? sellerId = await getSellerId(); // Get logged-in user ID
      if (sellerId == null) throw Exception('Failed to extract seller ID');

      final response = await http.get(
        Uri.parse('$baseUrl/api/products'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Filter out products belonging to the current user
        List<Map<String, dynamic>> allProducts =
            List<Map<String, dynamic>>.from(data['data']);
        List<Map<String, dynamic>> filteredProducts =
            allProducts
                .where((product) => product['seller_id'] != sellerId)
                .toList();

        return filteredProducts;
      } else {
        throw Exception(
          'Failed to fetch the products - ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Failed to fetch products - $e');
    }
  }

  Future<List<Map<String, dynamic>>> getProductsBySeller() async {
    try {
      String? token = await getToken(); // Get token
      if (token == null) throw Exception('User not logged in');
      String? sellerId = await getSellerId();

      final response = await http.get(
        Uri.parse('$baseUrl/api/products/$sellerId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception('Failed to fetch products');
      }
    } catch (e) {
      throw Exception('Failed to fetch products');
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      String? token = await getToken();
      if (token == null) throw Exception('User not logged in');

      final response = await http.delete(
        Uri.parse('$baseUrl/api/products/$productId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete product');
      }
    } catch (e) {
      throw Exception('Failed to delete product');
    }
  }

  Future<bool> updateProduct({
    required String productId,
    required String name,
    required String description,
    required double price,
    required int quantity,
    required String category,
    required String condition,
    required DateTime availableFromDate,
    // required List<Map<String, String>> images, // Updated to accept List<Map<String, String>>
  }) async {
    try {
      String? token = await getToken();
      if (token == null) throw Exception('User not logged in');

      String? sellerId = await getSellerId();
      if (sellerId == null) throw Exception('Failed to extract seller ID');

      final Map<String, dynamic> data = {
        "name": name,
        "description": description,
        "price": price,
        "quantity": quantity,
        "category": category,
        "condition": condition,
        "available_from_date": availableFromDate.toIso8601String(),
        // "images": images, // Directly assigning the encoded images list
        "seller_id": sellerId,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/api/products/$productId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        logger.i('Product updated successfully');
        return true;
      } else {
        logger.e('Failed to update product: ${response.body}');
        return false;
      }
    } catch (e) {
      logger.e('Error updating product: $e');
      return false;
    }
  }

  Future<List<Article>> getNewsArticles() async {
    try {
      String? token = await getToken();
      if (token == null) throw Exception('User not logged in');

      String combinedSearchQuery = await getCombinedSearchQuery();
      if (combinedSearchQuery.isEmpty) {
        logger.w("No search terms available. Returning an empty list.");
        return [];
      }

      logger.d('Combined search query___: $combinedSearchQuery');

      final response = await http.post(
        Uri.parse('$baseUrl/api/news/feed'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'query': combinedSearchQuery}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(
          response.body,
        ); // Decode to Map
        if (responseData['success'] == true) {
          final List<dynamic> articlesJson =
              responseData['data']; // Extract 'data'
          return articlesJson.map((json) => Article.fromJson(json)).toList();
        } else {
          throw Exception(
            'Failed: ${responseData['message']}',
          ); // Handle error message
        }
      } else {
        throw Exception(
          'Failed to fetch news data. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      logger.e('Error fetching news data for id : $e');
      throw Exception('Failed to fetch news data');
    }
  }

  Future<String> getCombinedSearchQuery() async {
    try {
      List<String> topics = await getTopicsOfInterest();
      String? pincode = await getPinCode();

      String combinedQuery = '';

      if (topics.isNotEmpty) {
        combinedQuery += topics.join(' '); // Join topics with spaces
      }

      logger.d('Combined search query: $combinedQuery');

      if (pincode != null && pincode.isNotEmpty) {
        if (combinedQuery.isNotEmpty) {
          combinedQuery += ' '; // Add space if topics exist
        }
        combinedQuery += pincode;
      }

      logger.d('Combined search query after adding pincode: $combinedQuery');

      return combinedQuery.trim(); // Trim any leading/trailing spaces
    } catch (e) {
      logger.e('Error creating combined search query: $e');
      return ''; // Return an empty string in case of an error
    }
  }

  // --- Dart Helper Functions ---

  Future<List<String>> getTopicsOfInterest() async {
    String sellerIdtemp = await getSellerId() ?? '0'; // Default to '0' if null
    try {
      String? token = await getToken(); // Get token
      if (token == null) throw Exception('User not logged in');
      String? sellerId =
          await getSellerId(); // Assuming sellerId is the user ID

      final response = await http.get(
        Uri.parse('$baseUrl/api/news/$sellerId/topics'), // Updated Endpoint
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('topics')) {
          // Checking if data is a map and contains the key
          return List<String>.from(data['topics']);
        } else {
          throw Exception(
            'Invalid response format: Expected a map with a "topics" key.',
          );
        }
      } else {
        throw Exception('Failed to fetch topics of interest');
      }
    } catch (e) {
      logger.e('Error fetching topics of interest for id $sellerIdtemp: $e');
      throw Exception('Failed to fetch topics of interest');
    }
  }

  Future<String?> getPinCode() async {
    try {
      String? token = await getToken();
      if (token == null) throw Exception('User not logged in');

      String? userId =
          await getSellerId(); // Using the existing getSellerId method to get user ID
      if (userId == null) throw Exception('Failed to extract user ID');

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/pincode/$userId'), // Updated Endpoint
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('pincode')) {
          return data['pincode'];
        } else {
          throw Exception('Pincode not found in user data');
        }
      } else {
        throw Exception('Failed to fetch user data');
      }
    } catch (e) {
      logger.e('Error fetching pincode: $e');
      throw Exception('Failed to fetch pincode: $e');
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      String? token = await getToken();
      if (token == null) throw Exception('User not logged in');

      String? sellerId = await getSellerId();
      if (sellerId == null) throw Exception('Failed to extract seller ID');

      final response = await http.get(
        Uri.parse('$baseUrl/api/profile/$sellerId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userData = data['data']; // ✅ Access inner object using map syntax

        if (userData == null) throw Exception('Empty response');

        return {
          'Name': userData['full_name'] ?? '',
          'Phone Number': userData['phone_no']?.replaceFirst('+91', '') ?? '',
          'Village Name': userData['village_name'] ?? '',
          'Pincode': userData['pincode'] ?? '',
          'District Name': userData['district'] ?? '',
          'Topic of Interests':
              (userData['topic_of_interests'] as List<dynamic>?)?.join(', ') ??
              '',
        };
      } else {
        throw Exception('Failed to fetch user details');
      }
    } catch (e) {
      logger.e('Error fetching user details: $e');
      throw Exception('Failed to fetch user details');
    }
  }

  Future<bool> updateUserProfile({
    required String fullName,
    required String phoneNo,
    required String pincode,
    required String villageName,
    required String district,
    required List<String> topicOfInterests,
  }) async {
    String? token = await getToken();
    if (token == null) throw Exception('User not logged in');
    final String formattedPhoneNo = '+91$phoneNo';
    String? userId = await getSellerId();
    if (userId == null) throw Exception('Failed to extract User ID');

    final response = await http.put(
      Uri.parse('$baseUrl/api/update/$userId'),
      body: json.encode({
        'full_name': fullName,
        'phone_no': formattedPhoneNo,
        'pincode': pincode,
        'village_name': villageName,
        'district': district,
        'topic_of_interests': topicOfInterests,
      }),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception(json.decode(response.body)['message']);
    }
  }

  Future<bool> send_question({
    required String name,
    required String constituency,
    required String question,
  }) async {
    logger.i("It came!");
    String? token = await getToken();
    if (token == null) throw Exception('User not logged in');
    // Send the query
    final response = await http.post(
      Uri.parse('$baseUrl/api/askquery'),
      body: json.encode({
        'name': name,
        'constituency': constituency,
        'question': question,
      }),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception(json.decode(response.body)['message']);
    }
  }

  Future<bool> updateNotificationPreference(
    String userId,
    bool allow, [
    String? fcmToken,
  ]) async {
    try {
      String? token = await getToken();
      if (token == null) throw Exception('User not logged in');

      final response = await http.put(
        Uri.parse('$baseUrl/api/users/$userId/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'allow_notifications': allow, 'fcmToken': fcmToken}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to update notification preferences');
      }
    } catch (e) {
      logger.e('Error updating notification preferences: $e');
      return false;
    }
  }

  Future<bool> updateFCMToken(String token) async {
    try {
      final authToken = await getToken();
      if (authToken == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/api/users/me/updateFCMToken'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'fcmToken': token}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        logger.e('Failed to update FCM token: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      logger.e('Error updating FCM token: $e');
      return false;
    }
  }

  // Request notification permissions
  Future<bool> requestNotificationPermission() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      String? userId = await getSellerId();
      if (userId == null) {
        logger.e('Failed to get user ID for notification permission');
        return false;
      }

      bool permissionGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized;

      if (permissionGranted) {
        logger.i('User granted notification permission');
        await _getAndSendFCMToken(userId);
      } else {
        logger.w('User declined or has not accepted notification permission');
      }

      // Update the user's preference in the database
      await updateNotificationPreference(userId, permissionGranted);

      return permissionGranted;
    } catch (e) {
      logger.e('Error requesting notification permission: $e');
      return false;
    }
  }

  // Get FCM token and send to backend
  Future<void> _getAndSendFCMToken(String userId) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      logger.i('FCM Token: $token');

      if (token != null && userId.isNotEmpty) {
        // Send token to backend
        bool updated = await updateFCMToken(token);
        if (updated) {
          logger.i('FCM token updated successfully for user $userId');
        } else {
          logger.e('Failed to update FCM token for user $userId');
        }

        // Also update in notification preferences
        await updateNotificationPreference(userId, true, token);
      } else {
        logger.w(
          'Cannot send FCM token: ${token == null ? "Token is null" : "User ID is empty"}',
        );
      }

      // Listen for token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        logger.i('FCM Token refreshed: $newToken');
        if (userId.isNotEmpty) {
          await updateFCMToken(newToken);
          await updateNotificationPreference(userId, true, newToken);
        } else {
          logger.w('Cannot update refreshed FCM token: User ID is empty');
        }
      });
    } catch (e) {
      logger.e('Error in _getAndSendFCMToken: $e');
    }
  }

  // Check if notification permission is already granted
  Future<bool> checkNotificationPermission() async {
    try {
      NotificationSettings settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      logger.e('Error checking notification permission: $e');
      return false;
    }
  }

  // Initialize FCM token handling - call this when app starts
  Future<void> initializeFCM() async {
    try {
      // Check if user is logged in
      bool isUserLoggedIn = await isLoggedIn();
      if (isUserLoggedIn) {
        String? userId = await getSellerId();
        if (userId != null) {
          logger.i('User already logged in, sending FCM token');
          await _getAndSendFCMToken(userId);
        } else {
          logger.w('User ID not available despite being logged in');
        }
      } else {
        logger.i('User not logged in, will send FCM token after login');
      }
    } catch (e) {
      logger.e('Error initializing FCM: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(
    String conversationId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      String? token = await getToken();
      if (token == null) throw Exception('User not logged in');

      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/conversations/$conversationId/messages?page=$page&limit=$limit',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['messages'] != null) {
          return List<Map<String, dynamic>>.from(data['messages']);
        } else {
          return [];
        }
      } else {
        logger.e('Failed to fetch messages: ${response.statusCode}');
        throw Exception('Failed to fetch messages');
      }
    } catch (e) {
      logger.e('Error fetching messages: $e');
      throw Exception('Error fetching messages');
    }
  }

  // Updated fetchConversationMessages method with better error handling
  Future<List<Map<String, dynamic>>> fetchConversationMessagesWithLogging(
    String conversationId,
  ) async {
    try {
      String? token = await getToken();
      if (token == null) throw Exception('User not logged in');

      // Ensure we have a valid user ID
      String? userId = await getSellerId();
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not available');
      }

      logger.d(
        'Fetching messages for conversation: $conversationId with userId: $userId',
      );

      final response = await http.get(
        Uri.parse('$baseUrl/api/conversations/$conversationId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['messages'] != null) {
          logger.i('Successfully fetched ${data['messages'].length} messages');
          return List<Map<String, dynamic>>.from(data['messages']);
        } else {
          logger.w('No messages found or invalid response format');
          return [];
        }
      } else {
        logger.e(
          'Failed to fetch messages: ${response.statusCode} ${response.body}',
        );
        throw Exception('Failed to fetch messages: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Error fetching conversation messages: $e');
      throw Exception('Error fetching conversation messages: $e');
    }
  }

  // Fetch messages for a specific conversation using direct API call
  Future<List<Map<String, dynamic>>> fetchConversationMessages(
    String conversationId,
  ) async {
    try {
      String? token = await getToken();
      if (token == null) throw Exception('User not logged in');

      // Ensure we have a valid user ID
      String? userId = await getSellerId();
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not available');
      }

      logger.d(
        'Fetching messages for conversation: $conversationId with userId: $userId',
      );

      final response = await http.get(
        Uri.parse('$baseUrl/api/conversations/$conversationId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['messages'] != null) {
          return List<Map<String, dynamic>>.from(data['messages']);
        } else {
          return [];
        }
      } else {
        logger.e(
          'Failed to fetch messages: ${response.statusCode} ${response.body}',
        );
        throw Exception('Failed to fetch messages: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Error fetching conversation messages: $e');
      throw Exception('Error fetching conversation messages');
    }
  }

  // Create a conversation with a seller when contacting from product page
  Future<Map<String, dynamic>> getOrCreateConversation(String sellerId) async {
    try {
      String? token = await getToken();
      if (token == null) throw Exception('User not logged in');

      String? currentUserId = await getSellerId();
      if (currentUserId == null)
        throw Exception('Failed to get current user ID');

      logger.d('Creating conversation between $currentUserId and $sellerId');

      final response = await http.post(
        Uri.parse('$baseUrl/api/conversations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'participantId': sellerId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        logger.e(
          'Failed to create conversation: ${response.statusCode} ${response.body}',
        );
        throw Exception('Failed to create conversation');
      }
    } catch (e) {
      logger.e('Error creating conversation: $e');
      throw Exception('Error creating conversation');
    }
  }

  // Updated sendMessage method with better error handling and logging
  Future<bool> sendMessage({
    required String conversationId,
    required String receiverId,
    required String text,
    String type = 'text',
    String? mediaUrl,
  }) async {
    try {
      String? token = await getToken();
      if (token == null) throw Exception('User not logged in');

      logger.d(
        'Sending message to $receiverId in conversation $conversationId',
      );

      final response = await http.post(
        Uri.parse('$baseUrl/api/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'conversationId': conversationId,
          'receiverId': receiverId,
          'text': text,
          'type': type,
          'mediaUrl': mediaUrl,
        }),
      );

      if (response.statusCode == 201) {
        logger.i('Message sent successfully via API');
        return true;
      } else {
        logger.e(
          'Failed to send message: ${response.statusCode} ${response.body}',
        );
        return false;
      }
    } catch (e) {
      logger.e('Error sending message: $e');
      return false;
    }
  }

  // Helper method to get the auth token
  Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(
      'token',
    ); // Changed from 'auth_token' to 'token'
    if (token == null) {
      throw Exception('Authentication token not found');
    }
    return token;
  }
}
