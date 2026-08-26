// Values are injected at build/run time via --dart-define-from-file=secrets.json
// (see secrets.example.json for the required keys). Never hardcode real keys here.
class Config {
  static const String weatherApiKey =
      String.fromEnvironment('GOOGLE_WEATHER_API_KEY');
  static const String coffeeCoreMapsAPI =
      String.fromEnvironment('MAPS_API_KEY_WEB');
  static const String agroApiKey = String.fromEnvironment('AGRO_API_KEY');
  static const String gfwApiKey = String.fromEnvironment('GFW_API_KEY');
  // Fixed local-dev App Check debug token for web (see main.dart). Using a
  // fixed value instead of the SDK's auto-generated one means it survives
  // port changes across `flutter run -d chrome` restarts and only needs to
  // be registered once in Firebase Console > App Check > Manage debug tokens.
  static const String appCheckDebugToken =
      String.fromEnvironment('FIREBASE_APPCHECK_DEBUG_TOKEN');
  // Sentinel Hub's OAuth client ID/secret are intentionally NOT here: they
  // live only in the sentinelHubNdwi Cloud Function's Secret Manager config
  // (see functions/index.js), never in the app itself — a compiled web
  // bundle or decompiled APK is effectively public, so a long-lived client
  // secret embedded in either would be exposed to anyone.
}
