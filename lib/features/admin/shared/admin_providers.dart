import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../auth/domain/app_user.dart';
import '../../bookings/domain/booking.dart';
import '../../bookings/presentation/booking_providers.dart';
import '../availability/availability_block.dart';
import '../availability/block_repository.dart';
import '../students/student_repository.dart';

final blockRepositoryProvider = Provider<BlockRepository>((ref) => BlockRepository(ref.watch(firestoreProvider)));
final studentRepositoryProvider =
    Provider<StudentRepository>((ref) => StudentRepository(ref.watch(firestoreProvider)));

/// Admin window: the last 180 days onwards. Older history is not streamed (keeps reads small).
final adminBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final since = DateTime.now().subtract(const Duration(days: 180));
  return ref.watch(bookingRepositoryProvider).watchSince(since);
});

final adminStudentsProvider = StreamProvider<List<AppUser>>(
  (ref) => ref.watch(studentRepositoryProvider).watchStudents(),
);

final adminStudentProvider = StreamProvider.autoDispose.family<AppUser?, String>(
  (ref, uid) => ref.watch(studentRepositoryProvider).watchStudent(uid),
);

final blocksProvider = StreamProvider<List<AvailabilityBlock>>(
  (ref) => ref.watch(blockRepositoryProvider).watchUpcoming(),
);

/// Today's lessons (business day), soonest first, excluding cancelled ones.
final todaysLessonsProvider = Provider<AsyncValue<List<Booking>>>((ref) {
  return ref.watch(adminBookingsProvider).whenData((all) {
    final now = DateTime.now();
    return all.where((b) => b.status.occupiesSlot && _sameBusinessDay(b.start, now)).toList();
  });
});

bool _sameBusinessDay(DateTime a, DateTime b) => DateTimeUtils.dateKey(a) == DateTimeUtils.dateKey(b);
