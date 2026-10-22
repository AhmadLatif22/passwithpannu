import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firebase_providers.dart';
import '../domain/booking_request.dart';

class RequestRepository {
  RequestRepository(this._db, this._fn);
  final FirebaseFirestore _db;
  final FunctionsClient _fn;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('booking_requests');

  static List<BookingRequest> _newestFirst(
    QuerySnapshot<Map<String, dynamic>> s,
  ) => s.docs.map(BookingRequest.fromDoc).toList()
    ..sort(
      (a, b) => (b.createdAt ?? b.currentStart).compareTo(
        a.createdAt ?? a.currentStart,
      ),
    );

  /// A student's requests for one booking (both filters are required by the security rules).
  Stream<List<BookingRequest>> watchForBooking(
    String bookingId,
    String studentId,
  ) => _col
      .where('bookingId', isEqualTo: bookingId)
      .where('studentId', isEqualTo: studentId)
      .snapshots()
      .map(_newestFirst);

  /// Admin: requests for one booking.
  Stream<List<BookingRequest>> watchForBookingAdmin(String bookingId) => _col
      .where('bookingId', isEqualTo: bookingId)
      .snapshots()
      .map(_newestFirst);

  Stream<List<BookingRequest>> watchPending() =>
      _col.where('status', isEqualTo: 'pending').snapshots().map(_newestFirst);

  Stream<List<BookingRequest>> watchRecent({int limit = 60}) => _col
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(_newestFirst);

  /// Creates a REQUEST only. The lesson itself is never altered by the student.
  Future<void> create({
    required String bookingId,
    required RequestType type,
    String? reason,
    DateTime? preferredStart,
  }) => _fn.call('createBookingRequest', {
    'bookingId': bookingId,
    'requestType': type.name,
    if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    if (preferredStart != null)
      'requestedStartIso': preferredStart.toUtc().toIso8601String(),
  });

  Future<void> resolve({
    required String requestId,
    required bool approve,
    String? adminResponse,
    DateTime? newStart,
    bool override = false,
  }) => _fn.call('resolveBookingRequest', {
    'requestId': requestId,
    'decision': approve ? 'approve' : 'reject',
    if (adminResponse != null && adminResponse.trim().isNotEmpty)
      'adminResponse': adminResponse.trim(),
    if (newStart != null) 'newStartIso': newStart.toUtc().toIso8601String(),
    'override': override,
  });
}
