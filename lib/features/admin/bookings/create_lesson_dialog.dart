import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/primary_button.dart';
import '../../availability/domain/slot.dart';
import '../../availability/presentation/pickup_field.dart';
import '../../bookings/domain/lesson_type.dart';
import '../../bookings/presentation/booking_providers.dart';
import '../shared/admin_actions.dart';
import '../shared/admin_providers.dart';

Future<void> showCreateLessonDialog(BuildContext context, {String? studentId}) => showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _CreateLesson(studentId: studentId),
        ),
      ),
    );

class _CreateLesson extends ConsumerStatefulWidget {
  const _CreateLesson({this.studentId});
  final String? studentId;
  @override
  ConsumerState<_CreateLesson> createState() => _CreateLessonState();
}

class _CreateLessonState extends ConsumerState<_CreateLesson> {
  String? _studentId;
  LessonType _type = LessonType.manual;
  DateTime? _start;
  PickupLocation? _pickup;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _studentId = widget.studentId;
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    final ok = await runAdminAction(
      context,
      (override) => ref.read(bookingRepositoryProvider).adminCreate(
            studentId: _studentId!,
            lessonType: _type,
            start: _start!,
            pickup: _pickup!,
            override: override,
          ),
      success: 'Lesson created. The student has been notified.',
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
    final students = ref.watch(adminStudentsProvider).valueOrNull ?? const [];
    final ready = _studentId != null && _start != null && _pickup != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add a lesson', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _studentId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Student', prefixIcon: Icon(Icons.person_outline)),
            items: [for (final s in students) DropdownMenuItem(value: s.uid, child: Text('${s.fullName} · ${s.email}', overflow: TextOverflow.ellipsis))],
            onChanged: _busy ? null : (v) => setState(() => _studentId = v),
          ),
          const SizedBox(height: 14),
          SegmentedButton<LessonType>(
            segments: [for (final t in LessonType.values) ButtonSegment(value: t, label: Text(t.label))],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    final d = await pickBusinessDateTime(context, initial: _start);
                    if (d != null) setState(() => _start = d);
                  },
            icon: const Icon(Icons.event_outlined),
            label: Text(_start == null ? 'Choose date & time' : '${DateTimeUtils.formatLongDate(_start!)} · ${DateTimeUtils.formatRange(_start!, _start!.add(const Duration(hours: 2)))}'),
          ),
          const SizedBox(height: 14),
          PickupAutocompleteField(onSelected: (l) => setState(() => _pickup = l)),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(label: 'Create lesson', isLoading: _busy, onPressed: ready ? _create : null),
          TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }
}
