import 'package:flutter/material.dart';

class JoinOpportunityConfirmationScreen extends StatelessWidget {
  const JoinOpportunityConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmation')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Thank you for registering for the opportunity.\n\nYou can return to your dashboard now.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
