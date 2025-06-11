// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/profile_screen.dart';
import '../screens/downline_team_screen.dart'; // Corrected: hide UserModel
import '../screens/share_screen.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/join_opportunity_screen.dart';
import '../services/session_manager.dart';
import '../screens/new_registration_screen.dart';
import '../screens/message_center_screen.dart';
import '../models/user_model.dart'; // Canonical UserModel
// Import main.dart to access firebaseConfig

class AppHeaderWithMenu extends StatefulWidget implements PreferredSizeWidget {
  final Map<String, dynamic> firebaseConfig;
  final String? initialAuthToken;
  final String appId;

  const AppHeaderWithMenu({
    super.key,
    required this.firebaseConfig,
    this.initialAuthToken,
    required this.appId,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<AppHeaderWithMenu> createState() => _AppHeaderWithMenuState();
}

class _AppHeaderWithMenuState extends State<AppHeaderWithMenu> {
  bool showJoinOpportunity = false;

  @override
  void initState() {
    super.initState();
    _checkJoinOpportunityEligibility();
  }

  Future<void> _checkJoinOpportunityEligibility() async {
    final user = await SessionManager().getCurrentUser();
    if (user == null || user.role == 'admin') return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = userDoc.data();
      if (data == null) return;

      final bizJoinDate = data['biz_join_date'];
      final directCount = data['direct_sponsor_count'] ?? 0;
      final teamCount = data['total_team_count'] ?? 0;

      final updatedUser = UserModel.fromFirestore(userDoc);
      final adminUid = updatedUser.uplineAdmin;

      DocumentSnapshot<Map<String, dynamic>>? adminSettingsDoc;
      if (adminUid != null && adminUid.isNotEmpty) {
        adminSettingsDoc = await FirebaseFirestore.instance
            .collection('admin_settings')
            .doc(adminUid)
            .get();
      }

      final int directSponsorMin = adminSettingsDoc?.data()?['direct_sponsor_min'] ?? 5;
      final int totalTeamMin = adminSettingsDoc?.data()?['total_team_min'] ?? 20;

      if (bizJoinDate == null &&
          directCount >= directSponsorMin &&
          teamCount >= totalTeamMin) {
        if (mounted) setState(() => showJoinOpportunity = true); // Guarded setState
      }
    } catch (e) {
      debugPrint('❌ Failed to evaluate join opportunity eligibility: $e');
    }
  }

  bool _shouldShowBackButton(BuildContext context) {
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    final settingsName = route?.settings.name;

    final suppressedRoutes = [
      '/',
      '/dashboard',
      '/login',
      '/home',
      '/register'
    ];

    return !(settingsName != null && suppressedRoutes.contains(settingsName));
  }

  @override
  Widget build(BuildContext context) {
    final isLoginScreen = context.widget.runtimeType == LoginScreen ||
        context.widget.runtimeType == DashboardScreen ||
        context.widget.runtimeType == MessageCenterScreen ||
        context.widget.runtimeType.toString().contains('HomePage') ||
        context.widget.runtimeType == NewRegistrationScreen;

    final showBack = _shouldShowBackButton(context);

    return AppBar(
      backgroundColor: const Color(0xFFEDE7F6),
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      title: const Text(
        'TeamBuild Pro',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
      ),
      centerTitle: true,
      actions: isLoginScreen
          ? null
          : [
              PopupMenuButton<String>(
                icon: const Icon(Icons.menu, color: Colors.black),
                onSelected: (String value) async {
                  final String? currentAuthToken = await FirebaseAuth.instance.currentUser?.getIdToken();
                  if (!mounted) return; // Guarded use of context

                  switch (value) {
                    case 'dashboard':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DashboardScreen(
                            firebaseConfig: widget.firebaseConfig,
                            initialAuthToken: currentAuthToken,
                            appId: widget.appId,
                          ),
                        ),
                      );
                      break;
                    case 'profile':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProfileScreen( // Pass required args
                              firebaseConfig: widget.firebaseConfig,
                              initialAuthToken: widget.initialAuthToken,
                              appId: widget.appId,
                            )),
                      );
                      break;
                    case 'downline':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DownlineTeamScreen(
                            firebaseConfig: widget.firebaseConfig,
                            initialAuthToken: currentAuthToken ?? '',
                            appId: widget.appId,
                          ),
                        ),
                      );
                      break;
                    case 'share':
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ShareScreen( // Pass required args
                          firebaseConfig: widget.firebaseConfig,
                          initialAuthToken: widget.initialAuthToken,
                          appId: widget.appId,
                        )),
                      );
                      break;
                    case 'join':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => JoinOpportunityScreen( // Pass required args
                              firebaseConfig: widget.firebaseConfig,
                              initialAuthToken: widget.initialAuthToken,
                              appId: widget.appId,
                            )),
                      );
                      break;
                    case 'messages':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => MessageCenterScreen( // Pass required args
                              firebaseConfig: widget.firebaseConfig,
                              initialAuthToken: widget.initialAuthToken,
                              appId: widget.appId,
                            )),
                      );
                      break;
                    case 'logout':
                      await SessionManager().clearSession();
                      await FirebaseAuth.instance.signOut();
                      if (!mounted) return; // Guarded context use
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => LoginScreen( // Pass required args
                          firebaseConfig: widget.firebaseConfig, // Access from widget
                          appId: widget.appId, // Access from widget
                        )),
                        (route) => false,
                      );
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  if (showJoinOpportunity)
                    const PopupMenuItem<String>(
                      value: 'join',
                      child: Text('Join Now!'),
                    ),
                  const PopupMenuItem<String>(
                    value: 'dashboard',
                    child: Text('Dashboard'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'profile',
                    child: Text('My Profile'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'downline',
                    child: Text('My Downline'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'messages',
                    child: Text('Messages Center'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'share',
                    child: Text('Share'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Text('Logout'),
                  ),
                ],
              )
            ],
    );
  }
}

class AppHeaderWithBack extends StatelessWidget implements PreferredSizeWidget {
  const AppHeaderWithBack({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFFEDE7F6),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      title: const Text(
        'TeamBuild Pro',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
      ),
      centerTitle: true,
    );
  }
}
