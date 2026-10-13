import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../auth/presentation/auth_providers.dart';
import 'booking_flow_controller.dart';

class StepReview extends ConsumerWidget {
  const StepReview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final d = ref.watch(bookingFlowProvider);
    final name = ref.watch(currentUserProvider).valueOrNull?.fullName ?? '';
    final slot = d.slot!;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('Review your booking', style: t.headlineMedium),
        const SizedBox(height: 4),
        Text('Check everything below, then confirm.', style: t.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          gradient: true,
          child: Column(
            children: [
              InfoRow(label: 'Student', value: name.isEmpty ? '-' : name, icon: Icons.person_outline),
              InfoRow(label: 'Lesson', value: '${d.lessonType!.label} · 2 hours', icon: Icons.directions_car_outlined),
              InfoRow(label: 'Date', value: DateTimeUtils.formatLongDate(slot.start), icon: Icons.event_outlined),
              InfoRow(label: 'Time', value: DateTimeUtils.formatRange(slot.start, slot.end), icon: Icons.schedule),
              InfoRow(label: 'Pickup', value: d.pickup!.address, icon: Icons.place_outlined),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Once confirmed, you can’t move the lesson yourself. You can request a change or cancellation at least 48 hours before it starts, and your instructor will approve or decline it.',
          style: t.bodySmall,
        ),
      ],
    );
  }
}
