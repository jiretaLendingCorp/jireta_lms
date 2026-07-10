// lib/core/theme/mobile_theme.dart
// Fixed: both light and dark variants for rider and lender mobile themes.
// Previously _buildMobileTheme always used ThemeData.dark() regardless of
// the isDark flag, so dark mode had no visible effect on mobile themes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class MobileTheme {
  // ── Rider ─────────────────────────────────────────────────────────────────

  static ThemeData riderDark() => _buildMobileTheme(
        primaryColor: AppColors.riderAccent,
        gradientStart: AppColors.riderGradientStart,
        gradientEnd: AppColors.riderGradientEnd,
        isDark: true,
      );

  static ThemeData riderLight() => _buildMobileTheme(
        primaryColor: AppColors.riderAccent,
        gradientStart: AppColors.riderGradientStart,
        gradientEnd: AppColors.riderGradientEnd,
        isDark: false,
      );

  // Keep backwards-compat alias
  static ThemeData rider() => riderDark();

  // ── Lender ────────────────────────────────────────────────────────────────

  static ThemeData lenderDark() => _buildMobileTheme(
        primaryColor: AppColors.lenderAccent,
        gradientStart: AppColors.lenderGradientStart,
        gradientEnd: AppColors.lenderGradientEnd,
        isDark: true,
      );

  static ThemeData lenderLight() => _buildMobileTheme(
        primaryColor: AppColors.lenderAccent,
        gradientStart: AppColors.lenderGradientStart,
        gradientEnd: AppColors.lenderGradientEnd,
        isDark: false,
      );

  // Keep backwards-compat alias
  static ThemeData lender() => lenderDark();

  // ── Builder ───────────────────────────────────────────────────────────────

  static ThemeData _buildMobileTheme({
    required Color primaryColor,
    required Color gradientStart,
    required Color gradientEnd,
    required bool isDark,
  }) {
    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
    final textBase = isDark ? AppColors.glassText : const Color(0xFF1F2937);
    final textMuted = isDark ? AppColors.glassTextMuted : const Color(0xFF6B7280);

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: primaryColor,
        surface: Colors.transparent,
        onPrimary: Colors.white,
        onSurface: textBase,
        secondary: primaryColor.withValues(alpha: 0.7),
      ),
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.poppins(
          fontSize: 30, fontWeight: FontWeight.w700,
          color: textBase, height: 1.15, letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 24, fontWeight: FontWeight.w700,
          color: textBase, height: 1.2, letterSpacing: -0.4,
        ),
        displaySmall: GoogleFonts.poppins(
          fontSize: 20, fontWeight: FontWeight.w600,
          color: textBase, height: 1.3,
        ),
        headlineLarge: GoogleFonts.poppins(
          fontSize: 17, fontWeight: FontWeight.w600, color: textBase, height: 1.4,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 15, fontWeight: FontWeight.w600, color: textBase, height: 1.4,
        ),
        headlineSmall: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w500, color: textBase,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 15, fontWeight: FontWeight.w400, color: textBase, height: 1.6,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 13, fontWeight: FontWeight.w400, color: textMuted, height: 1.5,
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 12, fontWeight: FontWeight.w400, color: textMuted,
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 15, fontWeight: FontWeight.w600, color: textBase,
        ),
        labelMedium: GoogleFonts.poppins(
          fontSize: 13, fontWeight: FontWeight.w500, color: textMuted,
        ),
        labelSmall: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w600,
          letterSpacing: 0.3, color: textMuted,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: primaryColor.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 17),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : const Color(0xFF1F2937),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.3)
                : const Color(0xFFD1D5DB),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.09)
            : Colors.white.withValues(alpha: 0.65),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.18)
                : const Color(0xFFD1D5DB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.18)
                : const Color(0xFFD1D5DB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        hintStyle: GoogleFonts.poppins(
          color: isDark
              ? Colors.white.withValues(alpha: 0.35)
              : const Color(0xFF9CA3AF),
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.poppins(
          color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF374151),
          fontSize: 14,
        ),
        floatingLabelStyle: GoogleFonts.poppins(
          color: primaryColor, fontSize: 13, fontWeight: FontWeight.w500,
        ),
        errorStyle: GoogleFonts.poppins(
          color: const Color(0xFFFF6B6B), fontSize: 12,
        ),
        prefixIconColor: isDark
            ? Colors.white.withValues(alpha: 0.5)
            : const Color(0xFF9CA3AF),
        suffixIconColor: isDark
            ? Colors.white.withValues(alpha: 0.5)
            : const Color(0xFF9CA3AF),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18, fontWeight: FontWeight.w600,
          color: textBase, letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: textBase, size: 22),
      ),
      iconTheme: IconThemeData(color: textBase, size: 22),
      dividerTheme: DividerThemeData(
        color: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFFE5E7EB),
        thickness: 1,
        space: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : primaryColor.withValues(alpha: 0.08),
        labelStyle: GoogleFonts.poppins(
          fontSize: 12,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : const Color(0xFFD1D5DB),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: isDark
            ? Colors.white.withValues(alpha: 0.7)
            : const Color(0xFF6B7280),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w500, color: textBase,
        ),
        subtitleTextStyle: GoogleFonts.poppins(
          fontSize: 12, color: textMuted,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: primaryColor,
        unselectedItemColor: isDark
            ? Colors.white.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.35),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 10, fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 10, fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}