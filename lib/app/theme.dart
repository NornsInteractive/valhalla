import 'package:flutter/material.dart';

enum AppThemeMode { system, light, dark, amoled }

enum AppAccentColor {
  cyberEmerald(Color(0xFF10B981)),
  techBlue(Color(0xFF2563EB)),
  electricViolet(Color(0xFF8B5CF6)),
  crimsonRed(Color(0xFFEF4444)),
  amberOrange(Color(0xFFF59E0B));

  final Color color;
  const AppAccentColor(this.color);
}

class AppTheme {
  static ThemeData buildTheme({
    required Brightness brightness,
    required Color seedColor,
    bool isAmoled = false,
  }) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: brightness,
        ).copyWith(
          surface: isAmoled
              ? Colors.black
              : (brightness == Brightness.dark
                    ? const Color(0xFF10141A)
                    : const Color(0xFFF8FAFC)),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isAmoled
          ? Colors.black
          : (brightness == Brightness.dark
                ? const Color(0xFF10141A)
                : const Color(0xFFF8FAFC)),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: brightness == Brightness.dark
                ? const Color(0xFF262A31)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        color: isAmoled
            ? const Color(0xFF0D0D0D)
            : (brightness == Brightness.dark
                  ? const Color(0xFF181C22)
                  : Colors.white),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isAmoled
            ? const Color(0xFF121212)
            : (brightness == Brightness.dark
                  ? const Color(0xFF1C2026)
                  : Colors.white),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isAmoled
            ? Colors.black
            : (brightness == Brightness.dark
                  ? const Color(0xFF10141A)
                  : const Color(0xFFF8FAFC)),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: brightness == Brightness.dark
              ? const Color(0xFFDFE2EB)
              : const Color(0xFF0F172A),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isAmoled
            ? Colors.black
            : (brightness == Brightness.dark
                  ? const Color(0xFF0A0E14)
                  : const Color(0xFFF1F5F9)),
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(
          color: brightness == Brightness.dark
              ? const Color(0xFF86948A)
              : const Color(0xFF64748B),
        ),
        labelType: NavigationRailLabelType.all,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isAmoled
            ? Colors.black
            : (brightness == Brightness.dark
                  ? const Color(0xFF10141A)
                  : const Color(0xFFF1F5F9)),
        elevation: 0,
        height: 65,
      ),
      fontFamily: 'Inter',
    );
  }
}
