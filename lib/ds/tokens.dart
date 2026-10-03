import 'package:flutter/material.dart';
import 'package:oons/core/tokens.dart';

/// Ons design system — tokens.
///
/// One source of truth for colour, shape, type and spacing. Screens never hard-code
/// a hex, a radius or a font size: they read it from here (or from a `Ds*`
/// component that already does). The palette is the one the customer app uses
/// (`T` / `Client`); `test/ds_test.dart` fails if the two ever drift apart.
class Ds {
  Ds._();

  // ── Colour ────────────────────────────────────────────────────────────────
  /// Screen background.
  static const cream = Color(0xFFF7F4EE);

  /// Inner boxes, time column, icon tiles, "off" tracks.
  static const surface = Color(0xFFEFE9E2);

  /// Cards and fields.
  static const white = Color(0xFFFFFFFF);

  /// Text and primary 1px borders.
  static const ink = Color(0xFF1C1518);

  /// Primary, selected, main button.
  static const plum = Color(0xFF3E2136);
  static const plumPressed = Color(0xFF2A1622);

  /// Selected background, tags.
  static const plumLight = Color(0xFFF0E6EE);

  /// Safe / done / verified only.
  static const olive = Color(0xFF6B7355);
  static const oliveText = Color(0xFF4E5540);
  static const oliveLight = Color(0xFFB9C19F); // check mark on ink (toast)
  static const oliveTint = Color(0xFFE8EBE3); // soft safe background

  /// Needs attention only — never decoration.
  static const terracotta = Color(0xFFB5654B);
  static const terracottaBg = Color(0xFFF6E7E1);
  static const terracottaText = Color(0xFF8E4B36);

  /// Neutral tag fill (cancelled / draft).
  static const neutral = Color(0xFFEDE6E0);

  /// Inner row dividers.
  static const divider = Color(0xFFDCD4CC);

  static const textBody = Color(0xFF4A3F45);
  static const textMuted = Color(0xFF6E655F);
  static const textFaint = Color(0xFF9A928C);

  /// Modal scrim: ink at 42%.
  static const scrim = Color(0x6B1C1518);

  // ── Shape ─────────────────────────────────────────────────────────────────
  /// Every corner in the product is square.
  static const radius = 0.0;
  static const rule = 1.0;

  /// A hit target is never smaller than this.
  static const minTarget = 44.0;
  static const buttonHeight = 54.0;
  static const buttonHeightCompact = 46.0;
  static const rowHeight = 56.0;

  // ── Space ─────────────────────────────────────────────────────────────────
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;

  /// Horizontal page gutter.
  static const gutter = 20.0;

  // ── Motion ────────────────────────────────────────────────────────────────
  static const dState = Duration(milliseconds: 160);
  static const toastLife = Duration(milliseconds: 1800);

  // ── Decorations ───────────────────────────────────────────────────────────
  /// White card with the primary 1px ink border.
  static BoxDecoration card({Color? color, Color? border}) =>
      BoxDecoration(color: color ?? white, border: Border.all(color: border ?? ink, width: rule));

  /// Hairline between rows inside a card.
  static const dividerSide = BorderSide(color: divider, width: rule);
}

/// Ons design system — type.
///
/// Families come from the ambient theme (IBM Plex Sans Arabic in Arabic,
/// Archivo in English). Numbers are the exception: always IBM Plex Mono
/// ([DsText.num]).
class DsText {
  DsText._();

  static const _base = TextStyle(color: Ds.ink, height: 1.3);

  static TextStyle get screenTitle => _base.copyWith(fontSize: 30, fontWeight: FontWeight.w700, height: 1.2);
  static TextStyle get subTitle => _base.copyWith(fontSize: 26, fontWeight: FontWeight.w700, height: 1.2);
  static TextStyle get section => _base.copyWith(fontSize: 16, fontWeight: FontWeight.w700);
  static TextStyle get itemName => _base.copyWith(fontSize: 15, fontWeight: FontWeight.w700);
  static TextStyle get body => _base.copyWith(fontSize: 13.5, fontWeight: FontWeight.w400, color: Ds.textBody, height: 1.5);
  static TextStyle get meta => _base.copyWith(fontSize: 12.5, fontWeight: FontWeight.w400, color: Ds.textMuted, height: 1.4);
  static TextStyle get hint => _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: Ds.textFaint, height: 1.4);
  static TextStyle get button => _base.copyWith(fontSize: 16, fontWeight: FontWeight.w700);

  /// Numbers, prices, times, counts: IBM Plex Mono.
  static TextStyle num({double size = 14, FontWeight weight = FontWeight.w500, Color color = Ds.ink}) =>
      TextStyle(fontFamily: T.mono, fontSize: size, fontWeight: weight, color: color, height: 1.2);
}
