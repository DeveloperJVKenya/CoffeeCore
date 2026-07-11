import 'package:flutter/material.dart';
import 'package:coffeecore/settings/edit_profile_screen.dart';
import 'package:coffeecore/settings/account_settings_screen.dart';
import 'package:coffeecore/settings/notifications_settings_screen.dart';
import 'package:coffeecore/settings/privacy_policy_screen.dart';
import 'package:coffeecore/settings/contact_us_screen.dart';
import 'package:coffeecore/settings/faq_screen.dart';
import 'package:coffeecore/settings/terms_and_conditions_screen.dart';
import 'package:coffeecore/settings/about_coffee_core.dart';
import 'package:coffeecore/home.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for logout functionality

class SettingsScreen extends StatelessWidget {
  final Color primaryColor = Colors.brown[700]!; // CoffeeCore theme color
  final Color darkRed = const Color(0xFF8B0000); // Retained for logout button

  SettingsScreen({super.key});

  Widget _buildIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primaryColor,
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 20,
      ),
    );
  }

// Logout method adapted from HomePage with safe context usage
  Future<void> _handleLogout(BuildContext context) async {
    // Store Navigator and ScaffoldMessenger before the async operation
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseAuth.instance.signOut();
      navigator.pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error logging out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double cardWidth = screenWidth - 32.0;
    double editProfileWidth = cardWidth * 0.75;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const HomePage(),
              ),
            );
          },
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold), // Bold to match HomePage
        ),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor,
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditProfileScreen(),
                          ),
                        );
                      },
                      child: Container(
                        width: editProfileWidth,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: const Center(
                          child: Text(
                            'Edit Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'General',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        leading: _buildIcon(Icons.account_circle),
                        title: Text(
                          'Account',
                          style: TextStyle(color: primaryColor),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios,
                            size: 16, color: primaryColor),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AccountSettingsScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, thickness: 1, indent: 50),
                      ListTile(
                        leading: _buildIcon(Icons.notifications),
                        title: Text(
                          'Notification Settings',
                          style: TextStyle(color: primaryColor),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios,
                            size: 16, color: primaryColor),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const NotificationsSettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Help',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        leading: _buildIcon(Icons.contact_support),
                        title: Text('Contact Us',
                            style: TextStyle(color: primaryColor)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ContactUsScreen(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: _buildIcon(Icons.help),
                        title: Text('Knowledge Base/FAQ',
                            style: TextStyle(color: primaryColor)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FAQScreen(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: _buildIcon(Icons.description),
                        title: Text('Terms and Conditions',
                            style: TextStyle(color: primaryColor)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const TermsAndConditionsScreen(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: _buildIcon(Icons.privacy_tip),
                        title: Text('Privacy Policy',
                            style: TextStyle(color: primaryColor)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PrivacyPolicyScreen(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: _buildIcon(Icons.info),
                        title: Text('About CoffeeCore',
                            style: TextStyle(
                                color:
                                    primaryColor)), // Updated from Kilimo Mkononi
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AboutCoffeeCoreScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: darkRed,
                  borderRadius: BorderRadius.circular(20.0),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: GestureDetector(
                  onTap: () =>
                      _handleLogout(context), // Updated to use proper logout
                  child: const Center(
                    child: Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold, // Added for consistency
                      ),
                    ),
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
