// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String county;
  final String constituency;
  final String ward;
  final String phoneNumber;
  final String? profileImage;
  final bool isDisabled;

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.county,
    required this.constituency,
    required this.ward,
    required this.phoneNumber,
    this.profileImage,
    this.isDisabled = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'county': county,
      'constituency': constituency,
      'ward': ward,
      'phoneNumber': phoneNumber,
      'profileImage': profileImage,
      'isDisabled': isDisabled,
    };
  }

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options) {
    final data = snapshot.data();
    return AppUser(
      id: snapshot.id,
      fullName: data?['fullName'] ?? '',
      email: data?['email'] ?? '',
      county: data?['county'] ?? '',
      constituency: data?['constituency'] ?? '',
      ward: data?['ward'] ?? '',
      phoneNumber: data?['phoneNumber'] ?? '',
      profileImage: data?['profileImage'] as String?,
      isDisabled: data?['isDisabled'] as bool? ?? false,
    );
  }
}
