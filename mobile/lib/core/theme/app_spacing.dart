/// Spacing and radius tokens.
///
/// Mirrors Tailwind's default 4-px-based spacing scale used throughout
/// the website, plus the website's `--radius: 0.75rem` (12 px).
class AppSpacing {
  AppSpacing._();

  // Spacing scale (4px base)
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  // Radius (matches website --radius family)
  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 12;     // primary
  static const double radiusXl = 16;
  static const double radiusFull = 999;
}
