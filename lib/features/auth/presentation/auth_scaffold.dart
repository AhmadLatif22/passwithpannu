import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, this.subtitle, required this.children});
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppBreakpoints.formWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: BrandLogo(height: 84)),
                    const SizedBox(height: AppSpacing.xl),
                    Text(title, style: t.headlineMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(subtitle!, style: t.bodyMedium),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline error banner for forms.
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      );
}
