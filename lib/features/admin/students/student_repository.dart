import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/domain/app_user.dart';

class StudentRepository {
  StudentRepository(this._db);
  final FirebaseFirestore _db;

  Stream<List<AppUser>> watchStudents() => _db
      .collection('users')
      .where('role', isEqualTo: 'student')
      .snapshots()
      .map(
        (s) => s.docs.map(AppUser.fromDoc).toList()
          ..sort(
            (a, b) =>
                a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
          ),
      );

  Stream<AppUser?> watchStudent(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? AppUser.fromDoc(d) : null);

  Future<void> setActive(String uid, bool active) => _db
      .collection('users')
      .doc(uid)
      .update({'isActive': active, 'updatedAt': FieldValue.serverTimestamp()});
}
