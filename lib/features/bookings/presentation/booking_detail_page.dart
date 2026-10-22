import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/booking_status_chip.dart';
import '../../../core/widgets/empty_state.dart';
import '../../lesson_requests/domain/booking_request.dart';
import '../../lesson_requests/presentation/request_providers.dart';
import '../domain/booking.dart';
import '../domain/booking_status.dart';
import 'booking_providers.dart';
import 'widgets/lesson_actions.dart';

class BookingDetailPage extends ConsumerWidget {
  const BookingDetailPage({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(bookingByIdProvider(bookingId));
    return Scaffold(
      appBar: AppBar(title: const Text('Lesson details')),
      body: AsyncValueView<Booking?>(
        value: value,
        onRetry: () => ref.invalidate(bookingByIdProvider(bookingId)),
        isEmpty: (b) => b == null,
        empty: const EmptyState(
          icon: Icons.search_off,
          title: 'Lesson not found',
        ),
        data: (b) => _Body(booking: b!),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final requests =
        ref.watch(bookingRequestsProvider(booking.id)).valueOrNull ??
        const <BookingRequest>[];
    return ListView(
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                gradient: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${booking.lessonType.label} lesson',
                            style: t.headlineMedium,
                          ),
                        ),
                        BookingStatusChip(status: booking.status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    InfoRow(
                      label: 'Date',
                      value: DateTimeUtils.formatLongDate(booking.start),
                      icon: Icons.event_outlined,
                    ),
                    InfoRow(
                      label: 'Start',
                      value: DateTimeUtils.formatTime(booking.start),
                      icon: Icons.play_arrow_outlined,
                    ),
                    InfoRow(
                      label: 'End',
                      value: DateTimeUtils.formatTime(booking.end),
                      icon: Icons.stop_outlined,
                    ),
                    InfoRow(
                      label: 'Pickup',
                      value: booking.pickupAddress,
                      icon: Icons.place_outlined,
                    ),
                    InfoRow(
                      label: 'Reference',
                      value: booking.reference,
                      icon: Icons.confirmation_number_outlined,
                    ),
                  ],
                ),
              ),
              if (booking.status == BookingStatus.cancelled &&
                  (booking.cancellationReason ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: InfoRow(
                    label: 'Cancelled',
                    value: booking.cancellationReason!,
                    icon: Icons.info_outline,
                  ),
                ),
              ],
              if (booking.previousStart != null &&
                  booking.status.occupiesSlot) ...[
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: InfoRow(
                    label: 'Moved from',
                    value: DateTimeUtils.formatDateTime(booking.previousStart!),
                    icon: Icons.swap_horiz,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              LessonActions(booking: booking),
              if (requests.isNotEmpty) ...[
                const SectionTitle('Your requests'),
                for (final r in requests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${r.type.label} request',
                                  style: t.titleSmall,
                                ),
                              ),
                              Text(
                                r.status.label,
                                style: t.labelMedium?.copyWith(
                                  color: switch (r.status) {
                                    RequestStatus.pending => AppColors.info,
                                    RequestStatus.approved => AppColors.success,
                                    RequestStatus.rejected => AppColors.error,
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (r.requestedStart != null)
                            Text(
                              'Preferred: ${DateTimeUtils.formatDateTime(r.requestedStart!)}',
                              style: t.bodyMedium,
                            ),
                          if ((r.reason ?? '').isNotEmpty)
                            Text('“${r.reason}”', style: t.bodySmall),
                          if ((r.adminResponse ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Pass With Pannu: ${r.adminResponse}',
                                style: t.bodyMedium,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
