import 'package:flutter/material.dart';

class UserProfile with ChangeNotifier {
  String _displayName = "Fab Naligu";
  String? _profileImagePath;
  String? _about;
  final List<Map<String, dynamic>> _reminders = [];

  String get displayName => _displayName;
  String? get profileImagePath => _profileImagePath;
  String? get about => _about;
  List<Map<String, dynamic>> get reminders => _reminders;

  void updateProfile(
      {String? displayName, String? profileImagePath, String? about}) {
    if (displayName != null) _displayName = displayName;
    if (profileImagePath != null) _profileImagePath = profileImagePath;
    if (about != null) _about = about;
    notifyListeners();
  }

  void addReminder(int plotId, String activity, DateTime date) {
    _reminders.add({
      'plotId': plotId,
      'title': 'Reminder for Plot $plotId',
      'message': 'Activity: $activity',
      'date': date,
      'time': _formatTimeSince(date),
    });
    notifyListeners();
  }

  String _formatTimeSince(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays > 0) return '${difference.inDays} days ago';
    if (difference.inHours > 0) return '${difference.inHours} hrs ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes} mins ago';
    return 'Just now';
  }
}
