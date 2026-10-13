import 'package:flutter/material.dart';

/// Brand palette for Pass With Pannu.
///
/// Values are estimated from the supplied website screenshot. Replace with the
/// exact hex codes from the site's CSS (browser dev tools -> :root variables)
/// and the whole app, student and admin, updates in one place.
abstract final class AppColors {
  // Core purple family
  static const Color primary = Color(0xFF7B00AB); // cards, buttons, top bar
  static const Color primaryDark = Color(0xFF5A0086); // pressed / gradient end
  static const Color primaryDeep = Color(0xFF1A0030); // deep section backgrounds
  static const Color accent = Color(0xFFB65CFF); // purple text on dark (AA contrast)

  // Neutrals
  static const Color black = Color(0xFF000000); // nav bar, cards
  static const Color charcoal = Color(0xFF1C1C1C); // page background
  static const Color surface = Color(0xFF121212);
  static const Color surfaceHigh = Color(0xFF262626);
  static const Color outline = Color(0xFF3A3A3A);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFD6D6D6);
  static const Color textMuted = Color(0xFF9A9A9A);

  // Semantic
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF5A623);
  static const Color error = Color(0xFFFF5C5C);
  static const Color info = Color(0xFF5CA8FF);

  /// Signature card gradient: black fading into brand purple.
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [black, primary],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [charcoal, primaryDeep],
  );
}
