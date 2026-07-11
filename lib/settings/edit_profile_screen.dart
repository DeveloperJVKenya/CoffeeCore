import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:coffeecore/settings/providers/user_profile_provider.dart';

Color? primaryColor = Colors.brown[700];

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  String _appTheme = 'System';
  String _unitSystem = 'Metric (sqm)';
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    final userProfile = Provider.of<UserProfile>(context, listen: false);
    _profileImage = userProfile.profileImagePath != null
        ? File(userProfile.profileImagePath!)
        : null;
  }

  Widget _buildIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primaryColor,
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text(
                  '${source == ImageSource.camera ? "Camera" : "Photo Library"} image selected')),
        );
      }
    } else if (mounted) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('No image selected')),
      );
    }
  }

  void _showProfilePictureBottomSheet(BuildContext context) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          height: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Take Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: _buildIcon(Icons.camera_alt),
                title: Text(
                  'Camera',
                  style: TextStyle(color: primaryColor),
                ),
                onTap: () => Navigator.pop(dialogContext, ImageSource.camera),
              ),
              ListTile(
                leading: _buildIcon(Icons.photo_library),
                title: Text(
                  'Photo Library',
                  style: TextStyle(color: primaryColor),
                ),
                onTap: () => Navigator.pop(dialogContext, ImageSource.gallery),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(dialogContext, null),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: const Center(
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (source != null && mounted) {
      await _pickImage(source);
    }
  }

  void _showAppThemeBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              height: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Theme',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    secondary: _buildIcon(Icons.brightness_auto),
                    title:
                        Text('System', style: TextStyle(color: primaryColor)),
                    value: 'System',
                    // ignore: deprecated_member_use
                    groupValue: _appTheme,
                    activeColor: primaryColor,
                    // ignore: deprecated_member_use
                    onChanged: (value) {
                      setModalState(() {
                        _appTheme = value!;
                      });
                      setState(() {
                        _appTheme = value!;
                      });
                    },
                  ),
                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    secondary: _buildIcon(Icons.wb_sunny),
                    title: Text('Light', style: TextStyle(color: primaryColor)),
                    value: 'Light',
                    // ignore: deprecated_member_use
                    groupValue: _appTheme,
                    activeColor: primaryColor,
                    // ignore: deprecated_member_use
                    onChanged: (value) {
                      setModalState(() {
                        _appTheme = value!;
                      });
                      setState(() {
                        _appTheme = value!;
                      });
                    },
                  ),
                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    secondary: _buildIcon(Icons.nightlight_round),
                    title: Text('Dark', style: TextStyle(color: primaryColor)),
                    value: 'Dark',
                    // ignore: deprecated_member_use
                    groupValue: _appTheme,
                    activeColor: primaryColor,
                    // ignore: deprecated_member_use
                    onChanged: (value) {
                      setModalState(() {
                        _appTheme = value!;
                      });
                      setState(() {
                        _appTheme = value!;
                      });
                    },
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: const Center(
                        child: Text(
                          'Close',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showUnitSystemBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              height: 250,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unit System',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    secondary: _buildIcon(Icons.straighten),
                    title: Text('Imperial (acres)',
                        style: TextStyle(color: primaryColor)),
                    value: 'Imperial (acres)',
                    // ignore: deprecated_member_use
                    groupValue: _unitSystem,
                    activeColor: primaryColor,
                    // ignore: deprecated_member_use
                    onChanged: (value) {
                      setModalState(() {
                        _unitSystem = value!;
                      });
                      setState(() {
                        _unitSystem = value!;
                      });
                    },
                  ),
                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    secondary: _buildIcon(Icons.square_foot),
                    title: Text('Metric (sqm)',
                        style: TextStyle(color: primaryColor)),
                    value: 'Metric (sqm)',
                    // ignore: deprecated_member_use
                    groupValue: _unitSystem,
                    activeColor: primaryColor,
                    // ignore: deprecated_member_use
                    onChanged: (value) {
                      setModalState(() {
                        _unitSystem = value!;
                      });
                      setState(() {
                        _unitSystem = value!;
                      });
                    },
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: const Center(
                        child: Text(
                          'Close',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _saveProfile(BuildContext context) {
    final userProfile = Provider.of<UserProfile>(context, listen: false);
    userProfile.updateProfile(
      profileImagePath: _profileImage?.path,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double cardWidth = screenWidth - 32.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        actions: [
          TextButton(
            onPressed: () => _saveProfile(context),
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  _showProfilePictureBottomSheet(context);
                },
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _profileImage != null ? null : primaryColor,
                        image: _profileImage != null
                            ? DecorationImage(
                                image: FileImage(_profileImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _profileImage == null
                          ? const Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    GestureDetector(
                      onTap: () {
                        _showProfilePictureBottomSheet(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor,
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Name and About',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ListTile(
                            leading: _buildIcon(Icons.person),
                            title: Text(
                              'Display Name',
                              style: TextStyle(color: primaryColor),
                            ),
                            trailing: Icon(Icons.arrow_forward_ios,
                                size: 16, color: primaryColor),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const EditDisplayNameScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            leading: _buildIcon(Icons.info),
                            title: Text(
                              'About',
                              style: TextStyle(color: primaryColor),
                            ),
                            trailing: Icon(Icons.arrow_forward_ios,
                                size: 16, color: primaryColor),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const AboutScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Current Location: Not Set',
                            style: TextStyle(color: primaryColor, fontSize: 16),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Update Location tapped')),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10.0, horizontal: 16.0),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildIcon(Icons.location_on),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Update Location',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'System Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ListTile(
                            leading: _buildIcon(Icons.brightness_6),
                            title: Text(
                              'App Theme',
                              style: TextStyle(color: primaryColor),
                            ),
                            trailing: Icon(Icons.arrow_forward_ios,
                                size: 16, color: primaryColor),
                            onTap: () {
                              _showAppThemeBottomSheet(context);
                            },
                          ),
                          const Divider(height: 1, thickness: 1, indent: 50),
                          ListTile(
                            leading: _buildIcon(Icons.straighten),
                            title: Text(
                              'Unit System',
                              style: TextStyle(color: primaryColor),
                            ),
                            trailing: Icon(Icons.arrow_forward_ios,
                                size: 16, color: primaryColor),
                            onTap: () {
                              _showUnitSystemBottomSheet(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class EditDisplayNameScreen extends StatefulWidget {
  const EditDisplayNameScreen({super.key});

  @override
  State<EditDisplayNameScreen> createState() => _EditDisplayNameScreenState();
}

class _EditDisplayNameScreenState extends State<EditDisplayNameScreen> {
  late TextEditingController _displayNameController;

  @override
  void initState() {
    super.initState();
    final userProfile = Provider.of<UserProfile>(context, listen: false);
    _displayNameController =
        TextEditingController(text: userProfile.displayName);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  void _saveDisplayName(BuildContext context) {
    final userProfile = Provider.of<UserProfile>(context, listen: false);
    userProfile.updateProfile(displayName: _displayNameController.text);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double cardWidth = screenWidth - 32.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Display Name',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Display Name',
                          style: TextStyle(color: primaryColor, fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _displayNameController,
                          decoration: InputDecoration(
                            labelText: 'Enter your display name',
                            labelStyle: TextStyle(color: primaryColor),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _saveDisplayName(context),
                child: Container(
                  width: cardWidth,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: const Center(
                    child: Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late TextEditingController _aboutController;

  @override
  void initState() {
    super.initState();
    final userProfile = Provider.of<UserProfile>(context, listen: false);
    _aboutController = TextEditingController(text: userProfile.about ?? '');
  }

  @override
  void dispose() {
    _aboutController.dispose();
    super.dispose();
  }

  void _saveAbout(BuildContext context) {
    final userProfile = Provider.of<UserProfile>(context, listen: false);
    userProfile.updateProfile(about: _aboutController.text);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double cardWidth = screenWidth - 32.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit About Text',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About (Optional)',
                          style: TextStyle(color: primaryColor, fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _aboutController,
                          decoration: InputDecoration(
                            labelText: 'Enter your about text',
                            labelStyle: TextStyle(color: primaryColor),
                            border: const OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _saveAbout(context),
                child: Container(
                  width: cardWidth,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: const Center(
                    child: Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
