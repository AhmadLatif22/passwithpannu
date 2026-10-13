import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_text_styles.dart';

/// Shows assets/images/logo.png, falling back to the wordmark until the logo file is added.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 96});
  final double height;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/passwithpannu_logo2.png',
        height: height,
        fit: BoxFit.contain,
        semanticLabel: AppConstants.appName,
        errorBuilder: (_, __, ___) => Text.rich(
          TextSpan(
            style: AppTextStyles.headlineLarge.copyWith(fontSize: height * 0.36),
            children: [
              const TextSpan(text: 'Pass With '),
              TextSpan(text: 'Pannu', style: AppTextStyles.accentOf(AppTextStyles.headlineLarge.copyWith(fontSize: height * 0.36))),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      );
}
