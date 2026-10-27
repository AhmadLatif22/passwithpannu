import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/lesson_card.dart';
import '../domain/booking.dart';
import 'booking_providers.dart';
import 'widgets/lesson_actions.dart';

class LessonsPage extends ConsumerWidget {
  const LessonsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My lessons'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Previous'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _List(
              provider: upcomingBookingsProvider,
              upcoming: true,
              empty: EmptyState(
                icon: Icons.event_available_outlined,
                title: 'No upcoming lessons',
                message: 'Book your next lesson and keep your learning moving.',
                actionLabel: 'Request a Lesson',
                onAction: () => context.go('/book'),
              ),
            ),
            _List(
              provider: bookingHistoryProvider,
              upcoming: false,
              empty: const EmptyState(
                icon: Icons.history,
                title: 'No previous lessons yet',
                message: 'Completed and cancelled lessons will appear here.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({
    required this.provider,
    required this.upcoming,
    required this.empty,
  });
  final Provider<AsyncValue<List<Booking>>> provider;
  final bool upcoming;
  final Widget empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<List<Booking>>(
      value: ref.watch(provider),
      onRetry: () => ref.invalidate(studentBookingsProvider),
      isEmpty: (l) => l.isEmpty,
      empty: empty,
      data: (items) => ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: LessonCard(
              booking: items[i],
              onTap: () => context.push('/lesson/${items[i].id}'),
              footer: upcoming
                  ? LessonActions(booking: items[i], compact: true)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
