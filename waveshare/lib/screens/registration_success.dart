import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';
import 'dart:async';

class RegistrationSuccess extends StatefulWidget {
  final String orgCode;
  final String adminId;
  final String orgId;
  final String orgName;

  const RegistrationSuccess({
    Key? key,
    required this.orgCode,
    required this.adminId,
    required this.orgId,
    required this.orgName,
  }) : super(key: key);

  @override
  State<RegistrationSuccess> createState() => _RegistrationSuccessState();
}

class _RegistrationSuccessState extends State<RegistrationSuccess> {
  int _countdown = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        _navigateToCSVUpload();
      }
    });
  }

  void _navigateToCSVUpload() {
    Navigator.pushReplacementNamed(
      context,
      '/csv-upload',
      arguments: {
        'orgId': widget.orgId,
        'orgCode': widget.orgCode,
        'adminId': widget.adminId,
        'orgName': widget.orgName,
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                '🎉 Welcome to WaveShare!',
                style: AppConstants.headingLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Text(
                widget.orgName,
                style: AppConstants.headingMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              _buildInfoCard(
                title: 'Organization Code',
                value: widget.orgCode,
                subtitle: 'Share this with your members',
                icon: Icons.business,
              ),
              const SizedBox(height: 16),

              _buildInfoCard(
                title: 'Your Admin ID',
                value: widget.adminId,
                subtitle: 'Use this to login',
                icon: Icons.person,
              ),
              const SizedBox(height: 32),

              Text(
                'Redirecting to setup in $_countdown seconds...',
                style: AppConstants.bodyMedium,
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () {
                  _timer?.cancel();
                  _navigateToCSVUpload();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  'Go to Setup Now',
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

  Widget _buildInfoCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        color: AppConstants.white,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(
          color: AppConstants.primaryBlue,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: AppConstants.primaryBlue),
              const SizedBox(width: 12),
              Text(title, style: AppConstants.bodyMedium),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppConstants.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: AppConstants.caption),
        ],
      ),
    );
  }
}