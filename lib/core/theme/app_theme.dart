import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Light and dark Material 3 themes built from [AppColors].
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.teal,
      onPrimary: AppColors.onDark,
      primaryContainer: AppColors.tealContainer,
      onPrimaryContainer: AppColors.onTealLight,
      secondary: AppColors.coral,
      onSecondary: AppColors.onCoral,
      secondaryContainer: AppColors.coralContainer,
      onSecondaryContainer: AppColors.onCoral,
      tertiary: AppColors.amber,
      onTertiary: AppColors.onAmber,
      tertiaryContainer: AppColors.amberContainer,
      onTertiaryContainer: AppColors.onAmber,
      error: AppColors.error,
      onError: AppColors.onDark,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textLight,
      onSurfaceVariant: AppColors.textMutedLight,
      surfaceContainerHighest: AppColors.surfaceVariantLight,
      outline: AppColors.outlineLight,
    ),
    scaffoldBackground: AppColors.backgroundLight,
  );

  static ThemeData get dark => _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.tealLight,
      onPrimary: AppColors.onTealLight,
      primaryContainer: AppColors.tealContainerDark,
      onPrimaryContainer: AppColors.tealContainer,
      secondary: AppColors.coralLight,
      onSecondary: AppColors.onCoral,
      secondaryContainer: AppColors.coralContainerDark,
      onSecondaryContainer: AppColors.coralContainer,
      tertiary: AppColors.amberLight,
      onTertiary: AppColors.onAmber,
      tertiaryContainer: AppColors.amberContainerDark,
      onTertiaryContainer: AppColors.amberContainer,
      error: AppColors.errorLight,
      onError: AppColors.onCoral,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textDark,
      onSurfaceVariant: AppColors.textMutedDark,
      surfaceContainerHighest: AppColors.surfaceVariantDark,
      outline: AppColors.outlineDark,
    ),
    scaffoldBackground: AppColors.backgroundDark,
  );

  static ThemeData _build(
    ColorScheme scheme, {
    required Color scaffoldBackground,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}
