import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:coffeecore/models/coffee_pest_models.dart';
import 'package:coffeecore/models/intervention_category.dart';
import 'package:coffeecore/screens/pests/coffee_view_interventions_page.dart';
import 'package:timezone/timezone.dart' as tz;

class CoffeeInterventionPage extends StatefulWidget {
  final CoffeePestData pestData;
  final String cropStage;
  final FlutterLocalNotificationsPlugin notificationsPlugin;

  const CoffeeInterventionPage({
    required this.pestData,
    required this.cropStage,
    required this.notificationsPlugin,
    super.key,
  });

  @override
  State<CoffeeInterventionPage> createState() => _CoffeeInterventionPageState();
}

class _CoffeeInterventionPageState extends State<CoffeeInterventionPage> {
  static const Color _brand = Color(0xFF6F4E37);

  final _interventionController = TextEditingController();
  final _amountController = TextEditingController();
  final _areaController = TextEditingController();
  bool _useSQM = false;

  /// Suggested-method text → category, built once from the pest's known
  /// control lists. Lookup key is lower-cased/trimmed for tolerant matching.
  late final Map<String, InterventionCategory> _suggestionCategories = {
    for (final s in widget.pestData.chemicalControls)
      s.trim().toLowerCase(): InterventionCategory.chemical,
    for (final s in widget.pestData.mechanicalControls)
      s.trim().toLowerCase(): InterventionCategory.mechanical,
    for (final s in widget.pestData.biologicalControls)
      s.trim().toLowerCase(): InterventionCategory.biological,
  };

  InterventionCategory? _selectedCategory;
  bool _categoryFromSuggestion = false;

  void _onInterventionTextChanged(String text) {
    final key = text.trim().toLowerCase();
    final matched = _suggestionCategories[key];
    if (matched != null) {
      setState(() {
        _selectedCategory = matched;
        _categoryFromSuggestion = true;
      });
    } else if (_categoryFromSuggestion) {
      // Text no longer matches a suggestion — fall back to manual picking.
      setState(() {
        _selectedCategory = null;
        _categoryFromSuggestion = false;
      });
    }
  }

  void _pickSuggestion(String text, InterventionCategory category) {
    setState(() {
      _interventionController.text = text;
      _selectedCategory = category;
      _categoryFromSuggestion = true;
    });
  }

  Future<void> _saveIntervention() async {
    final user = FirebaseAuth.instance.currentUser;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (user == null) {
      scaffoldMessenger
          .showSnackBar(const SnackBar(content: Text('Please log in')));
      return;
    }

    if (_interventionController.text.isEmpty &&
        _amountController.text.isEmpty &&
        _areaController.text.isEmpty) {
      scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Please fill at least one field')));
      return;
    }

    if (_interventionController.text.trim().isNotEmpty &&
        _selectedCategory == null) {
      scaffoldMessenger.showSnackBar(const SnackBar(
          content:
              Text('Please choose a category for this intervention (Chemical, '
                  'Mechanical, Biological or Other)')));
      return;
    }

    // A follow-up re-check is only meaningful when a solution was actually
    // logged (not just an area/amount-only entry).
    final hasIntervention = _interventionController.text.trim().isNotEmpty;
    final followUpDueAt =
        hasIntervention ? DateTime.now().add(const Duration(days: 7)) : null;

    final docRef = FirebaseFirestore.instance
        .collection('coffee_pest_interventions')
        .doc();

    final intervention = CoffeePestIntervention(
      id: docRef.id,
      pestName: widget.pestData.name,
      cropStage: widget.cropStage,
      intervention: _interventionController.text,
      category: _selectedCategory ?? InterventionCategory.other,
      area: _areaController.text.isNotEmpty
          ? double.tryParse(_areaController.text)
          : null,
      areaUnit: _useSQM ? 'SQM' : 'Acres',
      timestamp: Timestamp.now(),
      userId: user.uid,
      isDeleted: false,
      amount: _amountController.text.isNotEmpty ? _amountController.text : null,
      followUpDueAt: followUpDueAt,
    );

    try {
      await docRef.set(intervention.toMap());

      await FirebaseFirestore.instance.collection('User_logs').add({
        'userId': user.uid,
        'action': 'create',
        'collection': 'coffee_pest_interventions',
        'documentId': docRef.id,
        'timestamp': Timestamp.now(),
        'details': 'Created intervention for ${widget.pestData.name}',
      });

      if (followUpDueAt != null) {
        await _scheduleFollowUpReminder(docRef.id, followUpDueAt);
      }

      setState(() {
        _interventionController.clear();
        _amountController.clear();
        _areaController.clear();
        _selectedCategory = null;
        _categoryFromSuggestion = false;
      });
      scaffoldMessenger.showSnackBar(SnackBar(
          content: Text(followUpDueAt != null
              ? 'Intervention saved — check-in reminder set for '
                  '${followUpDueAt.day}/${followUpDueAt.month}/${followUpDueAt.year}'
              : 'Intervention saved successfully')));
    } catch (e) {
      scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error saving intervention: $e')));
    }
  }

  Future<void> _scheduleFollowUpReminder(
      String interventionId, DateTime dueAt) async {
    const androidDetails = AndroidNotificationDetails(
      'coffee_pest_followup_channel',
      'Coffee Pest Follow-Up Reminders',
      channelDescription: 'Reminders for coffee pest intervention follow-ups',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    try {
      await widget.notificationsPlugin.zonedSchedule(
        id: interventionId.hashCode,
        title: 'Time to check on ${widget.pestData.name}',
        body: 'It\'s been a week — see how your crop responded and log the '
            'outcome.',
        scheduledDate: tz.TZDateTime.from(dueAt, tz.local),
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // Non-critical — the in-app "due for check-in" badge still works even
      // if the OS notification couldn't be scheduled (e.g. permission denied).
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Pest Intervention',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.grey[200],
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_suggestionCategories.isNotEmpty) ...[
                _buildSuggestedMethods(),
                const SizedBox(height: 16),
              ],
              _buildTextField('Intervention Used', _interventionController,
                  'e.g., Chemical control',
                  onChanged: _onInterventionTextChanged),
              if (_interventionController.text.trim().isNotEmpty &&
                  !_categoryFromSuggestion) ...[
                const SizedBox(height: 10),
                _buildCategoryPicker(),
              ] else if (_selectedCategory != null) ...[
                const SizedBox(height: 10),
                _buildSelectedCategoryBadge(),
              ],
              const SizedBox(height: 16),
              _buildTextField(
                  'Amount Applied', _amountController, 'e.g., 5 ml'),
              const SizedBox(height: 16),
              _buildTextField(
                'Total Area Affected',
                _areaController,
                _useSQM ? 'e.g., 100 (SQM)' : 'e.g., 100 (Acres)',
                isNumber: true,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Use Square Meters (SQM)',
                    style: TextStyle(color: Colors.black87)),
                value: _useSQM,
                onChanged: (value) => setState(() => _useSQM = value),
                activeThumbColor: _brand,
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _saveIntervention,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Intervention',
                        style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CoffeeViewInterventionsPage(
                          pestData: widget.pestData,
                          notificationsPlugin: widget.notificationsPlugin,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('View Saved Interventions',
                        style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestedMethods() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Suggested methods for this pest',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            if (widget.pestData.chemicalControls.isNotEmpty)
              _buildSuggestionGroup(
                  'Chemical',
                  widget.pestData.chemicalControls,
                  InterventionCategory.chemical),
            if (widget.pestData.mechanicalControls.isNotEmpty)
              _buildSuggestionGroup(
                  'Mechanical',
                  widget.pestData.mechanicalControls,
                  InterventionCategory.mechanical),
            if (widget.pestData.biologicalControls.isNotEmpty)
              _buildSuggestionGroup(
                  'Biological',
                  widget.pestData.biologicalControls,
                  InterventionCategory.biological),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionGroup(
      String label, List<String> options, InterventionCategory category) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _categoryColor(category))),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final selected =
                  _interventionController.text.trim().toLowerCase() ==
                      option.trim().toLowerCase();
              return ChoiceChip(
                label: Text(option, style: const TextStyle(fontSize: 12)),
                selected: selected,
                selectedColor: _categoryColor(category).withValues(alpha: 0.18),
                side: BorderSide(
                    color: selected
                        ? _categoryColor(category)
                        : Colors.grey.shade300),
                onSelected: (_) => _pickSuggestion(option, category),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPicker() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Categorize your own entry:',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: InterventionCategory.values.map((category) {
              final selected = _selectedCategory == category;
              return ChoiceChip(
                label:
                    Text(category.label, style: const TextStyle(fontSize: 12)),
                selected: selected,
                selectedColor: _categoryColor(category).withValues(alpha: 0.2),
                side: BorderSide(
                    color: selected
                        ? _categoryColor(category)
                        : Colors.grey.shade300),
                onSelected: (_) => setState(() {
                  _selectedCategory = category;
                  _categoryFromSuggestion = false;
                }),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCategoryBadge() {
    final category = _selectedCategory!;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _categoryColor(category).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('Category: ${category.label}',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _categoryColor(category))),
      ),
    );
  }

  Color _categoryColor(InterventionCategory category) {
    switch (category) {
      case InterventionCategory.chemical:
        return const Color(0xFFB0763F);
      case InterventionCategory.mechanical:
        return const Color(0xFF5B7FA6);
      case InterventionCategory.biological:
        return const Color(0xFF5B8A4A);
      case InterventionCategory.other:
        return Colors.grey.shade600;
    }
  }

  Widget _buildTextField(
      String label, TextEditingController controller, String hint,
      {bool isNumber = false, ValueChanged<String>? onChanged}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
