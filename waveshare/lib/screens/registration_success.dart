import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

class RegistrationSuccess extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Registration Complete'),
        backgroundColor: AppConstants.white,
        automaticallyImplyLeading: false, // Remove back button
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
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

              // Welcome Text
              const Text(
                '🎉 Welcome to WaveShare!',
                style: AppConstants.headingLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Text(
                orgName,
                style: AppConstants.headingMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Organization Code Card
              _buildInfoCard(
                title: 'Organization Code',
                value: orgCode,
                subtitle: 'Share this with your members',
                icon: Icons.business,
              ),
              const SizedBox(height: 16),

              // Admin ID Card
              _buildInfoCard(
                title: 'Your Admin ID',
                value: adminId,
                subtitle: 'Use this to login',
                icon: Icons.person,
              ),
              const SizedBox(height: 32),

              // Share Buttons
              const Text(
                'Share codes with your members:',
                style: AppConstants.bodyMedium,
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildShareButton(
                    icon: Icons.copy,
                    label: 'Copy Code',
                    onPressed: () => _copyToClipboard(context, orgCode),
                  ),
                  const SizedBox(width: 16),
                  _buildShareButton(
                    icon: Icons.share,
                    label: 'Share',
                    onPressed: () => _shareCode(orgCode, adminId),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Continue Button
              ElevatedButton(
                onPressed: () {
                  // Go to admin login
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/admin-login',
                        (route) => false,
                  );
                },
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
                child: const Text(
                  'Continue to Login',
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
              Text(
                title,
                style: AppConstants.bodyMedium,
              ),
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
          Text(
            subtitle,
            style: AppConstants.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppConstants.lightBlue,
        foregroundColor: AppConstants.primaryBlue,
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareCode(String orgCode, String adminId) {
    // We'll implement share functionality later
    print('Sharing: $orgCode, $adminId');
  }
}