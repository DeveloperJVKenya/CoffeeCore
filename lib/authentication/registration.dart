import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:coffeecore/models/user_model.dart';
import 'package:coffeecore/data/kenya_locations.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  RegistrationScreenState createState() => RegistrationScreenState();
}

class RegistrationScreenState extends State<RegistrationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final logger = Logger(printer: PrettyPrinter());

  String? _fullName;
  String? _email;
  String? _phoneNumber;
  String? _password;
  String? _county;
  String? _constituency;
  String? _ward;
  bool _isLoading = false;
  bool _obscurePassword = true;

  List<String> _currentConstituencies = [];
  List<String> _currentWards = [];

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateConstituencies(String? county) {
    setState(() {
      _county = county;
      _currentConstituencies =
          county != null ? kenyaLocations[county] ?? [] : [];
      _constituency = null; // Reset constituency when county changes
      _currentWards = []; // Reset wards when county changes
      _ward = null;
    });
  }

  void _updateWards(String? constituency) {
    setState(() {
      _constituency = constituency;
      _currentWards =
          constituency != null ? constituencyWards[constituency] ?? [] : [];
      _ward = null; // Reset ward when constituency changes
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    'assets/coffee_registration_background.jpg'), // Updated asset
                fit: BoxFit.cover,
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 20.0),
                  Text(
                    'Welcome to CoffeeCore!',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown[700]),
                  ),
                  const SizedBox(height: 10.0),
                  Text(
                    'Create your coffee farming account below.',
                    style: TextStyle(fontSize: 16, color: Colors.brown[400]),
                  ),
                  const SizedBox(height: 30.0),
                  // Full Name Field
                  TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter your full name',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0)),
                      filled: true,
                      fillColor: Colors.brown[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _fullName = value;
                    },
                  ),
                  const SizedBox(height: 15.0),
                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email address',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0)),
                      filled: true,
                      fillColor: Colors.brown[50],
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty ||
                          !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _email = value;
                    },
                  ),
                  const SizedBox(height: 15.0),
                  // County Dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'County',
                      hintText: 'Select your county',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0)),
                      filled: true,
                      fillColor: Colors.brown[50],
                    ),
                    initialValue: _county,
                    items: kenyaLocations.keys
                        .map((county) => DropdownMenuItem(
                              value: county,
                              child: Text(county),
                            ))
                        .toList(),
                    onChanged: _updateConstituencies,
                    validator: (value) =>
                        value == null ? 'Please select a county' : null,
                    onSaved: (value) => _county = value,
                  ),
                  const SizedBox(height: 15.0),
                  // Constituency Dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Constituency',
                      hintText: 'Select your constituency',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0)),
                      filled: true,
                      fillColor: Colors.brown[50],
                    ),
                    initialValue: _constituency,
                    items: _currentConstituencies
                        .map((constituency) => DropdownMenuItem(
                              value: constituency,
                              child: Text(constituency),
                            ))
                        .toList(),
                    onChanged: _updateWards,
                    validator: (value) =>
                        value == null ? 'Please select a constituency' : null,
                    onSaved: (value) => _constituency = value,
                  ),
                  const SizedBox(height: 15.0),
                  // Ward Dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Ward',
                      hintText: 'Select your ward',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0)),
                      filled: true,
                      fillColor: Colors.brown[50],
                    ),
                    initialValue: _ward,
                    items: _currentWards
                        .map((ward) => DropdownMenuItem(
                              value: ward,
                              child: Text(ward),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _ward = value),
                    validator: (value) =>
                        value == null ? 'Please select a ward' : null,
                    onSaved: (value) => _ward = value,
                  ),
                  const SizedBox(height: 15.0),
                  // Phone Number Field
                  TextFormField(
                    controller: _phoneNumberController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'Enter your phone number',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0)),
                      filled: true,
                      fillColor: Colors.brown[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _phoneNumber = value;
                    },
                  ),
                  const SizedBox(height: 15.0),
                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0)),
                      filled: true,
                      fillColor: Colors.brown[50],
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.brown[700],
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _password = value;
                    },
                  ),
                  const SizedBox(height: 20.0),
                  // Sign Up Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (_formKey.currentState!.validate()) {
                                _formKey.currentState!.save();
                                _signUp();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.brown[700], // Coffee-inspired color
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0)),
                        padding: const EdgeInsets.symmetric(vertical: 15.0),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Sign Up',
                              style: TextStyle(
                                  fontSize: 20.0, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  // Login Link
                  Center(
                    child: TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushReplacementNamed('/login'),
                      child: Text(
                        'Already have an account? Log In',
                        style: TextStyle(color: Colors.brown[700]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signUp() async {
    setState(() => _isLoading = true);

    try {
      // Create user with email and password
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _email!,
        password: _password!,
      );

      // Create AppUser instance
      final appUser = AppUser(
        id: userCredential.user!.uid,
        fullName: _fullName!,
        email: _email!,
        county: _county!,
        constituency: _constituency!,
        ward: _ward!,
        phoneNumber: _phoneNumber!,
      );

      // Save to Firestore
      await _firestore.collection('Users').doc(appUser.id).set(appUser.toMap());

      if (!mounted) return;

      // Success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign up successful. Welcome, $_fullName!')),
      );

      // Navigate to home
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!mounted) return;

      logger.e('Error during sign up: $e');
      String errorMessage;
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = 'The email address is already in use.';
            break;
          case 'invalid-email':
            errorMessage = 'The email address is invalid.';
            break;
          case 'weak-password':
            errorMessage = 'The password is too weak.';
            break;
          default:
            errorMessage = 'Failed to sign up. Please try again.';
        }
      } else {
        errorMessage = 'An unknown error occurred. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
