import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/app_notification.dart';

class NotificationRepository {
  NotificationRepository(this._db);
  final FirebaseFirestore _db;

  Stream<List<AppNotification>> watch(String uid) => _db
      .collection('notifications')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map(
        (s) =>
            s.docs.map(AppNotification.fromDoc).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  Future<void> markRead(String id) =>
      _db.collection('notifications').doc(id).update({'isRead': true});

  Future<void> markAllRead(Iterable<String> ids) async {
    final batch = _db.batch();
    for (final id in ids) {
      batch.update(_db.collection('notifications').doc(id), {'isRead': true});
    }
    await batch.commit();
  }
}
