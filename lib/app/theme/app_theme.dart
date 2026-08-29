import 'package:flutter/material.dart';

/// Rank Rush visual identity.
///
/// A modern "card room after dark" palette: deep ink backgrounds, a felt-green
/// primary, warm gold for virtual coins, and clearly distinct LEFT/RIGHT hues
/// so the two betting sides are never confused. Designed for a dark theme with
/// strong contrast and generous spacing.
class AppColors {
  const AppColors._();

  static const Color ink = Color(0xFF0E1116);
  static const Color surface = Color(0xFF171B22);
  static const Color surfaceHigh = Color(0xFF1F2530);
  static const Color felt = Color(0xFF1B7A5A);
  static const Color feltBright = Color(0xFF2AA179);
  static const Color gold = Color(0xFFF2C14E);
  static const Color goldDim = Color(0xFFB8922F);

  static const Color left = Color(0xFF4C8DFF); // blue side
  static const Color right = Color(0xFFFF7A59); // coral side
  static const Color win = Color(0xFF3ED598);
  static const Color loss = Color(0xFFFF5D6C);

  static const Color textPrimary = Color(0xFFF3F5F8);
  static const Color textMuted = Color(0xFF9AA6B8);

  static const Color cardFace = Color(0xFFF7F8FA);
  static const Color cardRed = Color(0xFFD5303E);
  static const Color cardBlack = Color(0xFF1B2230);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.felt,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.feltBright,
      secondary: AppColors.gold,
      surface: AppColors.surface,
      error: AppColors.loss,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.ink,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x22FFFFFF)),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(color: Color(0x1AFFFFFF), space: 1),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
    );
  }
}
