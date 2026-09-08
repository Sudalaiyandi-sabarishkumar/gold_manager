import 'package:flutter/material.dart';

/// Yellow-on-black palette, shared with the HTML prototype.
class GoldColors {
  static const bg = Color(0xFF0D0B07);
  static const surface = Color(0xFF181410);
  static const surface2 = Color(0xFF211B13);
  static const raise = Color(0xFF2B2318);
  static const hairline = Color(0xFF3A2F1E);
  static const gold = Color(0xFFF5C518);
  static const goldDeep = Color(0xFFC9A227);
  static const goldInk = Color(0xFF241A02);
  static const text = Color(0xFFF6F1E4);
  static const muted = Color(0xFFA99E86);
  static const faint = Color(0xFF7C745F);
  static const gain = Color(0xFF5CC08A);
  static const loss = Color(0xFFE5675F);
}

ThemeData buildGoldTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );

  return base.copyWith(
    scaffoldBackgroundColor: GoldColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: GoldColors.gold,
      onPrimary: GoldColors.goldInk,
      secondary: GoldColors.goldDeep,
      onSecondary: GoldColors.goldInk,
      surface: GoldColors.surface,
      onSurface: GoldColors.text,
      error: GoldColors.loss,
      onError: Colors.white,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: GoldColors.text,
      displayColor: GoldColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: GoldColors.bg,
      foregroundColor: GoldColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    dividerTheme:
        const DividerThemeData(color: GoldColors.hairline, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GoldColors.surface2,
      hintStyle: const TextStyle(color: GoldColors.faint),
      labelStyle: const TextStyle(color: GoldColors.muted),
      enabledBorder: border(GoldColors.hairline),
      focusedBorder: border(GoldColors.gold, 2),
      errorBorder: border(GoldColors.loss),
      focusedErrorBorder: border(GoldColors.loss, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: GoldColors.gold,
        foregroundColor: GoldColors.goldInk,
        disabledBackgroundColor: GoldColors.raise,
        disabledForegroundColor: GoldColors.faint,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: GoldColors.gold,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: GoldColors.goldDeep),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: GoldColors.gold),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: GoldColors.gold,
      contentTextStyle:
          TextStyle(color: GoldColors.goldInk, fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: GoldColors.gold),
  );
}
