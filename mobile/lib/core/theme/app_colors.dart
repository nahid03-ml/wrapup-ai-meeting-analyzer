import 'package:flutter/material.dart';

/// App color palette.
///
/// Values are derived from the website's design tokens defined in
/// `src/index.css` (HSL CSS variables). The website is dark-first
/// (its body is hard-coded to hsl(228, 40%, 4%)) so the mobile app
/// also defaults to dark.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF8B5CF6);      // hsl(265, 90%, 60%)
  static const Color primaryHover = Color(0xFF7C3AED);
  static const Color cyan = Color(0xFF22D3EE);         // accent / glow
  static const Color pink = Color(0xFFEC4899);         // gradient accent

  // Surfaces (dark mode — primary)
  static const Color background = Color(0xFF050713);   // hsl(228, 40%, 4%)
  static const Color surface = Color(0xFF0B1020);      // hsl(228, 35%, 7%)
  static const Color surfaceElevated = Color(0xFF111634);
  static const Color border = Color(0xFF1B2138);       // hsl(228, 30%, 12%)
  static const Color input = Color(0xFF1B2138);

  // Text
  static const Color textPrimary = Color(0xFFE5E7F0);  // hsl(220, 20%, 92%)
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color destructive = Color(0xFFEF4444);

  // Gradient stops (matches --gradient-start / --gradient-end)
  static const Color gradientStart = Color(0xFF8B5CF6);
  static const Color gradientEnd = Color(0xFFD946EF);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );
}
