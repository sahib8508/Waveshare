import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({Key? key}) : super(key: key);

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        print('🔵 Attempting login...');
        final response = await ApiService.adminLogin(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        setState(() => _isLoading = false);

        if (response['success'] == true) {
          final org = response['org'];

          print('✅ Login successful');
          print('   Org: ${org['orgName']}');
          print('   CSV Uploaded: ${org['hasCSVUploaded']}');
          print('   Students: ${org['totalStudents']}');
          print('   Teachers: ${org['totalTeachers']}');

          // Prepare data for navigation
          // ✅ Prepare data for navigation with NEW hierarchy stats
          // ✅ COMPLETE FIX: Pass ALL data including hierarchy
          final navigationArgs = {
            'orgId': org['orgId'],
            'orgCode': org['orgCode'],
            'adminId': org['adminId'],
            'orgName': org['orgName'],
            'adminName': org['adminName'],

            // Hierarchy stats
            'hasCSVUploaded': org['hasCSVUploaded'] ?? false,
            'totalMembers': org['totalMembers'] ?? 0,
            'totalStudents': org['totalStudents'] ?? 0,
            'totalFaculty': org['totalFaculty'] ?? 0,
            'totalStaff': org['totalStaff'] ?? 0,

            // ✅ CRITICAL: Pass full hierarchy object
            'hierarchy': org['hierarchy'],

            // Old fields for backward compatibility
            'totalTeachers': org['totalTeachers'] ?? 0,
            'studentsCSVUrl': org['studentsCSVUrl'],
            'teachersCSVUrl': org['teachersCSVUrl'],
          };

          print('📦 Navigation args prepared:');
          print('   Has hierarchy: ${org['hierarchy'] != null}');
          if (org['hierarchy'] != null) {
            print('   Departments: ${org['hierarchy']['departments']?.length ?? 0}');
          }

          // Check CSV upload status and navigate accordingly
          final hasCSV = org['hasCSVUploaded'] ?? false;

          if (!mounted) return;

          if (hasCSV) {
            // Has CSV - go directly to dashboard
            print('📊 CSV already uploaded, navigating to dashboard');
            Navigator.pushReplacementNamed(
              context,
              '/admin-dashboard',
              arguments: navigationArgs,
            );
          } else {
            // No CSV - redirect to CSV upload screen
            print('⚠️ No CSV uploaded, redirecting to CSV upload');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please upload member CSV files to continue'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );

            await Future.delayed(const Duration(milliseconds: 500));

            if (!mounted) return;
            Navigator.pushReplacementNamed(
              context,
              '/csv-upload',
              arguments: navigationArgs,
            );
          }
        } else {
          _showError(response['message'] ?? 'Login failed');
        }
      } catch (e) {
        setState(() => _isLoading = false);
        print('🔴 Login error: $e');
        _showError('Network error: ${e.toString()}');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Admin Login'),
        backgroundColor: AppConstants.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),

                // Logo or Icon
                const Icon(
                  Icons.admin_panel_settings,
                  size: 80,
                  color: AppConstants.primaryBlue,
                ),
                const SizedBox(height: 16),

                const Text(
                  'Welcome Back',
                  style: AppConstants.headingLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  'Login to manage your organization',
                  style: AppConstants.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Admin Email',
                    hintText: 'admin@example.com',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadiusMedium,
                      ),
                    ),
                    prefixIcon: const Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadiusMedium,
                      ),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadiusMedium,
                      ),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                          context,
                          '/organization-registration',
                        );
                      },
                      child: const Text(
                        'Register',
                        style: TextStyle(
                          color: AppConstants.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}