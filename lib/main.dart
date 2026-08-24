import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coffeecore/authentication/splashscreen.dart';
import 'package:coffeecore/authentication/login.dart';
import 'package:coffeecore/authentication/registration.dart';
import 'package:coffeecore/home.dart';
import 'package:coffeecore/services/push_notification_service.dart';
import 'package:coffeecore/services/app_check_debug.dart';
import 'firebase_options.dart';
import 'package:flutter/services.dart';

// Registered in Firebase Console > App Check > Web app > reCAPTCHA Enterprise.
// Public site key — safe to embed client-side (same trust model as the Maps
// key already hardcoded in web/index.html).
const String _recaptchaEnterpriseSiteKey =
    '6LfHZI8tAAAAAMJbmkWdhn14fUg1_uRo5f6qmYPK';

/// App-level navigator key — needed so a notification tap (which has no
/// BuildContext, especially on a cold start) can still push a screen. See
/// PushNotificationService._handleTap.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Hot restart resets Dart-side state but not the native Firebase app
  // instance, so re-initializing throws [core/duplicate-app] on every hot
  // restart. Left unguarded, that throw happens before runApp() ever runs,
  // which is what makes hot restart specifically (never a cold start) leave
  // the app looking stuck until a fresh sign-in forces a clean auth event.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }

  // Must be activated before any Firebase AI Logic call (soil, pest, disease,
  // chat) or the backend rejects the request with an App Check enforcement
  // error. Debug provider is used in debug builds so local runs work without
  // a registered attestation token; release builds use the real attesters
  // configured in Firebase Console > App Check.
  try {
    if (kDebugMode) enableAppCheckDebugTokenForWeb();
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestProvider(),
      providerWeb: ReCaptchaEnterpriseProvider(_recaptchaEnterpriseSiteKey),
    );
  } catch (e, stack) {
    developer.log('Firebase App Check activation failed',
        error: e, stackTrace: stack, name: 'main');
  }

  // Must be registered before runApp() so the plugin can dispatch to it
  // when a push arrives with the app backgrounded/terminated.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Enable edge-to-edge mode globally
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Set transparent overlays (avoids deprecated color APIs)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'CoffeeCore',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown,
          primary: Colors.brown[700],
          secondary: Colors.green[800],
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegistrationScreen(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

// ------------------------------------------------------------------
// AuthGate
// ------------------------------------------------------------------
// Shows SplashScreen for its full animation (SplashScreen.totalDurationSeconds),
// then routes based on Firebase Auth state. Because no platform view is
// built during startup, the flutter/lifecycle discarded-message warning
// is eliminated.
// ------------------------------------------------------------------
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _splashFinished = false;
  bool _pushInitialized = false;

  // Captured once — FirebaseAuth.authStateChanges() returns a NEW Stream
  // object on every call (confirmed in firebase_auth's source; it isn't
  // memoized). Calling it inline as StreamBuilder's `stream:` argument means
  // every rebuild of this widget (e.g. the splash-timer setState below)
  // hands StreamBuilder a different stream reference, which makes it cancel
  // the working subscription and resubscribe cold — right at the exact
  // moment this widget decides Home vs. sign-in. Caching it once avoids
  // that resubscription entirely.
  late final Stream<User?> _authStateChanges =
      FirebaseAuth.instance.authStateChanges();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: SplashScreen.totalDurationSeconds),
        () {
      if (mounted) setState(() => _splashFinished = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStateChanges,
      builder: (context, snapshot) {
        // Keep splash animation running for its full duration
        if (!_splashFinished) {
          return const SplashScreen();
        }

        // After the splash duration: route based on Firebase Auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.hasData && snapshot.data != null) {
          if (!_pushInitialized) {
            _pushInitialized = true;
            // Fire-and-forget — a failure here (e.g. iOS not yet configured)
            // must never block reaching HomePage.
            PushNotificationService.initialize(navigatorKey);
          }
          return const HomePage();
        }

        return const RegistrationScreen();
      },
    );
  }
}
