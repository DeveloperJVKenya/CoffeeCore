import 'package:cloud_firestore/cloud_firestore.dart';

class Manual {
  final String id;
  final String userId;
  final String title;
  final String fileName;
  final String downloadUrl;
  final DateTime? uploadedAt;
  final String category;
  final String? uploadedBy; // User name who uploaded
  final String? platform; // Platform used for upload

  Manual({
    required this.id,
    required this.userId,
    required this.title,
    required this.fileName,
    required this.downloadUrl,
    this.uploadedAt,
    required this.category,
    this.uploadedBy,
    this.platform,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'title': title,
        'fileName': fileName,
        'downloadUrl': downloadUrl,
        'uploadedAt': uploadedAt?.toIso8601String(),
        'category': category,
        'uploadedBy': uploadedBy,
        'platform': platform,
      };

  factory Manual.fromJson(String id, Map<String, dynamic> json) => Manual(
        id: id,
        userId: json['userId'] as String,
        title: json['title'] as String,
        fileName: json['fileName'] as String,
        downloadUrl: json['downloadUrl'] as String,
        uploadedAt: json['uploadedAt'] != null
            ? DateTime.parse(json['uploadedAt'] as String)
            : null,
        category: json['category'] as String? ?? 'General',
        uploadedBy: json['uploadedBy'] as String?,
        platform: json['platform'] as String?,
      );

  factory Manual.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Manual(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      fileName: data['fileName'] as String,
      downloadUrl: data['downloadUrl'] as String,
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate(),
      category: data['category'] as String? ?? 'General',
      uploadedBy: data['uploadedBy'] as String?,
      platform: data['platform'] as String?,
    );
  }
}
