import 'package:flutter/material.dart';

/// Placeholder entry point for the Farm Journal feature.
/// ToDO: implement the actual journal UI/functionality.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Coming soon'),
      ),
    );
  }
}
