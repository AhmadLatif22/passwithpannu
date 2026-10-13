import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/month_grid.dart';
import '../../../availability/presentation/availability_providers.dart';
import '../../../settings/data/settings_repository.dart';
import 'booking_flow_controller.dart';

class StepDate extends ConsumerStatefulWidget {
  const StepDate({super.key});
  @override
  ConsumerState<StepDate> createState() => _StepDateState();
}

class _StepDateState extends ConsumerState<StepDate> {
  late DateTime _month = () {
    final n = DateTimeUtils.todayBusiness();
    return DateTime(n.year, n.month, 1);
  }();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final draft = ref.watch(bookingFlowProvider);
    final pickup = draft.pickup!;
    final settings = ref.watch(settingsProvider).valueOrNull;
    final maxDays = settings?.maxAdvanceBookingDays ?? 90;
    final today = DateTimeUtils.todayBusiness();
    final lastDay = today.add(Duration(days: maxDays));
    final monthKey = DateFormat('yyyy-MM').format(_month);
    final available = ref.watch(availableDatesProvider(DatesQuery(monthKey, pickup)));
    final canGoBack = DateTime(_month.year, _month.month) .isAfter(DateTime(today.year, today.month));
    final canGoForward = DateTime(_month.year, _month.month + 1).isBefore(lastDay);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('Choose a date', style: t.headlineMedium),
        const SizedBox(height: 4),
        Text('Highlighted days have lesson times available.', style: t.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: canGoBack ? () => setState(() => _month = DateTime(_month.year, _month.month - 1)) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(child: Text(DateTimeUtils.formatMonthYear(_month), style: t.titleMedium)),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: canGoForward ? () => setState(() => _month = DateTime(_month.year, _month.month + 1)) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        available.when(
          loading: () => const SizedBox(height: 280, child: Center(child: CircularProgressIndicator(color: AppColors.accent))),
          error: (e, _) => SizedBox(
            height: 200,
            child: Center(
              child: TextButton.icon(
                onPressed: () => ref.invalidate(availableDatesProvider(DatesQuery(monthKey, pickup))),
                icon: const Icon(Icons.refresh),
                label: const Text('Couldn’t load availability. Tap to retry'),
              ),
            ),
          ),
          data: (dates) => Column(
            children: [
              MonthGrid(
                month: _month,
                dayBuilder: (day) {
                  final key = DateTimeUtils.keyOfDate(day);
                  final ok = dates.contains(key);
                  final selected = draft.dateKey == key;
                  return InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    onTap: ok ? () => ref.read(bookingFlowProvider.notifier).setDate(key) : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : (ok ? AppColors.primary.withValues(alpha: 0.18) : null),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: selected ? Border.all(color: AppColors.accent, width: 1.6) : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: t.titleSmall?.copyWith(color: ok ? AppColors.textPrimary : AppColors.textMuted.withValues(alpha: 0.5)),
                      ),
                    ),
                  );
                },
              ),
              if (dates.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text('No available days this month. Try the next month.', style: t.bodyMedium),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
