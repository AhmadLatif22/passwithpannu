import 'package:cloud_firestore/cloud_firestore.dart';

import '../../bookings/domain/booking.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.bookingId,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final String? bookingId;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      title: (d['title'] as String?) ?? '',
      body: (d['body'] as String?) ?? '',
      type: (d['type'] as String?) ?? '',
      isRead: (d['isRead'] as bool?) ?? false,
      createdAt: tsToUtc(d['createdAt']) ?? DateTime.now().toUtc(),
      bookingId: d['bookingId'] as String?,
    );
  }
}
