import 'package:flutter/material.dart';

import '../../features/bookings/domain/booking.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../utils/date_time_utils.dart';
import 'app_card.dart';
import 'booking_status_chip.dart';

class LessonCard extends StatelessWidget {
  const LessonCard({
    super.key,
    required this.booking,
    this.onTap,
    this.showStudent = false,
    this.footer,
  });
  final Booking booking;
  final VoidCallback? onTap;
  final bool showStudent;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final local = DateTimeUtils.toBusiness(booking.start);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Column(
                  children: [
                    Text(
                      '${local.day}',
                      style: t.titleLarge?.copyWith(fontSize: 22),
                    ),
                    Text(
                      DateTimeUtils.formatShortDate(
                        booking.start,
                      ).split(' ').last.toUpperCase(),
                      style: t.labelMedium?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showStudent
                          ? booking.studentName
                          : '${booking.lessonType.label} lesson',
                      style: t.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DateTimeUtils.formatShortDate(booking.start)} · ${DateTimeUtils.formatRange(booking.start, booking.end)}',
                      style: t.bodyMedium,
                    ),
                    if (showStudent)
                      Text(
                        '${booking.lessonType.label} lesson',
                        style: t.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              BookingStatusChip(status: booking.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  booking.pickupAddress,
                  style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.sm),
            footer!,
          ],
        ],
      ),
    );
  }
}
