/// Spacing, radii and business constants. No magic numbers in widgets.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class AppRadius {
  static const double sm = 6; // buttons, inputs (website uses small radii)
  static const double md = 12; // cards
  static const double lg = 20;
}

abstract final class AppBreakpoints {
  static const double tablet = 700;
  static const double desktop = 1100;
  static const double maxContentWidth = 1200;
  static const double formWidth = 460;
}

abstract final class AppConstants {
  static const String appName = 'Pass With Pannu';

  /// All business times are shown in this zone; storage is always UTC.
  static const String businessTimeZone = 'Europe/London';

  /// Cloud Functions region (London). Must match functions/src/config.ts.
  static const String functionsRegion = 'europe-west2';

  /// Defaults only. The live values come from `app_settings/main` in Firestore.
  static const int lessonDurationMinutes = 120;
  static const int slotStepMinutes = 30;
  static const int studentChangeNoticeHours = 48;
}
