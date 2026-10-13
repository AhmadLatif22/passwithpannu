import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import 'primary_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 34, color: AppColors.accent),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: t.titleLarge, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(message!, style: t.bodyMedium, textAlign: TextAlign.center),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(label: actionLabel!, onPressed: onAction, expand: false),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
