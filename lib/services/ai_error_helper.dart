/// Converts a raw Gemini/Firebase AI error into a short, non-technical
/// message safe to show directly to a smallholder farmer.
///
/// Used by GeminiSoilAiService, GeminiPestAiService and GeminiDiseaseAiService
/// so all three AI features fail the same, friendly way instead of silently
/// dropping the error or surfacing a raw stack trace.
String humanizeAiError(Object error) {
  final msg = error.toString().toLowerCase();

  if (msg.contains('prepayment credits') ||
      msg.contains('billing') ||
      msg.contains('quota') ||
      msg.contains('resource_exhausted') ||
      msg.contains('rate limit')) {
    return 'The AI assistant has reached its usage limit for now. '
        'Please try again later.';
  }

  if (msg.contains('socketexception') ||
      msg.contains('network') ||
      msg.contains('failed host lookup') ||
      msg.contains('connection')) {
    return 'Could not reach the AI assistant — please check your '
        'internet connection and try again.';
  }

  if (msg.contains('permission') ||
      msg.contains('unauthenticated') ||
      msg.contains('api key')) {
    return 'The AI assistant is not available right now. '
        'Please try again later.';
  }

  return 'The AI assistant is temporarily unavailable. '
      'Please try again in a moment.';
}
