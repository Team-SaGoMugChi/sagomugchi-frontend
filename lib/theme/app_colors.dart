import 'package:flutter/material.dart';

/// Centralized color tokens for Oddo.
///
/// Single source of truth for every color used across the app. Screens and
/// widgets must reference these tokens (never raw `Color(0x...)`), so that a
/// palette change happens in exactly one place.
///
/// 2026-10 prototype palette: warm ivory surfaces and chocolate actions.
abstract final class AppColors {
  AppColors._();

  // --- Brand / primary ---------------------------------------------------
  static const Color primary = Color(0xFF603E2B);
  static const Color disabled = Color(0xFFE4D3C0);
  static const Color primaryPressed = Color(0xFF44291C);

  /// Selected cards and secondary actions.
  static const Color primarySoft = Color(0xFFF2E9DF);

  /// Border for soft/selected cards.
  static const Color primarySoftBorder = Color(0xFFE5D3C3);

  // --- Auth / onboarding surfaces ---------------------------------------
  /// Shared warm-ivory canvas from the prototype.
  static const Color authBackground = Color(0xFFFBF7F1);

  /// Decorative cloud/blob tint layered on the auth background corners.
  static const Color cloud = Color(0xFFFBF7F1);

  /// Kakao brand yellow — used only for the Kakao login icon chip.
  static const Color kakao = Color(0xFFFEE500);

  // --- Surfaces / backgrounds -------------------------------------------
  static const Color background = Color(0xFFFBF7F1);

  /// Very light grey alternative background.
  static const Color backgroundAlt = Color(0xFFF4EEE8);
  static const Color surface = Color(0xFFFFFFFF);

  /// Dim overlay behind modals / bottom sheets.
  static const Color overlayDim = Color(0x80000000);

  // --- Video-call (dark) screens ----------------------------------------
  // Tutorial call practice / baseline measuring / Step1 speaking / counseling.
  static const Color callBackground = Color(0xFF1D1815);
  static const Color callSurface = Color(0xFF302720);
  static const Color callTextPrimary = Color(0xFFFFFFFF);
  static const Color callTextSecondary = Color(0xFFB9ADA2);

  // --- Text --------------------------------------------------------------
  static const Color textStrong = Color(0xFF302823);
  static const Color textPrimary = Color(0xFF43372F);
  static const Color textSecondary = Color(0xFF80736A);
  static const Color textTertiary = Color(0xFF9D9086);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // --- Lines -------------------------------------------------------------
  static const Color border = Color(0xFFE9DCD0);
  static const Color divider = Color(0xFFF0E6DD);

  // --- Semantic ----------------------------------------------------------
  static const Color success = Color(0xFF4F9775);
  static const Color warning = Color(0xFFBB8249);
  static const Color error = Color(0xFFC4483C);

  // --- Inactive (e.g. bottom tab) ---------------------------------------
  static const Color inactive = Color(0xFFA99B90);
}
