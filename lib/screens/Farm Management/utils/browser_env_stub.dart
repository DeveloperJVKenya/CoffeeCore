/// Facts about the browser the web build is running in. On native builds
/// there is no browser, so everything reports the "no special handling"
/// defaults.
class BrowserEnv {
  const BrowserEnv._();

  /// iPhone/iPad (including iPadOS reporting itself as a Mac). Every iOS
  /// browser — Safari, Chrome, Firefox — runs on WebKit and shares Safari's
  /// location rules.
  static bool get isIOS => false;

  /// Name of the social/messaging app whose built-in browser opened the
  /// link, or null for a normal browser. In-app browsers frequently block
  /// geolocation outright.
  static String? get inAppBrowserName => null;

  /// Geolocation only works on https (or localhost).
  static bool get isSecureContext => true;

  /// Current page URL, for "copy link" when the user must switch browsers.
  static String get currentUrl => '';
}
