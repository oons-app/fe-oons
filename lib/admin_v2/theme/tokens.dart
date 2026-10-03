import 'package:flutter/material.dart';
import 'package:oons/ds/tokens.dart';

/// Ops Console tokens — the Ons design system (`lib/ds`) under the names the
/// console already uses.
///
/// There is no palette of its own here any more: every colour resolves to a
/// [Ds] value, every corner is square and every border is the system's 1px
/// ink rule. Screens must not hard-code hex or radii; `test/ds_test.dart`
/// fails if a token below drifts from [Ds].
///
/// Tone mapping (the console keeps its six tones, the system has three
/// meanings): ok → olive · warn/bad → terracotta (needs attention) ·
/// plum/info → plum-light / neutral. The label always says what the colour means.
abstract final class Ops {
  // Surfaces ---------------------------------------------------------------
  static const page = Ds.cream; // app background
  static const card = Ds.white; // cards, fields, tables
  static const cardAlt = Ds.white; // nested card
  static const panelSand = Ds.surface; // SLA + info strips
  static const panelSandBorder = Ds.divider;
  static const wellSand = Ds.surface; // address / summary wells
  static const rowHover = Ds.cream;
  static const headBg = Ds.surface; // table header row
  static const rowBorder = Ds.divider; // table row divider

  // Ink ------------------------------------------------------------------
  static const ink = Ds.ink;
  static const inkSoft = Ds.textBody;
  static const muted = Ds.textMuted;
  static const mutedSoft = Ds.textMuted;
  static const faint = Ds.textFaint;
  static const placeholder = Ds.textFaint;

  // Borders: one 1px ink rule; hairlines only between rows inside a card ----
  static const border = Ds.ink;
  static const borderSoft = Ds.divider;
  static const borderStrong = Ds.ink;
  static const rule = Ds.rule;

  // Plum (sidebar / dark bars) --------------------------------------------
  static const plum = Ds.plum;
  static const plumActive = Ds.plumPressed;
  static const plumField = Ds.plumPressed;
  static const plumText = Ds.cream;
  static const plumTextSoft = Ds.cream;
  static const plumInk = Ds.plum;
  // plum-light at 72 / 56 / 80 % — readable on the plum bar
  static const plumMuted = Color(0xB8F0E6EE);
  static const plumFaint = Color(0x8FF0E6EE);
  static const navIdle = Color(0xCCF0E6EE);
  static const plumHairline = Color(0x2EF0E6EE);
  static const creamTile = Ds.cream;

  // Tone chips ---------------------------------------------------------
  static const green = Ds.olive;
  static const greenInk = Ds.oliveText;
  static const greenTint = Ds.oliveTint;
  static const gold = Ds.terracotta;
  static const goldInk = Ds.terracottaText;
  static const goldTint = Ds.terracottaBg;
  static const terracotta = Ds.terracotta;
  static const terracottaInk = Ds.terracottaText;
  static const terracottaTint = Ds.terracottaBg;
  static const plumChip = Ds.plumLight;
  static const plumChipInk = Ds.plum;
  static const blueInk = Ds.textBody;
  static const blueTint = Ds.neutral;
  static const greyTint = Ds.neutral;
  static const greyInk = Ds.textBody;

  // Impersonate button surface -----------------------------------------
  static const impBg = Ds.terracottaBg;
  static const impBorder = Ds.terracotta;

  // Chart / bar palette ----------------------------------------------
  static const barConfirmed = Ds.plum;
  static const barProgress = Ds.textMuted;
  static const barCompleted = Ds.olive;
  static const barPending = Ds.terracotta;
  static const barCancelled = Ds.textFaint;
  static const barIdle = Ds.divider;
  static const track = Ds.surface;

  // Geometry -----------------------------------------------------------
  static const sidebarW = 246.0;
  static const contentMax = 1180.0;
  static const radiusCard = Ds.radius;
  static const radiusCtl = Ds.radius;
  static const radiusBtn = Ds.radius;
  static const radiusNav = Ds.radius;
  static const radiusModal = Ds.radius;
  static const radiusPill = Ds.radius;

  static const gutter = 24.0; // main horizontal padding
  static const gap = 16.0; // section gap

  /// A hit target is never smaller than this (the system's 44px).
  static const minTarget = Ds.minTarget;

  // Type -------------------------------------------------------------
  // The family comes from the theme (IBM Plex Sans Arabic / Archivo);
  // [mono] is for every number, id, price and time.
  static const sans = 'IBMPlexSansArabic';
  static const mono = 'IBMPlexMono';

  // Motion ---------------------------------------------------------
  static const dFast = Ds.dState;
  static const dBar = Duration(milliseconds: 200);
  static const dToast = Duration(milliseconds: 2600);
  static const refreshEvery = Duration(seconds: 30);

  /// The system's card: white, square, 1px ink border.
  static BoxDecoration cardBox({Color? color, Color? border}) => Ds.card(color: color, border: border);
}
