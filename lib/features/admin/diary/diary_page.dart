import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/booking_status_chip.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/lesson_card.dart';
import '../../../core/widgets/month_grid.dart';
import '../../bookings/domain/booking.dart';
import '../../bookings/domain/booking_status.dart';
import '../availability/availability_block.dart';
import '../bookings/create_lesson_dialog.dart';
import '../shared/admin_providers.dart';
import 'diary_controller.dart';

bool _visible(Booking b) =>
    b.status != BookingStatus.cancelled && b.status != BookingStatus.rejected;

List<Booking> _forDay(List<Booking> all, DateTime day) {
  final key = DateTimeUtils.keyOfDate(day);
  return all
      .where((b) => _visible(b) && DateTimeUtils.dateKey(b.start) == key)
      .toList();
}

List<AvailabilityBlock> _blocksForDay(
  List<AvailabilityBlock> blocks,
  DateTime day,
) {
  final start = DateTimeUtils.startOfBusinessDay(day.year, day.month, day.day);
  final next = DateTime(day.year, day.month, day.day + 1);
  final end = DateTimeUtils.startOfBusinessDay(next.year, next.month, next.day);
  return blocks.where((b) => b.overlaps(start, end)).toList();
}

class DiaryPage extends ConsumerWidget {
  const DiaryPage({super.key});

  String _title(DiaryState s) => switch (s.mode) {
    DiaryMode.day => DateTimeUtils.formatPlainShort(s.date),
    DiaryMode.week =>
      '${DateTimeUtils.formatPlainShort(s.weekStart)} – ${DateTimeUtils.formatPlainShort(DateTime(s.weekStart.year, s.weekStart.month, s.weekStart.day + 6))}',
    DiaryMode.month => DateTimeUtils.formatMonthYear(s.date),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(diaryControllerProvider);
    final ctrl = ref.read(diaryControllerProvider.notifier);
    final bookings = ref.watch(adminBookingsProvider);
    final blocks =
        ref.watch(blocksProvider).valueOrNull ?? const <AvailabilityBlock>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Diary')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateLessonDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add lesson'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<DiaryMode>(
                  segments: const [
                    ButtonSegment(value: DiaryMode.day, label: Text('Day')),
                    ButtonSegment(value: DiaryMode.week, label: Text('Week')),
                    ButtonSegment(value: DiaryMode.month, label: Text('Month')),
                  ],
                  selected: {state.mode},
                  onSelectionChanged: (s) => ctrl.setMode(s.first),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Previous',
                      onPressed: () => ctrl.shift(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 150),
                      child: Center(
                        child: Text(
                          _title(state),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next',
                      onPressed: () => ctrl.shift(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                OutlinedButton(
                  onPressed: ctrl.today,
                  child: const Text('Today'),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<List<Booking>>(
              value: bookings,
              onRetry: () => ref.invalidate(adminBookingsProvider),
              data: (all) => switch (state.mode) {
                DiaryMode.day => _DayView(
                  day: state.date,
                  bookings: _forDay(all, state.date),
                  blocks: _blocksForDay(blocks, state.date),
                ),
                DiaryMode.week => _WeekView(
                  start: state.weekStart,
                  all: all,
                  blocks: blocks,
                ),
                DiaryMode.month => _MonthView(
                  month: state.date,
                  all: all,
                  blocks: blocks,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile(this.block);
  final AvailabilityBlock block;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm + 2),
    decoration: BoxDecoration(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: AppColors.outline),
    ),
    child: Row(
      children: [
        const Icon(Icons.block, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Blocked ${DateTimeUtils.formatRange(block.start, block.end)}${block.reason.isEmpty ? '' : ' · ${block.reason}'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

class _DayView extends StatelessWidget {
  const _DayView({
    required this.day,
    required this.bookings,
    required this.blocks,
  });
  final DateTime day;
  final List<Booking> bookings;
  final List<AvailabilityBlock> blocks;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty && blocks.isEmpty) {
      return const EmptyState(
        icon: Icons.event_available_outlined,
        title: 'Nothing scheduled',
        message: 'No lessons or blocks on this day.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (final b in blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _BlockTile(b),
          ),
        for (final b in bookings)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: LessonCard(
                  booking: b,
                  showStudent: true,
                  onTap: () => context.go('/admin/bookings/${b.id}'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.start,
    required this.all,
    required this.blocks,
  });
  final DateTime start;
  final List<Booking> all;
  final List<AvailabilityBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final today = DateTimeUtils.todayBusiness();
    return LayoutBuilder(
      builder: (context, c) {
        final colWidth = ((c.maxWidth - AppSpacing.md * 2) / 7).clamp(
          150.0,
          400.0,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SizedBox(
            width: colWidth * 7,
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < 7; i++)
                    Builder(
                      builder: (context) {
                        final day = DateTime(
                          start.year,
                          start.month,
                          start.day + i,
                        );
                        final isToday = day == today;
                        final items = _forDay(all, day);
                        final bl = _blocksForDay(blocks, day);
                        return SizedBox(
                          width: colWidth,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? AppColors.primary
                                        : AppColors.black,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm,
                                    ),
                                    border: Border.all(
                                      color: isToday
                                          ? AppColors.accent
                                          : AppColors.outline,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      DateTimeUtils.formatPlainShort(day),
                                      style: t.labelMedium,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                for (final b in bl)
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceHigh,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                    ),
                                    child: Text(
                                      'Blocked${b.reason.isEmpty ? '' : '\n${b.reason}'}',
                                      style: t.bodySmall,
                                    ),
                                  ),
                                if (items.isEmpty && bl.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text('–', style: t.bodySmall),
                                  ),
                                for (final b in items)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      onTap: () =>
                                          context.go('/admin/bookings/${b.id}'),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: BookingStatusChip.colorFor(
                                            b.status,
                                          ).withValues(alpha: 0.16),
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.sm,
                                          ),
                                          border: Border(
                                            left: BorderSide(
                                              color: BookingStatusChip.colorFor(
                                                b.status,
                                              ),
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              DateTimeUtils.formatRange(
                                                b.start,
                                                b.end,
                                              ),
                                              style: t.labelMedium?.copyWith(
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              b.studentName,
                                              style: t.titleSmall,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${b.lessonType.label} · ${b.status.label}',
                                              style: t.bodySmall,
                                            ),
                                            Text(
                                              b.pickupAddress,
                                              style: t.bodySmall,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MonthView extends ConsumerWidget {
  const _MonthView({
    required this.month,
    required this.all,
    required this.blocks,
  });
  final DateTime month;
  final List<Booking> all;
  final List<AvailabilityBlock> blocks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final today = DateTimeUtils.todayBusiness();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: MonthGrid(
            month: month,
            cellHeight: 76,
            dayBuilder: (day) {
              final count = _forDay(all, day).length;
              final blocked = _blocksForDay(blocks, day).isNotEmpty;
              final isToday = day == today;
              return InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: () =>
                    ref.read(diaryControllerProvider.notifier).goToDay(day),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.black,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: isToday ? AppColors.accent : AppColors.outline,
                      width: isToday ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${day.day}', style: t.titleSmall),
                      const Spacer(),
                      if (count > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$count lesson${count == 1 ? '' : 's'}',
                            style: t.bodySmall?.copyWith(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        )
                      else if (blocked)
                        Text(
                          'Blocked',
                          style: t.bodySmall?.copyWith(fontSize: 11),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
