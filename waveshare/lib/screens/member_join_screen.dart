import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MemberJoinScreen extends StatefulWidget {
  const MemberJoinScreen({super.key});

  @override
  State<MemberJoinScreen> createState() => _MemberJoinScreenState();
}

class _MemberJoinScreenState extends State<MemberJoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orgCodeController = TextEditingController();
  final _uniqueIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _orgId;
  String? _orgName;
  Map<String, dynamic>? _memberData;
  bool _isLoading = false;
  int _currentStep = 0; // 0: org code, 1: unique ID, 2: verify details, 3: password

  @override
  void dispose() {
    _orgCodeController.dispose();
    _uniqueIdController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyOrgCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/auth/verify-org-code/${_orgCodeController.text.trim()}'),
      ).timeout(Duration(seconds: 30));

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _orgId = data['orgId'];
          _orgName = data['orgName'];
          _currentStep = 1;
        });

        // Download CSV for offline validation
        await ApiService.downloadCSVForOfflineValidation(orgId: _orgId!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Organization found: $_orgName'), backgroundColor: Colors.green),
        );
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Organization not found');
      }
    } catch (e) {
      print('❌ Verify error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyMember() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Offline validation
      var member = await ApiService.validateMemberOffline(
        orgId: _orgId!,
        uniqueId: _uniqueIdController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (member == null) {
        throw Exception('Invalid credentials. Please check your Unique ID, Email, and Phone.');
      }

      setState(() {
        _memberData = member;
        _currentStep = 2;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Identity verified!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // ✅ CRITICAL: Save all data AND mark as logged in
      await prefs.setString('user_id', _memberData!['unique_id']);
      await prefs.setString('user_role', _memberData!['role']);
      await prefs.setString('user_name', _memberData!['name']);
      await prefs.setString('user_password', _passwordController.text);
      await prefs.setString('org_id', _orgId!);
      await prefs.setString('org_name', _orgName!);
      await prefs.setString('user_department', _memberData!['department'] ?? '');
      await prefs.setString('user_branch', _memberData!['branch'] ?? '');
      await prefs.setString('user_year', _memberData!['year']?.toString() ?? '');
      await prefs.setString('user_semester', _memberData!['semester']?.toString() ?? '');
      await prefs.setString('user_section', _memberData!['section'] ?? '');

      // ✅ THIS IS THE KEY FIX
      // ✅ ENHANCED PASSWORD TRACKING
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('has_password', true);
      await prefs.setString('account_created_at', DateTime.now().toIso8601String());
      await prefs.setBool('first_login_complete', true);

      print('✅ SAVED LOGIN STATE:');
      print('   is_logged_in: true');
      print('   has_password: true');
      print('   user_id: ${_memberData!['unique_id']}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Account created!'), backgroundColor: Colors.green),
      );

      // Navigate based on role
      String role = _memberData!['role'].toString().toLowerCase();
      if (role == 'supervisor') {
        Navigator.pushReplacementNamed(context, '/supervisor-dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/student-dashboard');
      }
    } catch (e) {
      print('❌ Error creating account: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Join Organization'),
        backgroundColor: AppConstants.primaryBlue,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_currentStep == 0) ..._buildOrgCodeStep(),
              if (_currentStep == 1) ..._buildUniqueIdStep(),
              if (_currentStep == 2) ..._buildVerifyDetailsStep(),
              if (_currentStep == 3) ..._buildPasswordStep(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOrgCodeStep() {
    return [
      Text('Step 1: Enter Organization Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      SizedBox(height: 24),
      TextFormField(
        controller: _orgCodeController,
        decoration: InputDecoration(
          labelText: 'Organization Code',
          hintText: 'WAVE-SBU-9KX7M',
          border: OutlineInputBorder(),
        ),
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
      ),
      SizedBox(height: 24),
      ElevatedButton(
        onPressed: _isLoading ? null : _verifyOrgCode,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryBlue,
          padding: EdgeInsets.all(16),
        ),
        child: _isLoading
            ? CircularProgressIndicator(color: Colors.white)
            : Text('Verify Code', style: TextStyle(color: Colors.white)),
      ),
    ];
  }

  List<Widget> _buildUniqueIdStep() {
    return [
      Text('Step 2: Enter Your Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      SizedBox(height: 16),
      Text('Organization: $_orgName', style: TextStyle(color: Colors.green)),
      SizedBox(height: 24),
      TextFormField(
        controller: _uniqueIdController,
        decoration: InputDecoration(
          labelText: 'Unique ID',
          hintText: 'SBU2021CSE001 or PROF-CSE-001',
          border: OutlineInputBorder(),
        ),
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
      ),
      SizedBox(height: 16),
      TextFormField(
        controller: _emailController,
        decoration: InputDecoration(
          labelText: 'Email',
          border: OutlineInputBorder(),
        ),
        validator: (v) => v == null || !v.contains('@') ? 'Invalid email' : null,
      ),
      SizedBox(height: 16),
      TextFormField(
        controller: _phoneController,
        decoration: InputDecoration(
          labelText: 'Phone',
          border: OutlineInputBorder(),
        ),
        validator: (v) => v == null || v.length < 10 ? 'Invalid phone' : null,
      ),
      SizedBox(height: 24),
      ElevatedButton(
        onPressed: _isLoading ? null : _verifyMember,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryBlue,
          padding: EdgeInsets.all(16),
        ),
        child: _isLoading
            ? CircularProgressIndicator(color: Colors.white)
            : Text('Verify Identity', style: TextStyle(color: Colors.white)),
      ),
    ];
  }

  List<Widget> _buildVerifyDetailsStep() {
    return [
      Text('Step 3: Confirm Your Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      SizedBox(height: 24),
      Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${_memberData!['name']}', style: TextStyle(fontSize: 16)),
              SizedBox(height: 8),
              Text('Role: ${_memberData!['role']}', style: TextStyle(fontSize: 16)),
              SizedBox(height: 8),
              Text('Department: ${_memberData!['department']}', style: TextStyle(fontSize: 16)),
              if (_memberData!['branch'] != null && _memberData!['branch'].toString().isNotEmpty)
                Text('Branch: ${_memberData!['branch']}', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
      SizedBox(height: 24),
      Text('Is this you?', style: TextStyle(fontSize: 16)),
      SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => setState(() => _currentStep = 3),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.all(16),
              ),
              child: Text('Yes, it\'s me', style: TextStyle(color: Colors.white)),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _currentStep = 1),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.all(16),
              ),
              child: Text('No, try again'),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildPasswordStep() {
    return [
      Text('Step 4: Create Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      SizedBox(height: 24),
      TextFormField(
        controller: _passwordController,
        obscureText: true,
        decoration: InputDecoration(
          labelText: 'Password',
          border: OutlineInputBorder(),
        ),
        validator: (v) => v == null || v.length < 8 ? 'Min 8 characters' : null,
      ),
      SizedBox(height: 16),
      TextFormField(
        controller: _confirmPasswordController,
        obscureText: true,
        decoration: InputDecoration(
          labelText: 'Confirm Password',
          border: OutlineInputBorder(),
        ),
        validator: (v) => v != _passwordController.text ? 'Passwords don\'t match' : null,
      ),
      SizedBox(height: 24),
      ElevatedButton(
        onPressed: _isLoading ? null : _createAccount,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryBlue,
          padding: EdgeInsets.all(16),
        ),
        child: _isLoading
            ? CircularProgressIndicator(color: Colors.white)
            : Text('Complete Registration', style: TextStyle(color: Colors.white)),
      ),
    ];
  }
}