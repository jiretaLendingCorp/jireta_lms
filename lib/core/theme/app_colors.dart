// lib/core/theme/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  // ── Brand ───────────────────────────────────────────────────────────────────
  static const Color accent       = Color(0xFF5B4FE9);
  static const Color accentLight  = Color(0xFF7B71EF);
  static const Color accentDark   = Color(0xFF3D33C5);
  static const Color accentSoft   = Color(0xFFEEECFD); // 8% opacity bg for light
  static const Color accentSoftDk = Color(0xFF1E1A3A); // dark mode soft bg

  // ── Web Surfaces (Light) ────────────────────────────────────────────────────
  static const Color webBgLight       = Color(0xFFF4F5F8);
  static const Color webSurfaceLight  = Color(0xFFFFFFFF);
  static const Color webSidebarLight  = Color(0xFFFFFFFF);
  static const Color webHeaderLight   = Color(0xFFFFFFFF);
  static const Color webBorderLight   = Color(0xFFE9EAED);
  static const Color webBorderSoftL   = Color(0xFFF0F1F4);

  // ── Web Surfaces (Dark) ─────────────────────────────────────────────────────
  static const Color webBgDark        = Color(0xFF0C0E14);
  static const Color webSurfaceDark   = Color(0xFF141720);
  static const Color webSidebarDark   = Color(0xFF141720);
  static const Color webHeaderDark    = Color(0xFF141720);
  static const Color webBorderDark    = Color(0xFF262A38);
  static const Color webBorderSoftDk  = Color(0xFF1C1F2C);

  // ── Text (Light) ────────────────────────────────────────────────────────────
  static const Color textPrimaryLight   = Color(0xFF0F1117);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textTertiaryLight  = Color(0xFF9CA3AF);

  // ── Text (Dark) ─────────────────────────────────────────────────────────────
  static const Color textPrimaryDark    = Color(0xFFF0F2F8);
  static const Color textSecondaryDark  = Color(0xFF8B92A5);
  static const Color textTertiaryDark   = Color(0xFF5A6077);

  // ── Semantic ────────────────────────────────────────────────────────────────
  static const Color success    = Color(0xFF10B981);
  static const Color successSoft = Color(0xFFECFDF5);
  static const Color warning    = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFFFBEB);
  static const Color error      = Color(0xFFEF4444);
  static const Color errorSoft  = Color(0xFFFEF2F2);
  static const Color info       = Color(0xFF3B82F6);
  static const Color infoSoft   = Color(0xFFEFF6FF);

  // ── Status Badges ───────────────────────────────────────────────────────────
  static const Color statusActive      = Color(0xFF10B981);
  static const Color statusPending     = Color(0xFFF59E0B);
  static const Color statusRejected    = Color(0xFFEF4444);
  static const Color statusCompleted   = Color(0xFF6B7280);
  static const Color statusDefaulted   = Color(0xFFDC2626);
  static const Color statusUnderReview = Color(0xFF3B82F6);
  static const Color statusApproved    = Color(0xFF059669);
  static const Color statusDisbursed   = Color(0xFF8B5CF6);

  // ── Mobile / Glass ──────────────────────────────────────────────────────────
  static const Color riderGradientStart = Color(0xFF0A0F2E); // deep navy
  static const Color riderGradientMid   = Color(0xFF0D2060); // rich blue
  static const Color riderGradientEnd   = Color(0xFF1A3A8A); // medium blue
  static const Color riderAccent        = Color(0xFF38BDF8); // sky blue

  static const Color lenderGradientStart = Color(0xFF050D2A); // midnight blue
  static const Color lenderGradientMid   = Color(0xFF0F1F6B); // deep royal blue
  static const Color lenderGradientEnd   = Color(0xFF1E3FAA); // vivid blue
  static const Color lenderAccent        = Color(0xFF818CF8); // indigo-blue

  static const Color glassWhite    = Color(0x14FFFFFF); // 8%
  static const Color glassBorder   = Color(0x26FFFFFF); // 15%
  static const Color glassText     = Color(0xFFFFFFFF);
  static const Color glassTextMuted = Color(0xB3FFFFFF); // 70%

  // ── Shadows ──────────────────────────────────────────────────────────────────
  static const Color shadowLight = Color(0x0A000000);
  static const Color shadowMd    = Color(0x12000000);
  static const Color shadowDark  = Color(0x1F000000);

  // ── Chart Palette ────────────────────────────────────────────────────────────
  static const List<Color> chartPalette = [
    accent,
    success,
    warning,
    info,
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
  ];
}