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
import '../../auth/presentation/auth_providers.dart';
import '../shared/admin_providers.dart';
import 'availability_block.dart';

class AvailabilityPage extends ConsumerWidget {
  const AvailabilityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Availability')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: const _BlockForm())),
        ),
        icon: const Icon(Icons.block),
        label: const Text('Block time'),
      ),
      body: AsyncValueView<List<AvailabilityBlock>>(
        value: ref.watch(blocksProvider),
        onRetry: () => ref.invalidate(blocksProvider),
        isEmpty: (l) => l.isEmpty,
        empty: EmptyState(
          icon: Icons.event_available_outlined,
          title: 'Nothing blocked',
          message: 'Students can book any time inside your working hours. Block holidays or appointments here.',
          actionLabel: 'Edit working hours',
          onAction: () => context.go('/admin/settings'),
        ),
        data: (blocks) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Blocked periods disappear from students’ availability immediately. Remove a block to reopen the time.', style: t.bodyMedium),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final b in blocks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          child: Row(
                            children: [
                              const Icon(Icons.block, color: AppColors.warning),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.reason.isEmpty ? 'Blocked' : b.reason, style: t.titleSmall),
                                    Text('${DateTimeUtils.formatDateTime(b.start)}  →  ${DateTimeUtils.formatDateTime(b.end)}', style: t.bodyMedium),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Open this time again',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  final ok = await confirmDialog(context,
                                      title: 'Reopen this time?', message: 'Students will be able to book it again.', confirmLabel: 'Reopen', cancelLabel: 'Keep blocked');
                                  if (ok) await ref.read(blockRepositoryProvider).remove(b.id);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockForm extends ConsumerStatefulWidget {
  const _BlockForm();
  @override
  ConsumerState<_BlockForm> createState() => _BlockFormState();
}

class _BlockFormState extends ConsumerState<_BlockForm> {
  bool _fullDay = true;
  DateTime _from = DateTimeUtils.todayBusiness().add(const Duration(days: 1));
  DateTime? _to; // inclusive end date for full-day blocks
  TimeOfDay _start = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 15, minute: 0);
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 730)),
      );

  Future<void> _save() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final DateTime start;
    final DateTime end;
    if (_fullDay) {
      final last = _to ?? _from;
      start = DateTimeUtils.startOfBusinessDay(_from.year, _from.month, _from.day);
      final next = DateTime(last.year, last.month, last.day + 1);
      end = DateTimeUtils.startOfBusinessDay(next.year, next.month, next.day);
    } else {
      start = DateTimeUtils.fromBusinessParts(_from.year, _from.month, _from.day, _start.hour, _start.minute);
      end = DateTimeUtils.fromBusinessParts(_from.year, _from.month, _from.day, _end.hour, _end.minute);
    }
    if (!end.isAfter(start)) {
      setState(() => _error = 'The end must be after the start.');
      return;
    }
    final clashes = (ref.read(adminBookingsProvider).valueOrNull ?? const []).where((b) => b.status.occupiesSlot && b.start.isBefore(end) && b.end.isAfter(start)).length;
    if (clashes > 0) {
      final ok = await confirmDialog(
        context,
        title: '$clashes lesson${clashes == 1 ? '' : 's'} already in this period',
        message: 'Blocking won’t cancel or move them. You’ll need to handle them yourself. Block anyway?',
        confirmLabel: 'Block anyway',
        cancelLabel: 'Go back',
      );
      if (!ok) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(blockRepositoryProvider).add(start: start, end: end, reason: _reason.text.trim(), adminUid: uid);
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, 'Time blocked. Students no longer see it.');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Couldn’t save the block. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Block time', style: t.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<bool>(
            segments: const [ButtonSegment(value: true, label: Text('Full day(s)')), ButtonSegment(value: false, label: Text('Time range'))],
            selected: {_fullDay},
            onSelectionChanged: (s) => setState(() => _fullDay = s.first),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await _pickDate(_from);
              if (d != null) setState(() => _from = d);
            },
            icon: const Icon(Icons.event_outlined),
            label: Text(_fullDay ? 'From ${DateTimeUtils.formatPlainShort(_from)}' : DateTimeUtils.formatPlainShort(_from)),
          ),
          if (_fullDay) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await _pickDate(_to ?? _from);
                if (d != null) setState(() => _to = d.isBefore(_from) ? _from : d);
              },
              icon: const Icon(Icons.event_repeat_outlined),
              label: Text(_to == null ? 'Single day (tap to extend)' : 'Until ${DateTimeUtils.formatPlainShort(_to!)}'),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final x = await showTimePicker(context: context, initialTime: _start);
                      if (x != null) setState(() => _start = x);
                    },
                    icon: const Icon(Icons.schedule),
                    label: Text('From ${_start.format(context)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final x = await showTimePicker(context: context, initialTime: _end);
                      if (x != null) setState(() => _end = x);
                    },
                    icon: const Icon(Icons.schedule),
                    label: Text('To ${_end.format(context)}'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          TextField(controller: _reason, maxLength: 100, decoration: const InputDecoration(labelText: 'Reason (e.g. Holiday, Appointment)')),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: t.bodyMedium?.copyWith(color: AppColors.error))),
          PrimaryButton(label: 'Block this time', isLoading: _busy, onPressed: _save),
          TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }
}
