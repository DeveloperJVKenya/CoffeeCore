import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/models/activity_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/cycle_stage.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/activity_provider.dart';

/// Add-activity form: type, description, optional quantity/unit, cost,
/// date, and multiple photos uploaded via `ActivityProvider.uploadPhoto`.
class ActivityFormScreen extends StatefulWidget {
  final String farmId;
  final String cycleId;
  final CycleStage stage;

  const ActivityFormScreen({
    super.key,
    required this.farmId,
    required this.cycleId,
    required this.stage,
  });

  @override
  State<ActivityFormScreen> createState() => _ActivityFormScreenState();
}

class _ActivityFormScreenState extends State<ActivityFormScreen> {
  final Logger _log = Logger(printer: PrettyPrinter());
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _costController = TextEditingController();

  ActivityType _type = ActivityType.labour;
  DateTime _date = DateTime.now();
  final List<String> _photoUrls = [];
  bool _isUploadingPhoto = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _descController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final ActivityProvider activityProvider = context.read<ActivityProvider>();
    final XFile? picked =
        await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      final String url = await activityProvider.uploadPhoto(
        fileName: fileName,
        webBytes: kIsWeb ? await picked.readAsBytes() : null,
        nativeFile: kIsWeb ? null : File(picked.path),
      );
      if (!mounted) return;
      setState(() => _photoUrls.add(url));
    } catch (e, st) {
      _log.e('ActivityFormScreen._pickAndUploadPhoto: Error – $e',
          stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to upload photo. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _submit() async {
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description.')),
      );
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You must be signed in to log an activity.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final FarmActivity activity = FarmActivity(
        farmId: widget.farmId,
        cycleId: widget.cycleId,
        userId: user.uid,
        type: _type,
        stage: widget.stage,
        date: _date,
        description: _descController.text.trim(),
        quantity: double.tryParse(_quantityController.text.trim()),
        unit: _unitController.text.trim().isEmpty
            ? null
            : _unitController.text.trim(),
        cost: double.tryParse(_costController.text.trim()) ?? 0,
        photoUrls: _photoUrls,
        createdAt: DateTime.now(),
      );
      if (!mounted) return;
      await context.read<ActivityProvider>().addActivity(activity);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e, st) {
      _log.e('ActivityFormScreen._submit: Error – $e', stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to save activity. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Activity'),
        backgroundColor: FarmTheme.primaryBrown,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(FarmTheme.spaceMd),
        children: [
          DropdownButtonFormField<ActivityType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Activity Type'),
            items: ActivityType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: FarmTheme.spaceSm),
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: FarmTheme.spaceSm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Quantity (optional)'),
                ),
              ),
              const SizedBox(width: FarmTheme.spaceSm),
              Expanded(
                child: TextField(
                  controller: _unitController,
                  decoration:
                      const InputDecoration(labelText: 'Unit (optional)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: FarmTheme.spaceSm),
          TextField(
            controller: _costController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Cost (optional)'),
          ),
          const SizedBox(height: FarmTheme.spaceSm),
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(_date.toIso8601String().substring(0, 10)),
          ),
          const SizedBox(height: FarmTheme.spaceMd),
          Text('Photos (${_photoUrls.length})', style: FarmTheme.cardTitle),
          const SizedBox(height: FarmTheme.spaceSm),
          _buildPhotoSection(),
          const SizedBox(height: FarmTheme.spaceLg),
          ElevatedButton(
            onPressed: _isSaving ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: FarmTheme.primaryBrown,
              minimumSize: const Size.fromHeight(48),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save Activity',
                    style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Wrap(
      spacing: FarmTheme.spaceSm,
      runSpacing: FarmTheme.spaceSm,
      children: [
        for (final url in _photoUrls)
          ClipRRect(
            borderRadius: BorderRadius.circular(FarmTheme.spaceSm),
            child: Image.network(url, width: 72, height: 72, fit: BoxFit.cover),
          ),
        InkWell(
          onTap: _isUploadingPhoto
              ? null
              : () => showModalBottomSheet<void>(
                    context: context,
                    builder: (sheetContext) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.photo_camera),
                            title: const Text('Take Photo'),
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _pickAndUploadPhoto(ImageSource.camera);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.photo_library),
                            title: const Text('Choose from Gallery'),
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _pickAndUploadPhoto(ImageSource.gallery);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: FarmTheme.cardBackground,
              borderRadius: BorderRadius.circular(FarmTheme.spaceSm),
            ),
            child: _isUploadingPhoto
                ? const Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.add_a_photo, color: FarmTheme.primaryBrown),
          ),
        ),
      ],
    );
  }
}
