import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/primary_button.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/domain/app_settings.dart';

/// Booking rules and reminders only. Working hours live on AvailabilityPage.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: AsyncValueView<AppSettings>(
      value: ref.watch(settingsProvider),
      onRetry: () => ref.invalidate(settingsProvider),
      data: (s) => _SettingsForm(key: ValueKey(s.hashCode), initial: s),
    ),
  );
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({super.key, required this.initial});
  final AppSettings initial;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late final _buffer = TextEditingController(
    text: '${widget.initial.travelBufferMinutes}',
  );
  late final _notice = TextEditingController(
    text: '${widget.initial.studentChangeNoticeHours}',
  );
  late final _minBook = TextEditingController(
    text: '${widget.initial.minBookingNoticeHours}',
  );
  late final _reminders = TextEditingController(
    text: widget.initial.reminderOffsetsHours.join(', '),
  );
  late bool _approval = widget.initial.requireAdminApproval;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_buffer, _notice, _minBook, _reminders]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    int? n(TextEditingController c) => int.tryParse(c.text.trim());
    final buffer = n(_buffer);
    final notice = n(_notice);
    final minBook = n(_minBook);
    final offsets = _reminders.text
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .toList();

    if (buffer == null || buffer < 0 ||
        notice == null || notice < 0 ||
        minBook == null || minBook < 0 ||
        offsets.isEmpty ||
        offsets.any((o) => o == null || o <= 0)) {
      showSnack(
        context,
        'Enter non-negative whole numbers (reminders e.g. "24, 2").',
        error: true,
      );
      return;
    }

    setState(() => _busy = true);
    try {
      // Use the freshest available settings so saving this screen does not
      // revert working-hour changes made on the Availability screen.
      final latest = ref.read(settingsProvider).valueOrNull ?? widget.initial;
      await ref.read(settingsRepositoryProvider).save(
        latest.copyWith(
          travelBufferMinutes: buffer,
          studentChangeNoticeHours: notice,
          minBookingNoticeHours: minBook,
          reminderOffsetsHours: offsets.cast<int>(),
          requireAdminApproval: _approval,
        ),
      );
      if (mounted) {
        showSnack(context, 'Settings saved successfully.');
      }
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Couldn’t save settings. Please try again.', error: true);
      }
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
              const SectionTitle('Booking rules'),
              AppCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _buffer,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Extra travel buffer between lessons (minutes)',
                        helperText: 'Added on top of the driving time',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _minBook,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Earliest bookable time from now (hours)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _notice,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText:
                        'Notice needed for student change/cancel requests (hours)',
                      ),
                    ),
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
                  decoration: const InputDecoration(
                    labelText: 'Send reminders this many hours before',
                    helperText: 'Comma separated, e.g. 24, 2',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Save settings',
                isLoading: _busy,
                onPressed: _busy ? null : _save,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Lesson length is fixed at 2 hours.', style: t.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
