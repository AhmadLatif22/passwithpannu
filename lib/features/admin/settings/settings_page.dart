import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/primary_button.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/domain/app_settings.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: AsyncValueView<AppSettings>(
          value: ref.watch(settingsProvider),
          onRetry: () => ref.invalidate(settingsProvider),
          data: (s) => _SettingsForm(initial: s),
        ),
      );
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.initial});
  final AppSettings initial;
  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late Map<int, WorkingDay?> _hours = {...widget.initial.workingHours};
  late final _buffer = TextEditingController(text: '${widget.initial.travelBufferMinutes}');
  late final _notice = TextEditingController(text: '${widget.initial.studentChangeNoticeHours}');
  late final _minBook = TextEditingController(text: '${widget.initial.minBookingNoticeHours}');
  late final _reminders = TextEditingController(text: widget.initial.reminderOffsetsHours.join(', '));
  late bool _approval = widget.initial.requireAdminApproval;
  bool _busy = false;

  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void dispose() {
    for (final c in [_buffer, _notice, _minBook, _reminders]) {
      c.dispose();
    }
    super.dispose();
  }

  TimeOfDay _parse(String hm) {
    final p = hm.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick(int day, bool start) async {
    final wh = _hours[day]!;
    final t = await showTimePicker(context: context, initialTime: _parse(start ? wh.start : wh.end));
    if (t == null) return;
    setState(() => _hours[day] = start ? WorkingDay(_fmt(t), wh.end) : WorkingDay(wh.start, _fmt(t)));
  }

  Future<void> _save() async {
    int? n(TextEditingController c) => int.tryParse(c.text.trim());
    final offsets = _reminders.text.split(',').map((e) => int.tryParse(e.trim())).toList();
    if (n(_buffer) == null || n(_notice) == null || n(_minBook) == null || offsets.isEmpty || offsets.any((o) => o == null || o <= 0)) {
      showSnack(context, 'Please enter whole numbers (reminders as e.g. “24, 2”).', error: true);
      return;
    }
    for (final e in _hours.entries) {
      final wh = e.value;
      if (wh != null && _parse(wh.end).hour * 60 + _parse(wh.end).minute <= _parse(wh.start).hour * 60 + _parse(wh.start).minute) {
        showSnack(context, '${_days[e.key - 1]}: finish time must be after start.', error: true);
        return;
      }
    }
    setState(() => _busy = true);
    try {
      await ref.read(settingsRepositoryProvider).save(widget.initial.copyWith(
            travelBufferMinutes: n(_buffer),
            studentChangeNoticeHours: n(_notice),
            minBookingNoticeHours: n(_minBook),
            reminderOffsetsHours: offsets.cast<int>(),
            requireAdminApproval: _approval,
            workingHours: _hours,
          ));
      if (mounted) showSnack(context, 'Settings saved. Availability updates immediately.');
    } catch (_) {
      if (mounted) showSnack(context, 'Couldn’t save settings. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      children: [
        ContentWidth(
          maxWidth: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle('Working hours'),
              AppCard(
                child: Column(
                  children: [
                    for (var d = 1; d <= 7; d++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(width: 100, child: Text(_days[d - 1], style: t.titleSmall)),
                            Switch(
                              value: _hours[d] != null,
                              onChanged: (on) => setState(() => _hours[d] = on ? const WorkingDay('08:00', '18:00') : null),
                            ),
                            const SizedBox(width: 8),
                            if (_hours[d] != null) ...[
                              OutlinedButton(onPressed: () => _pick(d, true), child: Text(_hours[d]!.start)),
                              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('–')),
                              OutlinedButton(onPressed: () => _pick(d, false), child: Text(_hours[d]!.end)),
                            ] else
                              Text('Not working', style: t.bodySmall),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SectionTitle('Booking rules'),
              AppCard(
                child: Column(
                  children: [
                    TextField(controller: _buffer, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Extra travel buffer between lessons (minutes)', helperText: 'Added on top of the driving time')),
                    const SizedBox(height: 14),
                    TextField(controller: _minBook, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Earliest bookable time from now (hours)')),
                    const SizedBox(height: 14),
                    TextField(controller: _notice, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Notice needed for student change/cancel requests (hours)')),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Approve new bookings manually'),
                      subtitle: const Text('Off: bookings are confirmed instantly'),
                      value: _approval,
                      onChanged: (v) => setState(() => _approval = v),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Reminders'),
              AppCard(
                child: TextField(
                  controller: _reminders,
                  decoration: const InputDecoration(labelText: 'Send reminders this many hours before', helperText: 'Comma separated, e.g. 24, 2'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(label: 'Save settings', isLoading: _busy, onPressed: _save),
              const SizedBox(height: AppSpacing.md),
              Text('Lesson length is fixed at 2 hours.', style: t.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
