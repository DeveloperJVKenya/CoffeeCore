/// A lightweight, denormalized snapshot of a user — embedded directly inside
/// posts and comments so the feed never needs a second read per author.
/// This is a deliberate denormalization: if a user changes their display
/// name, past posts keep showing the name as it was when posted (same
/// trade-off Reddit/Stack Overflow both make).
class UserMiniProfile {
  final String uid;
  final String displayName;
  final String? avatarUrl;

  const UserMiniProfile({
    required this.uid,
    required this.displayName,
    this.avatarUrl,
  });

  factory UserMiniProfile.fromJson(Map<String, dynamic> json) {
    return UserMiniProfile(
      uid: json['uid'] as String,
      displayName: json['display_name'] as String? ?? 'Anonymous Farmer',
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'display_name': displayName,
      'avatar_url': avatarUrl,
    };
  }
}
