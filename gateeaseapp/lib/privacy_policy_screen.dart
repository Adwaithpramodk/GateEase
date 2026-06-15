import 'package:flutter/material.dart';
import 'package:gateeaseapp/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Last Updated: April 21, 2026',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Introduction',
              'Welcome to GateEase. We are committed to protecting your personal information and your right to privacy. This Privacy Policy explains how we collect, use, and share information when you use our mobile application and web portal.',
            ),
            _buildSection(
              '1. Information We Collect',
              'We collect information that you provide directly to us when you register for an account or use our services:\n\n'
              '• Personal Identifiers: Name, email address, phone number, and admission number.\n'
              '• Institutional Data: Batch/Class details and department affiliation.\n'
              '• Profile Information: Profile photographs used for campus security verification.\n'
              '• Device Information: We collect device tokens for the purpose of sending push notifications regarding your exit pass status.\n'
              '• Usage Data: Exit pass records, including reasons for exit, requested times, and approval timestamps.',
            ),
            _buildSection(
              '2. How We Use Your Information',
              'We use the collected information for the following purposes:\n\n'
              '• To provide and maintain the GateEase service.\n'
              '• To facilitate the exit pass approval workflow between students, mentors, and security personnel.\n'
              '• To verify student identity at campus exit points using QR codes.\n'
              '• To send real-time notifications about pass status updates.\n'
              '• To generate institutional reports for campus administration.',
            ),
            _buildSection(
              '3. Data Storage and Security',
              'Your data is stored securely on our production servers. We implement industry-standard security measures, including:\n\n'
              '• Password hashing using secure algorithms (Argon2/PBKDF2).\n'
              '• JWT-based authentication for all mobile API requests.\n'
              '• Encryption of sensitive data in transit.\n\n'
              'We retain your data for as long as your account is active or as needed to provide you with services and maintain institutional records.',
            ),
            _buildSection(
              '4. Sharing of Information',
              'We do not share, sell, or rent your personal information to third parties. Your data is only accessible to authorized personnel within your institution (Mentors, Security Officers, and Administrators) as required to perform their functions within the app.',
            ),
            _buildSection(
              '5. Contact Us',
              'If you have any questions about this Privacy Policy, please contact us at:\n\n'
              'Email: gateeaseapp@gmail.com',
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                '© 2026 GateEase. All rights reserved.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
