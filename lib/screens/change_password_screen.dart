// lib/screens/change_password_screen.dart

import 'package:flutter/material.dart';
import '../widgets/header_widgets.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String appId;

  const ChangePasswordScreen({
    super.key,
    required this.appId,
  });

  @override
  // ignore: library_private_types_in_public_api
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  // Add TextEditingControllers for old and new passwords

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeaderWithMenu(appId: widget.appId),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Change Password',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              const Text('TODO: Implement change password form here.'),
              // Add form fields for changing password
            ],
          ),
        ),
      ),
    );
  }
}
