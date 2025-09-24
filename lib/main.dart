import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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
      statusBarColor: Colors.transparent,  // Transparent status bar
      statusBarBrightness: Brightness.dark,  // Dark icons for light backgrounds (or light for dark)
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,  // Transparent nav bar
      systemNavigationBarContrastEnforced: false,  // Allow drawing behind (set true for varying backgrounds)
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
      title: 'CoffeeCore', // Updated app name
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown, // Coffee-inspired color
          primary: Colors.brown[700], // Darker coffee shade
          secondary: Colors.green[800], // Hint of coffee plant green
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegistrationScreen(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}