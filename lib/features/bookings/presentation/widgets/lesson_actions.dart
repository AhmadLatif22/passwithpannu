import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../lesson_requests/domain/booking_request.dart';
import '../../../lesson_requests/presentation/request_sheet.dart';
import '../../../settings/data/settings_repository.dart';
import '../../domain/booking.dart';
import '../../domain/booking_rules.dart';

/// Student actions for a booking: request change / cancellation only. There is deliberately
/// no "edit time" control anywhere in the student app.
class LessonActions extends ConsumerWidget {
  const LessonActions({super.key, required this.booking, this.compact = false});
  final Booking booking;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(settingsProvider).valueOrNull?.studentChangeNoticeHours ?? AppConstants.studentChangeNoticeHours;
    final a = BookingRules.studentActions(booking, DateTime.now(), noticeHours: notice);
    final t = Theme.of(context).textTheme;

    if (!a.canRequest) {
      if (a.message == null) return const SizedBox.shrink();
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(a.message!, style: t.bodySmall)),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14)),
            onPressed: () => showRequestSheet(context, booking, RequestType.reschedule),
            child: const Text('Request change'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14),
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            onPressed: () => showRequestSheet(context, booking, RequestType.cancel),
            child: const Text('Request cancellation'),
          ),
        ),
      ],
    );
  }
}
