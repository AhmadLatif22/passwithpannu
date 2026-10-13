import 'package:cloud_firestore/cloud_firestore.dart';

import '../../bookings/domain/booking.dart';

enum RequestType {
  reschedule,
  cancel;

  String get label => this == RequestType.cancel ? 'Cancellation' : 'Change';
  static RequestType fromName(String v) => RequestType.values.firstWhere((e) => e.name == v, orElse: () => RequestType.reschedule);
}

enum RequestStatus {
  pending,
  approved,
  rejected;

  String get label => switch (this) {
        RequestStatus.pending => 'Pending',
        RequestStatus.approved => 'Approved',
        RequestStatus.rejected => 'Declined',
      };
  static RequestStatus fromName(String v) => RequestStatus.values.firstWhere((e) => e.name == v, orElse: () => RequestStatus.pending);
}

class BookingRequest {
  const BookingRequest({
    required this.id,
    required this.bookingId,
    required this.studentId,
    required this.studentName,
    required this.type,
    required this.status,
    required this.currentStart,
    this.requestedStart,
    this.reason,
    this.adminResponse,
    this.createdAt,
    this.resolvedAt,
    this.lessonType,
    this.pickupAddress,
    this.reference,
  });

  final String id;
  final String bookingId;
  final String studentId;
  final String studentName;
  final RequestType type;
  final RequestStatus status;
  final DateTime currentStart;
  final DateTime? requestedStart;
  final String? reason;
  final String? adminResponse;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? lessonType;
  final String? pickupAddress;
  final String? reference;

  factory BookingRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return BookingRequest(
      id: doc.id,
      bookingId: (d['bookingId'] as String?) ?? '',
      studentId: (d['studentId'] as String?) ?? '',
      studentName: (d['studentName'] as String?) ?? '',
      type: RequestType.fromName((d['requestType'] as String?) ?? 'reschedule'),
      status: RequestStatus.fromName((d['status'] as String?) ?? 'pending'),
      currentStart: tsToUtc(d['currentDateTime']) ?? DateTime.now().toUtc(),
      requestedStart: tsToUtc(d['requestedDateTime']),
      reason: d['reason'] as String?,
      adminResponse: d['adminResponse'] as String?,
      createdAt: tsToUtc(d['createdAt']),
      resolvedAt: tsToUtc(d['resolvedAt']),
      lessonType: d['lessonType'] as String?,
      pickupAddress: d['pickupAddress'] as String?,
      reference: d['reference'] as String?,
    );
  }
}
