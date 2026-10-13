import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/lesson_type.dart';
import 'booking_flow_controller.dart';

class StepLessonType extends ConsumerWidget {
  const StepLessonType({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(bookingFlowProvider).lessonType;
    final t = Theme.of(context).textTheme;
    Widget option(LessonType type, IconData icon, String blurb) {
      final on = selected == type;
      return AppCard(
        gradient: on,
        onTap: () => ref.read(bookingFlowProvider.notifier).setType(type),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: on ? AppColors.black : AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: AppColors.accent, size: 28),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${type.label} lesson', style: t.titleMedium),
                  const SizedBox(height: 2),
                  Text(blurb, style: t.bodyMedium),
                ],
              ),
            ),
            Icon(on ? Icons.radio_button_checked : Icons.radio_button_off, color: on ? AppColors.accent : AppColors.textMuted),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('What would you like to learn in?', style: t.headlineMedium),
        const SizedBox(height: 4),
        Text('Every lesson is 2 hours with your DVSA approved instructor.', style: t.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        option(LessonType.manual, Icons.settings_outlined, 'Learn with a gearbox and clutch control.'),
        const SizedBox(height: AppSpacing.md),
        option(LessonType.automatic, Icons.directions_car_outlined, 'Simple, relaxed driving with no clutch.'),
      ],
    );
  }
}
