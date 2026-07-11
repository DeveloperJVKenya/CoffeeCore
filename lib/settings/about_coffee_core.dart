import 'package:flutter/material.dart';

class AboutCoffeeCoreScreen extends StatelessWidget {
  static Color primaryColor = Colors.brown[700]!;

  const AboutCoffeeCoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About CoffeeCore',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
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
                'About CoffeeCore',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Introduction
              const Text(
                'CoffeeCore is a mobile application tailored for coffee farmers, providing them with essential tools and real-time information to enhance the quality and yield of their coffee crops. Our aim is to combine traditional coffee farming wisdom with modern technology, helping farmers navigate the challenges of the coffee industry and achieve sustainable growth.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Mission Section
              _buildSectionTitle(context, 'Our Mission'),
              const Text(
                'Our mission is to empower coffee farmers with the tools and knowledge they need to produce high-quality coffee, connect with global markets, and adapt to environmental changes, all through a user-friendly mobile platform.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Vision Section
              _buildSectionTitle(context, 'Our Vision'),
              const Text(
                'A future where coffee farmers are equipped with the latest technology and information to ensure the sustainability and prosperity of their coffee farms, contributing to a thriving global coffee community.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Features Section
              _buildSectionTitle(context, 'Key Features'),
              _buildFeatureItem(
                context,
                icon: Icons.book,
                title: 'Coffee Cultivation Tips & Guides',
                description:
                    'Learn best practices for growing and maintaining healthy coffee plants from experts in the field.',
              ),
              _buildFeatureItem(
                context,
                icon: Icons.store,
                title: 'Coffee Market Insights',
                description:
                    'Stay informed about current coffee prices, trends, and connect with buyers to sell your produce effectively.',
              ),
              _buildFeatureItem(
                context,
                icon: Icons.cloud,
                title: 'Weather Updates',
                description:
                    'Get real-time weather forecasts to plan your coffee farming activities and protect your crops from adverse conditions.',
              ),
              _buildFeatureItem(
                context,
                icon: Icons.spa,
                title: 'Coffee Field Tracking',
                description:
                    'Track the progress of your coffee crops, monitor soil nutrients, and manage interventions efficiently.',
              ),
              _buildFeatureItem(
                context,
                icon: Icons.pest_control,
                title: 'Coffee Pest and Disease Control',
                description:
                    'Identify and manage common pests and diseases that affect coffee plants, ensuring the health and productivity of your farm.',
              ),
              _buildFeatureItem(
                context,
                icon: Icons.account_balance_wallet,
                title: 'Coffee Farm Management Tools',
                description:
                    'Track your farm\'s activities, costs, revenues, and loans to make informed financial decisions and maximize profitability.',
              ),
              const SizedBox(height: 24),

              // Contact Section
              _buildSectionTitle(context, 'Get in Touch'),
              const Text(
                'Have questions or feedback? Reach out to us!\n'
                'Email: infojvalmacis@gmail.com\n'
                'Phone: +254712174516\n'
                'Website: https://almagreentech.co.ke/#',
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
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  // Helper method for feature items
  Widget _buildFeatureItem(BuildContext context,
      {required IconData icon,
      required String title,
      required String description}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
