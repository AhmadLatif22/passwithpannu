import 'package:cloud_firestore/cloud_firestore.dart';

import '../../bookings/domain/booking.dart';

class AvailabilityBlock {
  const AvailabilityBlock({
    required this.id,
    required this.start,
    required this.end,
    required this.reason,
  });
  final String id;
  final DateTime start; // UTC
  final DateTime end; // UTC
  final String reason;

  bool overlaps(DateTime a, DateTime b) => start.isBefore(b) && a.isBefore(end);

  factory AvailabilityBlock.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? const <String, dynamic>{};
    final s = tsToUtc(d['startDateTime']) ?? DateTime.now().toUtc();
    return AvailabilityBlock(
      id: doc.id,
      start: s,
      end: tsToUtc(d['endDateTime']) ?? s.add(const Duration(hours: 1)),
      reason: (d['reason'] as String?) ?? '',
    );
  }
}
