import 'package:flutter/material.dart';
import 'package:oons/core/tokens.dart' as core;

/// Ops Console v2 palette — from Oons Ops Console v2 design.
class T {
  static const bg = Color(0xFFF3EEE7);
  static const surface = Color(0xFFFDFBF7);
  static const sand = Color(0xFFEFE8DD);
  static const line = Color(0xFFE0D5C6);
  static const lineStrong = Color(0xFFDCCFBE);
  static const ink = Color(0xFF2E2530);
  static const body = Color(0xFF4A2E45);
  static const muted = Color(0xFF7C6E7A);
  static const mutedSoft = Color(0xFFA79A8B);

  /// Sidebar / primary action (design #3B2138).
  static const action = Color(0xFF3B2138);
  static const actionPressed = Color(0xFF2E1C2B);
  static const actionSoft = Color(0xFF54334D);
  static const sidebar = Color(0xFF3B2138);
  static const sidebarText = Color(0xFFEFE4EC);
  static const sidebarMuted = Color(0xFFA691A2);
  static const sidebarIdle = Color(0xFFCBB8C6);
  static const sidebarGroup = Color(0xFF9A849A);

  static const trust = Color(0xFF7FAE7F);
  static const trustInk = Color(0xFF3D5A3E);
  static const trustTint = Color(0xFFE4EDE2);
  static const trustBright = Color(0xFF8DBF8D);
  static const plum = Color(0xFF8E7B93);
  static const plumTint = Color(0xFFEFE4EC);
  static const plumInk = Color(0xFF5A3552);
  static const warm = Color(0xFFC1735A);
  static const warmTint = Color(0xFFF7E2DC);
  static const warmInk = Color(0xFF8E3D26);
  static const pending = Color(0xFFB8862F);
  static const pendingTint = Color(0xFFF6ECD3);
  static const pendingInk = Color(0xFF7A5A16);
  static const danger = Color(0xFFC1735A);
  static const dangerTint = Color(0xFFF7E2DC);
  static const blueTint = Color(0xFFE3E8EF);
  static const blueInk = Color(0xFF3A4A60);
  static const white = Color(0xFFFFFFFF);
  static const chef = Color(0xFFB58A52);
  static const childcare = Color(0xFF81758B);

  static const rule = 1.0;
  static const radius = 12.0;
  static const radiusSm = 10.0;
  static const radiusLg = 16.0;
  static const sidebarWidth = 246.0;
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

  /// Latin UI (design uses IBM Plex Sans; Archivo ships for EN).
  static const archivo = core.T.archivo;
  static const arabic = core.T.arabic;
  static const mono = core.T.mono;
}

ThemeData opsTheme() {
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
      error: T.warmInk,
    ),
    textTheme: TextTheme(
      displayLarge: text.copyWith(fontSize: 28, fontWeight: FontWeight.w700, height: 1.12, letterSpacing: -0.4),
      headlineMedium: text.copyWith(fontSize: 22, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.2),
      titleLarge: text.copyWith(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: text.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: text.copyWith(fontSize: 15, height: 1.55, color: T.body),
      bodyMedium: text.copyWith(fontSize: 14, height: 1.55, color: T.body),
      bodySmall: text.copyWith(fontSize: 12, height: 1.45, color: T.muted),
      labelSmall: const TextStyle(
        fontFamily: T.mono,
        fontSize: 10,
        letterSpacing: 1.1,
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
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: T.ink,
      ),
    ),
    dividerColor: T.line,
    cardColor: T.surface,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: T.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(T.radiusSm), borderSide: const BorderSide(color: T.lineStrong)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.radiusSm), borderSide: const BorderSide(color: T.lineStrong)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.radiusSm), borderSide: const BorderSide(color: T.action, width: 1.4)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: T.action,
        foregroundColor: T.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.radiusSm)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: T.action,
        foregroundColor: T.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.radiusSm)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: T.action,
    ),
  );
}
