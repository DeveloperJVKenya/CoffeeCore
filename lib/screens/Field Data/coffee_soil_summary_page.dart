import 'dart:developer' as developer;
import 'package:coffeecore/models/coffee_soil_data.dart';
import 'package:coffeecore/screens/Field%20Data/helpers/nutrient_analysis_helper.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';

class CoffeeSoilSummaryPage extends StatefulWidget {
  final String userId;

  const CoffeeSoilSummaryPage({required this.userId, super.key});

  @override
  State<CoffeeSoilSummaryPage> createState() => _CoffeeSoilSummaryPageState();
}

class _CoffeeSoilSummaryPageState extends State<CoffeeSoilSummaryPage> {
  String _selectedFilter = 'All';
  bool _isPerPlant = false;
  final List<String> _filterOptions = ['All', 'With Recommendations', 'Without Recommendations'];
  static const List<String> _soilTypes = [
    'Volcanic', 'Red', 'Alluvial', 'Forest', 'Laterite'
  ];

  @override
  void initState() {
    super.initState();
    developer.log('Initializing CoffeeSoilSummaryPage for user: ${widget.userId}', name: 'CoffeeSoilSummaryPage');
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    _loadCachedData();
    _syncUnsyncedChanges();
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_soil_data_${widget.userId}');
      if (cachedData != null) {
        developer.log('Loaded cached soil data for user: ${widget.userId}', name: 'CoffeeSoilSummaryPage');
      } else {
        developer.log('No cached soil data found for user: ${widget.userId}', name: 'CoffeeSoilSummaryPage');
      }
    } catch (e, stackTrace) {
      developer.log('Error loading cached data: $e', name: 'CoffeeSoilSummaryPage', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error loading cached data. Please try again.'),
            backgroundColor: Color(0xFF4A2C2A),
          ),
        );
      }
    }
  }

  Future<bool> _isConnected() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = !connectivityResult.contains(ConnectivityResult.none);
      developer.log('Connectivity check: isOnline=$isOnline, result=$connectivityResult',
          name: 'CoffeeSoilSummaryPage');
      return isOnline;
    } catch (e, stackTrace) {
      developer.log('Error checking connectivity: $e', name: 'CoffeeSoilSummaryPage', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error checking connectivity. Assuming offline.'),
            backgroundColor: Color(0xFF4A2C2A),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _syncUnsyncedChanges() async {
    try {
      final isOnline = await _isConnected();
      if (!isOnline && mounted) {
        developer.log('Device offline, skipping sync', name: 'CoffeeSoilSummaryPage');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device offline. Changes will sync when online.'),
            backgroundColor: Color(0xFF4A2C2A),
          ),
        );
        return;
      }

      developer.log('Starting sync of unsynced changes for user: ${widget.userId}', name: 'CoffeeSoilSummaryPage');
      final prefs = await SharedPreferences.getInstance();
      final unsyncedEdits = prefs.getStringList('unsynced_edits_${widget.userId}') ?? [];
      final unsyncedDeletions = prefs.getStringList('unsynced_deletions_${widget.userId}') ?? [];

      developer.log('Found ${unsyncedEdits.length} unsynced edits and ${unsyncedDeletions.length} unsynced deletions',
          name: 'CoffeeSoilSummaryPage');

      for (final edit in unsyncedEdits) {
        final decoded = jsonDecode(edit) as Map<String, dynamic>;
        final docId = decoded['docId'] as String;
        final soilDataMap = decoded['data'] as Map<String, dynamic>;
        await FirebaseFirestore.instance
            .collection('SoilData')
            .doc(docId)
            .set(soilDataMap, SetOptions(merge: true));
        developer.log('Synced edit for doc: $docId', name: 'CoffeeSoilSummaryPage');
      }

      for (final deletion in unsyncedDeletions) {
        final docId = deletion;
        await FirebaseFirestore.instance.collection('SoilData').doc(docId).update({'isDeleted': true});
        developer.log('Synced deletion for doc: $docId', name: 'CoffeeSoilSummaryPage');
      }

      await prefs.setStringList('unsynced_edits_${widget.userId}', []);
      await prefs.setStringList('unsynced_deletions_${widget.userId}', []);

      if (mounted && (unsyncedEdits.isNotEmpty || unsyncedDeletions.isNotEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offline changes synced successfully'),
            backgroundColor: Color(0xFF4A2C2A),
          ),
        );
      }
      developer.log('Sync completed successfully', name: 'CoffeeSoilSummaryPage');
    } catch (e, stackTrace) {
      developer.log('Error syncing unsynced changes: $e', name: 'CoffeeSoilSummaryPage', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to sync offline changes. Please try again later.'),
            backgroundColor: Color(0xFF4A2C2A),
          ),
        );
      }
    }
  }

  Stream<QuerySnapshot> _getFilteredStream() {
    try {
      developer.log('Creating filtered stream for user: ${widget.userId}, filter: $_selectedFilter',
          name: 'CoffeeSoilSummaryPage');

      Query query = FirebaseFirestore.instance
          .collection('SoilData')
          .where('userId', isEqualTo: widget.userId)
          .where('isDeleted', isEqualTo: false);

      if (_selectedFilter == 'With Recommendations') {
        query = query.where('saveWithRecommendations', isEqualTo: true);
      } else if (_selectedFilter == 'Without Recommendations') {
        query = query.where('saveWithRecommendations', isEqualTo: false);
      }

      query = query.orderBy('timestamp', descending: true);

      developer.log('Query created successfully', name: 'CoffeeSoilSummaryPage');
      return query.snapshots();
    } catch (e, stackTrace) {
      developer.log('Error creating filtered stream: $e', name: 'CoffeeSoilSummaryPage', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

Future<void> _editSoilData(BuildContext context, CoffeeSoilData entry, String docId) async {
  try {
    developer.log('Starting edit for document: $docId', name: 'CoffeeSoilSummaryPage');

    final controllers = {
      'pH': TextEditingController(text: entry.ph?.toString()),
      'nitrogen': TextEditingController(text: entry.nitrogen?.toString()),
      'phosphorus': TextEditingController(text: entry.phosphorus?.toString()),
      'potassium': TextEditingController(text: entry.potassium?.toString()),
      'magnesium': TextEditingController(text: entry.magnesium?.toString()),
      'calcium': TextEditingController(text: entry.calcium?.toString()),
      'zinc': TextEditingController(text: entry.zinc?.toString()),
      'boron': TextEditingController(text: entry.boron?.toString()),
      'plantDensity': TextEditingController(text: entry.plantDensity.toString()),
      'interventionMethod': TextEditingController(text: entry.interventionMethod),
      'interventionQuantity': TextEditingController(text: entry.interventionQuantity),
      'interventionUnit': TextEditingController(text: entry.interventionUnit),
    };
    String? selectedSoilType = entry.soilType;
    String selectedStage = entry.stage;
    DateTime? interventionFollowUpDate = entry.interventionFollowUpDate?.toDate();
    bool saveWithRecommendations = entry.saveWithRecommendations;

    // Store context in a local variable
    final localContext = context;

    final result = await showDialog<bool>(
      context: localContext,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
            maxWidth: MediaQuery.of(dialogContext).size.width * 0.95,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF0E4D7),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Edit Soil Data',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A2C2A),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      icon: const Icon(Icons.close, color: Color(0xFF4A2C2A)),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Soil Type Section
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedSoilType,
                          decoration: const InputDecoration(
                            labelText: 'Soil Type (Optional)',
                            border: OutlineInputBorder(),
                            labelStyle: TextStyle(color: Color(0xFF3A5F0B)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Select Soil Type', style: TextStyle(color: Color(0xFF3A5F0B))),
                            ),
                            ..._soilTypes.map((soilType) => DropdownMenuItem(
                                  value: soilType,
                                  child: Text(soilType, style: const TextStyle(color: Color(0xFF3A5F0B))),
                                )),
                          ],
                          onChanged: (value) {
                            selectedSoilType = value;
                            developer.log('Selected soil type: $value', name: 'CoffeeSoilSummaryPage');
                          },
                        ),
                      ),
                      
                      // Growth Stage Section
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedStage,
                          decoration: const InputDecoration(
                            labelText: 'Growth Stage',
                            border: OutlineInputBorder(),
                            labelStyle: TextStyle(color: Color(0xFF3A5F0B)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'Establishment/Seedling',
                                child: Text('Establishment/Seedling', style: TextStyle(color: Color(0xFF3A5F0B)))),
                            DropdownMenuItem(
                                value: 'Vegetative Growth', child: Text('Vegetative Growth', style: TextStyle(color: Color(0xFF3A5F0B)))),
                            DropdownMenuItem(
                                value: 'Flowering and Fruiting',
                                child: Text('Flowering and Fruiting', style: TextStyle(color: Color(0xFF3A5F0B)))),
                            DropdownMenuItem(
                                value: 'Maturation and Harvesting',
                                child: Text('Maturation and Harvesting', style: TextStyle(color: Color(0xFF3A5F0B)))),
                          ],
                          onChanged: (value) {
                            selectedStage = value ?? 'Establishment/Seedling';
                            developer.log('Selected stage: $value', name: 'CoffeeSoilSummaryPage');
                          },
                        ),
                      ),
                      
                      // Plant Density Section
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: TextFormField(
                          controller: controllers['plantDensity'],
                          decoration: const InputDecoration(
                            labelText: 'Plant Density (plants/acre)',
                            border: OutlineInputBorder(),
                            labelStyle: TextStyle(color: Color(0xFF3A5F0B)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) =>
                              value == null || int.tryParse(value) == null ? 'Enter a valid number' : null,
                        ),
                      ),
                      
                      // Macronutrients Section
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Macronutrients', 
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold, 
                                color: Color(0xFF4A2C2A)
                              )
                            ),
                            const SizedBox(height: 12),
                            ...['pH', 'nitrogen', 'phosphorus', 'potassium', 'magnesium', 'calcium'].map((nutrient) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: TextFormField(
                                controller: controllers[nutrient],
                                decoration: InputDecoration(
                                  labelText: '${nutrient.toUpperCase()} ${NutrientAnalysisHelper.getNutrientUnit(nutrient, false)}',
                                  border: const OutlineInputBorder(),
                                  labelStyle: const TextStyle(color: Color(0xFF3A5F0B)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) =>
                                    value != null && value.isNotEmpty && double.tryParse(value) == null
                                        ? 'Enter a valid number'
                                        : null,
                              ),
                            )),
                          ],
                        ),
                      ),
                      
                      // Micronutrients Section
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Micronutrients', 
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold, 
                                color: Color(0xFF4A2C2A)
                              )
                            ),
                            const SizedBox(height: 12),
                            ...['zinc', 'boron'].map((nutrient) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: TextFormField(
                                controller: controllers[nutrient],
                                decoration: InputDecoration(
                                  labelText: '${nutrient.toUpperCase()} ${NutrientAnalysisHelper.getNutrientUnit(nutrient, false)}',
                                  border: const OutlineInputBorder(),
                                  labelStyle: const TextStyle(color: Color(0xFF3A5F0B)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) =>
                                    value != null && value.isNotEmpty && double.tryParse(value) == null
                                        ? 'Enter a valid number'
                                        : null,
                              ),
                            )),
                          ],
                        ),
                      ),
                      
                      // Intervention Section
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Intervention', 
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold, 
                                color: Color(0xFF4A2C2A)
                              )
                            ),
                            const SizedBox(height: 12),
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: TextFormField(
                                controller: controllers['interventionMethod'],
                                decoration: const InputDecoration(
                                  labelText: 'Intervention Method (Optional)',
                                  border: OutlineInputBorder(),
                                  labelStyle: TextStyle(color: Color(0xFF3A5F0B)),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                maxLines: 2,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    child: TextFormField(
                                      controller: controllers['interventionQuantity'],
                                      decoration: const InputDecoration(
                                        labelText: 'Quantity (Optional)',
                                        border: OutlineInputBorder(),
                                        labelStyle: TextStyle(color: Color(0xFF3A5F0B)),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    child: TextFormField(
                                      controller: controllers['interventionUnit'],
                                      decoration: const InputDecoration(
                                        labelText: 'Unit (Optional)',
                                        border: OutlineInputBorder(),
                                        labelStyle: TextStyle(color: Color(0xFF3A5F0B)),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: localContext,
                                  initialDate: interventionFollowUpDate ?? DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  interventionFollowUpDate = picked;
                                  developer.log('Selected follow-up date: $picked', name: 'CoffeeSoilSummaryPage');
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, color: Color(0xFF3A5F0B), size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        interventionFollowUpDate != null
                                            ? 'Follow-up: ${interventionFollowUpDate!.toString().substring(0, 10)}'
                                            : 'No Follow-up Date',
                                        style: const TextStyle(color: Color(0xFF3A5F0B)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Save Options Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Save with Recommendations', style: TextStyle(color: Color(0xFF4A2C2A))),
                          subtitle: const Text('Include all recommendations in saved data',
                              style: TextStyle(color: Color(0xFF3A5F0B), fontSize: 12)),
                          value: saveWithRecommendations,
                          onChanged: (value) {
                            saveWithRecommendations = value ?? false;
                            developer.log('Save with recommendations: $value', name: 'CoffeeSoilSummaryPage');
                          },
                          activeColor: const Color(0xFF4A2C2A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Footer with action buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF4A2C2A))),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A2C2A),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true && localContext.mounted) {
      final plantDensity = int.tryParse(controllers['plantDensity']!.text) ?? entry.plantDensity;
      final recommendations = <String, Map<String, String>>{};
      final nutrients = [
        'pH',
        'nitrogen',
        'phosphorus',
        'potassium',
        'magnesium',
        'calcium',
        'zinc',
        'boron'
      ];

      if (saveWithRecommendations) {
        for (final nutrient in nutrients) {
          final value = controllers[nutrient]!.text.isNotEmpty ? double.tryParse(controllers[nutrient]!.text) : null;
          if (value != null) {
            final status = NutrientAnalysisHelper.getNutrientStatus(nutrient, value, selectedStage);
            if (status != 'Optimal') {
              recommendations[nutrient] = NutrientAnalysisHelper.getRecommendations(
                nutrient,
                status,
                selectedStage,
                selectedSoilType,
                _isPerPlant,
                plantDensity,
              );
              developer.log('Generated recommendations for $nutrient: $status', name: 'CoffeeSoilSummaryPage');
            }
          }
        }
      }

      final updatedData = CoffeeSoilData(
        userId: widget.userId,
        plotId: entry.plotId,
        stage: selectedStage,
        soilType: selectedSoilType,
        ph: controllers['pH']!.text.isNotEmpty ? double.parse(controllers['pH']!.text) : null,
        nitrogen: controllers['nitrogen']!.text.isNotEmpty ? double.parse(controllers['nitrogen']!.text) : null,
        phosphorus: controllers['phosphorus']!.text.isNotEmpty ? double.parse(controllers['phosphorus']!.text) : null,
        potassium: controllers['potassium']!.text.isNotEmpty ? double.parse(controllers['potassium']!.text) : null,
        magnesium: controllers['magnesium']!.text.isNotEmpty ? double.parse(controllers['magnesium']!.text) : null,
        calcium: controllers['calcium']!.text.isNotEmpty ? double.parse(controllers['calcium']!.text) : null,
        zinc: controllers['zinc']!.text.isNotEmpty ? double.parse(controllers['zinc']!.text) : null,
        boron: controllers['boron']!.text.isNotEmpty ? double.parse(controllers['boron']!.text) : null,
        plantDensity: plantDensity,
        interventionMethod:
            controllers['interventionMethod']!.text.isNotEmpty ? controllers['interventionMethod']!.text : null,
        interventionQuantity:
            controllers['interventionQuantity']!.text.isNotEmpty ? controllers['interventionQuantity']!.text : null,
        interventionUnit:
            controllers['interventionUnit']!.text.isNotEmpty ? controllers['interventionUnit']!.text : null,
        interventionFollowUpDate: interventionFollowUpDate != null ? Timestamp.fromDate(interventionFollowUpDate!) : null,
        notificationTriggered: entry.notificationTriggered,
        recommendations: saveWithRecommendations ? recommendations : null,
        saveWithRecommendations: saveWithRecommendations,
        timestamp: Timestamp.now(),
        isDeleted: false,
      );

      final isOnline = await _isConnected();
      if (localContext.mounted) { // Check if the context is still mounted before proceeding
        if (isOnline) {
          await FirebaseFirestore.instance
              .collection('SoilData')
              .doc(docId)
              .set(updatedData.toMap(), SetOptions(merge: true));
          developer.log('Successfully updated soil data in Firestore for doc: $docId', name: 'CoffeeSoilSummaryPage');

          if (localContext.mounted) { // Check again before showing the SnackBar
            ScaffoldMessenger.of(localContext).showSnackBar(
              const SnackBar(
                content: Text('Soil data updated successfully'),
                backgroundColor: Color(0xFF4A2C2A),
              ),
            );
          }
        } else {
          final prefs = await SharedPreferences.getInstance();
          final unsyncedEdits = prefs.getStringList('unsynced_edits_${widget.userId}') ?? [];
          unsyncedEdits.add(jsonEncode({'docId': docId, 'data': updatedData.toMap()}));
          await prefs.setStringList('unsynced_edits_${widget.userId}', unsyncedEdits);
          developer.log('Saved edit locally for doc: $docId', name: 'CoffeeSoilSummaryPage');

          if (localContext.mounted) { // Check again before showing the SnackBar
            ScaffoldMessenger.of(localContext).showSnackBar(
              const SnackBar(
                content: Text('Changes saved locally, will sync when online'),
                backgroundColor: Color(0xFF4A2C2A),
              ),
            );
          }
        }
      }

      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
  } catch (e, stackTrace) {
    developer.log('Error editing soil data: $e', name: 'CoffeeSoilSummaryPage', error: e, stackTrace: stackTrace);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save changes. Please try again.'),
          backgroundColor: Color(0xFF4A2C2A),
        ),
      );
    }
  }
}

  Future<void> _deleteSoilData(BuildContext context, String docId) async {
    try {
      developer.log('Starting delete for document: $docId', name: 'CoffeeSoilSummaryPage');

      // Store the context in a local variable
      final localContext = context;

      final confirm = await showDialog<bool>(
        context: localContext,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Deletion', style: TextStyle(color: Color(0xFF4A2C2A))),
          content: const Text('Are you sure you want to delete this soil analysis entry? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(localContext, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF4A2C2A))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(localContext, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      // Check if the dialog was confirmed and if the widget is still mounted
      if (confirm != true) return;

      final isOnline = await _isConnected();

      if (isOnline) {
        await FirebaseFirestore.instance.collection('SoilData').doc(docId).update({'isDeleted': true});
        developer.log('Successfully deleted soil data in Firestore for doc: $docId', name: 'CoffeeSoilSummaryPage');

        // Check if the widget is still mounted before using the context
        if (localContext.mounted) {
          ScaffoldMessenger.of(localContext).showSnackBar(
            const SnackBar(
              content: Text('Soil analysis entry deleted'),
              backgroundColor: Color(0xFF4A2C2A),
            ),
          );
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        final unsyncedDeletions = prefs.getStringList('unsynced_deletions_${widget.userId}') ?? [];
        unsyncedDeletions.add(docId);
        await prefs.setStringList('unsynced_deletions_${widget.userId}', unsyncedDeletions);
        developer.log('Saved deletion locally for doc: $docId', name: 'CoffeeSoilSummaryPage');

        // Check if the widget is still mounted before using the context
        if (localContext.mounted) {
          ScaffoldMessenger.of(localContext).showSnackBar(
            const SnackBar(
              content: Text('Deletion saved locally, will sync when online'),
              backgroundColor: Color(0xFF4A2C2A),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      developer.log('Error deleting soil data: $e', name: 'CoffeeSoilSummaryPage', error: e, stackTrace: stackTrace);

      // Check if the widget is still mounted before using the context
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to delete soil data. Please try again.'),
            backgroundColor: Color(0xFF4A2C2A),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF3C2F2F),
        title: const Text(
          'Enhanced Soil History',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            developer.log('Navigating back from CoffeeSoilSummaryPage', name: 'CoffeeSoilSummaryPage');
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(_isPerPlant ? Icons.person : Icons.landscape, color: Colors.white),
            onPressed: () {
              setState(() {
                _isPerPlant = !_isPerPlant;
              });
              developer.log('Toggled unit display: ${_isPerPlant ? "per plant" : "per acre"}',
                  name: 'CoffeeSoilSummaryPage');
            },
            tooltip: _isPerPlant ? 'Switch to per acre' : 'Switch to per plant',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Container(
            color: const Color(0xFFF0E4D7),
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedFilter,
              decoration: const InputDecoration(
                labelText: 'Filter by',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                labelStyle: TextStyle(color: Color(0xFF3A5F0B)),
              ),
              items: _filterOptions
                  .map((filter) => DropdownMenuItem(
                        value: filter,
                        child: Text(filter, style: const TextStyle(color: Color(0xFF3A5F0B))),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedFilter = value ?? 'All';
                });
                developer.log('Filter changed to: $value', name: 'CoffeeSoilSummaryPage');
              },
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF5E8C7),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getFilteredStream(),
        builder: (context, snapshot) {
          developer.log('StreamBuilder state: ${snapshot.connectionState}', name: 'CoffeeSoilSummaryPage');

          if (snapshot.connectionState == ConnectionState.waiting) {
            developer.log('Loading soil data...', name: 'CoffeeSoilSummaryPage');
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            developer.log('Error loading data: ${snapshot.error}', name: 'CoffeeSoilSummaryPage', error: snapshot.error);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading data',
                    style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                      developer.log('Retrying data load...', name: 'CoffeeSoilSummaryPage');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A2C2A),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            developer.log('No snapshot data available', name: 'CoffeeSoilSummaryPage');
            return const Center(child: Text('No data available'));
          }

          final docs = snapshot.data!.docs;
          developer.log('Retrieved ${docs.length} documents from Firestore', name: 'CoffeeSoilSummaryPage');

          if (docs.isEmpty) {
            developer.log('No soil data found for user: ${widget.userId}', name: 'CoffeeSoilSummaryPage');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.eco, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No soil data available',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start by adding your first soil analysis',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          try {
            final entries = docs.map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                developer.log('Processing document: ${doc.id}', name: 'CoffeeSoilSummaryPage');
                return CoffeeSoilData.fromMap(data);
              } catch (e, stackTrace) {
                developer.log('Error parsing document ${doc.id}: $e',
                    name: 'CoffeeSoilSummaryPage', error: e, stackTrace: stackTrace);
                rethrow;
              }
            }).toList();

            developer.log('Successfully parsed ${entries.length} soil data entries', name: 'CoffeeSoilSummaryPage');

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                try {
                  return _buildEnhancedSoilCard(entries[index], docs[index].id);
                } catch (e, stackTrace) {
                  developer.log('Error building card for index $index: $e',
                      name: 'CoffeeSoilSummaryPage', error: e, stackTrace: stackTrace);
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.error, color: Colors.red),
                      title: const Text('Error loading this entry'),
                      subtitle: Text('Error: $e'),
                    ),
                  );
                }
              },
            );
          } catch (e, stackTrace) {
            developer.log('Error processing documents: $e',
                name: 'CoffeeSoilSummaryPage', error: e, stackTrace: stackTrace);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Error processing data',
                    style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error: $e',
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildEnhancedSoilCard(CoffeeSoilData entry, String docId) {
    try {
      final hasRecommendations = entry.recommendations != null && entry.recommendations!.isNotEmpty;

      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey[50]!,
              ],
            ),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.all(16),
            childrenPadding: const EdgeInsets.all(16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A5F0B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    entry.plotId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (hasRecommendations)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lightbulb, size: 12, color: Colors.blue[800]),
                        const SizedBox(width: 4),
                        Text(
                          'RECS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  entry.stage,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A2C2A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy • HH:mm').format(entry.timestamp.toDate()),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.notificationTriggered)
                  const Icon(Icons.notifications_active, color: Colors.green, size: 20),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editSoilData(context, entry, docId);
                    } else if (value == 'delete') {
                      _deleteSoilData(context, docId);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            children: [
              SingleChildScrollView(
                child: _buildNutrientDataSection(entry),
              ),
              if (entry.interventionMethod != null) ...[
                const SizedBox(height: 16),
                _buildInterventionSection(entry),
              ],
              if (hasRecommendations) ...[
                const SizedBox(height: 16),
                _buildRecommendationsSection(entry.recommendations!),
              ],
            ]
          ),
        ),
      );
    } catch (e, stackTrace) {
      developer.log('Error building enhanced soil card: $e',
          name: 'CoffeeSoilSummaryPage', error: e, stackTrace: stackTrace);
      return Card(
        child: ListTile(
          leading: const Icon(Icons.error, color: Colors.red),
          title: const Text('Error displaying this entry'),
          subtitle: Text('Error: $e'),
        ),
      );
    }
  }

  Widget _buildNutrientDataSection(CoffeeSoilData entry) {
    final nutrients = [
      {'name': 'pH', 'value': entry.ph, 'unit': ''},
      {'name': 'Nitrogen', 'value': entry.nitrogen, 'unit': _isPerPlant ? 'mg/plant' : 'kg/acre'},
      {'name': 'Phosphorus', 'value': entry.phosphorus, 'unit': _isPerPlant ? 'mg/plant' : 'kg/acre'},
      {'name': 'Potassium', 'value': entry.potassium, 'unit': _isPerPlant ? 'mg/plant' : 'kg/acre'},
      {'name': 'Magnesium', 'value': entry.magnesium, 'unit': _isPerPlant ? 'mg/plant' : 'kg/acre'},
      {'name': 'Calcium', 'value': entry.calcium, 'unit': _isPerPlant ? 'mg/plant' : 'kg/acre'},
      {'name': 'Zinc', 'value': entry.zinc, 'unit': _isPerPlant ? 'mg/plant' : 'g/acre'},
      {'name': 'Boron', 'value': entry.boron, 'unit': _isPerPlant ? 'mg/plant' : 'g/acre'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.science, color: Color(0xFF3A5F0B), size: 20),
                const SizedBox(width: 8),
                const Expanded( // Wrap text in Expanded to prevent overflow
                  child: Text(
                    'Nutrient Analysis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A2C2A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8), // Add spacing before the container
                Flexible( // Make the plant density container flexible
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), // Reduced padding
                    decoration: BoxDecoration(
                      color: Color(0xFF3A5F0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${entry.plantDensity} plants/acre',
                      style: const TextStyle(
                        fontSize: 11, // Slightly smaller font
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF3A5F0B),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
            if (entry.soilType != null) ...[
              const SizedBox(height: 12),
              Text(
                'Soil Type: ${entry.soilType}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2C2A)),
              ),
            ],
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.0, // Further reduced to give more height
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: nutrients.length,
              itemBuilder: (context, index) {
                final nutrient = nutrients[index];
                final value = nutrient['value'] as double?;
                if (value == null) return const SizedBox.shrink();

                final displayValue = _isPerPlant && nutrient['name'] != 'pH'
                    ? NutrientAnalysisHelper.convertToPerPlant(
                        nutrient['name'].toString().toLowerCase(), value, entry.plantDensity)
                    : value;
                final status = NutrientAnalysisHelper.getNutrientStatus(
                  nutrient['name'].toString().toLowerCase(),
                  value,
                  entry.stage,
                );

                return Container(
                  padding: const EdgeInsets.all(6), // Reduced padding from 8 to 6
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getStatusColor(status).withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center, // Changed back to center
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Nutrient name - no Flexible wrapper to avoid clipping
                      Text(
                        nutrient['name'].toString(),
                        style: const TextStyle(
                          fontSize: 11, // Slightly smaller font
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4A2C2A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4), // Reduced spacing
                      // Value row with proper overflow handling
                      Row(
                        children: [
                          // Value and unit in a single text widget to avoid splitting issues
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: displayValue.toStringAsFixed(nutrient['name'] == 'pH' ? 1 : 2),
                                    style: const TextStyle(
                                      fontSize: 13, // Slightly smaller font
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF3A5F0B),
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' ${nutrient['unit'].toString()}',
                                    style: TextStyle(
                                      fontSize: 9, // Smaller unit text
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1, // Reduced to 1 line to prevent overflow
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Status indicator (fixed size)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterventionSection(CoffeeSoilData entry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.build, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                'Intervention Applied',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A2C2A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFieldRow('Method', entry.interventionMethod ?? 'N/A'),
          if (entry.interventionQuantity != null && entry.interventionUnit != null)
            _buildFieldRow('Quantity', '${entry.interventionQuantity} ${entry.interventionUnit}'),
          if (entry.interventionFollowUpDate != null)
            _buildFieldRow(
              'Follow-up Date',
              DateFormat('MMM dd, yyyy').format(entry.interventionFollowUpDate!.toDate()),
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection(Map<String, dynamic> recommendations) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Saved Recommendations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A2C2A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recommendations.entries.map((entry) => _buildRecommendationCard(
                entry.key,
                entry.value as Map<String, dynamic>,
              )),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(String nutrient, Map<String, dynamic> recommendations) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        title: Text(
          nutrient.toUpperCase(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4A2C2A),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: recommendations.entries.map((rec) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getRecommendationTypeTitle(rec.key),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getRecommendationTypeColor(rec.key),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rec.value.toString(),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF3A5F0B)),
                        ),
                      ],
                    ),
                  )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF4A2C2A),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF3A5F0B),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRecommendationTypeTitle(String type) {
    switch (type) {
      case 'natural':
        return '🌱 Natural';
      case 'biological':
        return '🦠 Biological';
      case 'artificial':
        return '⚗️ Artificial';
      case 'application':
        return '📋 Application';
      case 'maintain':
        return '✅ Maintain';
      case 'avoid':
        return '⚠️ Avoid';
      default:
        return type.toUpperCase();
    }
  }

  Color _getRecommendationTypeColor(String type) {
    switch (type) {
      case 'natural':
        return Colors.green;
      case 'biological':
        return Colors.blue;
      case 'artificial':
        return Colors.orange;
      case 'application':
        return Colors.purple;
      case 'maintain':
        return Colors.teal;
      case 'avoid':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Low':
        return Colors.red;
      case 'High':
        return Colors.orange;
      case 'Optimal':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}