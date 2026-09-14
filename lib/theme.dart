import 'package:flutter/material.dart';

const _backgroundDark = Color(0xFF0D0D0D);
const _surfaceDark = Color(0xFF1A1A1A);
const _cardDark = Color(0xFF1E1E1E);
const _primaryGreen = Color(0xFF2E7D32);
const _primaryGreenLight = Color(0xFF4CAF50);
const _accentAmber = Color(0xFFFFB300);
const _textLight = Color(0xFFE0E0E0);
const _textMuted = Color(0xFF9E9E9E);

// ---------------------------------------------------------------------------
// Theme-adaptive color extension — use AppColorsX.of(context) in widgets
// ---------------------------------------------------------------------------

class AppColorsX extends ThemeExtension<AppColorsX> {
  const AppColorsX({
    required this.text,
    required this.textMuted,
    required this.primaryText,
    required this.amberText,
    required this.surface,
    required this.pillBg,
    required this.dropdownBg,
    required this.borderSubtle,
    required this.borderMedium,
    required this.unselectedBg,
    required this.activeControlBg,
    required this.inactiveLed,
  });

  final Color text;
  final Color textMuted;
  // Readable green/amber for TEXT on any background (darker in light mode)
  final Color primaryText;
  final Color amberText;
  final Color surface;
  final Color pillBg;
  final Color dropdownBg;
  final Color borderSubtle;
  final Color borderMedium;
  final Color unselectedBg;
  final Color activeControlBg;
  final Color inactiveLed;

  static AppColorsX of(BuildContext context) =>
      Theme.of(context).extension<AppColorsX>()!;

  static const dark = AppColorsX(
    text: Color(0xFFE0E0E0),
    textMuted: Color(0xFF9E9E9E),
    primaryText: Color(0xFF4CAF50),
    amberText: Color(0xFFFFB300),
    surface: Color(0xFF1A1A1A),
    pillBg: Color(0xFF0A1A0A),
    dropdownBg: Color(0xFF0D1A0D),
    borderSubtle: Color(0xFF2E2E2E),
    borderMedium: Color(0xFF444444),
    unselectedBg: Color(0xFF1A1A1A),
    activeControlBg: Color(0xFF1A1200),
    inactiveLed: Color(0xFF333333),
  );

  static const light = AppColorsX(
    text: Color(0xFF212121),
    textMuted: Color(0xFF424242),
    primaryText: Color(0xFF1B5E20),  // dark green — ~9:1 on white
    amberText: Color(0xFF7D4600),    // dark amber — ~5:1 on white
    surface: Color(0xFFFFFFFF),
    pillBg: Color(0xFFF0EBE3),       // warm tan/beige — neutral for any accent
    dropdownBg: Color(0xFFF5F2EA),   // slightly lighter beige for dropdowns
    borderSubtle: Color(0xFFDDD8D0), // warm-tinted border
    borderMedium: Color(0xFFBBB5AC), // medium warm border
    unselectedBg: Color(0xFFF0EBE3), // same tan for unselected controls
    activeControlBg: Color(0xFFEAE0D0), // slightly deeper tan for active selection
    inactiveLed: Color(0xFFBBB5AC),
  );

  @override
  AppColorsX copyWith({
    Color? text,
    Color? textMuted,
    Color? primaryText,
    Color? amberText,
    Color? surface,
    Color? pillBg,
    Color? dropdownBg,
    Color? borderSubtle,
    Color? borderMedium,
    Color? unselectedBg,
    Color? activeControlBg,
    Color? inactiveLed,
  }) =>
      AppColorsX(
        text: text ?? this.text,
        textMuted: textMuted ?? this.textMuted,
        primaryText: primaryText ?? this.primaryText,
        amberText: amberText ?? this.amberText,
        surface: surface ?? this.surface,
        pillBg: pillBg ?? this.pillBg,
        dropdownBg: dropdownBg ?? this.dropdownBg,
        borderSubtle: borderSubtle ?? this.borderSubtle,
        borderMedium: borderMedium ?? this.borderMedium,
        unselectedBg: unselectedBg ?? this.unselectedBg,
        activeControlBg: activeControlBg ?? this.activeControlBg,
        inactiveLed: inactiveLed ?? this.inactiveLed,
      );

  @override
  AppColorsX lerp(ThemeExtension<AppColorsX>? other, double t) {
    if (other is! AppColorsX) return this;
    return AppColorsX(
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      amberText: Color.lerp(amberText, other.amberText, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      pillBg: Color.lerp(pillBg, other.pillBg, t)!,
      dropdownBg: Color.lerp(dropdownBg, other.dropdownBg, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderMedium: Color.lerp(borderMedium, other.borderMedium, t)!,
      unselectedBg: Color.lerp(unselectedBg, other.unselectedBg, t)!,
      activeControlBg: Color.lerp(activeControlBg, other.activeControlBg, t)!,
      inactiveLed: Color.lerp(inactiveLed, other.inactiveLed, t)!,
    );
  }
}

// ---------------------------------------------------------------------------

ThemeData buildDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: _primaryGreenLight,
      secondary: _accentAmber,
      surface: _surfaceDark,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: _textLight,
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
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF1A1A1A),
      surfaceTintColor: Colors.transparent,
    ),
    dividerColor: const Color(0xFF2E2E2E),
    iconTheme: const IconThemeData(color: _textMuted),
    extensions: const [AppColorsX.dark],
  );
}

ThemeData buildLightTheme() {
  const background = Color(0xFFF0F2F5);
  const surface = Colors.white;
  const primaryGreen = Color(0xFF2E7D32);
  const primaryGreenLight = Color(0xFF4CAF50);
  const accentAmber = Color(0xFFFFB300);
  const textDark = Color(0xFF212121);
  const textMuted = Color(0xFF616161);

  return ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.light(
      primary: primaryGreen,
      secondary: accentAmber,
      surface: surface,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: textDark,
      error: Color(0xFFB00020),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 1,
      shadowColor: Colors.black26,
      margin: const EdgeInsets.all(4),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      foregroundColor: primaryGreen,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: primaryGreen,
        letterSpacing: 2,
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color(0xFFFAFAFA),
      selectedIconTheme: IconThemeData(color: primaryGreen),
      unselectedIconTheme: IconThemeData(color: textMuted),
      selectedLabelTextStyle: TextStyle(color: primaryGreen, fontSize: 11),
      unselectedLabelTextStyle: TextStyle(color: textMuted, fontSize: 11),
      indicatorColor: Color(0xFFE8F5E9),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: primaryGreen,
      inactiveTrackColor: Color(0xFFBDBDBD),
      thumbColor: primaryGreen,
      overlayColor: Color(0x1A2E7D32),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) =>
          states.contains(MaterialState.selected)
              ? primaryGreenLight
              : Colors.grey.shade400),
      trackColor: MaterialStateProperty.resolveWith((states) =>
          states.contains(MaterialState.selected)
              ? const Color(0xFFC8E6C9)
              : Colors.grey.shade300),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: primaryGreen, width: 1.5),
      ),
      labelStyle: const TextStyle(color: textMuted),
      hintStyle: TextStyle(color: Colors.grey.shade400),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primaryGreen),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: textDark),
      bodySmall: TextStyle(color: textMuted),
      titleMedium: TextStyle(color: textDark, fontWeight: FontWeight.bold),
      labelSmall: TextStyle(color: textMuted, fontSize: 10),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
    dividerColor: const Color(0xFFE0E0E0),
    iconTheme: const IconThemeData(color: textMuted),
    extensions: const [AppColorsX.light],
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
