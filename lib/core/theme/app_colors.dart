
import 'package:flutter/material.dart';

/// Pass With Pannu — Premium Brand Colour Palette.
/// Black, Royal Blue, Emerald Green and White.
/// Modern dark theme with balanced brand accents.

abstract final class AppColors {
  // Primary brand colours
  static const Color primary = Color(0xFF1E49E2);
  static const Color primaryDark = Color(0xFF1739B5);
  static const Color primaryDeep = Color(0xFF0E1F4D);

  // Green brand accents
  static const Color accent = Color(0xFF16C784);
  static const Color brandGreen = Color(0xFF16A637);

  // Dark backgrounds and surfaces
  static const Color black = Color(0xFF050505);
  static const Color charcoal = Color(0xFF0B0F19);
  static const Color surface = Color(0xFF131C32);
  static const Color surfaceHigh = Color(0xFF1B2945);
  static const Color outline = Color(0xFF293957);

  // Typography
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFE0E6F0);
  static const Color textMuted = Color(0xFF9CA3AF);

  // Status colours
  static const Color success = brandGreen;
  static const Color warning = Color(0xFFF2AA43);
  static const Color error = Color(0xFFE11D22);
  static const Color info = Color(0xFF3979F6);

  // Additional brand colours
  static const Color brightBlue = Color(0xFF3979F6);
  static const Color emeraldGreen = Color(0xFF16C784);
  static const Color brandRed = Color(0xFFE11D22);

  // Light surfaces for quick-action cards
  static const Color surfaceLight = Color(0xFFF3F6FB);
  static const Color textOnLight = Color(0xFF101827);

  // Premium navy card gradient
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF142753),
      Color(0xFF131C32),
      Color(0xFF192543),
    ],
    stops: [0, 0.58, 1],
  );

  // Dark background gradient
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      charcoal,
      black,
    ],
  );

  // Brand button gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      primaryDark,
      primary,
    ],
  );

  // Driving progress gradient
  static const LinearGradient progressGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      primary,
      accent,
    ],
  );
}
