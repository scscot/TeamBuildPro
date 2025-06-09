import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../screens/member_detail_screen.dart';
import '../widgets/header_widgets.dart';

enum JoinWindow {
  none,
  all,
  last24,
  last7,
  last30,
  newQualified,
}

class DownlineTeamScreen extends StatefulWidget {
  final String referredBy;
  const DownlineTeamScreen({super.key, required this.referredBy});

  @override
  State<DownlineTeamScreen> createState() => _DownlineTeamScreenState();
}

class _DownlineTeamScreenState extends State<DownlineTeamScreen> {
  bool isLoading = true;
  JoinWindow selectedJoinWindow = JoinWindow.none;
  Map<int, List<UserModel>> downlineByLevel = {};
  final currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  int levelOffset = 0;
  List<UserModel> allUsers = [];
  Map<JoinWindow, int> downlineCounts = {
    JoinWindow.all: 0,
    JoinWindow.last24: 0,
    JoinWindow.last7: 0,
    JoinWindow.last30: 0,
    JoinWindow.newQualified: 0,
  };
  String? uplineBizOpp;

  @override
  void initState() {
    super.initState();
    fetchDownline();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool userMatchesSearch(UserModel user) {
    final query = _searchQuery.toLowerCase();
    return [user.firstName, user.lastName, user.city, user.state, user.country]
        .any((field) => field != null && field.toLowerCase().contains(query));
  }

  Future<void> fetchDownline() async {
    setState(() => isLoading = true);
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      allUsers = snapshot.docs.map((doc) {
        final data = doc.data();
        return UserModel(
          uid: doc.id,
          email: data['email'] ?? '',
          firstName: data['firstName'],
          lastName: data['lastName'],
          country: data['country'],
          state: data['state'],
          city: data['city'],
          referredBy: data['referredBy'],
          referralCode: data['referralCode'],
          photoUrl: data['photoUrl'],
          joined: _parseTimestamp(data['createdAt']),
          createdAt: _parseTimestamp(data['createdAt']),
          level: data['level'],
          qualifiedDate: _parseTimestamp(data['qualified_date']),
          uplineAdmin: data['upline_admin'],
        );
      }).toList();

      final currentUserModel = allUsers.firstWhere(
        (u) => u.uid == currentUser?.uid,
        orElse: () => UserModel(uid: '', email: ''),
      );

      // debugPrint('⚠️ uplineAdmin = ${currentUserModel.uplineAdmin}');

      final uplineAdminCode = currentUserModel.uplineAdmin;
      if (uplineAdminCode != null && uplineAdminCode.isNotEmpty) {
        final uplineSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('referralCode', isEqualTo: uplineAdminCode)
            .limit(1)
            .get();
        if (uplineSnapshot.docs.isNotEmpty) {
          uplineBizOpp = uplineSnapshot.docs.first.data()['biz_opp'];
        }
      }

      final currentRefCode = currentUserModel.referralCode;

      if (currentRefCode == null || currentRefCode.isEmpty) {
        debugPrint('⚠️ Current user referralCode is null or empty');
        setState(() => isLoading = false);
        return;
      }

      levelOffset = currentUserModel.level ?? 0;
      final now = DateTime.now();

      downlineCounts.updateAll((_, __) => 0);
      final Set<String> visited = {};
      final Map<int, List<UserModel>> grouped = {};

      void collect(String refCode) {
        final direct = allUsers.where((u) => u.referredBy == refCode).toList();
        for (var user in direct) {
          final joined = user.joined;
          final qualified = user.qualifiedDate;
          if (user.level != null) {
            if (joined != null) {
              if (joined.isAfter(now.subtract(const Duration(days: 1)))) {
                downlineCounts[JoinWindow.last24] =
                    (downlineCounts[JoinWindow.last24] ?? 0) + 1;
              }
              if (joined.isAfter(now.subtract(const Duration(days: 7)))) {
                downlineCounts[JoinWindow.last7] =
                    (downlineCounts[JoinWindow.last7] ?? 0) + 1;
              }
              if (joined.isAfter(now.subtract(const Duration(days: 30)))) {
                downlineCounts[JoinWindow.last30] =
                    (downlineCounts[JoinWindow.last30] ?? 0) + 1;
              }
            }
            if (qualified != null) {
              downlineCounts[JoinWindow.newQualified] =
                  (downlineCounts[JoinWindow.newQualified] ?? 0) + 1;
            }
            downlineCounts[JoinWindow.all] =
                (downlineCounts[JoinWindow.all] ?? 0) + 1;

            final include = selectedJoinWindow == JoinWindow.none ||
                selectedJoinWindow == JoinWindow.all ||
                (selectedJoinWindow == JoinWindow.last24 &&
                    joined != null &&
                    joined.isAfter(now.subtract(const Duration(days: 1)))) ||
                (selectedJoinWindow == JoinWindow.last7 &&
                    joined != null &&
                    joined.isAfter(now.subtract(const Duration(days: 7)))) ||
                (selectedJoinWindow == JoinWindow.last30 &&
                    joined != null &&
                    joined.isAfter(now.subtract(const Duration(days: 30)))) ||
                (selectedJoinWindow == JoinWindow.newQualified &&
                    qualified != null);

            if (include && (_searchQuery.isEmpty || userMatchesSearch(user))) {
              grouped.putIfAbsent(user.level!, () => []).add(user);
            }

            if (!visited.contains(user.referralCode)) {
              visited.add(user.referralCode ?? '');
              collect(user.referralCode ?? '');
            }
          }
        }
      }

      collect(currentRefCode);

      grouped.forEach((level, users) {
        users.sort(
            (a, b) => b.joined?.compareTo(a.joined ?? DateTime(1970)) ?? 0);
      });

      setState(() {
        downlineByLevel = Map.fromEntries(
            grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
      });
    } catch (e) {
      debugPrint('Error loading downline: $e');
    }
    setState(() => isLoading = false);
  }

  String _dropdownLabel(JoinWindow window) {
    switch (window) {
      case JoinWindow.last24:
        return 'Joined Previous 24 Hours (${downlineCounts[JoinWindow.last24]})';
      case JoinWindow.last7:
        return 'Joined Previous 7 Days (${downlineCounts[JoinWindow.last7]})';
      case JoinWindow.last30:
        return 'Joined Previous 30 Days (${downlineCounts[JoinWindow.last30]})';
      case JoinWindow.newQualified:
        return 'Qualified Team Members (${downlineCounts[JoinWindow.newQualified]})';
      case JoinWindow.all:
        return 'All Team Members (${downlineCounts[JoinWindow.all]})';
      case JoinWindow.none:
        return 'Select Downline Report';
    }
  }

  Future<List<Map<String, dynamic>>> fetchEligibleDownlineUsers() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final settingsDoc = await FirebaseFirestore.instance
        .collection('admin_settings')
        .doc(uid)
        .get();
    if (!settingsDoc.exists) return [];

    final settings = settingsDoc.data();
    final directMin = settings?['direct_sponsor_min'] ?? 1;
    final totalMin = settings?['total_team_min'] ?? 1;
    final allowedCountries = List<String>.from(settings?['countries'] ?? []);

    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('upline_admin', isEqualTo: uid)
        .get();

    return querySnapshot.docs
        .map((doc) => doc.data())
        .where((user) =>
            (user['direct_sponsor_count'] ?? 0) >= directMin &&
            (user['total_team_count'] ?? 0) >= totalMin &&
            allowedCountries.contains(user['country']))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeaderWithMenu(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 24.0),
                  child: Center(
                    child: Text(
                      'Downline Team',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: DropdownButtonFormField<JoinWindow>(
                    isExpanded: true,
                    value: selectedJoinWindow,
                    decoration: InputDecoration(
                      labelText: 'Downline Report',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedJoinWindow = value;
                          _searchQuery = '';
                        });
                        fetchDownline();
                      }
                    },
                    // PATCH START
                    items: [
                      JoinWindow.none,
                      JoinWindow.all,
                      JoinWindow.newQualified,
                      JoinWindow.last24,
                      JoinWindow.last7,
                      JoinWindow.last30,
// PATCH END
                    ].map((window) {
                      return DropdownMenuItem(
                        value: window,
                        child: Text(_dropdownLabel(window)),
                      );
                    }).toList(),
                  ),
                ),
                if (selectedJoinWindow != JoinWindow.none)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search by name, country, state, city, etc.',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                        if (value.trim().isEmpty) fetchDownline();
                      },
                      onSubmitted: (value) {
                        setState(() => _searchQuery = value);
                        fetchDownline();
                      },
                    ),
                  ),
                if (selectedJoinWindow == JoinWindow.newQualified)
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black),
                        children: [
                          const TextSpan(
                              text:
                                  'These downline members are qualified to join '),
                          TextSpan(
                            text: uplineBizOpp ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const TextSpan(
                              text:
                                  ' however, they have not yet completed their '),
                          TextSpan(
                            text: uplineBizOpp ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const TextSpan(text: ' registration.'),
                        ],
                      ),
                    ),
                  ),
                if (selectedJoinWindow != JoinWindow.none)
                  Expanded(
                    child: ListView(
                      children: [
                        ...downlineByLevel.entries.map((entry) {
                          final adjustedLevel = entry.key - levelOffset;
                          final users = entry.value;
                          int localIndex = 1;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(thickness: 1),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 10),
                                child: Text(
                                  'Level $adjustedLevel (${users.length})',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue),
                                ),
                              ),
                              ...users.map((user) {
                                final index = localIndex++;
                                final spaceCount = index < 10
                                    ? 4
                                    : index < 100
                                        ? 6
                                        : 7;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '$index) ',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.normal),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      MemberDetailScreen(
                                                          userId: user.uid),
                                                ),
                                              );
                                            },
                                            child: Text(
                                              '${user.firstName ?? ''} ${user.lastName ?? ''}',
                                              style: const TextStyle(
                                                  color: Colors.blue,
                                                  decoration:
                                                      TextDecoration.underline),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${' ' * spaceCount}${user.city ?? ''}, ${user.state ?? ''} – ${user.country ?? ''}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.normal),
                                      ),
                                    ],
                                  ),
                                );
                              })
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
