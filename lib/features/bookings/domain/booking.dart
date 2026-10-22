import 'package:cloud_firestore/cloud_firestore.dart';

import 'booking_status.dart';
import 'lesson_type.dart';

DateTime? tsToUtc(Object? v) => v is Timestamp ? v.toDate().toUtc() : null;

/// A driving lesson booking. Read-only on the client: every change goes through a Cloud Function.
class Booking {
  const Booking({
    required this.id,
    required this.reference,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.studentPhone,
    required this.lessonType,
    required this.start,
    required this.end,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.status,
    this.createdAt,
    this.previousStart,
    this.cancellationReason,
    this.cancelledBy,
    this.cancelledAt,
    this.adminNotes,
  });

  final String id;
  final String reference;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String? studentPhone;
  final LessonType lessonType;
  final DateTime start; // UTC
  final DateTime end; // UTC
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final BookingStatus status;
  final DateTime? createdAt;
  final DateTime? previousStart;
  final String? cancellationReason;
  final String? cancelledBy;
  final DateTime? cancelledAt;
  final String? adminNotes;

  Duration get duration => end.difference(start);

  /// Still ahead of us and still holding a slot in the diary.
  bool isUpcoming(DateTime now) => status.occupiesSlot && end.isAfter(now);

  factory Booking.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final start = tsToUtc(d['startDateTime']) ?? DateTime.now().toUtc();
    return Booking(
      id: doc.id,
      reference:
          (d['reference'] as String?) ?? doc.id.substring(0, 6).toUpperCase(),
      studentId: (d['studentId'] as String?) ?? '',
      studentName: (d['studentName'] as String?) ?? '',
      studentEmail: (d['studentEmail'] as String?) ?? '',
      studentPhone: d['studentPhone'] as String?,
      lessonType: LessonType.fromName((d['lessonType'] as String?) ?? 'manual'),
      start: start,
      end: tsToUtc(d['endDateTime']) ?? start.add(const Duration(hours: 2)),
      pickupAddress: (d['pickupAddress'] as String?) ?? '',
      pickupLat: (d['pickupLatitude'] as num?)?.toDouble() ?? 0,
      pickupLng: (d['pickupLongitude'] as num?)?.toDouble() ?? 0,
      status: BookingStatus.fromName((d['status'] as String?) ?? 'pending'),
      createdAt: tsToUtc(d['createdAt']),
      previousStart: tsToUtc(d['previousStartTime']),
      cancellationReason: d['cancellationReason'] as String?,
      cancelledBy: d['cancelledBy'] as String?,
      cancelledAt: tsToUtc(d['cancelledAt']),
      adminNotes: d['adminNotes'] as String?,
    );
  }
}

/// Returned by the createBooking callable.
class BookingConfirmation {
  const BookingConfirmation({
    required this.bookingId,
    required this.reference,
    required this.status,
  });
  final String bookingId;
  final String reference;
  final BookingStatus status;
}
