// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- ADDED: Imports for the new menu destinations ---
import '../screens/downline_team_screen.dart';
import '../screens/share_screen.dart';
import '../screens/message_center_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/join_opportunity_screen.dart';
// --- END ADDED ---

import '../screens/profile_screen.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../services/session_manager.dart';
import '../config/app_constants.dart';

class AppHeaderWithMenu extends StatefulWidget implements PreferredSizeWidget {
  final String? initialAuthToken;
  final String appId;

  const AppHeaderWithMenu({
    super.key,
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

      final int directSponsorMin = AppConstants.projectWideDirectSponsorMin;
      final int totalTeamMin = AppConstants.projectWideTotalTeamMin;

      if ((data['biz_join_date'] == null) &&
          (data['direct_sponsor_count'] ?? 0) >= directSponsorMin &&
          (data['total_team_count'] ?? 0) >= totalTeamMin) {
        if (mounted) setState(() => showJoinOpportunity = true);
      }
    } catch (e) {
      debugPrint('❌ Failed to evaluate join opportunity: $e');
    }
  }

  // This is the improved back button logic from the new file
  bool _shouldShowBackButton(BuildContext context) {
    return ModalRoute.of(context)?.canPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // This is the improved logic to determine when to show the menu
    final isLoginScreen = ModalRoute.of(context)?.settings.name == '/login';

    return AppBar(
      backgroundColor: const Color(0xFFEDE7F6),
      automaticallyImplyLeading: false,
      leading: _shouldShowBackButton(context)
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context))
          : null,
      title: const Text('TeamBuild Pro',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
      centerTitle: true,
      actions: isLoginScreen
          ? null
          : [
              PopupMenuButton<String>(
                icon: const Icon(Icons.menu, color: Colors.black),
                onSelected: (String value) async {
                  final String? token =
                      await FirebaseAuth.instance.currentUser?.getIdToken();
                  if (!mounted) return;

                  // --- UPDATED: Added cases for all menu items ---
                  switch (value) {
                    case 'dashboard':
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => DashboardScreen(
                                  initialAuthToken: token,
                                  appId: widget.appId)));
                      break;
                    case 'profile':
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ProfileScreen(
                                  initialAuthToken: widget.initialAuthToken,
                                  appId: widget.appId)));
                      break;
                    case 'downline':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DownlineTeamScreen(
                            initialAuthToken: token ?? '',
                            appId: widget.appId,
                          ),
                        ),
                      );
                      break;
                    case 'share':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ShareScreen(
                                  initialAuthToken: widget.initialAuthToken,
                                  appId: widget.appId,
                                )),
                      );
                      break;
                    case 'join':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => JoinOpportunityScreen(
                                  initialAuthToken: widget.initialAuthToken,
                                  appId: widget.appId,
                                )),
                      );
                      break;
                    case 'messages':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => MessageCenterScreen(
                                  initialAuthToken: widget.initialAuthToken,
                                  appId: widget.appId,
                                )),
                      );
                      break;
                    case 'notifications':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => NotificationsScreen(
                                  initialAuthToken: widget.initialAuthToken,
                                  appId: widget.appId,
                                )),
                      );
                      break;
                    case 'logout':
                      await SessionManager().clearSession();
                      await FirebaseAuth.instance.signOut();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (_) => LoginScreen(appId: widget.appId)),
                        (route) => false,
                      );
                      break;
                  }
                },
                // --- UPDATED: Added all menu items from the old file ---
                itemBuilder: (BuildContext context) => [
                  if (showJoinOpportunity)
                    const PopupMenuItem<String>(
                        value: 'join', child: Text('Join Now!')),
                  const PopupMenuItem<String>(
                      value: 'dashboard', child: Text('Dashboard')),
                  const PopupMenuItem<String>(
                    value: 'downline',
                    child: Text('My Downline'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'share',
                    child: Text('Grow My Team'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'messages',
                    child: Text('Messages Center'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'notifications',
                    child: Text('Notifications'),
                  ),
                  const PopupMenuItem<String>(
                      value: 'profile', child: Text('My Profile')),
                  const PopupMenuItem<String>(
                      value: 'logout', child: Text('Logout')),
                ],
              )
            ],
    );
  }
}
