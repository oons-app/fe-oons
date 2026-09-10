import 'package:flutter/material.dart';
import 'package:oons/admin_v2/theme/tokens.dart';

ThemeData opsV2Theme({required bool arabic}) {
  final base = ThemeData(
    useMaterial3: false,
    brightness: Brightness.light,
    fontFamily: Ops.sans,
    scaffoldBackgroundColor: Ops.page,
    primaryColor: Ops.plum,
    colorScheme: const ColorScheme.light(
      primary: Ops.plum,
      secondary: Ops.green,
      surface: Ops.card,
      error: Ops.terracottaInk,
      onPrimary: Ops.plumText,
      onSurface: Ops.ink,
    ),
    dividerColor: Ops.border,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Ops.ink, fontSize: 14, height: 1.45),
      titleMedium: TextStyle(color: Ops.ink, fontSize: 16, fontWeight: FontWeight.w700),
      labelSmall: TextStyle(color: Ops.muted, fontSize: 11, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Ops.cardAlt,
      contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Ops.radiusCtl),
        borderSide: const BorderSide(color: Ops.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Ops.radiusCtl),
        borderSide: const BorderSide(color: Ops.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Ops.radiusCtl),
        borderSide: const BorderSide(color: Ops.plum, width: 1.4),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Ops.plum,
        foregroundColor: Ops.plumText,
        elevation: 0,
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, fontFamily: Ops.sans),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 15, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ops.radiusBtn)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Ops.plum,
      contentTextStyle: const TextStyle(color: Ops.plumTextSoft, fontSize: 12.5, fontFamily: Ops.sans),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Ops.plum,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 8),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Ops.plum : null),
    ),
  );
  return base;
}
