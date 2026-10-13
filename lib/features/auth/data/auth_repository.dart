import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/fcm_service.dart';
import '../domain/app_user.dart';

/// All Firebase Auth / profile-document access lives here, never in widgets.
class AuthRepository {
  AuthRepository(this._auth, this._db, this._fcm);
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FcmService _fcm;

  /// Emits on sign-in/out and token refresh. `isAdmin` is read from the verified token claim.
  Stream<AuthSession?> watchSession() => _auth.idTokenChanges().asyncMap((user) async {
        if (user == null) return null;
        final token = await user.getIdTokenResult();
        return AuthSession(uid: user.uid, email: user.email, isAdmin: token.claims?['admin'] == true);
      });

  Stream<AppUser?> watchProfile(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? AppUser.fromDoc(d) : null);

  Future<void> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    await _ensureStudentProfile(cred.user!);
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final user = cred.user!;
    await user.updateDisplayName(fullName.trim());
    await _createProfile(user, fullName.trim(), phone);
  }

  /// Repairs the rare case of an auth account whose profile write never landed.
  Future<void> _ensureStudentProfile(User user) async {
    final isAdmin = (await user.getIdTokenResult()).claims?['admin'] == true;
    if (isAdmin) return; // admin profile is created by scripts/set-admin.js
    final snap = await _db.collection('users').doc(user.uid).get();
    if (!snap.exists) await _createProfile(user, user.displayName ?? 'Student', null);
  }

  Future<void> _createProfile(User user, String fullName, String? phone) {
    final p = phone?.trim();
    return _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'fullName': fullName,
      'email': user.email,
      'phone': (p == null || p.isEmpty) ? null : p,
      'role': 'student', // display only; real authority is the server-set `admin` claim
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> updateProfile(String uid, {required String fullName, String? phone}) {
    final p = phone?.trim();
    return _db.collection('users').doc(uid).update({
      'fullName': fullName.trim(),
      'phone': (p == null || p.isEmpty) ? null : p,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signOut(String? uid) async {
    if (uid != null) await _fcm.unregister(uid);
    await _auth.signOut();
  }
}
