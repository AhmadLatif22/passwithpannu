import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

/// Brand card. [gradient] gives the website's black-to-purple look.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.gradient = false, this.padding, this.onTap});
  final Widget child;
  final bool gradient;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    return Material(
      color: gradient ? null : AppColors.black,
      borderRadius: radius,
      child: Ink(
        decoration: BoxDecoration(
          gradient: gradient ? AppColors.cardGradient : null,
          borderRadius: radius,
          border: Border.all(color: gradient ? AppColors.primary : AppColors.outline),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding ?? const EdgeInsets.all(AppSpacing.md), child: child),
        ),
      ),
    );
  }
}

/// "Label  value" row used across detail screens.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.icon, this.trailing});
  final String label;
  final String value;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: AppColors.accent), const SizedBox(width: 10)],
          SizedBox(width: 92, child: Text(label, style: t.bodySmall)),
          Expanded(child: Text(value, style: t.titleSmall)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

/// Centers content and caps its width so layouts don't stretch on tablets/desktop.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 720, this.padding});
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(padding: padding ?? const EdgeInsets.all(AppSpacing.md), child: child),
        ),
      );
}
