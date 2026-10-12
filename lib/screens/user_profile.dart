// lib/screens/user_profile.dart
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  UserProfileScreenState createState() => UserProfileScreenState();
}

/// One compression pass: (quality, min dimension).
typedef _CompressionStep = ({int quality, int minSize});

class UserProfileScreenState extends State<UserProfileScreen> {
  // Firestore documents are capped at 1 MiB, so keep the Base64 image well
  // under that (Base64 inflates bytes by ~33%).
  static const int _maxImageBytes = 700 * 1024;
  static const List<_CompressionStep> _compressionSteps = [
    (quality: 70, minSize: 1024),
    (quality: 40, minSize: 800),
    (quality: 20, minSize: 600),
  ];

  final User? user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _countyController = TextEditingController();
  final TextEditingController _constituencyController = TextEditingController();
  final TextEditingController _wardController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final Map<TextEditingController, FocusNode> _focusNodes = {};

  /// Decoded profile image currently shown (from Firestore or a new pick).
  Uint8List? _photoBytes;

  /// Base64 string persisted in Firestore.
  String? _currentPhotoBase64;

  bool _isInitialLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final TextEditingController controller in [
      _nameController,
      _emailController,
      _countyController,
      _constituencyController,
      _wardController,
      _phoneNumberController,
    ]) {
      _focusNodes[controller] = FocusNode();
    }
    if (user == null) {
      _isInitialLoading = false;
      return;
    }
    _loadUserProfile();
  }

  @override
  void dispose() {
    for (final MapEntry<TextEditingController, FocusNode> entry
        in _focusNodes.entries) {
      entry.key.dispose();
      entry.value.dispose();
    }
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection('Users').doc(user!.uid);

  Future<void> _loadUserProfile() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _userDoc.get();
      if (!mounted) return;
      if (!doc.exists) {
        // Fall back to the auth email so a new profile isn't saved blank.
        _emailController.text = user!.email ?? '';
        return;
      }
      final AppUser appUser = AppUser.fromFirestore(doc, null);
      _nameController.text = appUser.fullName;
      _emailController.text =
          appUser.email.isNotEmpty ? appUser.email : (user!.email ?? '');
      _countyController.text = appUser.county;
      _constituencyController.text = appUser.constituency;
      _wardController.text = appUser.ward;
      _phoneNumberController.text = appUser.phoneNumber;
      _currentPhotoBase64 = appUser.profileImage;
      _photoBytes = _decodeBase64Image(appUser.profileImage);
    } catch (e) {
      developer.log('Error loading profile', error: e, name: 'UserProfile');
      _showSnackBar('Error loading profile: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  Uint8List? _decodeBase64Image(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final String raw = value.startsWith('data:image')
          ? value.substring(value.indexOf(',') + 1)
          : value;
      return base64Decode(raw);
    } catch (e) {
      developer.log('Stored profile image is not valid Base64',
          error: e, name: 'UserProfile');
      return null;
    }
  }

  Future<void> _pickImage() async {
    if (_isSaving) return;
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 75,
    );
    if (pickedFile == null) return;

    setState(() => _isSaving = true);
    final Uint8List? previousBytes = _photoBytes;
    try {
      // readAsBytes works on mobile and web (no dart:io File needed).
      final Uint8List original = await pickedFile.readAsBytes();
      final Uint8List compressed = await _compressImage(original);
      final String base64Image = base64Encode(compressed);

      if (mounted) setState(() => _photoBytes = compressed);

      // Only touch the image field so unsaved text edits aren't persisted.
      await _userDoc
          .set({'profileImage': base64Image}, SetOptions(merge: true));
      _currentPhotoBase64 = base64Image;
      _showSnackBar('Profile photo updated!');
    } catch (e) {
      developer.log('Error updating photo', error: e, name: 'UserProfile');
      if (mounted) setState(() => _photoBytes = previousBytes);
      _showSnackBar('Error updating photo: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<Uint8List> _compressImage(Uint8List original) async {
    for (final _CompressionStep step in _compressionSteps) {
      final Uint8List result = await FlutterImageCompress.compressWithList(
        original,
        quality: step.quality,
        minWidth: step.minSize,
        minHeight: step.minSize,
      );
      if (result.isNotEmpty && result.length <= _maxImageBytes) return result;
    }
    throw Exception('Image too large even after compression');
  }

  Future<void> _updateProfile() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final String authEmail = user!.email ?? '';
      final String newEmail = _emailController.text.trim();
      final bool emailChanged = newEmail.isNotEmpty && newEmail != authEmail;

      final AppUser updatedUser = AppUser(
        id: user!.uid,
        fullName: _nameController.text.trim(),
        // Keep the verified auth email in Firestore; the new one only takes
        // effect after the user clicks the verification link.
        email: emailChanged ? authEmail : newEmail,
        county: _countyController.text.trim(),
        constituency: _constituencyController.text.trim(),
        ward: _wardController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
        profileImage: _currentPhotoBase64,
      );
      await _userDoc.set(updatedUser.toMap(), SetOptions(merge: true));

      if (!emailChanged) {
        _showSnackBar('Profile updated successfully!');
        return;
      }

      final String? password = await _promptForPassword();
      if (password == null) {
        _emailController.text = authEmail;
        _showSnackBar('Profile saved. Email change cancelled.');
        return;
      }
      await _updateEmail(password, newEmail);
    } on FirebaseAuthException catch (e) {
      developer.log('Auth error updating profile',
          error: e, name: 'UserProfile');
      _showSnackBar(_authErrorMessage(e), isError: true);
    } catch (e) {
      developer.log('Error updating profile', error: e, name: 'UserProfile');
      _showSnackBar('Error updating profile: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateEmail(String password, String newEmail) async {
    final AuthCredential credential = EmailAuthProvider.credential(
      email: user!.email!,
      password: password,
    );
    await user!.reauthenticateWithCredential(credential);
    await user!.verifyBeforeUpdateEmail(newEmail);
    _showSnackBar(
      'Profile saved. Verification email sent to $newEmail — '
      'your email changes once you confirm it.',
    );
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password. Email was not changed.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'email-already-in-use':
        return 'That email is already used by another account.';
      case 'requires-recent-login':
        return 'Please sign in again before changing your email.';
      default:
        return 'Could not change email: ${e.message ?? e.code}';
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<String?> _promptForPassword() async {
    final TextEditingController passwordController = TextEditingController();
    final String? password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Password'),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter your current password',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final String value = passwordController.text;
                if (value.isEmpty) return;
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    passwordController.dispose();
    return password;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (user == null) {
      return const Center(child: Text('Please log in to view your profile.'));
    }
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Stack(
            children: [
              Hero(
                tag: 'userImage',
                child: CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.grey[300],
                  backgroundImage:
                      _photoBytes != null ? MemoryImage(_photoBytes!) : null,
                  child: _photoBytes == null
                      ? Icon(Icons.person, size: 70, color: Colors.grey[600])
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isSaving ? null : _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.brown[700],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildEditableField(_nameController, 'Full Name', Icons.person),
          const SizedBox(height: 16),
          _buildEditableField(_emailController, 'Email', Icons.email,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildEditableField(_countyController, 'County', Icons.location_city),
          const SizedBox(height: 16),
          _buildEditableField(
              _constituencyController, 'Constituency', Icons.map),
          const SizedBox(height: 16),
          _buildEditableField(_wardController, 'Ward', Icons.place),
          const SizedBox(height: 16),
          _buildEditableField(
              _phoneNumberController, 'Phone Number', Icons.phone,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isSaving ? null : _updateProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text('Update Profile',
                    style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    final FocusNode focusNode = _focusNodes[controller]!;
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            focusNode.requestFocus();
            controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            );
          },
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
