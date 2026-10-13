import 'package:flutter/material.dart';

/// Outlined brand button for secondary actions (Request change, Back, etc.).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
