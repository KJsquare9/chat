import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';
import '../models/article.dart'; // Import the Article model

class ApiService {
  final String baseUrl = 'http://10.0.2.2:5000';
  final String widgetId = "35637a656b6e313137373339";
  final String authToken = "444836TBOiBsWxra0H67e6305fP1";
  ApiService() {
    OTPWidget.initializeWidget(widgetId, authToken);
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
        throw Exception('Failed to fetch products');
      }
    } catch (e) {
      throw Exception('Failed to fetch products');
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
        print('Product updated successfully');
        return true;
      } else {
        print('Failed to update product: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error updating product: $e');
      return false;
    }
  }

  Future<List<Article>> getNewsArticles() async {
    try {
      String? token = await getToken();
      if (token == null) throw Exception('User not logged in');

      String combinedSearchQuery = await getCombinedSearchQuery();
      if (combinedSearchQuery.isEmpty) {
        print("No search terms available. Returning an empty list.");
        return [];
      }

      print('Combined search query___: $combinedSearchQuery');

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
      print('Error fetching news data for id : $e');
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

      print('Combined search query: $combinedQuery'); // Debugging line

      if (pincode != null && pincode.isNotEmpty) {
        if (combinedQuery.isNotEmpty) {
          combinedQuery += ' '; // Add space if topics exist
        }
        combinedQuery += pincode;
      }

      print(
        'Combined search query after adding pincode: $combinedQuery',
      ); // Debugging line

      return combinedQuery.trim(); // Trim any leading/trailing spaces
    } catch (e) {
      print('Error creating combined search query: $e');
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
      print('Error fetching topics of interest for id $sellerIdtemp: $e');
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
      print('Error fetching pincode: $e');
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
      print('Error fetching user details: $e');
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
    print("It came!");
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
      final response = await http.put(
        Uri.parse('$baseUrl/users/$userId/notifications'),
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
      print('Error updating notification preferences: $e');
      return false;
    }
  }

  Future<bool> updateFCMToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/chat/updateFCMToken'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${prefs.getString('token')}',
        },
        body: jsonEncode({'userId': userId, 'fcmToken': token}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Failed to update FCM token: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error updating FCM token: $e');
      return false;
    }
  }
}
