import 'package:flutter/material.dart';

enum UserRole { resident, cityAdmin }

/// Default starting EXP for a freshly seeded Resident document. Residents
/// begin at 100 EXP and climb from there as reports get verified / tasks
/// are volunteered for.
const int kDefaultResidentExp = 100;

class AppUser {
  final String username;
  final UserRole role;
  // EXP value sourced from the `users` collection in MongoDB. Replaces the
  // earlier static `level` field — the home header reads this directly.
  final int currentExp;

  const AppUser({
    required this.username,
    required this.role,
    this.currentExp = kDefaultResidentExp,
  });

  /// Builds an [AppUser] from a Mongo `users` document. Role is parsed
  /// case-insensitively; unknown values fall back to [UserRole.resident].
  /// `currentExp` accepts any numeric type (Mongo can hand back int or
  /// double depending on driver path) and defaults to [kDefaultResidentExp]
  /// when missing.
  factory AppUser.fromMap(Map<String, dynamic> map) {
    final rawRole = (map['role'] as String?)?.toLowerCase();
    final role = rawRole == 'cityadmin' || rawRole == 'admin'
        ? UserRole.cityAdmin
        : UserRole.resident;
    final rawExp = map['currentExp'];
    final exp = rawExp is num ? rawExp.toInt() : kDefaultResidentExp;
    return AppUser(
      username: (map['username'] as String?) ?? '',
      role: role,
      currentExp: exp,
    );
  }

  AppUser copyWith({int? currentExp}) => AppUser(
        username: username,
        role: role,
        currentExp: currentExp ?? this.currentExp,
      );

  bool get isCityAdmin => role == UserRole.cityAdmin;
  bool get isResident => role == UserRole.resident;

  IconData get pfpIcon {
    switch (role) {
      case UserRole.resident:
        return Icons.person_outline_rounded;
      case UserRole.cityAdmin:
        return Icons.verified_user_outlined;
    }
  }

  String get roleLabel {
    switch (role) {
      case UserRole.resident:
        return 'Resident';
      case UserRole.cityAdmin:
        return 'City Admin';
    }
  }

  /// Short status string shown in the header chip — "150 EXP", "5000 EXP".
  String get headerStatus => '$currentExp EXP';

  /// The next milestone the EXP bar is filling toward. Tiered so both demo
  /// accounts land somewhere sensible on the bar: 150 EXP is 75% of the way
  /// to 200, 5000 EXP sits at the top of the 5000-tier (100%).
  int get _nextMilestone {
    if (currentExp <= 200) return 200;
    if (currentExp <= 1000) return 1000;
    if (currentExp <= 5000) return 5000;
    return ((currentExp ~/ 1000) + 1) * 1000;
  }

  /// Progress fraction (0..1) toward [_nextMilestone] — drives the
  /// horizontal bar inside the profile chip.
  double get expProgress {
    final next = _nextMilestone;
    if (next == 0) return 1.0;
    return (currentExp / next).clamp(0.0, 1.0);
  }
}
