import 'package:coffeecore/screens/Disease%20Management/coffee_disease_management.dart';
//import 'package:coffeecore/screens/Pest%20Management/coffee_pest_management_page.dart';
import 'package:coffeecore/screens/Symptom%20Analysis/coffee_symptom_checker_page.dart';
import 'package:coffeecore/screens/pests/coffee_pest_management_page.dart';
import 'package:flutter/material.dart';

class PestDiseaseHomePage extends StatelessWidget {
  const PestDiseaseHomePage({super.key});

  static final Color coffeeBrown = Colors.brown[700]!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Coffee Pest & Disease Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: coffeeBrown,
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth <= 600;
          final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 900;
          final cardWidth = isMobile
              ? constraints.maxWidth * 0.85
              : isTablet
                  ? constraints.maxWidth * 0.75
                  : constraints.maxWidth * 0.65;
          final padding = isMobile ? 16.0 : isTablet ? 24.0 : 32.0;
          final fontSizeTitle = isMobile ? 18.0 : isTablet ? 20.0 : 22.0;

          return Container(
            color: Colors.brown[50],
            child: SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Choose the item to manage on your coffee farm:',
                    style: TextStyle(
                      fontSize: fontSizeTitle,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: padding * 1.5),
                  _buildOptionCard(
                    context,
                    'Manage Coffee Pests',
                    Icons.bug_report,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CoffeePestManagementPage()),
                    ),
                    cardWidth,
                  ),
                  SizedBox(height: padding),
                  _buildOptionCard(
                    context,
                    'Manage Coffee Diseases',
                    Icons.local_hospital,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CoffeeDiseaseManagementPage()),
                    ),
                    cardWidth,
                  ),
                  SizedBox(height: padding),
                  _buildOptionCard(
                    context,
                    'Identify Issue by Symptoms',
                    Icons.search,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CoffeeSymptomCheckerPage()),
                    ),
                    cardWidth,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
    double cardWidth,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: cardWidth,
            minWidth: 200, // Minimum width to prevent cards from becoming too narrow
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: coffeeBrown),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}