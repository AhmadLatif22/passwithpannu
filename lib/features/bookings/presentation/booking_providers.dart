import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/booking_repository.dart';
import '../domain/booking.dart';

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(ref.watch(firestoreProvider), ref.watch(functionsClientProvider)),
);

/// All of the signed-in student's bookings (live).
final studentBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <Booking>[]);
  return ref.watch(bookingRepositoryProvider).watchForStudent(uid);
});

/// Future lessons that still hold a slot, soonest first.
final upcomingBookingsProvider = Provider<AsyncValue<List<Booking>>>((ref) {
  return ref.watch(studentBookingsProvider).whenData((all) {
    final now = DateTime.now();
    return all.where((b) => b.isUpcoming(now)).toList();
  });
});

/// Completed, cancelled, rejected and already-finished lessons, newest first.
final bookingHistoryProvider = Provider<AsyncValue<List<Booking>>>((ref) {
  return ref.watch(studentBookingsProvider).whenData((all) {
    final now = DateTime.now();
    return all.where((b) => !b.isUpcoming(now)).toList()..sort((a, b) => b.start.compareTo(a.start));
  });
});

final nextBookingProvider = Provider<AsyncValue<Booking?>>((ref) {
  return ref.watch(upcomingBookingsProvider).whenData((l) => l.isEmpty ? null : l.first);
});

final bookingByIdProvider = StreamProvider.autoDispose.family<Booking?, String>(
  (ref, id) => ref.watch(bookingRepositoryProvider).watchById(id),
);
