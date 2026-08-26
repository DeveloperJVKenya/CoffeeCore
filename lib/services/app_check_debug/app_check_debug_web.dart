import 'dart:js_interop';

@JS('self.FIREBASE_APPCHECK_DEBUG_TOKEN')
external set _firebaseAppCheckDebugToken(JSAny? value);

/// Tells the Firebase App Check JS SDK to bypass the configured web provider
/// (reCAPTCHA Enterprise) and use a debug token instead. Without this, local
/// `flutter run -d chrome` builds fail App Check token generation because the
/// reCAPTCHA site key is restricted to registered production domains, not
/// localhost — and since App Check enforcement covers the whole Firebase
/// project, that failure blocks Auth as well as the AI Logic calls.
///
/// A fixed [token] (registered once in Firebase Console > App Check > Manage
/// debug tokens) is used instead of leaving this `true`, because `true` makes
/// the SDK generate a new random token per browser storage origin — which
/// changes on every `flutter run -d chrome` restart when the dev server picks
/// a different port, requiring the token to be re-registered each time.
void enableAppCheckDebugTokenForWeb(String token) {
  _firebaseAppCheckDebugToken = token.toJS;
}
