/// Single source of truth for booking states. Never compare raw strings.
/// The Cloud Functions mirror [allowedTransitions] in TypeScript.
enum BookingStatus {
  pending,
  confirmed,
  changeRequested,
  cancellationRequested,
  cancelled,
  completed,
  rejected;

  static BookingStatus fromName(String value) =>
      BookingStatus.values.firstWhere(
        (e) => e.name == value,
        orElse: () => throw ArgumentError('Unknown BookingStatus: $value'),
      );

  String get label => switch (this) {
    BookingStatus.pending => 'Pending',
    BookingStatus.confirmed => 'Confirmed',
    BookingStatus.changeRequested => 'Change requested',
    BookingStatus.cancellationRequested => 'Cancellation requested',
    BookingStatus.cancelled => 'Cancelled',
    BookingStatus.completed => 'Completed',
    BookingStatus.rejected => 'Rejected',
  };

  /// Statuses whose time slot is still occupied in the diary.
  /// A pending change/cancel request keeps the original slot blocked
  /// until the admin decides.
  bool get occupiesSlot => switch (this) {
    BookingStatus.pending ||
    BookingStatus.confirmed ||
    BookingStatus.changeRequested ||
    BookingStatus.cancellationRequested => true,
    _ => false,
  };

  bool get isTerminal => switch (this) {
    BookingStatus.cancelled ||
    BookingStatus.completed ||
    BookingStatus.rejected => true,
    _ => false,
  };

  static const Map<BookingStatus, Set<BookingStatus>> allowedTransitions = {
    BookingStatus.pending: {
      BookingStatus.confirmed,
      BookingStatus.rejected,
      BookingStatus.cancelled,
    },
    BookingStatus.confirmed: {
      BookingStatus.changeRequested,
      BookingStatus.cancellationRequested,
      BookingStatus.cancelled, // admin
      BookingStatus.completed, // admin
    },
    BookingStatus.changeRequested: {
      BookingStatus.confirmed, // approved (new time) or rejected (unchanged)
      BookingStatus.cancelled,
      BookingStatus.completed,
    },
    BookingStatus.cancellationRequested: {
      BookingStatus.cancelled, // approved
      BookingStatus.confirmed, // rejected
      BookingStatus.completed,
    },
    BookingStatus.cancelled: {},
    BookingStatus.completed: {},
    BookingStatus.rejected: {},
  };

  bool canTransitionTo(BookingStatus next) =>
      allowedTransitions[this]?.contains(next) ?? false;
}
