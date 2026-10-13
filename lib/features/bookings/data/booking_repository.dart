import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firebase_providers.dart';
import '../../availability/domain/slot.dart';
import '../domain/booking.dart';
import '../domain/booking_status.dart';
import '../domain/lesson_type.dart';

class BookingRepository {
  BookingRepository(this._db, this._fn);
  final FirebaseFirestore _db;
  final FunctionsClient _fn;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('bookings');

  static List<Booking> _sorted(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map(Booking.fromDoc).toList()..sort((a, b) => a.start.compareTo(b.start));

  /// A student's own bookings (rules only allow reading these).
  Stream<List<Booking>> watchForStudent(String uid) =>
      _col.where('studentId', isEqualTo: uid).snapshots().map(_sorted);

  Stream<Booking?> watchById(String id) =>
      _col.doc(id).snapshots().map((d) => d.exists ? Booking.fromDoc(d) : null);

  /// Admin diary window. A single-field range query, so no composite index is needed.
  Stream<List<Booking>> watchSince(DateTime since) => _col
      .where('startDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
      .snapshots()
      .map(_sorted);

  // ---- student ---------------------------------------------------------------
  Future<BookingConfirmation> create({
    required LessonType lessonType,
    required Slot slot,
    required PickupLocation pickup,
  }) async {
    final r = await _fn.call('createBooking', {
      'lessonType': lessonType.name,
      'startIso': slot.start.toIso8601String(),
      'pickupAddress': pickup.address,
      'pickupLatitude': pickup.lat,
      'pickupLongitude': pickup.lng,
    });
    return BookingConfirmation(
      bookingId: r['bookingId'] as String,
      reference: r['reference'] as String,
      status: BookingStatus.fromName(r['status'] as String),
    );
  }

  // ---- admin (all validated server-side) ----------------------------------------
  Future<void> adminCreate({
    required String studentId,
    required LessonType lessonType,
    required DateTime start,
    required PickupLocation pickup,
    bool override = false,
  }) =>
      _fn.call('adminCreateBooking', {
        'studentId': studentId,
        'lessonType': lessonType.name,
        'startIso': start.toUtc().toIso8601String(),
        'pickupAddress': pickup.address,
        'pickupLatitude': pickup.lat,
        'pickupLongitude': pickup.lng,
        'override': override,
      });

  Future<void> adminReschedule(String bookingId, DateTime newStart, {bool override = false}) =>
      _fn.call('adminRescheduleBooking', {
        'bookingId': bookingId,
        'newStartIso': newStart.toUtc().toIso8601String(),
        'override': override,
      });

  Future<void> adminCancel(String bookingId, String reason) =>
      _fn.call('adminCancelBooking', {'bookingId': bookingId, 'reason': reason});

  Future<void> adminComplete(String bookingId) => _fn.call('adminCompleteBooking', {'bookingId': bookingId});

  Future<void> adminUpdate(
    String bookingId, {
    LessonType? lessonType,
    PickupLocation? pickup,
    String? adminNotes,
    bool override = false,
  }) =>
      _fn.call('adminUpdateBooking', {
        'bookingId': bookingId,
        if (lessonType != null) 'lessonType': lessonType.name,
        if (adminNotes != null) 'adminNotes': adminNotes,
        if (pickup != null) ...{
          'pickupAddress': pickup.address,
          'pickupLatitude': pickup.lat,
          'pickupLongitude': pickup.lng,
        },
        'override': override,
      });
}
