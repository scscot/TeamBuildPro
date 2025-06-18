// lib/screens/profile_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../screens/member_detail_screen.dart';
import 'edit_profile_screen.dart';
import '../widgets/header_widgets.dart';

class ProfileScreen extends StatefulWidget {
  final String appId;
  const ProfileScreen({super.key, required this.appId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _biometricEnabled = false; // This state is local and fine.
  bool _biometricsAvailable = false;

  @override
  void initState() {
    super.initState();
    // Moved biometric settings check here. It doesn't depend on user data.
    _checkBiometricSupport();
    _loadBiometricSetting();
  }

  Future<void> _checkBiometricSupport() async {
    final auth = LocalAuthentication();
    final available =
        await auth.canCheckBiometrics && await auth.isDeviceSupported();
    if (mounted) setState(() => _biometricsAvailable = available);
  }

  Future<void> _loadBiometricSetting() async {
    // This logic needs a replacement for SessionManager. For now, we'll disable it.
    // A proper solution would use a package like shared_preferences.
    // setState(() => _biometricEnabled = false);
  }

  Future<void> _toggleBiometric(bool value) async {
    // Logic for saving biometric preference would go here, likely to shared_preferences.
    setState(() => _biometricEnabled = value);
  }

  Future<Map<String, String?>> _fetchSponsorAndUplineNames(
      UserModel user) async {
    String? sponsorName;
    String? uplineAdminName;

    if (user.referredBy != null && user.referredBy!.isNotEmpty) {
      try {
        final sponsorSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('referralCode', isEqualTo: user.referredBy)
            .limit(1)
            .get();
        if (sponsorSnapshot.docs.isNotEmpty) {
          final sponsorData = sponsorSnapshot.docs.first.data();
          sponsorName =
              '${sponsorData['firstName'] ?? ''} ${sponsorData['lastName'] ?? ''}'
                  .trim();
        }
      } catch (e) {
        debugPrint('❌ Failed to load sponsor data: $e');
      }
    }

    if (user.uplineAdmin != null && user.uplineAdmin!.isNotEmpty) {
      try {
        final adminDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uplineAdmin)
            .get();
        if (adminDoc.exists) {
          final adminData = adminDoc.data();
          if (adminData != null) {
            uplineAdminName =
                '${adminData['firstName'] ?? ''} ${adminData['lastName'] ?? ''}'
                    .trim();
          }
        }
      } catch (e) {
        debugPrint('❌ Failed to load upline admin data: $e');
      }
    }
    return {'sponsorName': sponsorName, 'uplineAdminName': uplineAdminName};
  }

  @override
  Widget build(BuildContext context) {
    // Get the user directly from the Provider.
    final user = Provider.of<UserModel?>(context);

    if (user == null) {
      return Scaffold(
        appBar: AppHeaderWithMenu(appId: widget.appId),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppHeaderWithMenu(appId: widget.appId),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 16.0, bottom: 24.0),
              child: Center(
                  child: Text('My Profile',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold))),
            ),
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage:
                    user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? NetworkImage(user.photoUrl!)
                        : const AssetImage('assets/images/default_avatar.png')
                            as ImageProvider,
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoRow('Name', '${user.firstName} ${user.lastName}'),
            _buildInfoRow('Email', user.email),
            _buildInfoRow('City', user.city ?? 'N/A'),
            _buildInfoRow('State/Province', user.state ?? 'N/A'),
            _buildInfoRow('Country', user.country ?? 'N/A'),
            _buildInfoRow(
                'Join Date',
                user.createdAt != null
                    ? DateFormat.yMMMMd().format(user.createdAt!)
                    : 'N/A'),

            // Use a FutureBuilder for data that depends on the main user object.
            FutureBuilder<Map<String, String?>>(
              future: _fetchSponsorAndUplineNames(user),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6.0),
                      child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          )));
                }

                final sponsorName = snapshot.data?['sponsorName'];
                final uplineName = snapshot.data?['uplineAdminName'];

                return Column(
                  children: [
                    if (sponsorName != null &&
                        sponsorName.isNotEmpty &&
                        user.referredBy != null)
                      _buildClickableInfoRow(
                          'Sponsor Name', sponsorName, user.referredBy!),
                    if (uplineName != null &&
                        uplineName.isNotEmpty &&
                        user.uplineAdmin != null &&
                        user.referredBy != user.uplineAdmin)
                      _buildClickableInfoRow(
                          'Team Leader', uplineName, user.uplineAdmin!),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          EditProfileScreen(user: user, appId: widget.appId)));
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile'),
              ),
            ),
            const SizedBox(height: 20),
            if (_biometricsAvailable)
              SwitchListTile(
                title: const Text('Enable Face ID / Touch ID'),
                value: _biometricEnabled,
                onChanged: _toggleBiometric,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClickableInfoRow(
      String label, String displayName, String userId) {
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
