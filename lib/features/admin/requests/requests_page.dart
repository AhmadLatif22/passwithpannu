import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../lesson_requests/domain/booking_request.dart';
import '../../lesson_requests/presentation/request_providers.dart';
import '../shared/admin_actions.dart';

class RequestsPage extends ConsumerWidget {
  const RequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(adminPendingRequestsProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Requests'),
          bottom: TabBar(
            tabs: [
              Tab(
                text:
                    'Pending${pending.valueOrNull == null ? '' : ' (${pending.valueOrNull!.length})'}',
              ),
              const Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AsyncValueView<List<BookingRequest>>(
              value: pending,
              onRetry: () => ref.invalidate(adminPendingRequestsProvider),
              isEmpty: (l) => l.isEmpty,
              empty: const EmptyState(
                icon: Icons.inbox_outlined,
                title: 'No pending change requests',
                message: 'Student requests will show up here.',
              ),
              data: (items) => _RequestList(items: items, actionable: true),
            ),
            AsyncValueView<List<BookingRequest>>(
              value: ref
                  .watch(adminRecentRequestsProvider)
                  .whenData(
                    (l) => l
                        .where((r) => r.status != RequestStatus.pending)
                        .toList(),
                  ),
              onRetry: () => ref.invalidate(adminRecentRequestsProvider),
              isEmpty: (l) => l.isEmpty,
              empty: const EmptyState(
                icon: Icons.history,
                title: 'No handled requests yet',
              ),
              data: (items) => _RequestList(items: items, actionable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestList extends ConsumerWidget {
  const _RequestList({required this.items, required this.actionable});
  final List<BookingRequest> items;
  final bool actionable;

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    BookingRequest r,
  ) async {
    final msg = await promptDialog(
      context,
      title: 'Decline this request?',
      message:
          '${r.studentName}’s lesson stays exactly as booked. They’ll be notified.',
      label: 'Message to the student (optional)',
      confirmLabel: 'Decline request',
      destructive: true,
    );
    if (msg == null || !context.mounted) return;
    await runAdminAction(
      context,
      (_) => ref
          .read(requestRepositoryProvider)
          .resolve(requestId: r.id, approve: false, adminResponse: msg),
      success: 'Request declined. The student has been notified.',
    );
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    BookingRequest r,
  ) async {
    if (r.type == RequestType.cancel) {
      final msg = await promptDialog(
        context,
        title: 'Approve cancellation?',
        message:
            '${r.studentName}’s lesson on ${DateTimeUtils.formatDateTime(r.currentStart)} will be cancelled and the slot reopened.',
        label: 'Message to the student (optional)',
        confirmLabel: 'Approve & cancel',
        destructive: true,
      );
      if (msg == null || !context.mounted) return;
      await runAdminAction(
        context,
        (_) => ref
            .read(requestRepositoryProvider)
            .resolve(requestId: r.id, approve: true, adminResponse: msg),
        success: 'Cancelled. The student has been notified.',
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _FinalSlotForm(request: r),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) {
        final r = items[i];
        final isCancel = r.type == RequestType.cancel;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCancel ? Icons.event_busy_outlined : Icons.update,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${r.type.label} request · ${r.studentName}',
                          style: t.titleMedium,
                        ),
                      ),
                      if (!actionable)
                        Text(
                          r.status.label,
                          style: t.labelMedium?.copyWith(
                            color: r.status == RequestStatus.approved
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  InfoRow(
                    label: 'Current',
                    value: DateTimeUtils.formatDateTime(r.currentStart),
                    icon: Icons.schedule,
                  ),
                  if (r.requestedStart != null)
                    InfoRow(
                      label: 'Preferred',
                      value: DateTimeUtils.formatDateTime(r.requestedStart!),
                      icon: Icons.star_outline,
                    ),
                  if ((r.lessonType ?? '').isNotEmpty)
                    InfoRow(
                      label: 'Lesson',
                      value: r.lessonType!,
                      icon: Icons.directions_car_outlined,
                    ),
                  if ((r.reason ?? '').isNotEmpty)
                    InfoRow(
                      label: 'Reason',
                      value: r.reason!,
                      icon: Icons.chat_bubble_outline,
                    ),
                  if ((r.adminResponse ?? '').isNotEmpty)
                    InfoRow(
                      label: 'Your reply',
                      value: r.adminResponse!,
                      icon: Icons.reply,
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (actionable) ...[
                        FilledButton.icon(
                          onPressed: () => _approve(context, ref, r),
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(
                            isCancel
                                ? 'Approve cancellation'
                                : 'Approve & choose time',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _reject(context, ref, r),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Decline'),
                        ),
                      ],
                      TextButton(
                        onPressed: () =>
                            context.go('/admin/bookings/${r.bookingId}'),
                        child: const Text('View booking'),
                      ),
                    ],
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

/// Approving a change: the instructor confirms the final slot (it is never applied automatically).
class _FinalSlotForm extends ConsumerStatefulWidget {
  const _FinalSlotForm({required this.request});
  final BookingRequest request;
  @override
  ConsumerState<_FinalSlotForm> createState() => _FinalSlotFormState();
}

class _FinalSlotFormState extends ConsumerState<_FinalSlotForm> {
  late DateTime _slot =
      widget.request.requestedStart ?? widget.request.currentStart;
  final _msg = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final r = widget.request;
    final ok = await runAdminAction(
      context,
      (o) => ref
          .read(requestRepositoryProvider)
          .resolve(
            requestId: r.id,
            approve: true,
            adminResponse: _msg.text,
            newStart: _slot,
            override: o,
          ),
      success: 'Lesson moved. The student has been notified.',
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = widget.request;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Approve change', style: t.headlineMedium),
          const SizedBox(height: 6),
          Text(
            '${r.studentName} is currently booked for ${DateTimeUtils.formatDateTime(r.currentStart)}.'
            '${r.requestedStart != null ? '\nThey asked for ${DateTimeUtils.formatDateTime(r.requestedStart!)}.' : ''}',
            style: t.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Final lesson time', style: t.titleSmall),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    final d = await pickBusinessDateTime(
                      context,
                      initial: _slot,
                    );
                    if (d != null) setState(() => _slot = d);
                  },
            icon: const Icon(Icons.event_outlined),
            label: Text(
              '${DateTimeUtils.formatLongDate(_slot)} · ${DateTimeUtils.formatRange(_slot, _slot.add(const Duration(hours: 2)))}',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _msg,
            maxLines: 2,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Message to the student (optional)',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: 'Approve & move lesson',
            isLoading: _busy,
            onPressed: _confirm,
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}
