// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/session_manager.dart';
import '../models/user_model.dart';
import '../screens/member_detail_screen.dart';
import 'edit_profile_screen.dart';
import '../widgets/header_widgets.dart';

class ProfileScreen extends StatefulWidget {
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
  UserModel? _user;
  UserModel? _loggedInUser;
  String? _sponsorName;
  String? _uplineAdminName;
  String? _sponsorUid;
  String? _uplineAdminUid;

  bool _biometricEnabled = false;
  bool _biometricsAvailable = false;
  // REMOVED: final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _userProfileSubscription;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (mounted) setState(() => _isLoading = true);

    await _loadUserData();
    await _loadBiometricSetting();
    await _checkBiometricSupport();
    if (mounted) setState(() => _isLoading = false);
  }

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

    _userProfileSubscription?.cancel();

    _userProfileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .listen((docSnapshot) async {
      if (docSnapshot.exists) {
        final currentUserData = UserModel.fromFirestore(docSnapshot);
        _log(
            '✅ Current user profile fetched/updated: ${currentUserData.firstName} ${currentUserData.lastName}');

        if (mounted) {
          setState(() {
            _user = currentUserData;
            _loggedInUser = currentUserData;
          });
        }

        if (currentUserData.referredBy != null &&
            currentUserData.referredBy!.isNotEmpty) {
          _log(
              '🔎 Looking up sponsor name by referralCode: ${currentUserData.referredBy}');
          try {
            final sponsorSnapshot = await FirebaseFirestore.instance
                .collection('users')
                .where('referralCode', isEqualTo: currentUserData.referredBy)
                .limit(1)
                .get();

            if (sponsorSnapshot.docs.isNotEmpty) {
              final sponsorDoc = sponsorSnapshot.docs.first;
              _sponsorUid = sponsorDoc.id;
              final sponsorData = sponsorDoc.data();
              final sponsorFirstName = sponsorData['firstName'] ?? '';
              final sponsorLastName = sponsorData['lastName'] ?? '';
              final sponsorName = '$sponsorFirstName $sponsorLastName'.trim();

              if (sponsorName.isNotEmpty) {
                if (!mounted) return;
                _log(
                    '✅ Sponsor name resolved: $sponsorName (UID: $_sponsorUid)');
                setState(() => _sponsorName = sponsorName);
              }
            }
          } catch (e) {
            _log('❌ Failed to load sponsor data: $e');
          }
        } else {
          if (mounted) setState(() => _sponsorName = null);
        }

        if (currentUserData.uplineAdmin != null &&
            currentUserData.uplineAdmin!.isNotEmpty) {
          _uplineAdminUid = currentUserData.uplineAdmin;
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
                  _log(
                      '✅ Upline admin name resolved: $uplineAdminName (UID: $_uplineAdminUid)');
                  setState(() => _uplineAdminName = uplineAdminName);
                }
              }
            }
          } catch (e) {
            _log('❌ Failed to load upline admin data: $e');
          }
        } else {
          _log('ℹ️ Current user has no upline_admin specified.');
          if (mounted) setState(() => _uplineAdminName = null);
        }
      } else {
        _log(
            '⚠️ Current user document does not exist in Firestore. UID: ${currentUser.uid}');
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
    });
  }

  // REMOVED: _showImageSourceActionSheetWrapper() and _showImageSourceActionSheet() functions
  // as photo uploading is no longer handled on this screen.

  Future<void> _loadBiometricSetting() async {
    final enabled = await SessionManager().getBiometricEnabled();
    if (!mounted) return;
    setState(() => _biometricEnabled = enabled);
  }

  Future<void> _toggleBiometric(bool value) async {
    _log('🟢 Biometric toggle set to: $value');
    if (!mounted) return;
    setState(() => _biometricEnabled = value);
    try {
      await SessionManager().setBiometricEnabled(value);
    } catch (e) {
      _log('❌ Error saving biometric preference: $e');
      if (!mounted) return;
      setState(() => _biometricEnabled = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save biometric setting: $e')),
      );
    }
  }

  void _navigateToEditProfile() {
    if (!mounted || _user == null) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
              builder: (_) => EditProfileScreen(
                    user: _user!,
                    firebaseConfig: widget.firebaseConfig,
                    initialAuthToken: widget.initialAuthToken,
                    appId: widget.appId,
                  )),
        )
        .then((_) => _loadInitialData());
  }

  Widget _buildClickableInfoRow(
      String label, String displayName, String userId) {
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
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemberDetailScreen(
                      userId: userId,
                      firebaseConfig: widget.firebaseConfig,
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
    _userProfileSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isCurrentUserUserRole = _loggedInUser?.role == 'user';

    return Scaffold(
      appBar: AppHeaderWithMenu(
        firebaseConfig: widget.firebaseConfig,
        initialAuthToken: widget.initialAuthToken,
        appId: widget.appId,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
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
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            Center(
                              // REMOVED: GestureDetector for photo upload.
                              // This is now a static display.
                              child: CircleAvatar(
                                radius: 50,
                                backgroundImage: _user!.photoUrl != null &&
                                        _user!.photoUrl!.isNotEmpty
                                    ? NetworkImage(_user!.photoUrl!)
                                    : const AssetImage(
                                            'assets/images/default_avatar.png')
                                        as ImageProvider,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildInfoRow('Name',
                                '${_user!.firstName} ${_user!.lastName}'),
                            _buildInfoRow('Email', _user!.email ?? 'N/A'),
                            _buildInfoRow('City', _user!.city ?? 'N/A'),
                            _buildInfoRow(
                                'State/Province', _user!.state ?? 'N/A'),
                            _buildInfoRow('Country', _user!.country ?? 'N/A'),
                            _buildInfoRow(
                                'Join Date',
                                _user!.createdAt != null
                                    ? DateFormat.yMMMMd()
                                        .format(_user!.createdAt!)
                                    : 'N/A'),
                            if (_sponsorName != null &&
                                _sponsorName!.isNotEmpty &&
                                _sponsorUid != null)
                              _buildClickableInfoRow(
                                  'Sponsor Name', _sponsorName!, _sponsorUid!),
                            if (_uplineAdminName != null &&
                                _uplineAdminName!.isNotEmpty &&
                                _uplineAdminUid != null &&
                                _user!.referredBy != _user!.uplineAdmin &&
                                isCurrentUserUserRole)
                              _buildClickableInfoRow('Team Leader',
                                  _uplineAdminName!, _uplineAdminUid!),
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
