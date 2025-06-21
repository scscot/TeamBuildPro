import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? country;
  final String? state;
  final String? city;
  final String? referralCode;
  final String? referredBy;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? joined;
  final int level;
  final DateTime? qualifiedDate; // Keep as camelCase
  final List<String> uplineRefs;
  final int directSponsorCount;
  final int totalTeamCount;
  final String? bizOppRefUrl;
  final String? bizOpp;
  final String? role;
  final DateTime? bizVisitDate;
  final String? sponsorId;

  UserModel({
    required this.uid,
    this.sponsorId,
    this.email,
    this.firstName,
    this.lastName,
    this.country,
    this.state,
    this.city,
    this.referralCode,
    this.referredBy,
    this.photoUrl,
    this.createdAt,
    this.joined,
    this.level = 1,
    this.qualifiedDate,
    required this.uplineRefs,
    this.directSponsorCount = 0,
    this.totalTeamCount = 0,
    this.bizOppRefUrl,
    this.bizOpp,
    this.role,
    this.bizVisitDate,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data..['uid'] = doc.id);
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic dateValue) {
      if (dateValue == null) return null;
      if (dateValue is Timestamp) return dateValue.toDate();
      if (dateValue is String) return DateTime.tryParse(dateValue);
      return null;
    }

    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'],
      firstName: map['firstName'],
      lastName: map['lastName'],
      country: map['country'],
      sponsorId: map['sponsor_id'],
      state: map['state'],
      city: map['city'],
      referralCode: map['referralCode'],
      referredBy: map['referredBy'],
      photoUrl: map['photoUrl'],
      createdAt: parseDate(map['createdAt'] ?? map['joined']),
      joined: parseDate(map['createdAt'] ?? map['joined']),
      level: (map['level'] as num?)?.toInt() ?? 1,
      // THE FIX: Changed 'qualified_date' to 'qualifiedDate'
      qualifiedDate: parseDate(map['qualifiedDate']),
      uplineRefs: List<String>.from(map['upline_refs'] ?? []),
      // THE FIX: Changed 'direct_sponsor_count' and 'total_team_count' to camelCase
      directSponsorCount: (map['directSponsorCount'] as num?)?.toInt() ?? 0,
      totalTeamCount: (map['totalTeamCount'] as num?)?.toInt() ?? 0,
      bizOppRefUrl: map['biz_opp_ref_url'],
      bizOpp: map['biz_opp'],
      role: map['role'],
      bizVisitDate: parseDate(map['biz_visit_date']),
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
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'joined': joined != null ? Timestamp.fromDate(joined!) : null,
      'level': level,
      'qualifiedDate': qualifiedDate,
      'sponsor_id': sponsorId,
      'upline_refs': uplineRefs,
      'directSponsorCount': directSponsorCount,
      'totalTeamCount': totalTeamCount,
      'biz_opp_ref_url': bizOppRefUrl,
      'biz_opp': bizOpp,
      'role': role,
      'biz_visit_date': bizVisitDate,
    };
  }
}
