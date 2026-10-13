import 'package:cloud_firestore/cloud_firestore.dart';

import 'availability_block.dart';

class BlockRepository {
  BlockRepository(this._db);
  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('availability_blocks');

  /// Blocks that haven't fully ended yet.
  Stream<List<AvailabilityBlock>> watchUpcoming() => _col
      .where('endDateTime', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))))
      .snapshots()
      .map((s) => s.docs.map(AvailabilityBlock.fromDoc).toList()..sort((a, b) => a.start.compareTo(b.start)));

  /// Students stop seeing the blocked period immediately: getAvailableSlots reads this collection live.
  Future<void> add({required DateTime start, required DateTime end, required String reason, required String adminUid}) {
    final ref = _col.doc();
    return ref.set({
      'id': ref.id,
      'startDateTime': Timestamp.fromDate(start.toUtc()),
      'endDateTime': Timestamp.fromDate(end.toUtc()),
      'reason': reason,
      'createdBy': adminUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> remove(String id) => _col.doc(id).delete();
}
