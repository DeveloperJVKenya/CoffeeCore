import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static final Color coffeeBrown =
      Colors.brown[700]!; // Consistent with CoffeeCore theme

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: coffeeBrown,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Privacy Policy',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: coffeeBrown,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Last Updated
              Text(
                'Last Updated: October 11, 2025', // Updated to current date
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 24),

              // Introduction
              const Text(
                'CoffeeCore are committed to protecting your privacy. This Privacy Policy '
                'explains how we collect, use, store, and protect your personal information when you use our mobile '
                'application ("the App") and related services. By using the App, you consent to the practices described '
                'in this policy.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Table of Contents
              _buildSectionTitle(context, 'Table of Contents'),
              _buildTocItem(context, '1. Information We Collect'),
              _buildTocItem(context, '2. How We Use Your Information'),
              _buildTocItem(context, '3. How We Share Your Information'),
              _buildTocItem(context, '4. Your Privacy Rights and Choices'),
              _buildTocItem(context, '5. Data Security'),
              _buildTocItem(context, '6. Changes to This Policy'),
              _buildTocItem(context, '7. Third-Party Services'),
              _buildTocItem(context, '8. Contact Us'),
              const SizedBox(height: 24),

              // Section 1: Information We Collect
              _buildSectionTitle(context, '1. Information We Collect'),
              const Text(
                'We collect information to provide and improve our services. This includes:',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              _buildBulletPoint(
                'Personal Information: Name, email address, phone number, and profile details you provide when setting up your account.',
              ),
              _buildBulletPoint(
                'Coffee Field Data: Information you enter, such as coffee field data, pest management records, and reminders.',
              ),
              _buildBulletPoint(
                'Location Data: Approximate location (if permitted) to provide weather updates and region-specific coffee farming advice.',
              ),
              _buildBulletPoint(
                'Usage Data: How you interact with the App, including features used and time spent, to enhance user experience.',
              ),
              const SizedBox(height: 24),

              // Section 2: How We Use Your Information
              _buildSectionTitle(context, '2. How We Use Your Information'),
              const Text(
                'We use your information to:',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              _buildBulletPoint(
                'Provide Services: Deliver weather forecasts, coffee market price updates, and farming tips based on your data.',
              ),
              _buildBulletPoint(
                'Personalize Experience: Tailor content and reminders to your specific coffee farming needs.',
              ),
              _buildBulletPoint(
                'Improve the App: Analyze usage patterns to enhance functionality and fix issues.',
              ),
              _buildBulletPoint(
                'Communicate: Send notifications, updates, or support responses via email or in-app messages.',
              ),
              const SizedBox(height: 24),

              // Section 3: How We Share Your Information
              _buildSectionTitle(context, '3. How We Share Your Information'),
              const Text(
                'We do not sell your personal information. We may share it in these cases:',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              _buildBulletPoint(
                'Service Providers: With trusted partners who assist with app hosting, analytics, or weather data services, under strict confidentiality agreements.',
              ),
              _buildBulletPoint(
                'Legal Compliance: If required by law or to protect our rights, safety, or property.',
              ),
              _buildBulletPoint(
                'Aggregated Data: Anonymous, aggregated data (e.g., regional coffee trends) may be shared for research or marketing purposes.',
              ),
              const SizedBox(height: 24),

              // Section 4: Your Privacy Rights and Choices
              _buildSectionTitle(context, '4. Your Privacy Rights and Choices'),
              const Text(
                'You have control over your information. You may:',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              _buildBulletPoint(
                'Access and Update: View or edit your profile data within the App’s settings.',
              ),
              _buildBulletPoint(
                'Delete Data: Request deletion of your account and associated data by contacting us.',
              ),
              _buildBulletPoint(
                'Opt-Out: Disable location access or notifications via your device settings or App preferences.',
              ),
              const Text(
                'If you have concerns about your privacy, please reach out to us (see Section 8).',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Section 5: Data Security
              _buildSectionTitle(context, '5. Data Security'),
              const Text(
                'We take reasonable measures to protect your information, including encryption and secure storage. '
                'However, no system is completely secure, and we cannot guarantee absolute protection against '
                'unauthorized access or breaches.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Section 6: Changes to This Policy
              _buildSectionTitle(context, '6. Changes to This Policy'),
              const Text(
                'We may update this Privacy Policy to reflect changes in our practices or legal requirements. Updates '
                'will be posted in the App, and continued use after changes indicates your acceptance of the revised '
                'policy.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Section 7: Third-Party Services
              _buildSectionTitle(context, '7. Third-Party Services'),
              const Text(
                'This application, including sections like weather forecasts, collaborates with the Open Source Weather API. '
                'Updates will be posted in the App, and continued use after changes indicates your acceptance of this app.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Section 8: Contact Us
              _buildSectionTitle(context, '8. Contact Us'),
              const Text(
                'For questions, requests, or concerns about your privacy, please contact us at:\n'
                'Email: support@coffeecore.com\n'
                'Phone: +254 712 174 516\n'
                'Website: www.coffeecore.com', // Placeholder, update as needed
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 16),

              // Footer
              Center(
                child: Text(
                  '© 2025 CoffeeCore. All rights reserved.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method for section titles
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 8.0), // Fixed typo: should be 'bottom'
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: coffeeBrown,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  // Helper method for Table of Contents items
  Widget _buildTocItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: coffeeBrown,
            ),
      ),
    );
  }

  // Helper method for bullet points
  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontSize: 16, color: coffeeBrown)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
