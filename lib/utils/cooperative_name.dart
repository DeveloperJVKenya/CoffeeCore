/// Converts a cooperative's display name into the identifier used as a
/// prefix for its Firestore collections (e.g. "Kiambu Coop" becomes
/// "Kiambu_Coop", used as "Kiambu_Coop_users" etc). Centralizes
/// sanitization that was previously duplicated ad hoc at 45+ call sites
/// across the Cooperative Section, where only spaces were handled — a name
/// containing '/' or other Firestore-path-sensitive characters would
/// silently produce a broken or unexpected collection path.
String sanitizeCoopId(String cooperativeName) {
  return cooperativeName.trim().replaceAll(RegExp(r'[\s/]+'), '_');
}

/// Reverses [sanitizeCoopId] for display purposes (turning a stored
/// collection-prefix id like "Kiambu_Coop" back into "Kiambu Coop" for UI
/// labels). Not a true inverse when the original name contained a '/' —
/// that distinction is lost during sanitization — but matches the existing
/// display behavior this replaces.
String coopIdToDisplayName(String coopId) {
  return coopId.replaceAll('_', ' ');
}
