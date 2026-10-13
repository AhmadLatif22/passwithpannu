import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography mirrors the website: Playfair Display (serif) for headings,
/// Outfit (geometric sans) for body copy. Verify against the site's CSS.
abstract final class AppTextStyles {
  static TextStyle _heading(double size, {FontWeight w = FontWeight.w700}) =>
      GoogleFonts.playfairDisplay(
          fontSize: size, fontWeight: w, color: AppColors.textPrimary, height: 1.2);

  static TextStyle _body(double size, {FontWeight w = FontWeight.w400, Color? c}) =>
      GoogleFonts.outfit(
          fontSize: size,
          fontWeight: w,
          color: c ?? AppColors.textSecondary,
          height: 1.45);

  static TextStyle get displayLarge => _heading(40);
  static TextStyle get headlineLarge => _heading(32);
  static TextStyle get headlineMedium => _heading(26);
  static TextStyle get titleLarge => _heading(22);
  static TextStyle get titleMedium =>
      _body(17, w: FontWeight.w600, c: AppColors.textPrimary);
  static TextStyle get titleSmall =>
      _body(15, w: FontWeight.w600, c: AppColors.textPrimary);
  static TextStyle get bodyLarge => _body(16);
  static TextStyle get bodyMedium => _body(14);
  static TextStyle get bodySmall => _body(12, c: AppColors.textMuted);
  static TextStyle get labelLarge =>
      _body(15, w: FontWeight.w600, c: AppColors.textPrimary);
  static TextStyle get labelMedium =>
      _body(13, w: FontWeight.w500, c: AppColors.textPrimary);

  /// Used for the purple accent word in headings, e.g. "Our [School]".
  static TextStyle accentOf(TextStyle base) => base.copyWith(color: AppColors.accent);
}
