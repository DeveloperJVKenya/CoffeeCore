import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/screens/Farm%20Management/models/dds_readiness_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/farm_mapping_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/field_ledger_pdf_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/geojson_export_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/pdf_download_helper.dart';
import 'package:coffeecore/screens/admin/file_save_stub.dart'
    if (dart.library.html) 'package:coffeecore/screens/admin/file_save_web.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class _FarmerInfo {
  final String uid;
  final String name;
  final String email;

  const _FarmerInfo(
      {required this.uid, required this.name, required this.email});
}

class _FarmerGroup {
  final _FarmerInfo farmer;
  final List<FarmPolygon> farms;

  _FarmerGroup({required this.farmer, required this.farms});
}

/// Admin utility: exports mapped farm polygons as a GeoJSON FeatureCollection
/// with a forest / non-forest ground-truth label per farm, for sharing with
/// external satellite imagery/analytics partners validating an AOI algorithm.
class FarmGeoJsonExportScreen extends StatefulWidget {
  const FarmGeoJsonExportScreen({super.key});

  @override
  State<FarmGeoJsonExportScreen> createState() =>
      _FarmGeoJsonExportScreenState();
}

class _FarmGeoJsonExportScreenState extends State<FarmGeoJsonExportScreen> {
  final _mappingService = FarmMappingService();
  final _logger = Logger(printer: PrettyPrinter());
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<_FarmerGroup> _groups = [];
  final Map<String, bool> _included = {};
  final Map<String, String> _groundTruth = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(
          () => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final farms = await _mappingService.fetchAllFarms();
      final withCoords = farms.where((f) => f.coordinates.length >= 3).toList();

      final usersSnap =
          await FirebaseFirestore.instance.collection('Users').get();
      final farmerLookup = <String, _FarmerInfo>{};
      for (final doc in usersSnap.docs) {
        final data = doc.data();
        farmerLookup[doc.id] = _FarmerInfo(
          uid: doc.id,
          name: (data['fullName'] as String?)?.trim().isNotEmpty == true
              ? data['fullName'] as String
              : 'Unnamed farmer',
          email: data['email'] as String? ?? '',
        );
      }

      final byUser = <String, List<FarmPolygon>>{};
      for (final farm in withCoords) {
        byUser.putIfAbsent(farm.userId, () => []).add(farm);
        _included[farm.farmId!] = true;
        _groundTruth[farm.farmId!] = 'non-forest';
      }

      final groups = byUser.entries.map((e) {
        final farmer = farmerLookup[e.key] ??
            _FarmerInfo(
                uid: e.key, name: 'Unknown farmer (${e.key})', email: '');
        return _FarmerGroup(farmer: farmer, farms: e.value);
      }).toList()
        ..sort((a, b) =>
            a.farmer.name.toLowerCase().compareTo(b.farmer.name.toLowerCase()));

      setState(() {
        _groups = groups;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load farms: $e';
        _loading = false;
      });
    }
  }

  List<_FarmerGroup> get _visibleGroups {
    if (_searchQuery.isEmpty) return _groups;
    return _groups
        .where((g) =>
            g.farmer.name.toLowerCase().contains(_searchQuery) ||
            g.farmer.email.toLowerCase().contains(_searchQuery))
        .toList();
  }

  int get _selectedCount => _included.values.where((v) => v).length;

  bool? _groupSelectionState(_FarmerGroup group) {
    final states = group.farms.map((f) => _included[f.farmId] ?? false).toSet();
    if (states.length == 1) return states.first;
    return null; // mixed
  }

  void _setGroupSelection(_FarmerGroup group, bool value) {
    setState(() {
      for (final farm in group.farms) {
        _included[farm.farmId!] = value;
      }
    });
  }

  Future<void> _generateAndShare() async {
    final allFarms = _groups.expand((g) => g.farms).toList();
    final selections = allFarms
        .map((f) => GeoJsonFarmSelection(
              farm: f,
              included: _included[f.farmId] ?? false,
              groundTruth: _groundTruth[f.farmId] ?? 'non-forest',
            ))
        .toList();

    final featureCollection =
        GeoJsonExportService.buildFeatureCollection(selections);
    final jsonString =
        const JsonEncoder.withIndent('  ').convert(featureCollection);
    final fileName =
        'coffeecore_farm_aois_${DateTime.now().millisecondsSinceEpoch}.geojson';

    try {
      if (kIsWeb) {
        saveTextFileInBrowser(jsonString, fileName, 'application/geo+json');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded $fileName')),
        );
        return;
      }

      String outputDir;
      if (Platform.isAndroid) {
        outputDir = '/storage/emulated/0/Download';
      } else if (Platform.isIOS) {
        outputDir = (await getApplicationDocumentsDirectory()).path;
      } else {
        outputDir = (await getDownloadsDirectory())?.path ??
            (await getApplicationDocumentsDirectory()).path;
      }

      final file = File('$outputDir/$fileName');
      await file.create(recursive: true);
      await file.writeAsString(jsonString);
      _logger.i('GeoJSON saved to ${file.path}');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved $fileName'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () async {
              try {
                await SharePlus.instance.share(ShareParams(
                  files: [XFile(file.path)],
                  text: 'CoffeeCore sample farm AOIs (GeoJSON)',
                ));
              } catch (e) {
                _logger.e('Error sharing GeoJSON: $e');
              }
            },
          ),
        ),
      );
    } catch (e, st) {
      _logger.e('Error generating GeoJSON export: $e', stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating GeoJSON: $e')),
      );
    }
  }

  /// Generates and downloads/shares a single Field Ledger PDF covering
  /// every currently-selected farm — the multi-plot equivalent of the
  /// single-farm download on the EUDR tab (eudr_compliance_tab.dart).
  /// Works cross-platform via PdfDownloadHelper (browser download on web,
  /// saved file + Share action natively), same as the GeoJSON export above.
  Future<void> _generateFieldLedgerPdf() async {
    final allFarms = _groups.expand((g) => g.farms).toList();
    final selectedFarms =
        allFarms.where((f) => _included[f.farmId] ?? false).toList();
    if (selectedFarms.isEmpty) return;

    try {
      final readinessByFarmId = <String, DdsReadiness>{
        for (final farm in selectedFarms)
          farm.farmId!: DdsReadiness.evaluate(farm),
      };

      final bytes = await FieldLedgerPdfService.buildMultiFarmLedger(
        selectedFarms,
        readinessByFarmId,
      );
      final fileName =
          'coffeecore_field_ledger_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = await PdfDownloadHelper.saveBytes(bytes, fileName);

      if (!mounted) return;
      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded $fileName')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved $fileName'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () => PdfDownloadHelper.share(
              file,
              text: 'CoffeeCore Field Ledger (${selectedFarms.length} plot(s))',
            ),
          ),
        ),
      );
    } catch (e, st) {
      _logger.e('Error generating Field Ledger PDF: $e', stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating Field Ledger: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Farm AOIs (GeoJSON)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
        actions: (_loading || _groups.isEmpty)
            ? null
            : [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.checklist),
                  tooltip: 'Select / clear',
                  onSelected: (value) {
                    setState(() {
                      final allFarms = _groups.expand((g) => g.farms);
                      for (final farm in allFarms) {
                        _included[farm.farmId!] = value == 'all';
                      }
                    });
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                        value: 'all',
                        child: Text('Select all farmers\' farms')),
                    PopupMenuItem(value: 'none', child: Text('Clear all')),
                  ],
                ),
              ],
      ),
      body: _buildBody(),
      floatingActionButton: (_loading || _groups.isEmpty)
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'geojson-export',
                  onPressed: _selectedCount == 0 ? null : _generateAndShare,
                  backgroundColor: Colors.brown[700],
                  icon: const Icon(Icons.file_download, color: Colors.white),
                  label: Text('GeoJSON ($_selectedCount)',
                      style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'field-ledger-export',
                  onPressed:
                      _selectedCount == 0 ? null : _generateFieldLedgerPdf,
                  backgroundColor: Colors.brown[900],
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                  label: Text('Field Ledger ($_selectedCount)',
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_groups.isEmpty) {
      return const Center(
        child: Text('No mapped farms with a valid polygon were found.'),
      );
    }
    final groups = _visibleGroups;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.brown[50],
          padding: const EdgeInsets.all(12),
          child: const Text(
            'Tap a farmer to expand their farms and check individual plots, '
            'or use their header checkbox to select all of that farmer\'s '
            'farms at once. Use the menu (top right) to select or clear '
            'every farmer at once. Ground truth defaults to "non-forest" '
            '(cultivated coffee land) — override any plot with real '
            'forest/shade cover.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search farmer by name or email',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        Expanded(
          child: groups.isEmpty
              ? const Center(child: Text('No farmers match your search.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: groups.length,
                  itemBuilder: (context, index) =>
                      _buildFarmerGroup(groups[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildFarmerGroup(_FarmerGroup group) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        leading: Checkbox(
          tristate: true,
          value: _groupSelectionState(group),
          onChanged: (v) => _setGroupSelection(group, v ?? true),
        ),
        title: Text(group.farmer.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${group.farmer.email.isNotEmpty ? '${group.farmer.email} · ' : ''}'
          '${group.farms.length} farm(s)',
        ),
        children: group.farms.map((farm) => _buildFarmTile(farm)).toList(),
      ),
    );
  }

  Widget _buildFarmTile(FarmPolygon farm) {
    final id = farm.farmId!;
    return CheckboxListTile(
      value: _included[id] ?? false,
      onChanged: (v) => setState(() => _included[id] = v ?? false),
      title: Text(farm.farmName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${farm.areaLabel} · ${farm.coordinates.length} vertices'),
          if (farm.eudrCompliance != null)
            Text(
              'GFW: was forested before 2020 = '
              '${farm.eudrCompliance!.wasForestedBefore2020}, '
              'tree cover 2000 = '
              '${farm.eudrCompliance!.treeCoverPercent2000.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
          const SizedBox(height: 6),
          DropdownButton<String>(
            value: _groundTruth[id],
            isDense: true,
            items: const [
              DropdownMenuItem(value: 'non-forest', child: Text('Non-forest')),
              DropdownMenuItem(value: 'forest', child: Text('Forest')),
            ],
            onChanged: (v) =>
                setState(() => _groundTruth[id] = v ?? 'non-forest'),
          ),
        ],
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
