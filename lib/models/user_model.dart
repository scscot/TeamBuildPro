import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class UserModel with ChangeNotifier {
  final String uid;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? country;
  final String? state;
  final String? city;
  final String? referralCode;
  final String? referredBy;
  final String? photoUrl;
  final String? bizOppRefUrl;
  final String? uplineAdmin;
  final DateTime? createdAt;
  final DateTime? joined;
  final int level;
  final DateTime? qualifiedDate;
  final String? role;
  final bool? isUpgraded;
  final String? bizOpp;
  final DateTime? bizVisitDate;
  final List<String> uplineRefs;

  // These are kept for UI compatibility in other screens.
  final int directSponsorCount;
  final int totalTeamCount;
  final List<String>? downlineIds;
  final int? directSponsorMin;
  final int? totalTeamMin;

  UserModel({
    required this.uid,
    required this.email,
    this.firstName,
    this.lastName,
    this.country,
    this.state,
    this.city,
    this.referralCode,
    this.referredBy,
    this.photoUrl,
    this.bizOppRefUrl,
    this.uplineAdmin,
    this.createdAt,
    this.joined,
    required this.level,
    this.qualifiedDate,
    this.role,
    this.isUpgraded,
    this.bizOpp,
    this.bizVisitDate,
    required this.uplineRefs,
    this.directSponsorCount = 0,
    this.totalTeamCount = 0,
    this.downlineIds,
    this.directSponsorMin,
    this.totalTeamMin,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic dateData) {
      if (dateData == null) return null;
      if (dateData is Timestamp) return dateData.toDate();
      if (dateData is String) return DateTime.tryParse(dateData);
      return null;
    }

    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      firstName: data['firstName'],
      lastName: data['lastName'],
      country: data['country'],
      state: data['state'],
      city: data['city'],
      referralCode: data['referralCode'],
      referredBy: data['referredBy'],
      photoUrl: data['photoUrl'],
      bizOppRefUrl: data['bizOppRefUrl'],
      uplineAdmin: data['uplineAdmin'],
      createdAt: parseDate(data['createdAt']),
      joined: parseDate(data['joined']),
      level: data['level'] ?? 1,
      qualifiedDate: parseDate(data['qualifiedDate']),
      role: data['role'],
      isUpgraded: data['isUpgraded'],
      bizOpp: data['bizOpp'],
      bizVisitDate: parseDate(data['bizVisitDate']),
      uplineRefs: List<String>.from(data['upline_refs'] ?? []),
      directSponsorCount: data['directSponsorCount'] ?? 0,
      totalTeamCount: data['totalTeamCount'] ?? 0,
      downlineIds: data['downlineIds'] != null
          ? List<String>.from(data['downlineIds'])
          : null,
      directSponsorMin: data['directSponsorMin'],
      totalTeamMin: data['totalTeamMin'],
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    data['uid'] = doc.id;
    return UserModel.fromMap(data);
  }

  UserModel copyWith(
      {String? uid,
      String? email,
      String? firstName,
      String? lastName,
      String? country,
      String? state,
      String? city,
      String? referralCode,
      String? referredBy,
      String? photoUrl,
      String? bizOppRefUrl,
      String? uplineAdmin,
      DateTime? createdAt,
      DateTime? joined,
      int? level,
      DateTime? qualifiedDate,
      String? role,
      bool? isUpgraded,
      String? bizOpp,
      DateTime? bizVisitDate,
      List<String>? uplineRefs,
      int? directSponsorCount,
      int? totalTeamCount,
      List<String>? downlineIds,
      int? directSponsorMin,
      int? totalTeamMin}) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      country: country ?? this.country,
      state: state ?? this.state,
      city: city ?? this.city,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      photoUrl: photoUrl ?? this.photoUrl,
      bizOppRefUrl: bizOppRefUrl ?? this.bizOppRefUrl,
      uplineAdmin: uplineAdmin ?? this.uplineAdmin,
      createdAt: createdAt ?? this.createdAt,
      joined: joined ?? this.joined,
      level: level ?? this.level,
      qualifiedDate: qualifiedDate ?? this.qualifiedDate,
      role: role ?? this.role,
      isUpgraded: isUpgraded ?? this.isUpgraded,
      bizOpp: bizOpp ?? this.bizOpp,
      bizVisitDate: bizVisitDate ?? this.bizVisitDate,
      uplineRefs: uplineRefs ?? this.uplineRefs,
      directSponsorCount: directSponsorCount ?? this.directSponsorCount,
      totalTeamCount: totalTeamCount ?? this.totalTeamCount,
      downlineIds: downlineIds ?? this.downlineIds,
      directSponsorMin: directSponsorMin ?? this.directSponsorMin,
      totalTeamMin: totalTeamMin ?? this.totalTeamMin,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'country': country,
      'state': state,
      'city': city,
      'referralCode': referralCode,
      'referredBy': referredBy,
      'photoUrl': photoUrl,
      'bizOppRefUrl': bizOppRefUrl,
      'uplineAdmin': uplineAdmin,
      'createdAt': createdAt,
      'joined': joined,
      'level': level,
      'qualifiedDate': qualifiedDate,
      'role': role,
      'isUpgraded': isUpgraded,
      'bizOpp': bizOpp,
      'bizVisitDate': bizVisitDate,
      'upline_refs': uplineRefs,
      'direct_sponsor_count': directSponsorCount,
      'total_team_count': totalTeamCount,
      'downlineIds': downlineIds,
      'directSponsorMin': directSponsorMin,
      'totalTeamMin': totalTeamMin,
    };
  }
}
