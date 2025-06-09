// ignore_for_file: unused_import, use_build_context_synchronously, control_flow_in_finally

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io';
import 'dart:developer' as developer; // Import for logging

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/session_manager.dart';
import '../models/user_model.dart'; // Ensure UserModel is imported
import '../services/firestore_service.dart';
import '../screens/member_detail_screen.dart'; // Import MemberDetailScreen
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import '../widgets/header_widgets.dart';
import '../services/subscription_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user; // This is the user whose profile is being viewed (the currentUser in this screen)
  UserModel? _loggedInUser; // This represents the currently logged-in user viewing this profile
  String? _sponsorName;
  String? _uplineAdminName; // New state variable for upline admin name
  String? _sponsorUid; // To store the UID of the sponsor
  String? _uplineAdminUid; // To store the UID of the upline admin

  bool _biometricEnabled = false;
  bool _biometricsAvailable = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadBiometricSetting();
    _checkBiometricSupport();
  }

  // A simple log function that only prints in debug mode
  void _log(String message) {
    if (kDebugMode) {
      developer.log(message, name: 'ProfileScreen');
    }
  }

  Future<void> _checkBiometricSupport() async {
    final auth = LocalAuthentication();
    final available = await auth.canCheckBiometrics;
    final supported = await auth.isDeviceSupported();
    if (!mounted) return;
    setState(() {
      _biometricsAvailable = available && supported;
    });
  }

  Future<void> _loadUserData() async {
    // This is the user whose profile is being displayed (the current user of THIS screen)
    final currentUserData = await SessionManager().getCurrentUser();
    // Assuming _user is the current user of the profile screen
    // _loggedInUser will be the actual authenticated user viewing this profile (which is also _user in this screen's context)
    if (currentUserData != null) {
      _log('✅ Current user loaded: ${currentUserData.firstName} ${currentUserData.lastName}');
      if (!mounted) return;
      setState(() {
        _user = currentUserData;
        _loggedInUser = currentUserData; // In this screen, the viewer is the user whose profile is shown.
      });

      // --- Retrieve Sponsor Name ---
      if (currentUserData.referredBy != null &&
          currentUserData.referredBy!.isNotEmpty) {
        _log('🔎 Looking up sponsor name by referralCode: ${currentUserData.referredBy}');
        try {
          final sponsorSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('referralCode', isEqualTo: currentUserData.referredBy)
              .limit(1)
              .get();

          if (sponsorSnapshot.docs.isNotEmpty) {
            final sponsorDoc = sponsorSnapshot.docs.first;
            _sponsorUid = sponsorDoc.id; // Store sponsor UID
            final sponsorData = sponsorDoc.data();
            final sponsorFirstName = sponsorData['firstName'] ?? '';
            final sponsorLastName = sponsorData['lastName'] ?? '';
            final sponsorName = '$sponsorFirstName $sponsorLastName'.trim();

            if (sponsorName.isNotEmpty) {
              if (!mounted) return;
              _log('✅ Sponsor name resolved: $sponsorName (UID: $_sponsorUid)');
              setState(() => _sponsorName = sponsorName);
            } else {
              _log('⚠️ Sponsor name is empty despite user existing for referralCode: ${currentUserData.referredBy}');
            }
          } else {
            _log('❌ Sponsor user document not found for referralCode: ${currentUserData.referredBy}');
          }
        } catch (e) {
          _log('❌ Failed to load sponsor data: $e');
        }
      }

      // --- Retrieve Upline Admin Name ---
      if (currentUserData.uplineAdmin != null &&
          currentUserData.uplineAdmin!.isNotEmpty) {
        _uplineAdminUid = currentUserData.uplineAdmin; // Store upline admin UID
        _log('🔎 Looking up upline admin name by UID: $_uplineAdminUid');
        try {
          final adminUserDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_uplineAdminUid)
              .get();

          if (adminUserDoc.exists) {
            final adminData = adminUserDoc.data();
            if (adminData != null) {
              final adminFirstName = adminData['firstName'] ?? '';
              final adminLastName = adminData['lastName'] ?? '';
              final uplineAdminName = '$adminFirstName $adminLastName'.trim();
              if (uplineAdminName.isNotEmpty) {
                if (!mounted) return;
                _log('✅ Upline admin name resolved: $uplineAdminName (UID: $_uplineAdminUid)');
                setState(() => _uplineAdminName = uplineAdminName);
              } else {
                _log('⚠️ Upline admin name is empty despite user existing for UID: $_uplineAdminUid.');
              }
            }
          } else {
            _log('❌ Upline admin user document not found for UID: $_uplineAdminUid');
          }
        } catch (e) {
          _log('❌ Failed to load upline admin data: $e');
        }
      } else {
        _log('ℹ️ Current user has no upline_admin specified.');
      }
    }
  }

// PATCH START — Guard profile image upload for unsubscribed Admins
  void _showImageSourceActionSheetWrapper() async {
    // This _user refers to the profile owner being viewed
    if (_user?.role == 'admin') {
      final status =
          await SubscriptionService.checkAdminSubscriptionStatus(_user!.uid);
      final isActive = status['isActive'] == true;

      if (!isActive) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Subscription Required'),
            content: const Text(
                'To upload a profile image, please activate your Admin subscription.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushNamed(context, '/upgrade');
                },
                child: const Text('Upgrade Now'),
              ),
            ],
          ),
        );
        return;
      }
    }

    _showImageSourceActionSheet(context);
  }
// PATCH END

  Future<void> _showImageSourceActionSheet(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final file = File(pickedFile.path);

        try {
          final authUser = FirebaseAuth.instance.currentUser;
          if (authUser == null) {
            _log('❌ No FirebaseAuth user found. Cannot upload image.');
            return;
          }

          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );

          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_photos/${authUser.uid}/profile.jpg');

          await storageRef.putFile(file);
          final imageUrl = await storageRef.getDownloadURL();

          await FirestoreService()
              .updateUserField(authUser.uid, 'photoUrl', imageUrl);

          final updatedUser = _user!.copyWith(photoUrl: imageUrl);
          await SessionManager().setCurrentUser(updatedUser);
          if (!mounted) return;
          setState(() => _user = updatedUser);

          _log('✅ Image uploaded and profile updated successfully');
        } catch (e) {
          _log('❌ Error uploading image: $e');
        } finally {
          if (!mounted) return;
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _loadBiometricSetting() async {
    final enabled = await SessionManager().getBiometricEnabled();
    if (!mounted) return;
    setState(() => _biometricEnabled = enabled);
  }

  Future<void> _toggleBiometric(bool value) async {
    _log('🟢 Biometric toggle set to: $value');
    if (!mounted) return;
    setState(() => _biometricEnabled = value);
    await SessionManager().setBiometricEnabled(value);
  }

  void _navigateToEditProfile() {
    if (!mounted) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => EditProfileScreen(user: _user!)),
        )
        .then((_) => _loadUserData());
  }

  // Reusable widget for hyperlinked text that navigates to MemberDetailScreen
  Widget _buildClickableInfoRow(String label, String displayName, String userId) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemberDetailScreen(userId: userId),
                  ),
                );
              },
              child: Text(
                displayName,
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ensure _loggedInUser is available before checking its role
    final bool isCurrentUserUserRole = _loggedInUser?.role == 'user';

    return Scaffold(
      body: Column(
        children: [
          const AppHeaderWithMenu(),
          Expanded(
            child: _user == null
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 16.0, bottom: 24.0),
                          child: Center(
                            child: Text(
                              'My Profile',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Center(
                          child: GestureDetector(
                            onTap: _showImageSourceActionSheetWrapper,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundImage: _user!.photoUrl != null &&
                                          _user!.photoUrl!.isNotEmpty
                                      ? NetworkImage(_user!.photoUrl!)
                                      : const AssetImage(
                                              'assets/images/default_avatar.png')
                                          as ImageProvider,
                                ),
                                GestureDetector(
                                  onTap: _showImageSourceActionSheetWrapper,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black54,
                                    ),
                                    padding: const EdgeInsets.all(6),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildInfoRow(
                            'Name', '${_user!.firstName} ${_user!.lastName}'),
                        _buildInfoRow('Email', _user!.email),
                        _buildInfoRow('City', _user!.city ?? 'N/A'),
                        _buildInfoRow('State/Province', _user!.state ?? 'N/A'),
                        _buildInfoRow('Country', _user!.country ?? 'N/A'),
                        _buildInfoRow(
                            'Join Date',
                            _user!.createdAt != null
                                ? DateFormat.yMMMMd().format(_user!.createdAt!)
                                : 'N/A'),
                        if (_sponsorName != null && _sponsorName!.isNotEmpty && _sponsorUid != null)
                          _buildClickableInfoRow('Sponsor Name', _sponsorName!, _sponsorUid!),
                        // Display Team Leader ONLY if referredBy != uplineAdmin AND current user's role is 'user'
                        if (_uplineAdminName != null &&
                            _uplineAdminName!.isNotEmpty &&
                            _uplineAdminUid != null &&
                            _user!.referredBy != _user!.uplineAdmin &&
                            isCurrentUserUserRole) // Added this condition
                          _buildClickableInfoRow('Team Leader', _uplineAdminName!, _uplineAdminUid!),
                        const SizedBox(height: 30),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _navigateToEditProfile,
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit Profile'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0, vertical: 12.0),
                              textStyle: const TextStyle(fontSize: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
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
          ),
        ],
      ),
    );
  }
}
