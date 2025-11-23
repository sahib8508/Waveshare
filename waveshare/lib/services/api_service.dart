import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // IMPORTANT: Change this to your actual backend URL
  // For testing on Android emulator: http://10.0.2.2:3000
  // For testing on physical device: http://YOUR_COMPUTER_IP:3000
  // For production: https://your-domain.com
  static const String baseUrl = 'http://192.168.29.139:3000/api';

  // Timeout duration for API calls
  static const Duration timeout = Duration(seconds: 30);

  // Register organization
  static Future<Map<String, dynamic>> registerOrganization({
    required String orgName,
    required String orgType,
    required String emailDomain,
    required String adminEmail,
    required String adminName,
    required String adminPhone,
  }) async {
    print('🔵 API Service: Starting registration...');
    print('🔵 URL: $baseUrl/auth/register');

    final body = {
      'orgName': orgName,
      'orgType': orgType,
      'emailDomain': emailDomain,
      'adminEmail': adminEmail,
      'adminName': adminName,
      'adminPhone': adminPhone,
    };

    print('🔵 Request body: $body');

    try {
      print('🔵 Sending HTTP POST request...');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(timeout);

      print('🟢 Response received!');
      print('🟢 Status code: ${response.statusCode}');
      print('🟢 Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'orgId': data['orgId'],
          'orgCode': data['orgCode'],
          'adminId': data['adminId'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      print('🔴 ERROR: $e');
      print('🔴 Error type: ${e.runtimeType}');

      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Verify email OTP (we'll add this next)
  static Future<Map<String, dynamic>> verifyEmailOTP({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
        }),
      ).timeout(timeout);

      final data = jsonDecode(response.body);

      return {
        'success': response.statusCode == 200,
        'message': data['message'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}