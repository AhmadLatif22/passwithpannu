import 'package:cloud_firestore/cloud_firestore.dart';

import '../../bookings/domain/booking.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    this.createdAt,
    this.termsVersion,
  });

  final String uid;
  final String fullName;
  final String email;
  final String? phone;
  final String
  role; // display mirror only; authority comes from the `admin` token claim
  final bool isActive;
  final DateTime? createdAt;
  final String? termsVersion;

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return AppUser(
      uid: doc.id,
      fullName: (d['fullName'] as String?) ?? '',
      email: (d['email'] as String?) ?? '',
      phone: d['phone'] as String?,
      role: (d['role'] as String?) ?? 'student',
      isActive: (d['isActive'] as bool?) ?? true,
      createdAt: tsToUtc(d['createdAt']),
      termsVersion: d['termsVersion'] as String?,
    );
  }
}

/// Who is signed in. `isAdmin` comes from the verified ID-token custom claim.
class AuthSession {
  const AuthSession({
    required this.uid,
    required this.email,
    required this.isAdmin,
  });
  final String uid;
  final String? email;
  final bool isAdmin;
}
