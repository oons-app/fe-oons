import 'package:flutter/material.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/core/tokens.dart';

/// Material theme for the console, on the Ons design system: square
/// everything, 1px ink borders, plum primary, no elevation.
ThemeData opsV2Theme({required bool arabic}) {
  const square = RoundedRectangleBorder(borderRadius: BorderRadius.zero);
  OutlineInputBorder field(Color c, [double w = Ops.rule]) =>
      OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: c, width: w));
  final family = arabic ? Ops.sans : T.archivo;
  return ThemeData(
    useMaterial3: false,
    brightness: Brightness.light,
    fontFamily: family,
    scaffoldBackgroundColor: Ops.page,
    primaryColor: Ops.plum,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Ops.plumChip,
    colorScheme: const ColorScheme.light(
      primary: Ops.plum,
      secondary: Ops.green,
      surface: Ops.card,
      error: Ops.terracottaInk,
      onPrimary: Ops.plumText,
      onSurface: Ops.ink,
    ),
    dividerColor: Ops.borderSoft,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Ops.ink, fontSize: 14, height: 1.45),
      titleMedium: TextStyle(color: Ops.ink, fontSize: 16, fontWeight: FontWeight.w700),
      labelSmall: TextStyle(color: Ops.muted, fontSize: 11, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Ops.card,
      contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 11),
      hintStyle: const TextStyle(color: Ops.placeholder),
      border: field(Ops.border),
      enabledBorder: field(Ops.border),
      disabledBorder: field(Ops.borderSoft),
      focusedBorder: field(Ops.plum, 2),
      errorBorder: field(Ops.terracotta),
      focusedErrorBorder: field(Ops.terracotta, 2),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Ops.plum,
        foregroundColor: Ops.plumText,
        disabledBackgroundColor: Ops.borderSoft,
        disabledForegroundColor: Ops.faint,
        elevation: 0,
        minimumSize: const Size(0, Ops.minTarget),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 18, vertical: 12),
        shape: square,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Ops.ink,
        minimumSize: const Size(0, Ops.minTarget),
        side: const BorderSide(color: Ops.border),
        shape: square,
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Ops.plum,
        minimumSize: const Size(0, 36),
        shape: square,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 8),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Ops.ink,
      contentTextStyle: TextStyle(color: Ops.plumText, fontSize: 13, fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: square,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Ops.card, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: Ops.border))),
    popupMenuTheme: const PopupMenuThemeData(color: Ops.card, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: Ops.border))),
    checkboxTheme: CheckboxThemeData(
      shape: square,
      side: const BorderSide(color: Ops.border, width: Ops.rule),
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Ops.plum : Ops.card),
      checkColor: const WidgetStatePropertyAll(Ops.plumText),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Ops.card),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Ops.plum : Ops.track),
      trackOutlineColor: const WidgetStatePropertyAll(Ops.border),
    ),
    radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Ops.plum : Ops.ink)),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(color: Ops.ink),
      textStyle: TextStyle(color: Ops.plumText, fontSize: 12),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Ops.plum, linearTrackColor: Ops.track),
    dataTableTheme: const DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(Ops.headBg),
      dividerThickness: 1,
    ),
  );
}
