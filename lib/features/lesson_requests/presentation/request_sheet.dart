import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/primary_button.dart';
import '../../bookings/domain/booking.dart';
import '../domain/booking_request.dart';
import 'request_providers.dart';

/// Student request form. Submitting creates a REQUEST only: the lesson stays exactly as booked
/// until the instructor decides.
Future<void> showRequestSheet(
  BuildContext context,
  Booking booking,
  RequestType type,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => _RequestSheet(booking: booking, type: type),
  );
}

class _RequestSheet extends ConsumerStatefulWidget {
  const _RequestSheet({required this.booking, required this.type});
  final Booking booking;
  final RequestType type;

  @override
  ConsumerState<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends ConsumerState<_RequestSheet> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  bool _busy = false;
  String? _error;

  bool get _isCancel => widget.type == RequestType.cancel;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 120)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (t != null) setState(() => _time = t);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if ((_date == null) != (_time == null) && !_isCancel) {
      setState(
        () => _error =
            'Choose both a preferred date and time, or leave both empty.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      DateTime? preferred;
      if (!_isCancel && _date != null && _time != null) {
        preferred = DateTimeUtils.fromBusinessParts(
          _date!.year,
          _date!.month,
          _date!.day,
          _time!.hour,
          _time!.minute,
        );
      }
      await ref
          .read(requestRepositoryProvider)
          .create(
            bookingId: widget.booking.id,
            type: widget.type,
            reason: _reason.text,
            preferredStart: preferred,
          );
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(
        context,
        'Request sent. Your lesson stays as booked until it’s reviewed.',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AppFailure.from(e).message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isCancel ? 'Request cancellation' : 'Request a change',
                style: t.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Lesson: ${DateTimeUtils.formatDateTime(widget.booking.start)}. '
                '${_isCancel ? 'Your instructor will review this and confirm.' : 'This is only a request. Your instructor chooses the final time.'}',
                style: t.bodyMedium,
              ),
              if (!_isCancel) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Preferred new time (optional)', style: t.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _pickDate,
                        icon: const Icon(Icons.event_outlined, size: 18),
                        label: Text(
                          _date == null
                              ? 'Date'
                              : DateTimeUtils.formatPlainShort(_date!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _pickTime,
                        icon: const Icon(Icons.schedule, size: 18),
                        label: Text(
                          _time == null ? 'Time' : _time!.format(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _reason,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: _isCancel
                      ? 'Reason (required)'
                      : 'Message (optional)',
                ),
                validator: _isCancel
                    ? (v) => (v ?? '').trim().length < 5
                          ? 'Please add a short reason'
                          : null
                    : null,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: t.bodyMedium?.copyWith(color: AppColors.error),
                  ),
                ),
              PrimaryButton(
                label: _isCancel
                    ? 'Send cancellation request'
                    : 'Send change request',
                isLoading: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
