import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'coffee_soil_input_page.dart';
import 'coffee_soil_summary_page.dart';
import 'dart:developer' as developer;

class CoffeeSoilHomePage extends StatefulWidget {
  const CoffeeSoilHomePage({super.key});

  @override
  State<CoffeeSoilHomePage> createState() => _CoffeeSoilHomePageState();
}

class _CoffeeSoilHomePageState extends State<CoffeeSoilHomePage> {
  bool _isNavigating = false;

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF3C2F2F),
        title: const Text(
          'Soil Management',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            developer.log('Back button pressed', name: 'CoffeeSoilHomePage');
            Navigator.pop(context);
          },
        ),
      ),
      backgroundColor: const Color(0xFFF5E8C7),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCard(
              context,
              'Enter Soil Data',
              'Record soil data for your coffee plots.',
              () => _navigate(context, () => const CoffeeSoilInputPage()),
            ),
            _buildCard(
              context,
              'Soil History',
              'View saved soil data and interventions.',
              () => _navigate(context, () {
                if (userId.isNotEmpty) {
                  return CoffeeSoilSummaryPage(userId: userId);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please log in to view soil history.'),
                        backgroundColor: Color(0xFF4A2C2A),
                      ),
                    );
                  }
                  return null;
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, Widget? Function() pageBuilder) {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    final startTime = DateTime.now();
    developer.log(
        'Navigating to ${pageBuilder() != null ? pageBuilder().runtimeType.toString() : "null"}',
        name: 'CoffeeSoilHomePage');

    final page = pageBuilder();
    if (page != null) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration:
              const Duration(milliseconds: 200), // Faster transition
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      ).then((_) {
        setState(() => _isNavigating = false);
        final duration = DateTime.now().difference(startTime).inMilliseconds;
        developer.log('Navigation completed in $duration ms',
            name: 'CoffeeSoilHomePage');
      });
    } else {
      setState(() => _isNavigating = false);
    }
  }

  Widget _buildCard(
    BuildContext context,
    String title,
    String description,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: () {
          developer.log('Tapped card: $title', name: 'CoffeeSoilHomePage');
          onTap();
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A2C2A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF3A5F0B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
