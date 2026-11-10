import 'package:flutter/material.dart';

enum AppThemeMode {
  dark,
  light,
  moderate,
}

class AppThemeColors {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color border;
  final Color primary;
  final Color secondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color cardBackground;
  final Brightness brightness;

  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.primary,
    required this.secondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardBackground,
    required this.brightness,
  });

  static const AppThemeColors dark = AppThemeColors(
    background: Color(0xFF0B0F19),
    surface: Color(0xFF151E2E),
    surfaceVariant: Color(0xFF1E293B),
    border: Color(0xFF232F46),
    primary: Color(0xFF6366F1),
    secondary: Color(0xFF10B981),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    cardBackground: Color(0xFF151E2E),
    brightness: Brightness.dark,
  );

  static const AppThemeColors light = AppThemeColors(
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    primary: Color(0xFF4F46E5),
    secondary: Color(0xFF059669),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    cardBackground: Color(0xFFFFFFFF),
    brightness: Brightness.light,
  );

  static const AppThemeColors moderate = AppThemeColors(
    background: Color(0xFF1A1D24),
    surface: Color(0xFF252A36),
    surfaceVariant: Color(0xFF2F3646),
    border: Color(0xFF3A4356),
    primary: Color(0xFF818CF8),
    secondary: Color(0xFF34D399),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFFA0AAB8),
    cardBackground: Color(0xFF252A36),
    brightness: Brightness.dark,
  );

  static AppThemeColors of(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return light;
      case AppThemeMode.moderate:
        return moderate;
      case AppThemeMode.dark:
      default:
        return dark;
    }
  }
}

class AppTheme {
  static ThemeData getThemeData(AppThemeMode mode) {
    final colors = AppThemeColors.of(mode);
    final isDark = colors.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      scaffoldBackgroundColor: colors.background,
      cardColor: colors.cardBackground,
      colorScheme: ColorScheme(
        brightness: colors.brightness,
        primary: colors.primary,
        onPrimary: Colors.white,
        secondary: colors.secondary,
        onSecondary: Colors.white,
        error: Colors.redAccent,
        onError: Colors.white,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        surfaceContainerHighest: colors.surfaceVariant,
        outline: colors.border,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      dividerColor: colors.border,
      textTheme: isDark
          ? Typography.material2021().white
          : Typography.material2021().black,
    );
  }
}
