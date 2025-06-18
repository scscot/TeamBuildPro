// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../screens/member_detail_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/header_widgets.dart';

class ProfileScreen extends StatefulWidget {
  final String appId;
  const ProfileScreen({super.key, required this.appId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _biometricEnabled = false;
  bool _biometricsAvailable = false;
  String? _sponsorName;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
    _loadBiometricSetting();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSponsorName();
      }
    });
  }

  Future<void> _checkBiometricSupport() async {
    final auth = LocalAuthentication();
    try {
      final available =
          await auth.canCheckBiometrics && await auth.isDeviceSupported();
      if (mounted) setState(() => _biometricsAvailable = available);
    } catch (e) {
      if (mounted) setState(() => _biometricsAvailable = false);
    }
  }

  Future<void> _loadBiometricSetting() async {
    // This logic would require a local storage solution like shared_preferences.
  }

  Future<void> _toggleBiometric(bool value) async {
    // This would save the setting to local storage.
    setState(() => _biometricEnabled = value);
  }

  void _loadSponsorName() {
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user?.referredBy != null && user!.referredBy!.isNotEmpty) {
      _firestoreService.getUser(user.referredBy!).then((sponsor) {
        if (mounted && sponsor != null) {
          setState(() {
            _sponsorName = '${sponsor.firstName} ${sponsor.lastName}';
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserModel?>(context);

    if (currentUser == null) {
      return Scaffold(
        appBar: AppHeaderWithMenu(appId: widget.appId),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppHeaderWithMenu(appId: widget.appId),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: currentUser.photoUrl != null &&
                            currentUser.photoUrl!.isNotEmpty
                        ? NetworkImage(currentUser.photoUrl!)
                        : null,
                    child: currentUser.photoUrl == null ||
                            currentUser.photoUrl!.isEmpty
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${currentUser.firstName ?? ''} ${currentUser.lastName ?? ''}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(currentUser.email ?? 'No email'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            _buildInfoRow('Referral Code', currentUser.referralCode ?? 'N/A'),
            if (_sponsorName != null)
              _buildClickableInfoRow(
                  'Sponsor', _sponsorName!, currentUser.referredBy ?? ''),
            if (currentUser.createdAt != null)
              _buildInfoRow(
                  'Joined', DateFormat.yMMMd().format(currentUser.createdAt!)),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(
                      user: currentUser,
                      appId: widget.appId,
                    ),
                  ),
                ),
                child: const Text('Edit Profile'),
              ),
            ),
            const Divider(height: 40),
            Text('Security Settings',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (_biometricsAvailable)
              SwitchListTile(
                title: const Text('Enable Face ID / Touch ID'),
                value: _biometricEnabled,
                onChanged: _toggleBiometric,
              ),
            // MODIFIED: Removed the Change Password ListTile
            const Divider(height: 40),
            Center(
              child: ElevatedButton(
                onPressed: () => context.read<AuthService>().signOut(),
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                child: const Text('Logout'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildClickableInfoRow(
      String label, String displayName, String userId) {
    if (userId.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
              width: 130,
              child: Text('$label:',
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MemberDetailScreen(
                          userId: userId, appId: widget.appId))),
              child: Text(displayName,
                  style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
              width: 130,
              child: Text('$label:',
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
