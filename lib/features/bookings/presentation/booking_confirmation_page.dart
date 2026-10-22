import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/booking_status_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../domain/booking.dart';
import '../domain/booking_status.dart';
import 'booking_providers.dart';

class BookingConfirmationPage extends ConsumerWidget {
  const BookingConfirmationPage({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking confirmed'),
        automaticallyImplyLeading: false,
      ),
      body: AsyncValueView<Booking?>(
        value: ref.watch(bookingByIdProvider(bookingId)),
        data: (b) {
          if (b == null) return const SizedBox.shrink();
          final confirmed = b.status == BookingStatus.confirmed;
          return ListView(
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          confirmed ? Icons.check_rounded : Icons.hourglass_top,
                          size: 46,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      confirmed ? 'You’re booked in!' : 'Booking received',
                      style: t.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      confirmed
                          ? 'We’ve sent you a confirmation.'
                          : 'Your instructor will confirm shortly.',
                      style: t.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppCard(
                      gradient: true,
                      child: Column(
                        children: [
                          InfoRow(
                            label: 'Student',
                            value: b.studentName,
                            icon: Icons.person_outline,
                          ),
                          InfoRow(
                            label: 'Lesson',
                            value: b.lessonType.label,
                            icon: Icons.directions_car_outlined,
                          ),
                          InfoRow(
                            label: 'Date',
                            value: DateTimeUtils.formatLongDate(b.start),
                            icon: Icons.event_outlined,
                          ),
                          InfoRow(
                            label: 'Time',
                            value: DateTimeUtils.formatRange(b.start, b.end),
                            icon: Icons.schedule,
                          ),
                          InfoRow(
                            label: 'Pickup',
                            value: b.pickupAddress,
                            icon: Icons.place_outlined,
                          ),
                          InfoRow(
                            label: 'Reference',
                            value: b.reference,
                            icon: Icons.confirmation_number_outlined,
                          ),
                          InfoRow(
                            label: 'Status',
                            value: '',
                            icon: Icons.flag_outlined,
                            trailing: BookingStatusChip(status: b.status),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: 'View my lessons',
                      onPressed: () => context.go('/lessons'),
                    ),
                    const SizedBox(height: 10),
                    SecondaryButton(
                      label: 'Back to home',
                      onPressed: () => context.go('/home'),
                    ),
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
