import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/presentation/auth_providers.dart';
import '../shared/admin_providers.dart';
import 'availability_block.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/domain/app_settings.dart';

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
          builder: (_) => Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: const _BlockForm(),
            ),
          ),
        ),
        icon: const Icon(Icons.block),
        label: const Text('Block time'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Working hours'),
                  AsyncValueView<AppSettings>(
                    value: ref.watch(settingsProvider),
                    onRetry: () => ref.invalidate(settingsProvider),
                    data: (settings) => _WorkingHoursEditor(
                      key: ValueKey(settings.hashCode),
                      initial: settings,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionTitle('Blocked periods'),
                  Text(
                    'Blocked periods disappear from students’ availability immediately. Remove a block to reopen the time.',
                    style: t.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AsyncValueView<List<AvailabilityBlock>>(
                    value: ref.watch(blocksProvider),
                    onRetry: () => ref.invalidate(blocksProvider),
                    data: (blocks) => blocks.isEmpty
                        ? const AppCard(
                            child: Text(
                              'Nothing blocked. Use “Block time” to add holidays or appointments.',
                            ),
                          )
                        : Column(
                            children: [
                              for (final b in blocks)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: AppCard(
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.block,
                                          color: AppColors.warning,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                b.reason.isEmpty
                                                    ? 'Blocked'
                                                    : b.reason,
                                                style: t.titleSmall,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                '${DateTimeUtils.formatDateTime(b.start)}  →  ${DateTimeUtils.formatDateTime(b.end)}',
                                                style: t.bodyMedium,
                                                softWrap: true,
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Open this time again',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: () async {
                                            final ok = await confirmDialog(
                                              context,
                                              title: 'Reopen this time?',
                                              message:
                                                  'Students will be able to book it again.',
                                              confirmLabel: 'Reopen',
                                              cancelLabel: 'Keep blocked',
                                            );
                                            if (ok && context.mounted) {
                                              await ref
                                                  .read(blockRepositoryProvider)
                                                  .remove(b.id);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 84),
                ],
              ),
            ),
          ),
        ],
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
      start = DateTimeUtils.startOfBusinessDay(
        _from.year,
        _from.month,
        _from.day,
      );
      final next = DateTime(last.year, last.month, last.day + 1);
      end = DateTimeUtils.startOfBusinessDay(next.year, next.month, next.day);
    } else {
      start = DateTimeUtils.fromBusinessParts(
        _from.year,
        _from.month,
        _from.day,
        _start.hour,
        _start.minute,
      );
      end = DateTimeUtils.fromBusinessParts(
        _from.year,
        _from.month,
        _from.day,
        _end.hour,
        _end.minute,
      );
    }
    if (!end.isAfter(start)) {
      setState(() => _error = 'The end must be after the start.');
      return;
    }
    final clashes = (ref.read(adminBookingsProvider).valueOrNull ?? const [])
        .where(
          (b) =>
              b.status.occupiesSlot &&
              b.start.isBefore(end) &&
              b.end.isAfter(start),
        )
        .length;
    if (clashes > 0) {
      final ok = await confirmDialog(
        context,
        title:
            '$clashes lesson${clashes == 1 ? '' : 's'} already in this period',
        message:
            'Blocking won’t cancel or move them. You’ll need to handle them yourself. Block anyway?',
        confirmLabel: 'Block anyway',
        cancelLabel: 'Go back',
      );
      if (!mounted || !ok) return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(blockRepositoryProvider)
          .add(
            start: start,
            end: end,
            reason: _reason.text.trim(),
            adminUid: uid,
          );
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
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Block time', style: t.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Full day(s)')),
              ButtonSegment(value: false, label: Text('Time range')),
            ],
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
            label: Text(
              _fullDay
                  ? 'From ${DateTimeUtils.formatPlainShort(_from)}'
                  : DateTimeUtils.formatPlainShort(_from),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_fullDay) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await _pickDate(_to ?? _from);
                if (d != null) {
                  setState(() => _to = d.isBefore(_from) ? _from : d);
                }
              },
              icon: const Icon(Icons.event_repeat_outlined),
              label: Text(
                _to == null
                    ? 'Single day (tap to extend)'
                    : 'Until ${DateTimeUtils.formatPlainShort(_to!)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 370;

                final startButton = OutlinedButton.icon(
                  onPressed: () async {
                    final x = await showTimePicker(
                      context: context,
                      initialTime: _start,
                    );
                    if (!mounted) return;
                    if (x != null) setState(() => _start = x);
                  },
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(
                    'From ${_start.format(context)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );

                final endButton = OutlinedButton.icon(
                  onPressed: () async {
                    final x = await showTimePicker(
                      context: context,
                      initialTime: _end,
                    );
                    if (!mounted) return;
                    if (x != null) setState(() => _end = x);
                  },
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(
                    'To ${_end.format(context)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      startButton,
                      const SizedBox(height: 8),
                      endButton,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: startButton),
                    const SizedBox(width: 8),
                    Expanded(child: endButton),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _reason,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Reason (e.g. Holiday, Appointment)',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: t.bodyMedium?.copyWith(color: AppColors.error),
              ),
            ),
          PrimaryButton(
            label: 'Block this time',
            isLoading: _busy,
            onPressed: _save,
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _WorkingHoursEditor extends ConsumerStatefulWidget {
  const _WorkingHoursEditor({super.key, required this.initial});
  final AppSettings initial;

  @override
  ConsumerState<_WorkingHoursEditor> createState() =>
      _WorkingHoursEditorState();
}

class _WorkingHoursEditorState extends ConsumerState<_WorkingHoursEditor> {
  late final Map<int, WorkingDay?> _hours = {...widget.initial.workingHours};
  bool _saving = false;

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  TimeOfDay _parse(String hm) {
    final parts = hm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pick(int day, bool start) async {
    final workingDay = _hours[day];
    if (workingDay == null) return;
    final selected = await showTimePicker(
      context: context,
      initialTime: _parse(start ? workingDay.start : workingDay.end),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _hours[day] = start
          ? WorkingDay(_fmt(selected), workingDay.end)
          : WorkingDay(workingDay.start, _fmt(selected));
    });
  }

  Future<void> _save() async {
    for (final entry in _hours.entries) {
      final day = entry.value;
      if (day != null &&
          _minutes(_parse(day.end)) <= _minutes(_parse(day.start))) {
        showSnack(
          context,
          '${_days[entry.key - 1]}: finish time must be after start.',
          error: true,
        );
        return;
      }
    }
    setState(() => _saving = true);
    try {
      // Preserve booking-rule fields saved on the separate Settings screen.
      final latest = ref.read(settingsProvider).valueOrNull ?? widget.initial;
      await ref
          .read(settingsRepositoryProvider)
          .save(latest.copyWith(workingHours: {..._hours}));
      if (mounted) {
        showSnack(
          context,
          'Working hours saved. Availability updates immediately.',
        );
      }
    } catch (_) {
      if (mounted) {
        showSnack(
          context,
          'Couldn’t save working hours. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _timeButton(int day, bool start) {
    final wh = _hours[day]!;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 5),
      ),
      onPressed: _saving ? null : () => _pick(day, start),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(start ? wh.start : wh.end, maxLines: 1),
      ),
    );
  }

  Widget _dayRow(BuildContext context, int day) {
    final t = Theme.of(context).textTheme;
    final wh = _hours[day];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        final dayLabel = Text(_days[day - 1], style: t.titleSmall);
        final toggle = Switch(
          value: wh != null,
          onChanged: _saving
              ? null
              : (on) => setState(() {
                  _hours[day] = on ? const WorkingDay('08:00', '18:00') : null;
                }),
        );
        final times = wh == null
            ? Text('Not working', style: t.bodySmall)
            : Row(
                children: [
                  Expanded(child: _timeButton(day, true)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('–'),
                  ),
                  Expanded(child: _timeButton(day, false)),
                ],
              );

        if (compact) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: dayLabel),
                    toggle,
                  ],
                ),
                const SizedBox(height: 5),
                times,
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(width: 105, child: dayLabel),
              toggle,
              const SizedBox(width: 8),
              Expanded(child: times),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var d = 1; d <= 7; d++) ...[
          _dayRow(context, d),
          if (d != 7) const Divider(height: 16),
        ],
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: 'Save working hours',
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    ),
  );
}
