import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography matching the website's font stack:
/// - sans (display): Space Grotesk
/// - body: Inter
/// - mono: JetBrains Mono
class AppTypography {
  AppTypography._();

  static TextTheme buildTextTheme() {
    final base = ThemeData(brightness: Brightness.dark).textTheme;
    final body = GoogleFonts.interTextTheme(base);

    return body.copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(
        textStyle: body.displayLarge,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      displayMedium: GoogleFonts.spaceGrotesk(
        textStyle: body.displayMedium,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      displaySmall: GoogleFonts.spaceGrotesk(
        textStyle: body.displaySmall,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        textStyle: body.headlineLarge,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        textStyle: body.headlineMedium,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        textStyle: body.headlineSmall,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: body.titleLarge?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: body.titleMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: body.titleSmall?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: body.bodyLarge?.copyWith(color: AppColors.textPrimary),
      bodyMedium: body.bodyMedium?.copyWith(color: AppColors.textPrimary),
      bodySmall: body.bodySmall?.copyWith(color: AppColors.textSecondary),
      labelLarge: body.labelLarge?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: body.labelMedium?.copyWith(color: AppColors.textSecondary),
      labelSmall: body.labelSmall?.copyWith(color: AppColors.textMuted),
    );
  }

  static TextStyle mono({double? size, Color? color, FontWeight? weight}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        color: color ?? AppColors.textPrimary,
        fontWeight: weight,
      );
}
