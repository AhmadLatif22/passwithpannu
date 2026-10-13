import '../../../core/constants/app_constants.dart';
import 'booking.dart';
import 'booking_status.dart';

/// What a student may do with a booking right now.
class StudentActionAvailability {
  const StudentActionAvailability({required this.canRequest, this.message});
  final bool canRequest;

  /// Why requests are unavailable (shown instead of the buttons), if applicable.
  final String? message;
}

/// Pure business rules (unit-tested). The server enforces the same rules.
abstract final class BookingRules {
  static DateTime endTime(DateTime start, {int minutes = AppConstants.lessonDurationMinutes}) =>
      start.add(Duration(minutes: minutes));

  /// 48-hour rule: a student request needs at least [hours] of notice.
  static bool hasEnoughNotice(DateTime start, DateTime now,
          {int hours = AppConstants.studentChangeNoticeHours}) =>
      start.difference(now) >= Duration(hours: hours);

  static const lateMessage =
      'Changes or cancellations must normally be requested at least 48 hours before your lesson.';

  static StudentActionAvailability studentActions(Booking b, DateTime now,
      {int noticeHours = AppConstants.studentChangeNoticeHours}) {
    switch (b.status) {
      case BookingStatus.confirmed:
        if (!hasEnoughNotice(b.start, now, hours: noticeHours)) {
          return const StudentActionAvailability(canRequest: false, message: lateMessage);
        }
        return const StudentActionAvailability(canRequest: true);
      case BookingStatus.changeRequested:
      case BookingStatus.cancellationRequested:
        return const StudentActionAvailability(
          canRequest: false,
          message: 'Your request is with Pass With Pannu and will be reviewed shortly. Your lesson stays as booked until then.',
        );
      case BookingStatus.pending:
        return const StudentActionAvailability(
          canRequest: false,
          message: 'This booking is awaiting confirmation.',
        );
      case BookingStatus.cancelled:
      case BookingStatus.completed:
      case BookingStatus.rejected:
        return const StudentActionAvailability(canRequest: false);
    }
  }
}
