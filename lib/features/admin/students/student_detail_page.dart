import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/lesson_card.dart';
import '../../auth/domain/app_user.dart';
import '../../bookings/domain/booking.dart';
import '../bookings/create_lesson_dialog.dart';
import '../shared/admin_actions.dart';
import '../shared/admin_providers.dart';

class StudentDetailPage extends ConsumerWidget {
  const StudentDetailPage({super.key, required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(adminBookingsProvider).valueOrNull ?? const <Booking>[];
    final now = DateTime.now();
    final mine = bookings.where((b) => b.studentId == studentId).toList();
    final upcoming = mine.where((b) => b.isUpcoming(now)).toList()..sort((a, b) => a.start.compareTo(b.start));
    final previous = mine.where((b) => !b.isUpcoming(now)).toList()..sort((a, b) => b.start.compareTo(a.start));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student'),
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/admin/students')),
      ),
      body: AsyncValueView<AppUser?>(
        value: ref.watch(adminStudentProvider(studentId)),
        onRetry: () => ref.invalidate(adminStudentProvider(studentId)),
        isEmpty: (u) => u == null,
        empty: const EmptyState(icon: Icons.person_off_outlined, title: 'Student not found'),
        data: (s) {
          final t = Theme.of(context).textTheme;
          return ListView(
            children: [
              ContentWidth(
                maxWidth: 820,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      gradient: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s!.fullName, style: t.headlineMedium),
                          const SizedBox(height: AppSpacing.sm),
                          InfoRow(label: 'Email', value: s.email, icon: Icons.mail_outline),
                          InfoRow(label: 'Phone', value: (s.phone ?? '').isEmpty ? 'Not provided' : s.phone!, icon: Icons.phone_outlined),
                          if (s.createdAt != null) InfoRow(label: 'Joined', value: DateTimeUtils.formatDate(s.createdAt!), icon: Icons.calendar_today_outlined),
                          InfoRow(label: 'Lessons', value: '${mine.where((b) => b.status.name == 'completed').length} completed · ${upcoming.length} upcoming', icon: Icons.directions_car_outlined),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if ((s.phone ?? '').isNotEmpty)
                          OutlinedButton.icon(onPressed: () => openUrl(context, Uri(scheme: 'tel', path: s.phone)), icon: const Icon(Icons.call_outlined, size: 18), label: const Text('Call')),
                        OutlinedButton.icon(onPressed: () => openUrl(context, Uri(scheme: 'mailto', path: s.email)), icon: const Icon(Icons.mail_outline, size: 18), label: const Text('Email')),
                        FilledButton.icon(onPressed: () => showCreateLessonDialog(context, studentId: s.uid), icon: const Icon(Icons.add, size: 18), label: const Text('Add lesson')),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final deactivate = s.isActive;
                            final ok = await confirmDialog(
                              context,
                              title: deactivate ? 'Deactivate student?' : 'Reactivate student?',
                              message: deactivate ? 'They won’t be able to book new lessons. Existing lessons are not changed.' : 'They’ll be able to book lessons again.',
                              confirmLabel: deactivate ? 'Deactivate' : 'Reactivate',
                              destructive: deactivate,
                            );
                            if (ok) await ref.read(studentRepositoryProvider).setActive(s.uid, !s.isActive);
                          },
                          icon: Icon(s.isActive ? Icons.person_off_outlined : Icons.person_outline, size: 18),
                          label: Text(s.isActive ? 'Deactivate' : 'Reactivate'),
                        ),
                      ],
                    ),
                    const SectionTitle('Upcoming lessons'),
                    if (upcoming.isEmpty) const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('No upcoming lessons.')),
                    for (final b in upcoming)
                      Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: LessonCard(booking: b, onTap: () => context.go('/admin/bookings/${b.id}'))),
                    const SectionTitle('Previous lessons & history'),
                    if (previous.isEmpty) const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('No previous lessons yet.')),
                    for (final b in previous)
                      Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: LessonCard(booking: b, onTap: () => context.go('/admin/bookings/${b.id}'))),
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
