// lib/coffeecore/user_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io';
import 'dart:convert';
import 'package:coffeecore/models/user_model.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  UserProfileScreenState createState() => UserProfileScreenState();
}

class UserProfileScreenState extends State<UserProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _countyController = TextEditingController();
  final TextEditingController _constituencyController = TextEditingController();
  final TextEditingController _wardController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  File? _imageFile;
  String? _currentPhotoUrl; // Stores Base64 string
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  late Stream<DocumentSnapshot> _userStream;

  @override
  void initState() {
    super.initState();
    if (user != null) {
      _userStream = _firestore.collection('Users').doc(user!.uid).snapshots();
      _loadUserProfile();
    }
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      DocumentSnapshot<Map<String, dynamic>> doc =
          await _firestore.collection('Users').doc(user!.uid).get();
      if (doc.exists) {
        AppUser appUser = AppUser.fromFirestore(doc, null);
        setState(() {
          _nameController.text = appUser.fullName;
          _emailController.text = appUser.email;
          _countyController.text = appUser.county;
          _constituencyController.text = appUser.constituency;
          _wardController.text = appUser.ward;
          _phoneNumberController.text = appUser.phoneNumber;
          _currentPhotoUrl = appUser.profileImage; // Base64 string or null
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error loading profile: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 75,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      await _updateProfile(imageOnly: true); // Update only image
    }
  }

  Future<String> _convertImageToBase64(File imageFile) async {
    try {
      List<int>? compressedImage = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );

      double sizeInMb = compressedImage!.length / (1024 * 1024);
      if (sizeInMb > 0.7) {
        compressedImage = await FlutterImageCompress.compressWithFile(
          imageFile.absolute.path,
          quality: 40,
          minWidth: 800,
          minHeight: 800,
        );

        sizeInMb = (compressedImage!.length / (1024 * 1024));
        if (sizeInMb > 0.7) {
          compressedImage = await FlutterImageCompress.compressWithFile(
            imageFile.absolute.path,
            quality: 20,
            minWidth: 600,
            minHeight: 600,
          );

          if (compressedImage!.length / (1024 * 1024) > 0.7) {
            throw Exception('Image too large even after compression');
          }
        }
      }
      return base64Encode(compressedImage);
    } catch (e) {
      throw Exception('Error converting image: $e');
    }
  }

  Future<void> _updateProfile({bool imageOnly = false}) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      String? photoBase64;

      if (_imageFile != null) {
        photoBase64 = await _convertImageToBase64(_imageFile!);
        _currentPhotoUrl = photoBase64; // Update local Base64 string
      }

      // Create or update Firestore document
      AppUser updatedUser = AppUser(
        id: user!.uid,
        fullName: _nameController.text,
        email: _emailController.text,
        county: _countyController.text,
        constituency: _constituencyController.text,
        ward: _wardController.text,
        phoneNumber: _phoneNumberController.text,
        profileImage:
            photoBase64 ?? _currentPhotoUrl, // Use new or existing Base64
      );

      // Use set() with merge to create/update document
      await _firestore.collection('Users').doc(user!.uid).set(
            updatedUser.toMap(),
            SetOptions(
                merge: true), // Merge to avoid overwriting unchanged fields
          );

      if (!imageOnly && _emailController.text != user?.email) {
        String? password = await _promptForPassword();
        if (password != null) {
          await _updateEmail(password);
        }
      }

      await user?.reload();

      if (!mounted) return;

      setState(() => _isLoading = false);
      _showSuccessSnackBar('Profile updated successfully!');
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error updating profile: $e');
    }
  }

  Future<void> _updateEmail(String password) async {
    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: password,
      );

      await user?.reauthenticateWithCredential(credential);
      await user?.verifyBeforeUpdateEmail(_emailController.text);

      if (mounted) {
        _showSuccessSnackBar(
            'Verification email sent to ${_emailController.text}');
      }
    } catch (e) {
      throw Exception('Failed to update email: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<String?> _promptForPassword() async {
    String? password;
    await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Password'),
          content: TextField(
            onChanged: (value) => password = value,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Enter your current password',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, password),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
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
                        backgroundImage: _getProfileImage(),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
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
                _buildEditableField(_emailController, 'Email', Icons.email),
                const SizedBox(height: 16),
                _buildEditableField(
                    _countyController, 'County', Icons.location_city),
                const SizedBox(height: 16),
                _buildEditableField(
                    _constituencyController, 'Constituency', Icons.map),
                const SizedBox(height: 16),
                _buildEditableField(_wardController, 'Ward', Icons.place),
                const SizedBox(height: 16),
                _buildEditableField(
                    _phoneNumberController, 'Phone Number', Icons.phone),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _updateProfile(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 30),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Update Profile',
                          style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  ImageProvider? _getProfileImage() {
    if (_imageFile != null) {
      return FileImage(_imageFile!);
    } else if (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty) {
      // Decode Base64 string to display image
      if (_currentPhotoUrl!.startsWith('data:image')) {
        // Handle if Base64 includes MIME type prefix
        final base64String = _currentPhotoUrl!.split(',')[1];
        return MemoryImage(base64Decode(base64String));
      }
      return MemoryImage(base64Decode(_currentPhotoUrl!));
    }
    return null;
  }

  Widget _buildEditableField(
      TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            FocusScope.of(context).requestFocus(FocusNode());
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
