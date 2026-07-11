import 'package:flutter/material.dart';

class AccountSettingsScreen extends StatelessWidget {
  AccountSettingsScreen({super.key});

  // Define primary color for CoffeeCore theme
  final Color primaryColor = Colors.brown[700]!;
  final Color darkRed = const Color(0xFF8B0000);

  // Helper method to create a brown circle with an icon
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

  @override
  Widget build(BuildContext context) {
    // Get the screen width and calculate card width (screen width - padding)
    double screenWidth = MediaQuery.of(context).size.width;
    double cardWidth = screenWidth - 32.0; // 16.0 padding on each side

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Account',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Email and Password Card
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email and Password',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ListTile(
                          leading: _buildIcon(Icons.email),
                          title: Text(
                            'Update Email',
                            style: TextStyle(color: primaryColor),
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Update Email tapped')),
                            );
                          },
                        ),
                        const Divider(height: 1, thickness: 1, indent: 50),
                        ListTile(
                          leading: _buildIcon(Icons.lock),
                          title: Text(
                            'Change Password',
                            style: TextStyle(color: primaryColor),
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Change Password tapped')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Account Type Card
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Type',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ListTile(
                          leading: _buildIcon(Icons.account_box),
                          title: Text(
                            'Account Type (Free)',
                            style: TextStyle(color: primaryColor),
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Account Type tapped')),
                            );
                          },
                        ),
                        const Divider(height: 1, thickness: 1, indent: 50),
                        ListTile(
                          leading: _buildIcon(Icons.restore),
                          title: Text(
                            'Restore Purchase',
                            style: TextStyle(color: primaryColor),
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Restore Purchase tapped')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Delete Account Section (Red Column)
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delete Account tapped')),
                  );
                },
                child: Container(
                  width: cardWidth, // Match card width
                  decoration: BoxDecoration(
                    color: darkRed,
                    borderRadius:
                        BorderRadius.circular(12.0), // Match card corner radius
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: const Center(
                    child: Text(
                      'Delete Account and All Data',
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
      ),
    );
  }
}
