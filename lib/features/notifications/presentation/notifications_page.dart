import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/app_notification.dart';
import 'notification_providers.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  IconData _icon(String type) => switch (type) {
        'booking_cancelled' => Icons.event_busy_outlined,
        'booking_rescheduled' => Icons.update,
        'request_approved' => Icons.check_circle_outline,
        'request_rejected' => Icons.cancel_outlined,
        'request_created' => Icons.mark_email_unread_outlined,
        'reminder' => Icons.alarm,
        _ => Icons.event_available_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final repo = ref.watch(notificationRepositoryProvider);
    final value = ref.watch(notificationsProvider);
    final unread = (value.valueOrNull ?? const <AppNotification>[]).where((n) => !n.isRead).map((n) => n.id).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread.isNotEmpty) TextButton(onPressed: () => repo.markAllRead(unread), child: const Text('Mark all read')),
        ],
      ),
      body: AsyncValueView<List<AppNotification>>(
        value: value,
        onRetry: () => ref.invalidate(notificationsProvider),
        isEmpty: (l) => l.isEmpty,
        empty: const EmptyState(
          icon: Icons.notifications_none,
          title: 'Nothing here yet',
          message: 'Booking updates and reminders will appear here.',
        ),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) {
            final n = items[i];
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: AppCard(
                  onTap: () {
                    if (!n.isRead) repo.markRead(n.id);
                    if (n.bookingId != null) context.push(isAdmin ? '/admin/bookings/${n.bookingId}' : '/lesson/${n.bookingId}');
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_icon(n.type), color: n.isRead ? AppColors.textMuted : AppColors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.title, style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(n.body, style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 4),
                            Text(DateTimeUtils.formatDateTime(n.createdAt), style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      if (!n.isRead)
                        Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
