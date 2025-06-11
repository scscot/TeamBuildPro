// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io';
import 'dart:async'; // Added for StreamSubscription
import 'dart:developer' as developer; // Import for logging

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/session_manager.dart';
import '../models/user_model.dart'; // Ensure UserModel is imported
import '../services/firestore_service.dart';
import '../screens/member_detail_screen.dart'; // Import MemberDetailScreen
import 'edit_profile_screen.dart';
// import 'login_screen.dart'; // Used in logout navigation
import '../widgets/header_widgets.dart';
import '../services/subscription_service.dart'; // Assuming SubscriptionService is in this path

class ProfileScreen extends StatefulWidget {
  // Add required parameters to ProfileScreen constructor
  final Map<String, dynamic> firebaseConfig;
  final String? initialAuthToken;
  final String appId;

  const ProfileScreen({
    super.key,
    required this.firebaseConfig,
    this.initialAuthToken,
    required this.appId,
  });

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
  final ImagePicker _picker = ImagePicker(); // Initialized ImagePicker
  bool _isLoading = true; // <--- This line ensures _isLoading is declared and initialized

  // Stream subscription for current user's profile data
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userProfileSubscription;

  @override
  void initState() {
    super.initState();
    _loadInitialData(); // Consolidated initial loading
  }

  Future<void> _loadInitialData() async {
    // Set loading to true immediately when starting to load initial data
    if (mounted) setState(() => _isLoading = true); // Ensure loading is true at start

    await _loadUserData(); // This will also listen to changes via _userProfileSubscription
    await _loadBiometricSetting();
    await _checkBiometricSupport();
    // Set _isLoading to false after all initial data is loaded
    if (mounted) setState(() => _isLoading = false);
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
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _log('❌ No FirebaseAuth user found. Cannot load profile data.');
      return;
    }

    // Cancel previous subscription to avoid duplicate listeners
    _userProfileSubscription?.cancel();

    _userProfileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .snapshots() // Listen for real-time updates
        .listen((docSnapshot) async {
      if (docSnapshot.exists) {
        final currentUserData = UserModel.fromFirestore(docSnapshot);
        _log('✅ Current user profile fetched/updated: ${currentUserData.firstName} ${currentUserData.lastName}');

        if (mounted) {
          setState(() {
            _user = currentUserData;
            _loggedInUser = currentUserData; // In this screen, the viewer is the user whose profile is shown.
          });
        }

        // --- Retrieve Sponsor Name ---
        if (currentUserData.referredBy != null && currentUserData.referredBy!.isNotEmpty) {
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
        } else {
          if (mounted) setState(() => _sponsorName = null); // Clear if no referrer
        }

        // --- Retrieve Upline Admin Name ---
        if (currentUserData.uplineAdmin != null && currentUserData.uplineAdmin!.isNotEmpty) {
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
          if (mounted) setState(() => _uplineAdminName = null); // Clear if no upline admin
        }
      } else {
        _log('⚠️ Current user document does not exist in Firestore. UID: ${currentUser.uid}');
        if (mounted) {
          setState(() {
            _user = null;
            _loggedInUser = null;
            _sponsorName = null;
            _uplineAdminName = null;
            _sponsorUid = null;
            _uplineAdminUid = null;
          });
        }
      }
    }, onError: (error) {
      _log('❌ Error listening to current user profile: $error');
      // Optionally set an error message in the UI
    });
  }

  // PATCH START — Guard profile image upload for unsubscribed Admins
  void _showImageSourceActionSheetWrapper() async {
    // This _user refers to the profile owner being viewed
    if (_user?.role == 'admin') {
      final status =
          await SubscriptionService.checkAdminSubscriptionStatus(_user!.uid);
      final isActive = status['isActive'] == true;

      if (!isActive) {
        if (!mounted) return; // Guarded context usage
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

    if (!mounted) return; // Guarded context usage
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
            if (!mounted) return; // Guarded context usage before using ScaffoldMessenger
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Authentication required to upload image.')),
            );
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
              .updateUser(authUser.uid, {'photoUrl': imageUrl}); // Use updateUser method

          final updatedUser = _user!.copyWith(photoUrl: imageUrl);
          await SessionManager().setCurrentUser(updatedUser);
          if (!mounted) return;
          setState(() => _user = updatedUser);

          _log('✅ Image uploaded and profile updated successfully');
        } catch (e) {
          _log('❌ Error uploading image: $e');
          if (!mounted) return; // Guarded context usage before using ScaffoldMessenger
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image upload failed: $e')),
          );
        } finally {
          // ignore: control_flow_in_finally
          if (!mounted) return;
          // Pop the loading dialog only if it was shown by this method
          // Check if the current route is a dialog before popping
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      }
    }
  }

  Future<void> _loadBiometricSetting() async {
    final enabled = await SessionManager().getBiometricEnabled(); // Corrected SessionManager access
    if (!mounted) return;
    setState(() => _biometricEnabled = enabled);
  }

  Future<void> _toggleBiometric(bool value) async {
    _log('🟢 Biometric toggle set to: $value');
    if (!mounted) return;
    setState(() => _biometricEnabled = value);
    try {
      await SessionManager().setBiometricEnabled(value); // Corrected SessionManager access
    } catch (e) {
      _log('❌ Error saving biometric preference: $e');
      if (!mounted) return;
      setState(() => _biometricEnabled = !value); // Revert UI on failure
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save biometric setting: $e')),
      );
    }
  }

  void _navigateToEditProfile() {
    if (!mounted) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
              builder: (_) => EditProfileScreen(
                user: _user!,
                firebaseConfig: widget.firebaseConfig, // Pass required args
                initialAuthToken: widget.initialAuthToken,
                appId: widget.appId,
              )),
        )
        .then((_) => _loadInitialData()); // Reload all data after editing
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
                if (!mounted) return; // Guarded context usage
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemberDetailScreen(
                      userId: userId,
                      firebaseConfig: widget.firebaseConfig, // Pass required args
                      initialAuthToken: widget.initialAuthToken,
                      appId: widget.appId,
                    ),
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
  void dispose() {
    _userProfileSubscription?.cancel(); // Cancel the subscription on dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure _loggedInUser is available before checking its role
    final bool isCurrentUserUserRole = _loggedInUser?.role == 'user';

    return Scaffold(
      appBar: AppHeaderWithMenu( // Pass required args
        firebaseConfig: widget.firebaseConfig,
        initialAuthToken: widget.initialAuthToken,
        appId: widget.appId,
      ),
      body: Column(
        children: [
          // Use a Consumer or Builder if AppHeaderWithMenu needs parameters from this screen
          // For now, assuming AppHeaderWithMenu takes widget.firebaseConfig etc. directly

          Expanded(
            child: _isLoading // Use the _isLoading state here
                ? const Center(child: CircularProgressIndicator())
                : _user == null
                    ? const Center(child: Text('User profile not found.'))
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
                                                  'assets/images/default_avatar.png') // Ensure this asset exists or provide another fallback
                                              as ImageProvider,
                                    ),
                                    GestureDetector(
                                      onTap: _showImageSourceActionSheetWrapper,
                                      child: Container(
                                        decoration: const BoxDecoration( // Made const
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
                            _buildInfoRow('Email', _user!.email ?? 'N/A'),
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
                                isCurrentUserUserRole)
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
