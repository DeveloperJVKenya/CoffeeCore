import 'dart:js_interop';

@JS('self.FIREBASE_APPCHECK_DEBUG_TOKEN')
external set _firebaseAppCheckDebugToken(JSAny? value);

/// Tells the Firebase App Check JS SDK to bypass the configured web provider
/// (reCAPTCHA Enterprise) and use a debug token instead. Without this, local
/// `flutter run -d chrome` builds fail App Check token generation because the
/// reCAPTCHA site key is restricted to registered production domains, not
/// localhost — and since App Check enforcement covers the whole Firebase
/// project, that failure blocks Auth as well as the AI Logic calls.
void enableAppCheckDebugTokenForWeb() {
  _firebaseAppCheckDebugToken = true.toJS;
}
