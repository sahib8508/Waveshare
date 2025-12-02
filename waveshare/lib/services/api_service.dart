import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:io'; // For File class
import 'package:http_parser/http_parser.dart'; // For MediaType


class ApiService {
  static const String baseUrl = 'http://10.166.122.21:3000/api';
  static const Duration timeout = Duration(seconds: 30);

  // ============================================================================
  // REGISTRATION FLOW
  // ============================================================================

  // Step 1: Register Organization
  static Future<Map<String, dynamic>> registerOrganization({
    required String orgName,
    required String orgType,
    required String emailDomain,
    required String adminEmail,
    required String adminName,
    required String adminPhone,
    required String password,
  }) async {
    try {
      print('🔵 Registering organization...');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'orgName': orgName,
          'orgType': orgType,
          'emailDomain': emailDomain,
          'adminEmail': adminEmail,
          'adminName': adminName,
          'adminPhone': adminPhone,
          'password': password,
        }),
      ).timeout(timeout);

      print('🟢 Response: ${response.statusCode}');
      final data = jsonDecode(response.body);

      return {
        'success': response.statusCode == 201,
        'orgId': data['orgId'],
        'adminEmail': data['adminEmail'],
        'testEmailOTP': data['testEmailOTP'],
        'message': data['message'],
      };
    } catch (e) {
      print('🔴 Error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Step 2: Verify Email OTP
  static Future<Map<String, dynamic>> verifyEmailOTP({
    required String orgId,
    required String otp,
    required String email,
  }) async {
    try {
      print('🔵 Verifying email OTP...');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'orgId': orgId, 'otp': otp}),
      ).timeout(timeout);

      final data = jsonDecode(response.body);

      return {
        'success': response.statusCode == 200,
        'adminPhone': data['adminPhone'],
        'testPhoneOTP': data['testPhoneOTP'],
        'message': data['message'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Step 3: Resend Email OTP
  static Future<Map<String, dynamic>> resendEmailOTP({
    required String orgId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/resend-email-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'orgId': orgId}),
      ).timeout(timeout);

      final data = jsonDecode(response.body);

      return {
        'success': response.statusCode == 200,
        'testEmailOTP': data['testEmailOTP'],
        'message': data['message'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

// Verify Phone OTP
  static Future<Map<String, dynamic>> verifyPhoneOTP({
    required String orgId,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-phone'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {'orgId': orgId, 'otp': otp}), // Change phoneOTP to otp
      ).timeout(timeout);

      final data = jsonDecode(response.body);

      return {
        'success': response.statusCode == 200,
        'orgCode': data['orgCode'],
        'adminId': data['adminId'],
        'orgName': data['orgName'],
        'message': data['message'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

// Upload Document
  // ✅ FIXED: Upload Document with proper error handling
  static Future<Map<String, dynamic>> uploadDocument({
    required String orgId,
    required String documentType,
    required PlatformFile file,
  }) async {
    try {
      print('🔵 Uploading document...');
      print('📤 orgId: $orgId');
      print('📤 documentType: $documentType');
      print('📤 fileName: ${file.name}');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/auth/upload-document'),
      );

      request.fields['orgId'] = orgId;
      request.fields['documentType'] = documentType;

      // ✅ CRITICAL: Handle both web and mobile file uploads
      if (file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'document',
            file.bytes!,
            filename: file.name,
          ),
        );
      } else if (file.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'document',
            file.path!,
            filename: file.name,
          ),
        );
      } else {
        return {
          'success': false,
          'message': 'File data not available',
        };
      }

      print('📤 Sending request...');

      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      print('🟢 Response status: ${response.statusCode}');
      print('🟢 Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // ✅ Verify all required fields are present
        if (data['orgCode'] == null || data['adminId'] == null ||
            data['orgName'] == null) {
          print('⚠️ WARNING: Backend returned null values');
          print('📦 Received data: $data');
          return {
            'success': false,
            'message': 'Incomplete data from server',
          };
        }

        return {
          'success': true,
          'orgCode': data['orgCode'],
          'adminId': data['adminId'],
          'orgName': data['orgName'],
          'message': data['message'] ?? 'Upload successful',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Upload failed',
        };
      }
    } catch (e) {
      print('🔴 Upload error: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

// ✅ FIXED: Skip Document with proper error handling
  static Future<Map<String, dynamic>> skipDocument({
    required String orgId,
  }) async {
    try {
      print('🔵 Skipping document upload...');
      print('📤 orgId: $orgId');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/skip-document'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'orgId': orgId}),
      ).timeout(timeout);

      print('🟢 Response status: ${response.statusCode}');
      print('🟢 Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // ✅ Verify all required fields are present
        if (data['orgCode'] == null || data['adminId'] == null ||
            data['orgName'] == null) {
          print('⚠️ WARNING: Backend returned null values');
          print('📦 Received data: $data');
          return {
            'success': false,
            'message': 'Incomplete data from server',
          };
        }

        return {
          'success': true,
          'orgCode': data['orgCode'],
          'adminId': data['adminId'],
          'orgName': data['orgName'],
          'message': data['message'] ?? 'Skip successful',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Skip failed',
        };
      }
    } catch (e) {
      print('🔴 Skip error: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Step 7: Set Password
  static Future<Map<String, dynamic>> setPassword({
    required String orgId,
    required String password,
  }) async {
    try {
      print('🔵 Setting password...');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/set-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'orgId': orgId, 'password': password}),
      ).timeout(timeout);

      final data = jsonDecode(response.body);

      return {
        'success': response.statusCode == 200,
        'orgCode': data['orgCode'],
        'adminId': data['adminId'],
        'orgName': data['orgName'],
        'message': data['message'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ============================================================================
  // LOGIN
  // ============================================================================

// Add these methods to your existing ApiService class

// CSV Upload
  static Future<Map<String, dynamic>> uploadCSV({
    required String orgId,
    required String csvType,
    required PlatformFile file,
  }) async {
    try {
      print('📤 Uploading $csvType CSV...');
      print('   OrgId: $orgId');
      print('   File: ${file.name}');
      print('   Size: ${file.size} bytes');
      print('   Has bytes: ${file.bytes != null}');
      print('   Has path: ${file.path != null}');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/auth/upload-csv'), // Added /auth // Added /auth
      );

      // Add form fields
      request.fields['orgId'] = orgId;
      request.fields['csvType'] = csvType;

      // ✅ FIX: Handle both web (bytes) and mobile (path)
      if (file.bytes != null) {
        // Web platform - use bytes directly
        print('📱 Using bytes (Web platform)');
        request.files.add(
          http.MultipartFile.fromBytes(
            'csvFile',
            file.bytes!,
            filename: file.name,
            contentType: MediaType('text', 'csv'),
          ),
        );
      } else if (file.path != null) {
        // Mobile/Desktop platform - read from path
        print('📱 Using path (Mobile/Desktop platform)');
        var fileStream = http.ByteStream(File(file.path!).openRead());
        var length = await File(file.path!).length();

        request.files.add(
          http.MultipartFile(
            'csvFile',
            fileStream,
            length,
            filename: file.name,
            contentType: MediaType('text', 'csv'),
          ),
        );
      } else {
        throw Exception('File has neither bytes nor path');
      }

      print('🚀 Sending request to: $baseUrl/upload-csv');

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Upload timeout after 30 seconds');
        },
      );

      var response = await http.Response.fromStream(streamedResponse);

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Upload successful');
        return data;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Upload failed');
      }
    } catch (e) {
      print('❌ Upload error: $e');
      rethrow;
    }
  }

// Updated Admin Login (checks CSV status)
  // ✅ FIXED: Admin Login with correct endpoint
  static Future<Map<String, dynamic>> adminLogin({
    required String email,
    required String password,
  }) async {
    try {
      print('🔑 Attempting login...');
      print('   Email: $email');
      print('   Endpoint: $baseUrl/auth/admin-login');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/admin-login'), // ✅ FIXED: Added /auth
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - please check your connection');
        },
      );

      print('📥 Login response: ${response.statusCode}');
      print('📥 Body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        print('✅ Login successful');
        print('   Org: ${data['org']['orgName']}');
        print('   CSV Status: ${data['org']['hasCSVUploaded']}');
        return data;
      } else if (response.statusCode == 403) {
        throw Exception(data['message'] ?? 'Registration not complete');
      } else if (response.statusCode == 401) {
        throw Exception('Incorrect password');
      } else if (response.statusCode == 404) {
        throw Exception('Email not found');
      } else {
        throw Exception(data['message'] ?? 'Login failed');
      }
    } catch (e) {
      print('❌ Login error: $e');
      rethrow;
    }
  }
}