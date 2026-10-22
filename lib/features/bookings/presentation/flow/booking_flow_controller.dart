import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../availability/domain/slot.dart';
import '../../domain/booking.dart';
import '../../domain/lesson_type.dart';
import '../booking_providers.dart';

/// What the student has chosen so far. Changing an earlier choice clears later ones,
/// because availability depends on pickup location and date.
class BookingDraft {
  const BookingDraft({this.lessonType, this.pickup, this.dateKey, this.slot});
  final LessonType? lessonType;
  final PickupLocation? pickup;
  final String? dateKey;
  final Slot? slot;

  bool get isComplete =>
      lessonType != null && pickup != null && dateKey != null && slot != null;
}

class BookingFlowController extends Notifier<BookingDraft> {
  @override
  BookingDraft build() => const BookingDraft();

  void setType(LessonType t) => state = BookingDraft(
    lessonType: t,
    pickup: state.pickup,
    dateKey: state.dateKey,
    slot: state.slot,
  );

  void setPickup(PickupLocation p) =>
      state = BookingDraft(lessonType: state.lessonType, pickup: p);

  void setDate(String key) => state = BookingDraft(
    lessonType: state.lessonType,
    pickup: state.pickup,
    dateKey: key,
  );

  void setSlot(Slot s) => state = BookingDraft(
    lessonType: state.lessonType,
    pickup: state.pickup,
    dateKey: state.dateKey,
    slot: s,
  );

  void clearSlot() => state = BookingDraft(
    lessonType: state.lessonType,
    pickup: state.pickup,
    dateKey: state.dateKey,
  );

  void reset() => state = const BookingDraft();
}

final bookingFlowProvider =
    NotifierProvider<BookingFlowController, BookingDraft>(
      BookingFlowController.new,
    );

/// Submits the draft. The server re-validates the slot inside a transaction, so a
/// slot taken while the review screen was open fails cleanly with `slot_unavailable`.
class BookingSubmitController extends AsyncNotifier<BookingConfirmation?> {
  @override
  FutureOr<BookingConfirmation?> build() => null;

  Future<BookingConfirmation?> submit() async {
    final d = ref.read(bookingFlowProvider);
    if (!d.isComplete) return null;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(bookingRepositoryProvider)
          .create(lessonType: d.lessonType!, slot: d.slot!, pickup: d.pickup!),
    );
    return state.valueOrNull;
  }

  void reset() => state = const AsyncData(null);
}

final bookingSubmitProvider =
    AsyncNotifierProvider<BookingSubmitController, BookingConfirmation?>(
      BookingSubmitController.new,
    );
