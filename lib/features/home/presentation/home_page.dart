import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'widgets/home_video_banner.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/booking_status_chip.dart';
import '../../../core/widgets/lesson_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../bookings/domain/booking.dart';
import '../../bookings/presentation/booking_providers.dart';
import '../../bookings/presentation/widgets/lesson_actions.dart';
import '../../notifications/presentation/notification_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  String _greeting() {
    final h = DateTimeUtils.toBusiness(DateTime.now()).hour;
    return h < 12
        ? 'Good morning'
        : (h < 18 ? 'Good afternoon' : 'Good evening');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final name = ref.watch(currentUserProvider).valueOrNull?.firstName;
    final unread = ref.watch(unreadNotificationsProvider);
    final upcoming = ref.watch(upcomingBookingsProvider);
    final history =
        ref.watch(bookingHistoryProvider).valueOrNull ?? const <Booking>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          name == null || name.isEmpty ? _greeting() : '${_greeting()}, $name',
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        ],
      ),
      body: AsyncValueView<List<Booking>>(
        value: upcoming,
        onRetry: () => ref.invalidate(studentBookingsProvider),
        data: (list) {
          final next = list.isEmpty ? null : list.first;
          final rest = list.skip(1).take(3).toList();
          return ListView(
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Premium introductory video
                    const HomeVideoBanner(),

                    const SizedBox(height: AppSpacing.md),

                    if (next != null)
                      _NextLesson(booking: next)
                    else
                      const _BookCta(),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: 'Book lesson',
                            icon: Icons.add,
                            onPressed: () => context.go('/book'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SecondaryButton(
                            label: 'View availability',
                            icon: Icons.calendar_month_outlined,
                            onPressed: () => context.go('/book'),
                          ),
                        ),
                      ],
                    ),
                    if (rest.isNotEmpty) ...[
                      SectionTitle(
                        'Coming up',
                        trailing: TextButton(
                          onPressed: () => context.go('/lessons'),
                          child: const Text('See all'),
                        ),
                      ),
                      for (final b in rest)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: LessonCard(
                            booking: b,
                            onTap: () => context.push('/lesson/${b.id}'),
                          ),
                        ),
                    ],
                    if (history.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppCard(
                        onTap: () => context.go('/lessons'),
                        child: Row(
                          children: [
                            const Icon(Icons.history, color: AppColors.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Previous lessons',
                                style: t.titleSmall,
                              ),
                            ),
                            Text('${history.length}', style: t.titleMedium),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NextLesson extends StatelessWidget {
  const _NextLesson({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      gradient: true,
      onTap: () => context.push('/lesson/${booking.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your next lesson',
                  style: t.labelMedium?.copyWith(color: AppColors.accent),
                ),
              ),
              BookingStatusChip(status: booking.status),
            ],
          ),
          const SizedBox(height: 6),
          Text('${booking.lessonType.label} lesson', style: t.headlineMedium),
          const SizedBox(height: 2),
          Text(
            DateTimeUtils.untilLabel(booking.start, DateTime.now()),
            style: t.bodyMedium?.copyWith(color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.sm),
          InfoRow(
            label: 'Date',
            value: DateTimeUtils.formatLongDate(booking.start),
            icon: Icons.event_outlined,
          ),
          InfoRow(
            label: 'Time',
            value: DateTimeUtils.formatRange(booking.start, booking.end),
            icon: Icons.schedule,
          ),
          InfoRow(
            label: 'Pickup',
            value: booking.pickupAddress,
            icon: Icons.place_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          LessonActions(booking: booking, compact: true),
        ],
      ),
    );
  }
}

class _BookCta extends StatelessWidget {
  const _BookCta();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      gradient: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.directions_car_filled_outlined,
            color: AppColors.accent,
            size: 34,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Book Your Next Lesson', style: t.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Pick manual or automatic and choose a time that suits you. Calm, patient tuition.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: 'Book a lesson',
            expand: false,
            onPressed: () => context.go('/book'),
          ),
        ],
      ),
    );
  }
}
