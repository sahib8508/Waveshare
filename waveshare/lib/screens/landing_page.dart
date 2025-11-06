import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/landing_button.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            child: Column(
              children: [
                // Logo and Title Section
                const SizedBox(height: 40),
                _buildLogoSection(),
                const SizedBox(height: 60),

                // Buttons Section
                _buildButtons(context),

                const SizedBox(height: 40),

                // Version Info
                _buildVersionInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        // Logo (placeholder - replace with actual logo later)
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppConstants.primaryBlue,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppConstants.primaryBlue.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.share_rounded,
            size: 60,
            color: AppConstants.white,
          ),
        ),
        const SizedBox(height: 20),

        // App Name
        const Text(
          AppConstants.appName,
          style: AppConstants.headingLarge,
        ),
        const SizedBox(height: 8),

        // Tagline
        Text(
          AppConstants.tagline,
          style: AppConstants.bodyLarge.copyWith(
            color: AppConstants.primaryBlue,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),

        // Subtitle
        Text(
          AppConstants.subtitle,
          style: AppConstants.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        // Button 1: Continue as Organization
        LandingButton(
          icon: Icons.business,
          title: 'Continue as Organization',
          subtitle: 'Register or login as admin',
          onPressed: () {
            _onOrganizationPressed(context);
          },
        ),
        const SizedBox(height: AppConstants.buttonSpacing),

        // Button 2: Join Your Organization
        LandingButton(
          icon: Icons.group,
          title: 'Join Your Organization',
          subtitle: 'Join as member (student/employee)',
          onPressed: () {
            _onJoinOrganizationPressed(context);
          },
        ),
        const SizedBox(height: AppConstants.buttonSpacing),

        // Button 3: Universal Share
        LandingButton(
          icon: Icons.upload_file,
          title: 'Universal Share',
          subtitle: 'Share files with anyone nearby',
          onPressed: () {
            _onUniversalSharePressed(context);
          },
        ),
        const SizedBox(height: AppConstants.buttonSpacing),

        // Button 4: Chat with Anyone
        LandingButton(
          icon: Icons.chat_bubble,
          title: 'Chat with Anyone',
          subtitle: 'Message anyone using WaveShare',
          onPressed: () {
            _onChatPressed(context);
          },
        ),
      ],
    );
  }

  Widget _buildVersionInfo() {
    return Column(
      children: [
        const Divider(color: AppConstants.textLight),
        const SizedBox(height: 8),
        Text(
          AppConstants.appVersion,
          style: AppConstants.caption,
        ),
      ],
    );
  }

  // Button Actions (temporary - just show messages)
  void _onOrganizationPressed(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Continue as Organization - Coming Soon'),
        duration: Duration(seconds: 2),
        backgroundColor: AppConstants.primaryBlue,
      ),
    );
    debugPrint('Organization button pressed');
  }

  void _onJoinOrganizationPressed(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Join Organization - Coming Soon'),
        duration: Duration(seconds: 2),
        backgroundColor: AppConstants.primaryBlue,
      ),
    );
    debugPrint('Join Organization button pressed');
  }

  void _onUniversalSharePressed(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Universal Share - Coming Soon'),
        duration: Duration(seconds: 2),
        backgroundColor: AppConstants.primaryBlue,
      ),
    );
    debugPrint('Universal Share button pressed');
  }

  void _onChatPressed(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chat with Anyone - Coming Soon'),
        duration: Duration(seconds: 2),
        backgroundColor: AppConstants.primaryBlue,
      ),
    );
    debugPrint('Chat button pressed');
  }
}