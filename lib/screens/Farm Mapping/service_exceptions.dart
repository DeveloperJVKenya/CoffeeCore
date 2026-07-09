import 'dart:convert';

/// Thrown by Farm Mapping services when a live data fetch cannot complete.
///
/// [userMessage] is safe to show directly in the UI — callers should surface
/// it instead of substituting fabricated/simulated data, so the app never
/// presents guessed numbers as if they were real. Full technical detail
/// (status codes, response bodies, stack traces) stays in the log call each
/// service already makes before throwing.
class ServiceUnavailableException implements Exception {
  final String userMessage;
  final bool isNetworkError;

  const ServiceUnavailableException(this.userMessage, {this.isNetworkError = false});

  @override
  String toString() => userMessage;
}

/// Heuristic: does this error look like a connectivity failure rather than
/// an API rejecting the request? Covers the exception shapes `http` throws
/// on native (SocketException) and web (ClientException "Failed to fetch"),
/// plus generic timeouts.
bool isNetworkError(Object error) {
  final s = error.toString().toLowerCase();
  return s.contains('socketexception') ||
      s.contains('clientexception') ||
      s.contains('failed to fetch') ||
      s.contains('timeoutexception') ||
      s.contains('connection refused') ||
      s.contains('network is unreachable');
}

/// Best-effort extraction of a human-readable message from a JSON error
/// body, supporting the shapes used by AgroMonitoring/GFW (`{"message":...}`)
/// and Google APIs (`{"error":{"message":...}}`). Returns null if the body
/// isn't JSON or doesn't match a known error shape.
String? extractApiMessage(String body) {
  if (body.isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is Map && error['message'] is String) {
        return error['message'] as String;
      }
      if (decoded['message'] is String) {
        return decoded['message'] as String;
      }
    }
  } catch (_) {
    // Body wasn't JSON or didn't match a known shape.
  }
  return null;
}
