import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/booking_status_chip.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../availability/domain/slot.dart';
import '../../availability/presentation/pickup_field.dart';
import '../../bookings/domain/booking.dart';
import '../../bookings/domain/booking_status.dart';
import '../../bookings/domain/lesson_type.dart';
import '../../bookings/presentation/booking_providers.dart';
import '../../lesson_requests/domain/booking_request.dart';
import '../../lesson_requests/presentation/request_providers.dart';
import '../shared/admin_actions.dart';

class AdminBookingDetailPage extends ConsumerWidget {
  const AdminBookingDetailPage({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(
          title: const Text('Booking'),
          leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/admin/bookings')),
        ),
        body: AsyncValueView<Booking?>(
          value: ref.watch(bookingByIdProvider(bookingId)),
          onRetry: () => ref.invalidate(bookingByIdProvider(bookingId)),
          isEmpty: (b) => b == null,
          empty: const EmptyState(icon: Icons.search_off, title: 'Booking not found'),
          data: (b) => _Body(booking: b!),
        ),
      );
}

class _Body extends ConsumerWidget {
  const _Body({required this.booking});
  final Booking booking;

  Future<void> _move(BuildContext context, WidgetRef ref) async {
    final newStart = await pickBusinessDateTime(context, initial: booking.start);
    if (newStart == null || !context.mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'Move this lesson?',
      message: '${booking.studentName}\nFrom ${DateTimeUtils.formatDateTime(booking.start)}\nTo ${DateTimeUtils.formatDateTime(newStart)}\n\nThe student will be notified.',
      confirmLabel: 'Move lesson',
    );
    if (!ok || !context.mounted) return;
    await runAdminAction(
      context,
      (o) => ref.read(bookingRepositoryProvider).adminReschedule(booking.id, newStart, override: o),
      success: 'Lesson moved. The student has been notified.',
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final reason = await promptDialog(
      context,
      title: 'Cancel this lesson?',
      message: '${booking.studentName} · ${DateTimeUtils.formatDateTime(booking.start)}\nThe student is notified straight away.',
      label: 'Reason (shown to the student)',
      confirmLabel: 'Cancel lesson',
      minLength: 3,
      destructive: true,
    );
    if (reason == null || !context.mounted) return;
    await runAdminAction(
      context,
      (_) => ref.read(bookingRepositoryProvider).adminCancel(booking.id, reason),
      success: 'Lesson cancelled. The student has been notified.',
    );
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(context,
        title: 'Mark as completed?', message: 'This lesson will move to the student’s previous lessons.', confirmLabel: 'Mark completed');
    if (!ok || !context.mounted) return;
    await runAdminAction(context, (_) => ref.read(bookingRepositoryProvider).adminComplete(booking.id), success: 'Marked as completed.');
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: _EditForm(booking: booking))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final requests = ref.watch(adminBookingRequestsProvider(booking.id)).valueOrNull ?? const <BookingRequest>[];
    final hasOpenRequest = booking.status == BookingStatus.changeRequested || booking.status == BookingStatus.cancellationRequested;
    final active = booking.status.occupiesSlot;

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
                    Row(children: [
                      Expanded(child: Text(booking.studentName, style: t.headlineMedium)),
                      BookingStatusChip(status: booking.status),
                    ]),
                    const SizedBox(height: AppSpacing.sm),
                    InfoRow(label: 'Email', value: booking.studentEmail, icon: Icons.mail_outline),
                    InfoRow(label: 'Phone', value: (booking.studentPhone ?? '').isEmpty ? 'Not provided' : booking.studentPhone!, icon: Icons.phone_outlined),
                    InfoRow(label: 'Lesson', value: booking.lessonType.label, icon: Icons.directions_car_outlined),
                    InfoRow(label: 'Date', value: DateTimeUtils.formatLongDate(booking.start), icon: Icons.event_outlined),
                    InfoRow(label: 'Time', value: DateTimeUtils.formatRange(booking.start, booking.end), icon: Icons.schedule),
                    InfoRow(label: 'Pickup', value: booking.pickupAddress, icon: Icons.place_outlined),
                    InfoRow(label: 'Reference', value: booking.reference, icon: Icons.confirmation_number_outlined),
                    if (booking.previousStart != null)
                      InfoRow(label: 'Moved from', value: DateTimeUtils.formatDateTime(booking.previousStart!), icon: Icons.swap_horiz),
                    if ((booking.cancellationReason ?? '').isNotEmpty)
                      InfoRow(label: 'Cancel reason', value: booking.cancellationReason!, icon: Icons.info_outline),
                    if ((booking.adminNotes ?? '').isNotEmpty) InfoRow(label: 'Notes', value: booking.adminNotes!, icon: Icons.sticky_note_2_outlined),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if ((booking.studentPhone ?? '').isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => openUrl(context, Uri(scheme: 'tel', path: booking.studentPhone)),
                      icon: const Icon(Icons.call_outlined, size: 18),
                      label: const Text('Call'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => openUrl(context, Uri(scheme: 'mailto', path: booking.studentEmail)),
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: const Text('Email'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => openUrl(context, mapsUri(booking.pickupLat, booking.pickupLng)),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Open in Maps'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/admin/students/${booking.studentId}'),
                    icon: const Icon(Icons.person_search_outlined, size: 18),
                    label: const Text('Student details'),
                  ),
                ],
              ),
              if (hasOpenRequest) ...[
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.mark_email_unread_outlined, color: AppColors.info),
                      const SizedBox(width: 12),
                      Expanded(child: Text('The student has an open request for this lesson. Review it before making changes.', style: t.bodyMedium)),
                      TextButton(onPressed: () => context.go('/admin/requests'), child: const Text('Review')),
                    ],
                  ),
                ),
              ],
              if (active) ...[
                const SectionTitle('Actions'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    SizedBox(width: 200, child: SecondaryButton(label: 'Edit', icon: Icons.edit_outlined, onPressed: () => _edit(context, ref))),
                    if (!hasOpenRequest)
                      SizedBox(width: 200, child: SecondaryButton(label: 'Move lesson', icon: Icons.update, onPressed: () => _move(context, ref))),
                    SizedBox(
                      width: 200,
                      child: SecondaryButton(
                        label: 'Mark completed',
                        icon: Icons.check_circle_outline,
                        onPressed: booking.start.isAfter(DateTime.now()) ? null : () => _complete(context, ref),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error), padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: () => _cancel(context, ref),
                        icon: const Icon(Icons.event_busy_outlined, size: 18),
                        label: const Text('Cancel lesson'),
                      ),
                    ),
                  ],
                ),
              ],
              if (requests.isNotEmpty) ...[
                const SectionTitle('Request history'),
                for (final r in requests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r.type.label} request · ${r.status.label}', style: t.titleSmall),
                          if (r.requestedStart != null) Text('Preferred: ${DateTimeUtils.formatDateTime(r.requestedStart!)}', style: t.bodyMedium),
                          if ((r.reason ?? '').isNotEmpty) Text('“${r.reason}”', style: t.bodySmall),
                          if ((r.adminResponse ?? '').isNotEmpty) Text('Reply: ${r.adminResponse}', style: t.bodyMedium),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.booking});
  final Booking booking;
  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  late LessonType _type = widget.booking.lessonType;
  late final _notes = TextEditingController(text: widget.booking.adminNotes ?? '');
  PickupLocation? _pickup;
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final b = widget.booking;
    final ok = await runAdminAction(
      context,
      (o) => ref.read(bookingRepositoryProvider).adminUpdate(
            b.id,
            lessonType: _type == b.lessonType ? null : _type,
            pickup: _pickup,
            adminNotes: _notes.text.trim() == (b.adminNotes ?? '') ? null : _notes.text.trim(),
            override: o,
          ),
      success: 'Lesson updated.',
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit lesson', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('To change the date or time, use “Move lesson”.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<LessonType>(
              segments: [for (final t in LessonType.values) ButtonSegment(value: t, label: Text(t.label))],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 14),
            PickupAutocompleteField(
              initial: PickupLocation(address: widget.booking.pickupAddress, lat: widget.booking.pickupLat, lng: widget.booking.pickupLng),
              onSelected: (l) => _pickup = l,
            ),
            const SizedBox(height: 14),
            TextField(controller: _notes, maxLines: 3, maxLength: 500, decoration: const InputDecoration(labelText: 'Private notes (students can’t see these)')),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(label: 'Save changes', isLoading: _busy, onPressed: _save),
            TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
          ],
        ),
      );
}
