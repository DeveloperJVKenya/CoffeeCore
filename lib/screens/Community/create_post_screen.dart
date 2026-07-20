import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:coffeecore/screens/Community/community_enums.dart';
import 'package:coffeecore/screens/Community/community_storage_service.dart';
import 'package:coffeecore/screens/Community/community_strings.dart';
import 'package:coffeecore/screens/Community/fade_slide_in_widget.dart';
import 'providers.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  static const _maxWidth = 640.0;
  final Logger _logger = Logger(printer: PrettyPrinter());

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  PostType _type = PostType.discussion;
  PostCategory _category = PostCategory.general;
  CropCategory? _cropCategory;
  final List<XFile> _images = [];
  final _picker = ImagePicker();
  final _storageService = CommunityStorageService();

  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= CommunityStorageService.maxImagesPerPost) return;
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null && mounted) {
      setState(() => _images.add(picked));
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final repo = ref.read(communityRepositoryProvider);
      final post = await repo.createPost(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
        crop: _cropCategory,
        type: _type,
      );

      if (_images.isNotEmpty) {
        final urls = await _storageService.uploadPostImages(
            postId: post.id, images: _images);
        await repo.attachImages(postId: post.id, imageUrls: urls);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (error, stackTrace) {
      _logSubmitFailure(error, stackTrace);
      if (!mounted) return;
      setState(() {
        // Form data is intentionally left intact so the user can retry
        // without retyping — posting is the only thing connectivity
        // should block, not drafting.
        _submitError = _friendlyError(error);
        _isSubmitting = false;
      });
    }
  }

  String _friendlyError(Object e) {
    final message = e.toString().toLowerCase();
    if (message.contains('network') ||
        message.contains('unavailable') ||
        message.contains('socket')) {
      return "Couldn't reach the server — check your connection and try again. Your draft is still here.";
    }
    return "Something went wrong while posting. Your draft is still here — try again.";
  }

  void _logSubmitFailure(Object error, StackTrace stackTrace) {
    if (error is FirebaseException) {
      _logger.e(
        'Create post failed with FirebaseException code=${error.code}, message=${error.message}',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    _logger.e(
      'Create post failed with ${error.runtimeType}: $error',
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = CommunityStrings.of(ref);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EE),
      appBar: AppBar(
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(strings.newPostTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxWidth),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      children: [
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          alignment: Alignment.topCenter,
                          child: _submitError == null
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _ErrorBanner(message: _submitError!),
                                ),
                        ),
                        FadeSlideIn(
                          index: 0,
                          child: _buildSection(
                            strings.postTypeLabel,
                            _PostTypeToggle(
                              value: _type,
                              discussionLabel: strings.discussion,
                              questionLabel: strings.question,
                              onChanged: (t) => setState(() => _type = t),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FadeSlideIn(
                          index: 1,
                          child: _buildSection(
                            strings.titleLabel,
                            TextFormField(
                              controller: _titleController,
                              maxLength: 120,
                              textInputAction: TextInputAction.next,
                              decoration: _fieldDecoration(
                                hint: _type == PostType.question
                                    ? 'e.g. Why are my Arabica leaves yellowing?'
                                    : 'e.g. Best time to prune this season?',
                              ),
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return strings.titleRequired;
                                if (v.length < 6) {
                                  return strings.titleTooShort;
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FadeSlideIn(
                          index: 2,
                          child: _buildSection(
                            strings.descriptionLabel,
                            TextFormField(
                              controller: _descriptionController,
                              maxLength: 2000,
                              minLines: 5,
                              maxLines: 10,
                              textInputAction: TextInputAction.newline,
                              decoration: _fieldDecoration(
                                hint: _type == PostType.question
                                    ? 'Describe the problem — crop, symptoms, what you\'ve already tried…'
                                    : 'Share the details…',
                              ),
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) {
                                  return strings.descriptionRequired;
                                }
                                if (v.length < 20) {
                                  return strings.descriptionTooShort;
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FadeSlideIn(
                          index: 3,
                          child: _buildSection(
                            strings.categoryLabel,
                            _CategoryChips(
                              selected: _category,
                              onSelected: (c) => setState(() => _category = c),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FadeSlideIn(
                          index: 4,
                          child: _buildSection(
                            strings.cropOptionalLabel,
                            _CropChips(
                              selected: _cropCategory,
                              onSelected: (c) =>
                                  setState(() => _cropCategory = c),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FadeSlideIn(
                          index: 5,
                          child: _buildSection(
                            strings.photosOptionalLabel,
                            _ImagePickerRow(
                              images: _images,
                              onAdd: _pickImage,
                              onRemove: _removeImage,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Submit button fixed at bottom — animated in last, after the
            // form sections above have finished staggering into place.
            FadeSlideIn(
              index: 6,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxWidth),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.brown[700],
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.brown[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _isSubmitting
                              ? const SizedBox(
                                  key: ValueKey('spinner'),
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  strings.post,
                                  key: const ValueKey('label'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String label, Widget control) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 8),
        control,
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.brown[800],
      ),
    );
  }

  InputDecoration _fieldDecoration({required String hint}) {
    final radius = BorderRadius.circular(12);
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      counterStyle: TextStyle(color: Colors.grey[500], fontSize: 11),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border:
          OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Colors.brown[700]!, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}

class _PostTypeToggle extends StatelessWidget {
  final PostType value;
  final String discussionLabel;
  final String questionLabel;
  final ValueChanged<PostType> onChanged;

  const _PostTypeToggle({
    required this.value,
    required this.discussionLabel,
    required this.questionLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PostType>(
      segments: [
        ButtonSegment(
          value: PostType.discussion,
          label: Text(discussionLabel),
          icon: const Icon(Icons.forum_outlined, size: 18),
        ),
        ButtonSegment(
          value: PostType.question,
          label: Text(questionLabel),
          icon: const Icon(Icons.help_outline, size: 18),
        ),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: Colors.brown[700],
        selectedForegroundColor: Colors.white,
        foregroundColor: Colors.brown[700],
        side: BorderSide(color: Colors.brown[700]!),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final PostCategory selected;
  final ValueChanged<PostCategory> onSelected;

  const _CategoryChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PostCategory.values.map((category) {
        final isSelected = category == selected;
        final color = category.color;
        return ChoiceChip(
          label: Text(category.label),
          selected: isSelected,
          onSelected: (_) => onSelected(category),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
          backgroundColor: Colors.white,
          selectedColor: color,
          side:
              BorderSide(color: color.withValues(alpha: isSelected ? 1 : 0.5)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        );
      }).toList(),
    );
  }
}

class _CropChips extends StatelessWidget {
  final CropCategory? selected;
  final ValueChanged<CropCategory?> onSelected;

  const _CropChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final brown = Colors.brown[700]!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('None'),
          selected: selected == null,
          onSelected: (_) => onSelected(null),
          labelStyle: TextStyle(
            color: selected == null ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
          backgroundColor: Colors.white,
          selectedColor: Colors.grey[600],
          side: BorderSide(color: Colors.grey.shade400),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        ...CropCategory.values.map((crop) {
          final isSelected = crop == selected;
          return ChoiceChip(
            label: Text(crop.label),
            selected: isSelected,
            onSelected: (_) => onSelected(crop),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : brown,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
            backgroundColor: Colors.white,
            selectedColor: brown,
            side: BorderSide(
                color: brown.withValues(alpha: isSelected ? 1 : 0.5)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          );
        }),
      ],
    );
  }
}

class _ImagePickerRow extends StatelessWidget {
  final List<XFile> images;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _ImagePickerRow({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final canAddMore = images.length < CommunityStorageService.maxImagesPerPost;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < images.length; i++)
          _ImageThumbnail(image: images[i], onRemove: () => onRemove(i)),
        if (canAddMore)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(Icons.add_a_photo_outlined, color: Colors.brown[700]),
            ),
          ),
      ],
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final XFile image;
  final VoidCallback onRemove;

  const _ImageThumbnail({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(image.path),
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                  color: Colors.black87, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off, size: 16, color: Colors.orange[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: Colors.orange[800]),
            ),
          ),
        ],
      ),
    );
  }
}
