import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/constants.dart';
import '../services/api_service.dart';
import 'phone_verification.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String orgId;
  final String orgCode;
  final String adminId;
  final String orgName;

  const EmailVerificationScreen({
    Key? key,
    required this.email,
    required this.orgId,
    required this.orgCode,
    required this.adminId,
    required this.orgName,
  }) : super(key: key);

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  int _resendTimer = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _resendTimer = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOTP() async {
    final otp = _otpControllers.map((c) => c.text).join();

    if (otp.length != 6) {
      _showError('Please enter complete OTP');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.verifyEmailOTP(
        email: widget.email,
        otp: otp,
        orgId: widget.orgId,
      );

      setState(() => _isLoading = false);

      if (response['success']) {
        // Navigate to phone verification
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PhoneVerification(
              orgId: widget.orgId,
              orgCode: widget.orgCode,  // ADD THIS
              adminId: widget.adminId,  // ADD THIS
              orgName: widget.orgName,  // ADD THIS
              adminPhone: response['adminPhone'] ?? '',
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

  Future<void> _resendOTP() async {
    if (_resendTimer > 0) return;

    setState(() => _isResending = true);

    try {
      // Call resend OTP API
      await Future.delayed(const Duration(seconds: 2)); // Simulated API call

      setState(() => _isResending = false);
      _startTimer();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isResending = false);
      _showError('Failed to resend OTP');
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
        title: const Text('Verify Email'),
        backgroundColor: AppConstants.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // Email Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppConstants.lightBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.email,
                  size: 40,
                  color: AppConstants.primaryBlue,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Verify Your Email',
                style: AppConstants.headingLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                'We sent a 6-digit code to',
                style: AppConstants.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.email,
                style: AppConstants.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppConstants.primaryBlue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) => _buildOTPBox(index)),
              ),
              const SizedBox(height: 32),

              // Verify Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
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
                    'Verify',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: AppConstants.bodyMedium,
                  ),
                  TextButton(
                    onPressed: _resendTimer == 0 && !_isResending ? _resendOTP : null,
                    child: Text(
                      _resendTimer > 0
                          ? 'Resend in 0:${_resendTimer.toString().padLeft(2, '0')}'
                          : _isResending
                          ? 'Sending...'
                          : 'Resend',
                      style: TextStyle(
                        color: _resendTimer == 0 && !_isResending
                            ? AppConstants.primaryBlue
                            : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOTPBox(int index) {
    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        color: AppConstants.white,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        border: Border.all(
          color: _otpControllers[index].text.isNotEmpty
              ? AppConstants.primaryBlue
              : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }

          if (index == 5 && value.isNotEmpty) {
            _verifyOTP();
          }
        },
      ),
    );
  }
}