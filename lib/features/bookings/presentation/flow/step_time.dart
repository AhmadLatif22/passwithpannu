import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/availability_slot.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../availability/presentation/availability_providers.dart';
import 'booking_flow_controller.dart';

class StepTime extends ConsumerWidget {
  const StepTime({super.key, this.notice});

  /// Shown above the list, e.g. after a slot was taken while reviewing.
  final String? notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final draft = ref.watch(bookingFlowProvider);
    final query = SlotQuery(draft.dateKey!, draft.lessonType!, draft.pickup!);
    final slots = ref.watch(availableSlotsProvider(query));
    final date = DateTimeUtils.parseKey(draft.dateKey!);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('Choose a start time', style: t.headlineMedium),
        const SizedBox(height: 4),
        Text(DateTimeUtils.formatPlainShort(date), style: t.bodyMedium),
        if (notice != null) ...[const SizedBox(height: 10), Text(notice!, style: t.bodyMedium?.copyWith(color: const Color(0xFFF5A623)))],
        const SizedBox(height: AppSpacing.md),
        slots.when(
          loading: () => const SizedBox(height: 260, child: SkeletonList(count: 3, height: 64)),
          error: (e, _) => SizedBox(
            height: 260,
            child: ErrorView(message: AppFailure.from(e).message, onRetry: () => ref.invalidate(availableSlotsProvider(query))),
          ),
          data: (list) => list.isEmpty
              ? const SizedBox(
                  height: 260,
                  child: EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'No available slots for this date',
                    message: 'Go back and pick another day.',
                  ),
                )
              : Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final s in list)
                      AvailabilitySlot(
                        start: s.start,
                        end: s.end,
                        selected: draft.slot == s,
                        onTap: () => ref.read(bookingFlowProvider.notifier).setSlot(s),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
