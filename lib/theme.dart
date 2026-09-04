import 'package:flutter/material.dart';

const _backgroundDark = Color(0xFF0D0D0D);
const _surfaceDark = Color(0xFF1A1A1A);
const _cardDark = Color(0xFF1E1E1E);
const _primaryGreen = Color(0xFF2E7D32);
const _primaryGreenLight = Color(0xFF4CAF50);
const _accentAmber = Color(0xFFFFB300);
const _textLight = Color(0xFFE0E0E0);
const _textMuted = Color(0xFF9E9E9E);

ThemeData buildDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: _primaryGreenLight,
      secondary: _accentAmber,
      surface: _surfaceDark,
      background: _backgroundDark,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: _textLight,
      onBackground: _textLight,
      error: Color(0xFFCF6679),
    ),
    cardTheme: const CardThemeData(
      color: _cardDark,
      elevation: 4,
      margin: EdgeInsets.all(4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: Color(0xFF2E2E2E), width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF111111),
      foregroundColor: _primaryGreenLight,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: _primaryGreenLight,
        letterSpacing: 2,
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color(0xFF111111),
      selectedIconTheme: IconThemeData(color: _primaryGreenLight),
      unselectedIconTheme: IconThemeData(color: _textMuted),
      selectedLabelTextStyle: TextStyle(color: _primaryGreenLight, fontSize: 11),
      unselectedLabelTextStyle: TextStyle(color: _textMuted, fontSize: 11),
      indicatorColor: Color(0xFF1B3A1B),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: _primaryGreenLight,
      inactiveTrackColor: Color(0xFF2E2E2E),
      thumbColor: _primaryGreenLight,
      overlayColor: Color(0x1A4CAF50),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) =>
          states.contains(MaterialState.selected) ? _primaryGreenLight : _textMuted),
      trackColor: MaterialStateProperty.resolveWith((states) =>
          states.contains(MaterialState.selected)
              ? const Color(0xFF1B3A1B)
              : const Color(0xFF2E2E2E)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF111111),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF2E2E2E)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF2E2E2E)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _primaryGreenLight, width: 1.5),
      ),
      labelStyle: TextStyle(color: _textMuted),
      hintStyle: TextStyle(color: Color(0xFF555555)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: _textLight),
      bodySmall: TextStyle(color: _textMuted),
      titleMedium: TextStyle(color: _textLight, fontWeight: FontWeight.bold),
      labelSmall: TextStyle(color: _textMuted, fontSize: 10),
    ),
    dividerColor: const Color(0xFF2E2E2E),
    iconTheme: const IconThemeData(color: _textMuted),
  );
}

ThemeData buildLightTheme() {
  return ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: _primaryGreen,
      secondary: _accentAmber,
    ),
  );
}

class AppColors {
  static const background = _backgroundDark;
  static const surface = _surfaceDark;
  static const card = _cardDark;
  static const primaryGreen = _primaryGreenLight;
  static const amber = _accentAmber;
  static const text = _textLight;
  static const textMuted = _textMuted;
  static const rxGreen = Color(0xFF00E676);
  static const txRed = Color(0xFFFF1744);
  static const pttIdle = Color(0xFF424242);
  static const pttActive = Color(0xFFD32F2F);
}
