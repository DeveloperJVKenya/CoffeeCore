import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
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
  final FocusNode _fullNameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
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
    _fullNameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _showToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? Colors.red[700] : Colors.brown[700],
      textColor: Colors.white,
    );
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

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      _signUp();
    }
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
                image: AssetImage('assets/coffee_registration_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  elevation: 6,
                  color: Colors.white.withValues(alpha: 0.94),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.0)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'Welcome to CoffeeCore!',
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown[700]),
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            'Create your coffee farming account below.',
                            style: TextStyle(
                                fontSize: 15, color: Colors.brown[400]),
                          ),
                          const SizedBox(height: 24.0),
                          TextFormField(
                            controller: _fullNameController,
                            focusNode: _fullNameFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                            decoration: _fieldDecoration(
                              label: 'Full Name',
                              hintText: 'Enter your full name',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your full name';
                              }
                              return null;
                            },
                            onSaved: (value) => _fullName = value,
                          ),
                          const SizedBox(height: 15.0),
                          TextFormField(
                            controller: _emailController,
                            focusNode: _emailFocus,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                            decoration: _fieldDecoration(
                              label: 'Email',
                              hintText: 'Enter your email address',
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.isEmpty ||
                                  !RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                      .hasMatch(value)) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                            onSaved: (value) => _email = value,
                          ),
                          const SizedBox(height: 15.0),
                          DropdownButtonFormField<String>(
                            decoration: _fieldDecoration(
                              label: 'County',
                              hintText: 'Select your county',
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
                          DropdownButtonFormField<String>(
                            decoration: _fieldDecoration(
                              label: 'Constituency',
                              hintText: 'Select your constituency',
                            ),
                            initialValue: _constituency,
                            items: _currentConstituencies
                                .map((constituency) => DropdownMenuItem(
                                      value: constituency,
                                      child: Text(constituency),
                                    ))
                                .toList(),
                            onChanged: _updateWards,
                            validator: (value) => value == null
                                ? 'Please select a constituency'
                                : null,
                            onSaved: (value) => _constituency = value,
                          ),
                          const SizedBox(height: 15.0),
                          DropdownButtonFormField<String>(
                            decoration: _fieldDecoration(
                              label: 'Ward',
                              hintText: 'Select your ward',
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
                          TextFormField(
                            controller: _phoneNumberController,
                            focusNode: _phoneFocus,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                _passwordFocus.requestFocus(),
                            decoration: _fieldDecoration(
                              label: 'Phone Number',
                              hintText: 'Enter your phone number',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              return null;
                            },
                            onSaved: (value) => _phoneNumber = value,
                          ),
                          const SizedBox(height: 15.0),
                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submitForm(),
                            decoration: _fieldDecoration(
                              label: 'Password',
                              hintText: 'Enter your password',
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
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                            onSaved: (value) => _password = value,
                          ),
                          const SizedBox(height: 22.0),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.brown[700],
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16.0)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14.0),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Sign Up',
                                      style: TextStyle(
                                          fontSize: 18.0, color: Colors.white),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.of(context)
                                  .pushReplacementNamed('/login'),
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.0)),
      filled: true,
      fillColor: Colors.brown[50],
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
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

      _showToast('Sign up successful. Welcome, $_fullName!');

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

      _showToast(errorMessage, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
