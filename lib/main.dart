import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:coffeecore/authentication/splashscreen.dart';
import 'package:coffeecore/authentication/login.dart';
import 'package:coffeecore/authentication/registration.dart';
import 'package:coffeecore/home.dart';
import 'firebase_options.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
// Shows SplashScreen for the full 5-second animation, then routes
// based on Firebase Auth state. Because no platform view is built
// during startup, the flutter/lifecycle discarded-message warning
// is eliminated.
// ------------------------------------------------------------------
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _splashFinished = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _splashFinished = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Keep splash animation running for the full 5 seconds
        if (!_splashFinished) {
          return const SplashScreen();
        }

        // After 5 s: route based on Firebase Auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const HomePage();
        }

        return const RegistrationScreen();
      },
    );
  }
}