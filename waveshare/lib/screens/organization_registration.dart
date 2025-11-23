import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';

class OrganizationRegistration extends StatefulWidget {
  const OrganizationRegistration({Key? key}) : super(key: key);

  @override
  State<OrganizationRegistration> createState() => _OrganizationRegistrationState();
}

class _OrganizationRegistrationState extends State<OrganizationRegistration> {
  // Form controllers to get text from input fields
  final _formKey = GlobalKey<FormState>();
  final _orgNameController = TextEditingController();
  final _emailDomainController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminPhoneController = TextEditingController();

  String _selectedOrgType = 'Education'; // Default value
  bool _isLoading = false; // Show loading spinner when submitting

  @override
  void dispose() {
    // Clean up controllers when screen closes
    _orgNameController.dispose();
    _emailDomainController.dispose();
    _adminEmailController.dispose();
    _adminNameController.dispose();
    _adminPhoneController.dispose();
    super.dispose();
  }

  // This function runs when user clicks "Verify Organization"
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Call backend API
        final response = await ApiService.registerOrganization(
          orgName: _orgNameController.text.trim(),
          orgType: _selectedOrgType,
          emailDomain: _emailDomainController.text.trim(),
          adminEmail: _adminEmailController.text.trim(),
          adminName: _adminNameController.text.trim(),
          adminPhone: _adminPhoneController.text.trim(),
        );

        setState(() => _isLoading = false);

        if (response['success']) {
          setState(() => _isLoading = false);

          // Print response for debugging
          print('✅ Registration Response: $response');

          final orgCode = response['orgCode'] ?? 'N/A';
          final adminId = response['adminId'] ?? 'N/A';
          final orgId = response['orgId'] ?? 'N/A';

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Registration Successful!\n\n'
                    'Organization Code: $orgCode\n'
                    'Admin ID: $adminId\n'
                    'Organization ID: $orgId\n\n'
                    'Share the Organization Code with your members!',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 8),
            ),
          );

          // Wait a bit then go back
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pop(context);
          }
        } else {
          setState(() => _isLoading = false);
          _showError(response['message'] ?? 'Registration failed');
        }
      } catch (e) {
        setState(() => _isLoading = false);
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
        title: const Text('Register Organization'),
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
                // Progress indicator
                const Text(
                  'Step 1 of 7',
                  style: AppConstants.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Title
                const Text(
                  'Register Your Organization',
                  style: AppConstants.headingLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Organization Name
                TextFormField(
                  controller: _orgNameController,
                  decoration: InputDecoration(
                    labelText: 'Organization Name',
                    hintText: 'Sarla Birla University',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                    ),
                    prefixIcon: const Icon(Icons.business),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter organization name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Organization Type Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedOrgType, // ✔ New correct property
                  decoration: InputDecoration(
                    labelText: 'Organization Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                    ),
                    prefixIcon: const Icon(Icons.category),
                  ),
                  items: ['Education', 'Mining', 'Healthcare', 'Corporate', 'Other']
                      .map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedOrgType = value!);
                  },
                ),

                const SizedBox(height: 16),

                // Email Domain
                TextFormField(
                  controller: _emailDomainController,
                  decoration: InputDecoration(
                    labelText: 'Official Email Domain',
                    hintText: '@sarlaberlauniversity.edu',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                    ),
                    prefixIcon: const Icon(Icons.domain),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email domain';
                    }
                    if (!value.startsWith('@')) {
                      return 'Domain must start with @';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Admin Email
                TextFormField(
                  controller: _adminEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Admin Email',
                    hintText: 'admin@sarlaberlauniversity.edu',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                    ),
                    prefixIcon: const Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter admin email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Admin Name
                TextFormField(
                  controller: _adminNameController,
                  decoration: InputDecoration(
                    labelText: 'Admin Name',
                    hintText: 'Dr. Rajesh Kumar',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter admin name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Admin Phone
                TextFormField(
                  controller: _adminPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Admin Phone',
                    hintText: '+91 9876543210',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                    ),
                    prefixIcon: const Icon(Icons.phone),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter phone number';
                    }
                    if (value.length < 10) {
                      return 'Please enter valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
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
                    'Verify Organization',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}