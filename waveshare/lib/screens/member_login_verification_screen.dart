import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'dart:convert';

class MemberLoginVerificationScreen extends StatefulWidget {
  const MemberLoginVerificationScreen({super.key});

  @override
  State<MemberLoginVerificationScreen> createState() => _MemberLoginVerificationScreenState();
}

class _MemberLoginVerificationScreenState extends State<MemberLoginVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orgCodeController = TextEditingController();
  final _uniqueIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  int _currentStep = 0; // 0: org code, 1: unique ID + email + phone, 2: check if exists, 3: login or register

  String? _orgId;
  String? _orgName;
  bool _userExists = false;
  Map<String, dynamic>? _memberData;

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

  // ✅ FIXED: Verify member identity from CSV
  Future<void> _verifyMemberIdentity() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String uniqueId = _uniqueIdController.text.trim();
      String email = _emailController.text.trim();
      String phone = _phoneController.text.trim();

      print('🔍 Verifying member:');
      print('   Unique ID: $uniqueId');
      print('   Email: $email');
      print('   Phone: $phone');

      // ✅ FIX: Proper CSV validation
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? csvData = prefs.getString('offline_csv_$_orgId');

      if (csvData == null) {
        throw Exception('CSV data not found. Please verify organization code again.');
      }

      List<dynamic> members = json.decode(csvData);
      print('📊 Total members in CSV: ${members.length}');

      // ✅ FIXED: Find member with exact match
      Map<String, dynamic>? foundMember;

      for (var member in members) {
        String csvUniqueId = member['unique_id']?.toString().trim() ?? '';
        String csvEmail = member['email']?.toString().trim().toLowerCase() ?? '';
        String csvPhone = member['phone']?.toString().trim() ?? '';

        // ✅ CRITICAL FIX: Match ANY of these conditions for supervisors
        bool idMatch = csvUniqueId == uniqueId;
        bool emailMatch = csvEmail == email.toLowerCase();
        bool phoneMatch = csvPhone == phone;

        if (idMatch && emailMatch && phoneMatch) {
          foundMember = Map<String, dynamic>.from(member);
          print('✅ Member found: ${member['name']}');
          break;
        }
      }

      if (foundMember == null) {
        throw Exception('Invalid credentials. Please check your Unique ID, Email, and Phone.');
      }

      // Save member data temporarily
      setState(() {
        _memberData = foundMember;
        _currentStep = 2;
      });

      // Check if user already has an account
      String? storedUserId = prefs.getString('user_id');
      String? storedPassword = prefs.getString('user_password');

      if (storedUserId == uniqueId && storedPassword != null) {
        // User exists - go to login
        print('✅ User already registered. Going to login.');
        setState(() {
          _userExists = true;
          _currentStep = 3;
        });
      } else {
        // User doesn't exist - go to registration
        print('⚠️ New user. Going to registration.');
        setState(() {
          _userExists = false;
          _currentStep = 3;
        });
      }

    } catch (e) {
      print('❌ Verification error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ Login existing user
  Future<void> _loginExistingUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      String uniqueId = _uniqueIdController.text.trim();
      String enteredPassword = _passwordController.text.trim();

      String? storedPassword = prefs.getString('user_password');
      String? storedRole = prefs.getString('user_role');

      if (storedPassword == enteredPassword) {
        // Password correct
        print('✅ Login successful!');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Welcome back!'), backgroundColor: Colors.green),
        );

        // Navigate based on role
        if (storedRole?.toLowerCase() == 'supervisor') {
          Navigator.pushReplacementNamed(context, '/supervisor-dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/student-dashboard');
        }
      } else {
        // Wrong password
        throw Exception('Incorrect password');
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ Register new user (first time)
  Future<void> _registerNewUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_memberData == null) {
        throw Exception('Member data not found');
      }

      // Save all data
      SharedPreferences prefs = await SharedPreferences.getInstance();

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

      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('has_password', true);
      await prefs.setString('account_created_at', DateTime.now().toIso8601String());
      await prefs.setBool('first_login_complete', true);

      print('✅ Account created successfully');
      print('   User ID: ${_memberData!['unique_id']}');
      print('   Role: ${_memberData!['role']}');

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
      print('❌ Registration error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
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
              if (_currentStep == 1) ..._buildIdentityVerificationStep(),
              if (_currentStep == 2) ..._buildConfirmDetailsStep(),
              if (_currentStep == 3 && _userExists) ..._buildLoginStep(),
              if (_currentStep == 3 && !_userExists) ..._buildRegistrationStep(),
            ],
          ),
        ),
      ),
    );
  }

  // Step 1: Organization Code
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

  // Step 2: Identity Verification (Unique ID + Email + Phone)
  List<Widget> _buildIdentityVerificationStep() {
    return [
      Text('Step 2: Verify Your Identity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      SizedBox(height: 16),
      Text('Organization: $_orgName', style: TextStyle(color: Colors.green)),
      SizedBox(height: 24),
      TextFormField(
        controller: _uniqueIdController,
        decoration: InputDecoration(
          labelText: 'Unique ID',
          hintText: 'SBU2021CSE001 or PROF-CSE-107',
          border: OutlineInputBorder(),
        ),
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
      ),
      SizedBox(height: 16),
      TextFormField(
        controller: _emailController,
        decoration: InputDecoration(
          labelText: 'Email',
          hintText: 'your.email@sbu.edu',
          border: OutlineInputBorder(),
        ),
        validator: (v) => v == null || !v.contains('@') ? 'Invalid email' : null,
      ),
      SizedBox(height: 16),
      TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: 'Phone',
          hintText: '9876543210',
          border: OutlineInputBorder(),
        ),
        validator: (v) => v == null || v.length < 10 ? 'Invalid phone' : null,
      ),
      SizedBox(height: 24),
      ElevatedButton(
        onPressed: _isLoading ? null : _verifyMemberIdentity,
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

  // Step 3: Confirm Details
  List<Widget> _buildConfirmDetailsStep() {
    return [
      Icon(Icons.check_circle, size: 60, color: Colors.green),
      SizedBox(height: 16),
      Text('Identity Verified!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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
      SizedBox(height: 16),
      Text('Checking account status...', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
    ];
  }

  // Step 4a: Login (for existing users)
  List<Widget> _buildLoginStep() {
    return [
      Icon(Icons.lock_person, size: 60, color: Colors.green),
      SizedBox(height: 16),
      Text('Welcome Back!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      SizedBox(height: 8),
      Text('${_memberData!['name']}', style: TextStyle(fontSize: 18, color: Colors.grey), textAlign: TextAlign.center),
      Text('You already have an account. Please login.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
      SizedBox(height: 32),
      TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: 'Password',
          border: OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
      ),
      SizedBox(height: 24),
      ElevatedButton(
        onPressed: _isLoading ? null : _loginExistingUser,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: EdgeInsets.all(16),
        ),
        child: _isLoading
            ? CircularProgressIndicator(color: Colors.white)
            : Text('Login', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
    ];
  }

  // Step 4b: Registration (for new users)
  List<Widget> _buildRegistrationStep() {
    return [
      Icon(Icons.person_add, size: 60, color: AppConstants.primaryBlue),
      SizedBox(height: 16),
      Text('Create Account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      SizedBox(height: 8),
      Text('${_memberData!['name']}', style: TextStyle(fontSize: 18, color: Colors.grey), textAlign: TextAlign.center),
      Text('First time? Create your password.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
      SizedBox(height: 32),
      TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: 'Create Password',
          border: OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
      ),
      SizedBox(height: 16),
      TextFormField(
        controller: _confirmPasswordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: 'Confirm Password',
          border: OutlineInputBorder(),
        ),
        validator: (v) => v != _passwordController.text ? 'Passwords don\'t match' : null,
      ),
      SizedBox(height: 24),
      ElevatedButton(
        onPressed: _isLoading ? null : _registerNewUser,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryBlue,
          padding: EdgeInsets.all(16),
        ),
        child: _isLoading
            ? CircularProgressIndicator(color: Colors.white)
            : Text('Create Account', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
    ];
  }
}