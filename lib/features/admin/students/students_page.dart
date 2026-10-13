import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/domain/app_user.dart';
import '../../bookings/domain/booking.dart';
import '../shared/admin_providers.dart';

class StudentsPage extends ConsumerStatefulWidget {
  const StudentsPage({super.key});
  @override
  ConsumerState<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends ConsumerState<StudentsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final bookings = ref.watch(adminBookingsProvider).valueOrNull ?? const <Booking>[];
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: const InputDecoration(hintText: 'Search by name, email or phone', prefixIcon: Icon(Icons.search)),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<AppUser>>(
              value: ref.watch(adminStudentsProvider).whenData((l) => _query.isEmpty
                  ? l
                  : l.where((s) => s.fullName.toLowerCase().contains(_query) || s.email.toLowerCase().contains(_query) || (s.phone ?? '').contains(_query)).toList()),
              onRetry: () => ref.invalidate(adminStudentsProvider),
              isEmpty: (l) => l.isEmpty,
              empty: const EmptyState(icon: Icons.groups_outlined, title: 'No students found', message: 'Students appear here when they register.'),
              data: (students) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                itemCount: students.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) {
                  final s = students[i];
                  final mine = bookings.where((b) => b.studentId == s.uid).toList();
                  final upcoming = mine.where((b) => b.isUpcoming(now)).toList()..sort((a, b) => a.start.compareTo(b.start));
                  final previous = mine.where((b) => !b.isUpcoming(now) && b.status.name == 'completed').length;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: AppCard(
                        onTap: () => context.go('/admin/students/${s.uid}'),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: Text(s.fullName.isEmpty ? '?' : s.fullName[0].toUpperCase()),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Flexible(child: Text(s.fullName, style: t.titleMedium, overflow: TextOverflow.ellipsis)),
                                    if (!s.isActive)
                                      Padding(padding: const EdgeInsets.only(left: 8), child: Text('Inactive', style: t.bodySmall?.copyWith(color: AppColors.error))),
                                  ]),
                                  Text(s.email, style: t.bodyMedium, overflow: TextOverflow.ellipsis),
                                  Text((s.phone ?? '').isEmpty ? 'No phone' : s.phone!, style: t.bodySmall),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(upcoming.isEmpty ? 'No upcoming' : DateTimeUtils.formatDateTime(upcoming.first.start), style: t.bodyMedium),
                                Text('$previous completed', style: t.bodySmall),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
