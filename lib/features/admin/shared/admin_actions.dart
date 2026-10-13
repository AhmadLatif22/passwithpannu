import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/dialogs.dart';

/// Runs an admin scheduling action. If the server reports a conflict the instructor is allowed to
/// override (travel time, blocked period, outside hours), asks for explicit confirmation and retries.
/// Overlap with another lesson can never be overridden.
Future<bool> runAdminAction(
  BuildContext context,
  Future<void> Function(bool override) action, {
  String? success,
}) async {
  try {
    await action(false);
  } on AppFailure catch (e) {
    if (!e.isOverridable) {
      if (context.mounted) showSnack(context, e.message, error: true);
      return false;
    }
    if (!context.mounted) return false;
    final go = await confirmDialog(
      context,
      title: 'Scheduling warning',
      message: '${e.message}\n\nAs the instructor you can override this. Continue anyway?',
      confirmLabel: 'Override',
      cancelLabel: 'Go back',
      destructive: true,
    );
    if (!go || !context.mounted) return false;
    try {
      await action(true);
    } on AppFailure catch (e2) {
      if (context.mounted) showSnack(context, e2.message, error: true);
      return false;
    }
  }
  if (context.mounted && success != null) showSnack(context, success);
  return true;
}

/// Picks a business-time date + time and returns it as a UTC instant.
Future<DateTime?> pickBusinessDateTime(BuildContext context, {DateTime? initial}) async {
  final base = initial != null ? DateTimeUtils.toBusiness(initial) : DateTimeUtils.toBusiness(DateTime.now().add(const Duration(days: 1)));
  final date = await showDatePicker(
    context: context,
    initialDate: DateTime(base.year, base.month, base.day),
    firstDate: DateTime.now().subtract(const Duration(days: 1)),
    lastDate: DateTime.now().add(const Duration(days: 400)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: initial != null ? base.hour : 10, minute: initial != null ? base.minute : 0),
  );
  if (time == null) return null;
  return DateTimeUtils.fromBusinessParts(date.year, date.month, date.day, time.hour, time.minute);
}

Future<void> openUrl(BuildContext context, Uri uri) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showSnack(context, 'Couldn’t open that on this device.', error: true);
}

Uri mapsUri(double lat, double lng) => Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
