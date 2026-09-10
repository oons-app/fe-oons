import 'package:flutter/material.dart';

class T {
  static const bg = Color(0xFFF7F4EE);
  static const surface = Color(0xFFFFFFFF);
  static const sand = Color(0xFFEDE6E0);
  static const line = Color(0xFFDCD4CC);
  static const ink = Color(0xFF1C1518);
  static const body = Color(0xFF4A3F45);
  static const muted = Color(0xFF6E655F);
  static const action = Color(0xFF3E2136);
  static const actionPressed = Color(0xFF2A1622);
  static const trust = Color(0xFF6B7355);
  static const trustInk = Color(0xFF4E5540);
  static const trustTint = Color(0xFFE8F0DE);
  static const plumTint = Color(0xFFF0E6EE);
  static const warm = Color(0xFFB5654B);
  static const pending = Color(0xFFA87832);
  static const pendingTint = Color(0xFFF3E7D2);
  static const danger = Color(0xFFB84F4F);
  static const dangerTint = Color(0xFFF6E7E7);
  static const chef = Color(0xFFB58A52);
  static const childcare = Color(0xFF81758B);
  static const white = Color(0xFFFFFFFF);

  static const rule = 1.0;
  static const radius = 0.0;
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;
  static const space8 = 32.0;

  static const dState = Duration(milliseconds: 160);
  static const dArrival = Duration(milliseconds: 240);
  static const dHold = Duration(milliseconds: 900);

  static const archivo = 'Archivo';
  static const arabic = 'IBMPlexSansArabic';
  static const mono = 'IBMPlexMono';
}

ThemeData sanctuaryTheme() {
  const text = TextStyle(color: T.ink, fontFamily: T.archivo);
  return ThemeData(
    useMaterial3: false,
    brightness: Brightness.light,
    scaffoldBackgroundColor: T.bg,
    canvasColor: T.bg,
    primaryColor: T.action,
    colorScheme: const ColorScheme.light(
      primary: T.action,
      onPrimary: T.white,
      surface: T.surface,
      onSurface: T.ink,
      error: T.danger,
    ),
    textTheme: TextTheme(
      displayLarge: text.copyWith(fontSize: 28, fontWeight: FontWeight.w800, height: 1.12, letterSpacing: -0.4),
      headlineMedium: text.copyWith(fontSize: 24, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.3),
      titleLarge: text.copyWith(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.2),
      titleMedium: text.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
      bodyLarge: text.copyWith(fontSize: 15, height: 1.55, color: T.body),
      bodyMedium: text.copyWith(fontSize: 14, height: 1.55, color: T.body),
      bodySmall: text.copyWith(fontSize: 12, height: 1.45, color: T.muted),
      labelSmall: const TextStyle(
        fontFamily: T.mono,
        fontSize: 10,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w500,
        color: T.muted,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: T.bg,
      foregroundColor: T.ink,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: T.archivo,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: T.ink,
      ),
    ),
    dividerColor: T.ink,
  );
}
