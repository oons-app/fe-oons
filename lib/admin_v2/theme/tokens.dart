import 'package:flutter/material.dart';

/// Ops Console v2 design tokens (from `Oons Ops Console v2.html`).
///
/// Colours, radii, type families and motion are lifted verbatim from the
/// standalone design export so the Flutter console renders pixel-close to the
/// prototype. Keep this file the single source — screens must not hard-code hex.
abstract final class Ops {
  // Surfaces ---------------------------------------------------------------
  static const page = Color(0xFFF3EEE7); // app background / cream
  static const card = Color(0xFFFDFBF7); // primary card
  static const cardAlt = Color(0xFFFFFDFA); // inset / nested card
  static const panelSand = Color(0xFFF6EFE6); // SLA + info strips
  static const panelSandBorder = Color(0xFFE3D3BC);
  static const wellSand = Color(0xFFF6F1E9); // address / summary wells
  static const rowHover = Color(0xFFF8F3EB);
  static const headBg = Color(0xFFF2EADF); // table header row
  static const rowBorder = Color(0xFFF0E9DE); // table row divider

  // Ink ------------------------------------------------------------------
  static const ink = Color(0xFF2E2530);
  static const inkSoft = Color(0xFF5C4F5A);
  static const muted = Color(0xFF7C6E7A);
  static const mutedSoft = Color(0xFF8C7F8A);
  static const faint = Color(0xFF9C8E9A);
  static const placeholder = Color(0xFFA79A8B);

  // Borders ------------------------------------------------------------
  static const border = Color(0xFFE0D5C6);
  static const borderSoft = Color(0xFFEBE2D6);
  static const borderStrong = Color(0xFFDCCFBE);

  // Plum (sidebar / dark bars) --------------------------------------------
  static const plum = Color(0xFF3B2138);
  static const plumActive = Color(0xFF54334D);
  static const plumField = Color(0xFF4A2A43);
  static const plumText = Color(0xFFEFE4EC);
  static const plumTextSoft = Color(0xFFF1E8EE);
  static const plumInk = Color(0xFF4A2E45);
  static const plumMuted = Color(0xFFA691A2);
  static const plumFaint = Color(0xFF9A849A);
  static const navIdle = Color(0xFFCBB8C6);
  static const creamTile = Color(0xFFF7F0EA);

  // Tone chips (mirror prototype TONES) ---------------------------------
  static const green = Color(0xFF7FAE7F);
  static const greenInk = Color(0xFF3D5A3E);
  static const greenTint = Color(0xFFE4EDE2);
  static const gold = Color(0xFFB8862F);
  static const goldInk = Color(0xFF7A5A16);
  static const goldTint = Color(0xFFF6ECD3);
  static const terracotta = Color(0xFFC1735A);
  static const terracottaInk = Color(0xFF8E3D26);
  static const terracottaTint = Color(0xFFF7E2DC);
  static const plumChip = Color(0xFFEFE4EC);
  static const plumChipInk = Color(0xFF5A3552);
  static const blueInk = Color(0xFF3A4A60);
  static const blueTint = Color(0xFFE3E8EF);
  static const greyTint = Color(0xFFEEE8DE);
  static const greyInk = Color(0xFF5F5560);

  // Impersonate button surface -----------------------------------------
  static const impBg = Color(0xFFF8EDE7);
  static const impBorder = Color(0xFFD9C4B8);

  // Chart / bar palette ----------------------------------------------
  static const barConfirmed = Color(0xFF8E7B93);
  static const barProgress = Color(0xFF5A7FA8);
  static const barCompleted = Color(0xFF6E8B6E);
  static const barPending = Color(0xFFB8862F);
  static const barCancelled = Color(0xFFC1735A);
  static const barIdle = Color(0xFFE3DACD);
  static const track = Color(0xFFEDE4D8);

  // Geometry -----------------------------------------------------------
  static const sidebarW = 246.0;
  static const contentMax = 1180.0;
  static const radiusCard = 15.0;
  static const radiusCtl = 10.0;
  static const radiusBtn = 9.0;
  static const radiusNav = 9.0;
  static const radiusModal = 16.0;
  static const radiusPill = 999.0;

  static const gutter = 24.0; // main horizontal padding
  static const gap = 16.0; // section gap

  // Type -------------------------------------------------------------
  static const sans = 'IBMPlexSansArabic';
  static const mono = 'IBMPlexMono';

  // Motion ---------------------------------------------------------
  static const dFast = Duration(milliseconds: 160);
  static const dBar = Duration(milliseconds: 200);
  static const dToast = Duration(milliseconds: 2600);
  static const refreshEvery = Duration(seconds: 30);
}
