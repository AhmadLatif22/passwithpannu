import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../availability/presentation/availability_providers.dart';
import 'booking_flow_controller.dart';
import 'step_date.dart';
import 'step_lesson_type.dart';
import 'step_pickup.dart';
import 'step_review.dart';
import 'step_time.dart';

/// Five guided steps (the spec's step 4 "pickup" runs second; see README for why).
class BookingFlowPage extends ConsumerStatefulWidget {
  const BookingFlowPage({super.key});
  @override
  ConsumerState<BookingFlowPage> createState() => _BookingFlowPageState();
}

class _BookingFlowPageState extends ConsumerState<BookingFlowPage> {
  static const _labels = ['Type', 'Pickup', 'Date', 'Time', 'Review'];
  int _step = 0;
  String? _notice;

  bool _canContinue(BookingDraft d) => switch (_step) {
    0 => d.lessonType != null,
    1 => d.pickup != null,
    2 => d.dateKey != null,
    3 => d.slot != null,
    _ => d.isComplete,
  };

  void _go(int step) => setState(() {
    _step = step;
    _notice = null;
  });

  Future<void> _confirm() async {
    final submit = ref.read(bookingSubmitProvider.notifier);
    final result = await submit.submit();
    if (!mounted) return;
    final state = ref.read(bookingSubmitProvider);
    if (result != null) {
      // Leave the review screen before clearing the draft it depends on.
      context.go('/book/confirmation/${result.bookingId}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _step = 0);
        ref.read(bookingFlowProvider.notifier).reset();
        ref.read(bookingSubmitProvider.notifier).reset();
      });
    } else if (state.hasError) {
      final failure = AppFailure.from(state.error!);
      // The slot was taken (or no longer valid) while reviewing: refresh and send them back to pick again.
      if (failure.isSlotUnavailable) {
        final d = ref.read(bookingFlowProvider);
        ref.invalidate(availableSlotsProvider);
        ref.invalidate(availableDatesProvider);
        ref.read(bookingFlowProvider.notifier).clearSlot();
        setState(() {
          _step = 3;
          _notice = failure.message;
        });
        if (d.dateKey == null) _go(2);
      }
      submit.reset();
      if (mounted && !failure.isSlotUnavailable) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingFlowProvider);
    final submitting = ref.watch(bookingSubmitProvider).isLoading;
    final t = Theme.of(context).textTheme;

    final body = switch (_step) {
      0 => const StepLessonType(),
      1 => const StepPickup(),
      2 => const StepDate(),
      3 => StepTime(notice: _notice),
      _ => const StepReview(),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Request a Lesson')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _labels.length; i++) ...[
                    Expanded(
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 4,
                            decoration: BoxDecoration(
                              color: i <= _step
                                  ? AppColors.accent
                                  : AppColors.outline,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _labels[i],
                            style: t.bodySmall?.copyWith(
                              color: i == _step
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < _labels.length - 1) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(key: ValueKey(_step), child: body),
                  ),
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.black,
                border: Border(top: BorderSide(color: AppColors.outline)),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Row(
                    children: [
                      if (_step > 0) ...[
                        Expanded(
                          child: SecondaryButton(
                            label: 'Back',
                            onPressed: submitting ? null : () => _go(_step - 1),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      Expanded(
                        flex: 2,
                        child: PrimaryButton(
                          label: _step == _labels.length - 1
                              ? 'Submit Request'
                              : 'Continue',
                          isLoading: submitting,
                          onPressed: _canContinue(draft)
                              ? (_step == _labels.length - 1
                                    ? _confirm
                                    : () => _go(_step + 1))
                              : null,
                        ),
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
  }
}
