import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography with a confident hierarchy. Inter (a modern variable sans) with
/// only two real weights in play: regular (400) and medium (500). Large display
/// sizes for the concept name and clarity score; generous line height for body.
///
/// Sentence case everywhere — never ALL CAPS, never Title Case (that is a usage
/// rule we follow in the widgets, not something the type system enforces).
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(AppPalette p) {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      // Big, confident display — concept name, clarity score.
      displayLarge: GoogleFonts.inter(
        fontSize: 56,
        height: 1.04,
        fontWeight: FontWeight.w500,
        letterSpacing: -1.2,
        color: p.textPrimary,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 40,
        height: 1.08,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.8,
        color: p.textPrimary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.4,
        color: p.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 17,
        height: 1.3,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: p.textPrimary,
      ),
      // Generous line height for readable body.
      bodyLarge: GoogleFonts.inter(
        fontSize: 17,
        height: 1.5,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.1,
        color: p.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 15,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: p.textSecondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: p.textPrimary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: p.textSecondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11.5,
        height: 1.2,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: p.textTertiary,
      ),
    );
  }
}
