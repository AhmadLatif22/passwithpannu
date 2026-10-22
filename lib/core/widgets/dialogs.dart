import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Keep as is',
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.error)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Asks for a line of text (e.g. a cancellation reason). Returns null if dismissed.
Future<String?> promptDialog(
  BuildContext context, {
  required String title,
  required String label,
  String? message,
  String confirmLabel = 'Submit',
  int minLength = 0,
  int maxLines = 3,
  String initial = '',
  bool destructive = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PromptDialog(
      title: title,
      label: label,
      message: message,
      confirmLabel: confirmLabel,
      minLength: minLength,
      maxLines: maxLines,
      initial: initial,
      destructive: destructive,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.label,
    required this.message,
    required this.confirmLabel,
    required this.minLength,
    required this.maxLines,
    required this.initial,
    required this.destructive,
  });
  final String title, label, confirmLabel, initial;
  final String? message;
  final int minLength, maxLines;
  final bool destructive;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );
  final _key = GlobalKey<FormState>();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _c,
            maxLines: widget.maxLines,
            minLines: 1,
            maxLength: 500,
            decoration: InputDecoration(labelText: widget.label),
            validator: (v) => (v ?? '').trim().length < widget.minLength
                ? 'Please enter at least ${widget.minLength} characters'
                : null,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back'),
      ),
      FilledButton(
        style: widget.destructive
            ? FilledButton.styleFrom(backgroundColor: AppColors.error)
            : null,
        onPressed: () {
          if (_key.currentState!.validate()) {
            Navigator.pop(context, _c.text.trim());
          }
        },
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error.withValues(alpha: 0.95) : null,
      ),
    );
}
