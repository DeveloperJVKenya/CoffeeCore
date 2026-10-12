import 'dart:js_interop';

@JS('navigator.userAgent')
external String get _userAgent;

@JS('navigator.maxTouchPoints')
external int? get _maxTouchPoints;

@JS('window.isSecureContext')
external bool? get _isSecureContext;

@JS('location.href')
external String get _href;

/// Facts about the browser the web build is running in, used to explain
/// location failures that only happen on specific browsers.
class BrowserEnv {
  const BrowserEnv._();

  /// User-agent markers of common in-app browsers, in match order.
  static const List<(String, String)> _inAppMarkers = [
    ('FBAN', 'Facebook'),
    ('FBAV', 'Facebook'),
    ('Instagram', 'Instagram'),
    ('WhatsApp', 'WhatsApp'),
    ('Snapchat', 'Snapchat'),
    ('musical_ly', 'TikTok'),
    ('BytedanceWebview', 'TikTok'),
    ('Twitter', 'X (Twitter)'),
    ('LinkedInApp', 'LinkedIn'),
    ('Line/', 'LINE'),
    ('MicroMessenger', 'WeChat'),
    ('Telegram', 'Telegram'),
    ('GSA/', 'Google app'),
  ];

  /// iPhone/iPad (including iPadOS reporting itself as a Mac). Every iOS
  /// browser — Safari, Chrome, Firefox — runs on WebKit and shares Safari's
  /// location rules.
  static bool get isIOS {
    final String ua = _userAgent;
    if (RegExp(r'iPhone|iPad|iPod').hasMatch(ua)) return true;
    // iPadOS 13+ sends a desktop Mac user agent; real Macs have no touch.
    return ua.contains('Macintosh') && (_maxTouchPoints ?? 0) > 1;
  }

  /// Name of the social/messaging app whose built-in browser opened the
  /// link, or null for a normal browser. In-app browsers frequently block
  /// geolocation outright.
  static String? get inAppBrowserName {
    final String ua = _userAgent;
    for (final (String marker, String name) in _inAppMarkers) {
      if (ua.contains(marker)) return name;
    }
    return null;
  }

  /// Geolocation only works on https (or localhost).
  static bool get isSecureContext => _isSecureContext ?? true;

  /// Current page URL, for "copy link" when the user must switch browsers.
  static String get currentUrl => _href;
}
