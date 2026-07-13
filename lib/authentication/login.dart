import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:coffeecore/authentication/registration.dart';
import 'package:coffeecore/home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _isLoading = false;
  bool _obscureText = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
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

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      _showToast('Welcome back!');
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()));
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Incorrect email or password.';
      } else {
        message = 'Login failed: ${e.message}';
      }
      if (mounted) _showToast(message, isError: true);
    } catch (e) {
      if (mounted) {
        _showToast('Login failed. Please try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showToast('Please enter your email address first', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _emailController.text.trim());
      if (!mounted) return;
      _showToast('Password reset email sent. Check your inbox.');
    } catch (e) {
      if (!mounted) return;
      _showToast('Failed to send password reset email.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.0)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28.0, vertical: 36.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Image.asset('assets/coffee-plant.png', width: 140.0),
                    const SizedBox(height: 16.0),
                    const Text(
                      'CoffeeCore Login',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown),
                    ),
                    const SizedBox(height: 24.0),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _emailController,
                            focusNode: _emailFocus,
                            label: 'Email',
                            hintText: 'Enter your email address',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                _passwordFocus.requestFocus(),
                            validator: (value) {
                              if (value == null ||
                                  value.isEmpty ||
                                  !RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                      .hasMatch(value)) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15.0),
                          _buildTextField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            label: 'Password',
                            hintText: 'Enter your password',
                            obscureText: _obscureText,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleEmailLogin(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscureText
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.brown[700]),
                              onPressed: () {
                                setState(() {
                                  _obscureText = !_obscureText;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your registered password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 6.0),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed:
                                  _isLoading ? null : _handleForgotPassword,
                              child: Text('Forgot Password?',
                                  style: TextStyle(color: Colors.brown[700])),
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          SizedBox(
                            width: double.infinity,
                            child: _buildElevatedButton(
                              onPressed: _isLoading ? null : _handleEmailLogin,
                              label: 'Login',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                              builder: (context) => const RegistrationScreen()),
                        );
                      },
                      child: Text(
                        'Do not have an account? Sign Up',
                        style:
                            TextStyle(color: Colors.brown[700], fontSize: 15.0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    String? hintText,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onFieldSubmitted,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.0)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.brown[50],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      ),
      validator: validator,
    );
  }

  Widget _buildElevatedButton({
    required VoidCallback? onPressed,
    required String label,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.brown[700],
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        elevation: 3,
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
          : Text(label,
              style: const TextStyle(fontSize: 18.0, color: Colors.white)),
    );
  }
}
