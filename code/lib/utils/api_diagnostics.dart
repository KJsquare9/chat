import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiDiagnostics {
  static final String baseUrl = 'http://10.0.2.2:5000';

  /// Test available routes on the backend
  static Future<Map<String, dynamic>> testBackendRoutes() async {
    final results = <String, dynamic>{};

    try {
      // Test base connectivity
      final baseResponse = await http.get(Uri.parse(baseUrl));
      results['baseConnection'] = {
        'status': baseResponse.statusCode,
        'working': baseResponse.statusCode < 500,
      };
    } catch (e) {
      results['baseConnection'] = {
        'status': 'error',
        'message': e.toString(),
        'working': false,
      };
    }

    // Test specific endpoint
    try {
      final chatRouteResponse = await http.get(
        Uri.parse('$baseUrl/api/chat/test'),
        headers: {'Content-Type': 'application/json'},
      );

      results['chatRouteWithApiPrefix'] = {
        'status': chatRouteResponse.statusCode,
        'working': chatRouteResponse.statusCode != 404,
      };
    } catch (e) {
      results['chatRouteWithApiPrefix'] = {
        'status': 'error',
        'message': e.toString(),
        'working': false,
      };
    }

    // Test without api prefix
    try {
      final chatRouteResponse = await http.get(
        Uri.parse('$baseUrl/chat/test'),
        headers: {'Content-Type': 'application/json'},
      );

      results['chatRouteWithoutApiPrefix'] = {
        'status': chatRouteResponse.statusCode,
        'working': chatRouteResponse.statusCode != 404,
      };
    } catch (e) {
      results['chatRouteWithoutApiPrefix'] = {
        'status': 'error',
        'message': e.toString(),
        'working': false,
      };
    }

    return results;
  }
}
