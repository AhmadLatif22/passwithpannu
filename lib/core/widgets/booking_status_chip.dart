import 'package:flutter/material.dart';

import '../../features/bookings/domain/booking_status.dart';
import '../theme/app_colors.dart';

class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip({super.key, required this.status, this.label});
  final BookingStatus status;
  final String? label;

  static Color colorFor(BookingStatus s) => switch (s) {
        BookingStatus.confirmed => AppColors.success,
        BookingStatus.pending => AppColors.warning,
        BookingStatus.changeRequested || BookingStatus.cancellationRequested => AppColors.info,
        BookingStatus.completed => AppColors.accent,
        BookingStatus.cancelled || BookingStatus.rejected => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    final c = colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(
        label ?? status.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c, fontSize: 12),
      ),
    );
  }
}
