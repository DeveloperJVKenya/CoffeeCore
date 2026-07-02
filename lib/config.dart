// Values are injected at build/run time via --dart-define-from-file=secrets.json
// (see secrets.example.json for the required keys). Never hardcode real keys here.
class Config {
  static const String weatherApiKey =
      String.fromEnvironment('GOOGLE_WEATHER_API_KEY');
  static const String coffeeCoreMapsAPI =
      String.fromEnvironment('MAPS_API_KEY_WEB');
  static const String agroApiKey = String.fromEnvironment('AGRO_API_KEY');
  static const String gfwApiKey = String.fromEnvironment('GFW_API_KEY');
}
