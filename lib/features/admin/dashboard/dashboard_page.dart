import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/lesson_card.dart';
import '../../bookings/domain/booking.dart';
import '../../lesson_requests/presentation/request_providers.dart';
import '../bookings/create_lesson_dialog.dart';
import '../shared/admin_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final all = ref.watch(adminBookingsProvider);
    final today = ref.watch(todaysLessonsProvider);
    final pending = ref.watch(adminPendingRequestsProvider);
    final students = ref.watch(adminStudentsProvider);
    final now = DateTime.now();
    final upcomingCount = all.valueOrNull?.where((b) => b.isUpcoming(now) && b.start.isAfter(now)).length;

    Widget stat(String label, int? value, IconData icon, String path) => SizedBox(
          width: 230,
          child: AppCard(
            gradient: true,
            onTap: () => context.go(path),
            child: Row(
              children: [
                Icon(icon, color: AppColors.accent, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value?.toString() ?? '–', style: t.headlineMedium),
                      Text(label, style: t.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text('Dashboard · ${DateTimeUtils.formatLongDate(now)}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateLessonDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add lesson'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              stat('Today’s lessons', today.valueOrNull?.length, Icons.today_outlined, '/admin/diary'),
              stat('Upcoming lessons', upcomingCount, Icons.event_available_outlined, '/admin/bookings'),
              stat('Pending requests', pending.valueOrNull?.length, Icons.mark_email_unread_outlined, '/admin/requests'),
              stat('Total students', students.valueOrNull?.length, Icons.groups_outlined, '/admin/students'),
            ],
          ),
          const SectionTitle('Today'),
          AsyncValueView<List<Booking>>(
            value: today,
            loading: const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
            onRetry: () => ref.invalidate(adminBookingsProvider),
            isEmpty: (l) => l.isEmpty,
            empty: const SizedBox(
              height: 220,
              child: EmptyState(icon: Icons.free_breakfast_outlined, title: 'No lessons today', message: 'Enjoy the free day, or add a lesson.'),
            ),
            data: (items) => Column(
              children: [
                for (final b in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: LessonCard(booking: b, showStudent: true, onTap: () => context.go('/admin/bookings/${b.id}')),
                  ),
              ],
            ),
          ),
          if ((pending.valueOrNull ?? const []).isNotEmpty) ...[
            SectionTitle('Needs your attention', trailing: TextButton(onPressed: () => context.go('/admin/requests'), child: const Text('Review all'))),
            for (final r in pending.valueOrNull!.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  onTap: () => context.go('/admin/requests'),
                  child: Row(
                    children: [
                      Icon(r.type.name == 'cancel' ? Icons.event_busy_outlined : Icons.update, color: AppColors.info),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${r.studentName} · ${r.type.label.toLowerCase()} request for ${DateTimeUtils.formatDateTime(r.currentStart)}',
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
    );
  }
}
