import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Exposes the active [AppPalette] to the widget tree. We keep the palette on a
/// [ThemeExtension] so any widget can read precise design tokens (hairline,
/// orb stops, warning accent) that Material's [ColorScheme] doesn't model.
@immutable
class AppThemeExt extends ThemeExtension<AppThemeExt> {
  const AppThemeExt(this.palette);

  final AppPalette palette;

  @override
  AppThemeExt copyWith({AppPalette? palette}) => AppThemeExt(palette ?? this.palette);

  @override
  AppThemeExt lerp(ThemeExtension<AppThemeExt>? other, double t) {
    if (other is! AppThemeExt) return this;
    // Snap at the midpoint — palettes are discrete, not blended.
    return t < 0.5 ? this : other;
  }
}

/// Convenience accessor: `context.palette`.
extension AppThemeContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppThemeExt>()?.palette ?? AppPalette.dark;
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() => _build(AppPalette.dark);
  static ThemeData light() => _build(AppPalette.light);

  static ThemeData _build(AppPalette p) {
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.accent,
      onPrimary: p.isDark ? const Color(0xFF0B0B0F) : Colors.white,
      secondary: p.accent,
      onSecondary: p.isDark ? const Color(0xFF0B0B0F) : Colors.white,
      error: p.recordingDot,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.textPrimary,
      surfaceContainerHighest: p.surfaceHigh,
      outline: p.hairline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      scaffoldBackgroundColor: p.bg,
      colorScheme: scheme,
      textTheme: AppTypography.textTheme(p),
      splashFactory: InkSparkle.splashFactory,
      extensions: [AppThemeExt(p)],
      iconTheme: IconThemeData(color: p.textSecondary, size: 22),
      dividerColor: p.hairline,
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.surfaceHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.hairline),
        ),
        textStyle: AppTypography.textTheme(p).labelMedium,
      ),
    );
  }
}
