import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/request_repository.dart';
import '../domain/booking_request.dart';

final requestRepositoryProvider = Provider<RequestRepository>(
  (ref) => RequestRepository(ref.watch(firestoreProvider), ref.watch(functionsClientProvider)),
);

/// Student: request history for one of their bookings.
final bookingRequestsProvider = StreamProvider.autoDispose.family<List<BookingRequest>, String>((ref, bookingId) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <BookingRequest>[]);
  return ref.watch(requestRepositoryProvider).watchForBooking(bookingId, uid);
});

/// Admin: request history for one booking.
final adminBookingRequestsProvider = StreamProvider.autoDispose.family<List<BookingRequest>, String>(
  (ref, bookingId) => ref.watch(requestRepositoryProvider).watchForBookingAdmin(bookingId),
);

final adminPendingRequestsProvider = StreamProvider<List<BookingRequest>>(
  (ref) => ref.watch(requestRepositoryProvider).watchPending(),
);

final adminRecentRequestsProvider = StreamProvider<List<BookingRequest>>(
  (ref) => ref.watch(requestRepositoryProvider).watchRecent(),
);
