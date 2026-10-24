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
import '../../notifications/presentation/notification_providers.dart';

const _paper = Color(0xFFF5F7FA);
/// Instructor dashboard. Uses the existing application palette and providers.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsProvider);
    final today = ref.watch(todaysLessonsProvider);
    final bookings = ref.watch(adminBookingsProvider);
    final pending = ref.watch(adminPendingRequestsProvider);
    final students = ref.watch(adminStudentsProvider);
    final now = DateTime.now();
    final upcomingCount = bookings.valueOrNull
        ?.where((booking) => booking.isUpcoming(now) && booking.start.isAfter(now))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instructor dashboard', style: TextStyle(
          color: _paper, fontSize: 14, fontWeight: FontWeight.w800,
          letterSpacing: 2.4,
        )),

        actions: [

          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              context.push('/admin/notifications');
            },
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              smallSize: 8,
              backgroundColor: Colors.red,
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],

      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminBookingsProvider);
          ref.invalidate(adminPendingRequestsProvider);
          ref.invalidate(adminStudentsProvider);
          // Allow the refreshed providers to begin their new requests.
          await Future<void>.delayed(const Duration(milliseconds: 350));
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 112),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _WelcomeHeader(now: now),
                      const SizedBox(height: 20),
                      _StatGrid(
                        items: [
                          _StatInfo('Today’s lessons', today.valueOrNull?.length,
                              Icons.today_outlined, '/admin/diary', AppColors.primary),
                          _StatInfo('Upcoming', upcomingCount,
                              Icons.event_available_outlined, '/admin/bookings', AppColors.brandGreen),
                          _StatInfo('Pending requests', pending.valueOrNull?.length,
                              Icons.pending_actions_outlined, '/admin/requests', AppColors.warning),
                          _StatInfo('Students', students.valueOrNull?.length,
                              Icons.groups_outlined, '/admin/students', AppColors.info),
                        ],
                      ),
                      const SizedBox(height: 26),
                      const _SectionHeader(title: 'Quick actions', subtitle: 'Manage your day in a tap'),
                      const SizedBox(height: 12),
                      _QuickActions(
                        onAddLesson: () => showCreateLessonDialog(context),
                      ),
                      const SizedBox(height: 26),
                      _SectionHeader(
                        title: 'Today’s lessons',
                        subtitle: DateTimeUtils.formatLongDate(now),
                        action: 'Open diary',
                        onAction: () => context.go('/admin/diary'),
                      ),
                      const SizedBox(height: 12),
                      AsyncValueView<List<Booking>>(
                        value: today,
                        onRetry: () => ref.invalidate(adminBookingsProvider),
                        loading: const SizedBox(
                          height: 155,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        isEmpty: (lessons) => lessons.isEmpty,
                        empty: const _NoLessonsCard(),
                        data: (lessons) => Column(
                          children: [
                            for (final booking in lessons)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: LessonCard(
                                  booking: booking,
                                  showStudent: true,
                                  onTap: () => context.go('/admin/bookings/${booking.id}'),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if ((pending.valueOrNull ?? const []).isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _SectionHeader(
                          title: 'Needs your attention',
                          subtitle: 'Student requests awaiting your review',
                          action: 'View all',
                          onAction: () => context.go('/admin/requests'),
                        ),
                        const SizedBox(height: 12),
                        for (final request in pending.valueOrNull!.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              onTap: () => context.go('/admin/requests'),
                              child: Row(
                                children: [
                                  _IconTile(
                                    icon: request.type.name == 'cancel'
                                        ? Icons.event_busy_outlined
                                        : Icons.update_rounded,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          request.studentName,
                                          style: Theme.of(context).textTheme.titleSmall,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${request.type.label} • ${DateTimeUtils.formatDateTime(request.currentStart)}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateLessonDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add lesson'),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final hour = DateTimeUtils.toBusiness(now).hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Here’s your teaching overview', style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Text(DateTimeUtils.formatLongDate(now), style: textTheme.labelMedium?.copyWith(color: AppColors.brandGreen)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _IconTile(icon: Icons.directions_car_filled_outlined, color: AppColors.primary, large: true),
        ],
      ),
    );
  }
}

class _StatInfo {
  const _StatInfo(this.label, this.value, this.icon, this.path, this.color);
  final String label;
  final int? value;
  final IconData icon;
  final String path;
  final Color color;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items});
  final List<_StatInfo> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final cols = constraints.maxWidth >= 760 ? 4 : 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 132,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => context.go(item.path),
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.outline),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(item.icon, color: item.color, size: 25),
                        Text(item.value?.toString() ?? '—',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                        Text(item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onAddLesson});
  final VoidCallback onAddLesson;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 560;
          final buttons = <Widget>[
            _ActionButton(icon: Icons.add_circle_outline_rounded, label: 'Add lesson', onTap: onAddLesson, prominent: true),
            _ActionButton(icon: Icons.groups_outlined, label: 'Students', onTap: () => context.go('/admin/students')),
            _ActionButton(icon: Icons.calendar_month_outlined, label: 'Diary', onTap: () => context.go('/admin/diary')),
            _ActionButton(icon: Icons.event_busy_outlined, label: 'Availability', onTap: () => context.go('/admin/availability')),
          ];
          return GridView.count(
            crossAxisCount: narrow ? 2 : 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: narrow ? 1.65 : 1.9,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: buttons,
          );
        },
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.prominent = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Material(
        color: prominent ? AppColors.primary : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: prominent ? AppColors.primary : AppColors.outline),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.textPrimary, size: 25),
                const SizedBox(height: 7),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle, this.action, this.onAction});
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                ],
              ],
            ),
          ),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      );
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color, this.large = false});
  final IconData icon;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) => Container(
        height: large ? 58 : 42,
        width: large ? 58 : 42,
        decoration: BoxDecoration(
          color: color.withAlpha(28),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: large ? 29 : 22),
      );
}

class _NoLessonsCard extends StatelessWidget {
  const _NoLessonsCard();


  @override
  Widget build(BuildContext context) => const AppCard(
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 24,
      ),
      child: EmptyState(
        icon: Icons.event_available_outlined,
        title: 'No lessons scheduled today',
        message:
        'Your diary is clear. Add a lesson whenever you’re ready.',
      ),
    ),
  );
}
