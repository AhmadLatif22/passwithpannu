import 'package:flutter/material.dart';

/// Pass With Pannu premium palette: blue-led, with restrained purple and green.
abstract final class AppColors {
  static const Color primary = Color(0xFF3E77FF);
  static const Color primaryDark = Color(0xFF2449AD);
  static const Color primaryDeep = Color(0xFF10182B);
  static const Color accent = Color(0xFF9876F5);
  static const Color brandGreen = Color(0xFF18D67B);

  static const Color black = Color(0xFF090B11);
  static const Color charcoal = Color(0xFF0B0D14);
  static const Color surface = Color(0xFF171B28);
  static const Color surfaceHigh = Color(0xFF22293A);
  static const Color outline = Color(0xFF30384B);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFD7DCE8);
  static const Color textMuted = Color(0xFFAAB3C5);

  static const Color success = brandGreen;
  static const Color warning = Color(0xFFF5B84B);
  static const Color error = Color(0xFFFF6474);
  static const Color info = Color(0xFF62B4FF);

  // Gentle deep-blue/purple glow instead of the previous neon-green wash.
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF182D40), Color(0xFF171B28), Color(0xFF252044)],
    stops: [0, 0.58, 1],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [charcoal, primaryDeep],
  );
}
