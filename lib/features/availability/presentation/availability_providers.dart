import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../bookings/domain/lesson_type.dart';
import '../data/availability_repository.dart';
import '../domain/slot.dart';

final availabilityRepositoryProvider =
    Provider<AvailabilityRepository>((ref) => AvailabilityRepository(ref.watch(functionsClientProvider)));

final placesRepositoryProvider =
    Provider<PlacesRepository>((ref) => PlacesRepository(ref.watch(functionsClientProvider)));

class SlotQuery {
  const SlotQuery(this.dateKey, this.lessonType, this.pickup);
  final String dateKey;
  final LessonType lessonType;
  final PickupLocation pickup;

  @override
  bool operator ==(Object other) =>
      other is SlotQuery && other.dateKey == dateKey && other.lessonType == lessonType && other.pickup == pickup;
  @override
  int get hashCode => Object.hash(dateKey, lessonType, pickup);
}

class DatesQuery {
  const DatesQuery(this.month, this.pickup);
  final String month; // yyyy-MM
  final PickupLocation pickup;

  @override
  bool operator ==(Object other) => other is DatesQuery && other.month == month && other.pickup == pickup;
  @override
  int get hashCode => Object.hash(month, pickup);
}

/// Genuinely bookable slots for a day (travel-time aware), always fetched live.
final availableSlotsProvider = FutureProvider.autoDispose.family<List<Slot>, SlotQuery>(
  (ref, q) => ref.watch(availabilityRepositoryProvider).slots(
        dateKey: q.dateKey,
        lessonType: q.lessonType,
        pickup: q.pickup,
      ),
);

final availableDatesProvider = FutureProvider.autoDispose.family<Set<String>, DatesQuery>(
  (ref, q) => ref.watch(availabilityRepositoryProvider).dates(month: q.month, pickup: q.pickup),
);
