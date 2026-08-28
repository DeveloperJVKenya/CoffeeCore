/// Encodes/decodes the QR payload printed on a produce bag tag and read
/// back by the Market Manager's scanner. Plain pipe-delimited text rather
/// than JSON/a URL scheme — this QR is only ever read by this app's own
/// camera scanner, not a generic QR reader, so there's no benefit to a
/// heavier format.
class ProduceQrPayload {
  final String coopId;
  final String userId;
  final String submissionId;

  const ProduceQrPayload({
    required this.coopId,
    required this.userId,
    required this.submissionId,
  });
}

class ProduceQrService {
  ProduceQrService._();

  static const String _prefix = 'COFFEECORE-TRACE';

  static String encode({
    required String coopId,
    required String userId,
    required String submissionId,
  }) {
    return '$_prefix|$coopId|$userId|$submissionId';
  }

  /// Returns null for anything that isn't a well-formed tag this app
  /// generated — e.g. a farmer's phone scanning an unrelated QR code.
  static ProduceQrPayload? decode(String raw) {
    final parts = raw.split('|');
    if (parts.length != 4 || parts[0] != _prefix) return null;
    final coopId = parts[1].trim();
    final userId = parts[2].trim();
    final submissionId = parts[3].trim();
    if (coopId.isEmpty || userId.isEmpty || submissionId.isEmpty) return null;
    return ProduceQrPayload(
      coopId: coopId,
      userId: userId,
      submissionId: submissionId,
    );
  }
}
