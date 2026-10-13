import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';

/// Shown only while the first auth state resolves. The router leaves this page the
/// moment a session (or its absence) is known, so users are never held here.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandLogo(height: 140),
              SizedBox(height: 32),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
              ),
            ],
          ),
        ),
      );
}
