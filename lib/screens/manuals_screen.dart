import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/models/manual.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:coffeecore/home.dart';

class ManualsScreen extends StatefulWidget {
  const ManualsScreen({super.key});

  @override
  State<ManualsScreen> createState() => _ManualsScreenState();
}

class _ManualsScreenState extends State<ManualsScreen> {
  final logger = Logger(printer: PrettyPrinter());
  final TextEditingController _titleController = TextEditingController();
  double? _uploadProgress;
  String _selectedCategory = 'Coffee Farming';
  String _currentRole = 'User';
  bool _canUpload = false;
  bool _canDelete = false;

  static const Map<String, String> manualCategories = {
    'Coffee Farming': 'Coffee Farming',
    'Pest Management': 'Pest Management',
    'Disease Management': 'Disease Management',
    'Soil Management': 'Soil Management',
    'Harvesting': 'Harvesting',
    'Processing': 'Processing',
    'Quality Control': 'Quality Control',
    'Equipment': 'Equipment',
    'General': 'General',
  };

  static final Color coffeeBrown = Colors.brown[700]!;

  @override
  void initState() {
    super.initState();
    logger.i('ManualsScreen initialized');
    _getCurrentUserRole();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('Admins')
          .doc(user.uid)
          .get();
      final coopAdminDoc = await FirebaseFirestore.instance
          .collection('CoopAdmins')
          .doc(user.uid)
          .get();
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();

      String newRole = 'User';
      bool isMainAdmin = false;
      bool isCoopAdmin = false;

      if (adminDoc.exists) {
        newRole = 'Admin';
        isMainAdmin = true;
        adminDoc.data();
      } else if (coopAdminDoc.exists) {
        newRole = 'Co-op Admin';
        isCoopAdmin = true;
        coopAdminDoc.data();
      } else if (userDoc.exists) {
        newRole = 'User';
      }

      if (mounted) {
        setState(() {
          _currentRole = newRole;
          _canUpload = isMainAdmin || isCoopAdmin;
          _canDelete = isMainAdmin;
        });
      }
    } catch (e) {
      logger.e('Error getting user role: $e');
    }
  }

  Future<void> _showUploadDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upload Manual', style: TextStyle(color: coffeeBrown)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(16.0),
              const SizedBox(height: 12),
              _buildCategoryDropdown(16.0),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _uploadManual();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: coffeeBrown,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upload File'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadManual() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );

      if (result == null || result.files.isEmpty) return;

      final platformFile = result.files.single;
      final fileName = platformFile.name;
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to upload manuals')),
          );
        }
        return;
      }

      final title = _titleController.text.trim().isEmpty 
          ? fileName 
          : _titleController.text.trim();

      if (!mounted) return;

      final bool? confirmUpload = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Confirm Upload', style: TextStyle(color: coffeeBrown)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (kIsWeb)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'WEB',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text('Do you want to upload the file: $fileName?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Upload'),
            ),
          ],
        ),
      );

      if (confirmUpload != true) return;

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text('Uploading $fileName', style: TextStyle(color: coffeeBrown)),
            content: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(coffeeBrown),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _uploadProgress != null
                          ? '${(_uploadProgress! * 100).toStringAsFixed(0)}%'
                          : 'Starting upload...',
                    ),
                    if (kIsWeb) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Web Upload',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      );

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('manuals/${DateTime.now().millisecondsSinceEpoch}_$fileName');

      late UploadTask uploadTask;

      if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final fileBytes = await platformFile.readAsBytes();

        final metadata = SettableMetadata(
          contentType: _getContentType(fileName),
          customMetadata: {
            'uploadedBy': user.uid,
            'originalName': fileName,
            'platform': kIsWeb ? 'web' : Platform.operatingSystem,
          },
        );

        uploadTask = storageRef.putData(fileBytes, metadata);
      } else {
        if (platformFile.path == null) {
          throw 'File path not available for mobile upload';
        }

        final file = File(platformFile.path!);
        final metadata = SettableMetadata(
          contentType: _getContentType(fileName),
          customMetadata: {
            'uploadedBy': user.uid,
            'originalName': fileName,
            'platform': Platform.operatingSystem,
          },
        );

        uploadTask = storageRef.putFile(file, metadata);
      }

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (mounted) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        }
      }, onError: (e) {
        logger.e('Upload progress error: $e');
      });

      await uploadTask;
      final downloadUrl = await storageRef.getDownloadURL();

      // Get user's full name for uploadedBy field
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();
      final userName = userDoc.data()?['fullName'] ?? 'Unknown User';

      await FirebaseFirestore.instance.collection('Manuals').add({
        'userId': user.uid,
        'title': title,
        'fileName': fileName,
        'downloadUrl': downloadUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'category': _selectedCategory,
        'uploadedBy': userName,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manual uploaded successfully')),
        );
        _titleController.clear();
      }

      logger.i('Uploaded manual: $fileName, URL: $downloadUrl');
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading manual: $e')),
        );
      }
      logger.e('Error uploading manual: $e');
    } finally {
      if (mounted) {
        setState(() {
          _uploadProgress = null;
        });
      }
    }
  }

  String _getContentType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _viewManual(String url, String fileName) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: coffeeBrown),
            const SizedBox(height: 16),
            const Text('Loading manual...'),
          ],
        ),
      ),
    );

    try {
      if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        Navigator.pop(context);
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not open manual in browser';
        }
      } else if (Platform.isAndroid || Platform.isIOS) {
        if (fileName.toLowerCase().endsWith('.pdf')) {
          final tempDir = await getTemporaryDirectory();
          final filePath = '${tempDir.path}/$fileName';
          await Dio().download(url, filePath);
          final file = File(filePath);
          if (await file.exists()) {
            if (mounted) {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PDFViewerScreen(
                    filePath: filePath,
                    fileName: fileName,
                  ),
                ),
              );
            }
          } else {
            throw 'Failed to download PDF';
          }
        } else {
          Navigator.pop(context);
          throw 'Only PDF viewing is supported on mobile';
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error viewing manual: $e')),
        );
      }
      logger.e('Error viewing manual: $e');
    }
  }

  Future<void> _downloadManual(String url, String fileName) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: coffeeBrown),
            const SizedBox(height: 16),
            const Text('Downloading...'),
          ],
        ),
      ),
    );

    try {
      if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        Navigator.pop(context);
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not download manual';
        }
      } else if (Platform.isAndroid || Platform.isIOS) {
        bool permissionGranted = await _requestStoragePermission();
        if (!permissionGranted) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Storage permission denied')),
            );
          }
          return;
        }

        final downloadsDir = await getExternalStorageDirectory();
        final filePath = '${downloadsDir!.path}/$fileName';
        await Dio().download(url, filePath);
        final file = File(filePath);
        if (await file.exists()) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Manual downloaded to $filePath'),
                action: SnackBarAction(
                  label: 'Open',
                  onPressed: () => OpenFile.open(filePath),
                ),
              ),
            );
          }
          logger.i('Downloaded manual: $fileName to $filePath');
        } else {
          throw 'Failed to download manual';
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading manual: $e')),
        );
      }
      logger.e('Error downloading manual: $e');
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
      }
      return status.isGranted;
    }
    return true;
  }

  Future<void> _deleteManual(String downloadUrl, String fileName, String docId) async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Deletion', style: TextStyle(color: coffeeBrown)),
        content: Text('Are you sure you want to delete "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: coffeeBrown),
              const SizedBox(height: 16),
              const Text('Deleting...'),
            ],
          ),
        ),
      );
    }

    try {
      await FirebaseStorage.instance.refFromURL(downloadUrl).delete();
      await FirebaseFirestore.instance.collection('Manuals').doc(docId).delete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manual deleted successfully')),
        );
      }
      logger.i('Deleted manual: $fileName, docId: $docId');
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting manual: $e')),
        );
      }
      logger.e('Error deleting manual: $e');
    }
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf':
        return Colors.red[600]!;
      case 'doc':
      case 'docx':
        return Colors.blue[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Coffee Farming Manuals',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            Text(
              _currentRole,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: coffeeBrown,
        elevation: 2,
      ),
      floatingActionButton: _canUpload
          ? FloatingActionButton(
              onPressed: _showUploadDialog,
              backgroundColor: coffeeBrown,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= 600;
    final isTablet = screenWidth > 600 && screenWidth <= 900;
    final padding = isMobile ? 16.0 : isTablet ? 24.0 : 32.0;
    final fontSizeTitle = isMobile ? 20.0 : isTablet ? 24.0 : 28.0;
    final fontSizeSubtitle = isMobile ? 14.0 : isTablet ? 16.0 : 18.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Available Manuals',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: fontSizeTitle,
                  color: coffeeBrown,
                ),
              ),
              if (kIsWeb) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'WEB',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Manuals')
                .orderBy('uploadedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                logger.e('StreamBuilder error: ${snapshot.error}');
                return Text('Error: ${snapshot.error}');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: coffeeBrown));
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.book,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No manuals uploaded yet',
                          style: TextStyle(
                            fontSize: fontSizeSubtitle,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _canUpload
                              ? 'Tap the + button to upload your first manual'
                              : 'Check back later for new manuals',
                          style: TextStyle(
                            fontSize: fontSizeSubtitle - 2,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final manual = Manual.fromSnapshot(docs[index]);
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: Icon(
                        _getFileIcon(manual.fileName),
                        color: _getFileIconColor(manual.fileName),
                        size: isMobile ? 32 : 36,
                      ),
                      title: Text(
                        manual.title,
                        style: TextStyle(
                          color: coffeeBrown,
                          fontWeight: FontWeight.w500,
                          fontSize: fontSizeSubtitle,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Category: ${manual.category}',
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            'Uploaded: ${manual.uploadedAt != null ? DateFormat('MMM dd, yyyy').format(manual.uploadedAt!) : 'Unknown date'}',
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (manual.uploadedBy != null)
                            Text(
                              'By: ${manual.uploadedBy}',
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 14,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'view') {
                            _viewManual(manual.downloadUrl, manual.fileName);
                          } else if (value == 'download') {
                            _downloadManual(manual.downloadUrl, manual.fileName);
                          } else if (value == 'delete') {
                            _deleteManual(manual.downloadUrl, manual.fileName, manual.id);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility, color: Colors.blue[700], size: 20),
                                const SizedBox(width: 8),
                                const Text('View'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'download',
                            child: Row(
                              children: [
                                Icon(Icons.download, color: Colors.green[700], size: 20),
                                const SizedBox(width: 8),
                                const Text('Download'),
                              ],
                            ),
                          ),
                          if (_canDelete)
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red[700], size: 20),
                                  const SizedBox(width: 8),
                                  const Text('Delete'),
                                ],
                              ),
                            ),
                        ],
                        icon: Icon(Icons.more_vert, color: coffeeBrown),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(double fontSize) {
    return TextField(
      controller: _titleController,
      decoration: InputDecoration(
        labelText: 'Manual Title (Optional)',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: coffeeBrown, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        labelStyle: TextStyle(color: Colors.grey[600]),
        hintStyle: TextStyle(color: Colors.grey[400]),
      ),
      style: TextStyle(fontSize: fontSize),
    );
  }

  Widget _buildCategoryDropdown(double fontSize) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Manual Category',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: coffeeBrown, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        labelStyle: TextStyle(color: Colors.grey[600]),
      ),
      items: manualCategories.entries.map((entry) {
        return DropdownMenuItem<String>(
          value: entry.key,
          child: Text(
            entry.value,
            style: TextStyle(fontSize: fontSize),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCategory = value!;
        });
      },
      style: TextStyle(fontSize: fontSize, color: Colors.black),
    );
  }
}

class PDFViewerScreen extends StatelessWidget {
  final String filePath;
  final String fileName;

  const PDFViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.brown[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: PDFView(
          filePath: filePath,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          onError: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading PDF: $error')),
            );
          },
        ),
      ),
    );
  }
}