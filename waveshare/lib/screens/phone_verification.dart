import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import 'document_upload.dart';

class PhoneVerification extends StatefulWidget {
  final String orgId;
  final String orgCode;
  final String adminId;
  final String orgName;
  final String adminPhone;

  const PhoneVerification({
    Key? key,
    required this.orgId,
    required this.orgCode,
    required this.adminId,
    required this.orgName,
    required this.adminPhone,
  }) : super(key: key);

  @override
  State<PhoneVerification> createState() => _PhoneVerificationState();
}

class _PhoneVerificationState extends State<PhoneVerification> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
        (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyOTP() async {
    final otp = _otpControllers.map((c) => c.text).join();

    if (otp.length != 6) {
      _showError('Please enter complete OTP');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.verifyPhoneOTP(
        orgId: widget.orgId,
        otp: otp,
      );

      setState(() => _isLoading = false);

      if (response['success']) {
        print('📍 Phone verified, navigating to document upload');
        print('📍 Data: orgCode=${widget.orgCode}, adminId=${widget.adminId}, orgName=${widget.orgName}');

        // Navigate to document upload with ALL required data
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentUpload(
              orgId: widget.orgId,
              orgCode: widget.orgCode,
              adminId: widget.adminId,
              orgName: widget.orgName,
            ),
          ),
        );
      } else {
        _showError(response['message'] ?? 'Verification failed');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Verify Phone'),
        backgroundColor: AppConstants.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Step 3 of 7',
                style: AppConstants.bodyMedium,
              ),
              const SizedBox(height: 16),
              const Text(
                'Verify Your Phone',
                style: AppConstants.headingLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'We sent a 6-digit code to\n${widget.adminPhone}',
                style: AppConstants.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // OTP Input
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 50,
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppConstants.primaryBlue,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.length == 1 && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // Verify Button
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOTP,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
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
                  'Verify',
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
    );
  }
}