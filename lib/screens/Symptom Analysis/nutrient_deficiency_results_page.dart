import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Field%20Data/coffee_soil_home_page.dart';
import 'package:coffeecore/screens/Symptom%20Analysis/nutrient_deficiency_details.dart';
import 'package:coffeecore/screens/Symptom%20Analysis/symptom_checker_ai_service.dart';

/// Shows the top-ranked possible nutrient deficiencies for the farmer's
/// selected symptoms — deliberately NOT a single forced "best match" the
/// way pest/disease results are, since several coffee nutrient deficiencies
/// share very similar visual symptoms. Framed throughout as "possible
/// indicators", with the primary action being an actual soil test, which is
/// the only way to reliably confirm a deficiency.
class NutrientDeficiencyResultsPage extends StatelessWidget {
  final List<String> selectedSymptoms;

  const NutrientDeficiencyResultsPage({
    required this.selectedSymptoms,
    super.key,
  });

  static const Color _brand = Color(0xFF3A5F0B);

  @override
  Widget build(BuildContext context) {
    final candidates =
        SymptomCheckerAiService.rankNutrientCandidates(selectedSymptoms);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Possible Nutrient Deficiency',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.brown[50],
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'These are possible indicators based on visible symptoms '
                        'only — several nutrient deficiencies look similar. '
                        'Confirm with a soil test before applying any '
                        'fertilizer.',
                        style:
                            TextStyle(fontSize: 12.5, color: Colors.brown[800]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (candidates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No specific nutrient could be matched from the selected '
                    'symptoms — a soil test is the most reliable next step.',
                    style: TextStyle(fontSize: 13.5, color: Colors.brown[700]),
                  ),
                )
              else
                for (final candidate in candidates)
                  _NutrientCard(nutrientKey: candidate.name),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CoffeeSoilHomePage()),
                  ),
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Test Your Soil'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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

class _NutrientCard extends StatelessWidget {
  final String nutrientKey;

  const _NutrientCard({required this.nutrientKey});

  @override
  Widget build(BuildContext context) {
    final details = kNutrientDeficiencyDetails[nutrientKey];
    if (details == null) return const SizedBox.shrink();

    final visualSymptoms = (details['visualSymptoms'] as List).cast<String>();
    final correctiveMeasures =
        (details['correctiveMeasures'] as List).cast<String>();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(details['displayName'] as String? ?? nutrientKey,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3A5F0B))),
            const SizedBox(height: 6),
            Text(details['description'] as String? ?? '',
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
            const SizedBox(height: 12),
            const Text('Typical visual symptoms',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            const SizedBox(height: 6),
            ...visualSymptoms.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  ', style: TextStyle(fontSize: 12.5)),
                      Expanded(
                          child:
                              Text(s, style: const TextStyle(fontSize: 12.5))),
                    ],
                  ),
                )),
            const SizedBox(height: 10),
            const Text('Corrective measures',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            const SizedBox(height: 6),
            ...correctiveMeasures.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  ', style: TextStyle(fontSize: 12.5)),
                      Expanded(
                          child:
                              Text(s, style: const TextStyle(fontSize: 12.5))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
