import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    final base = ThemeData.dark();

    // ── Outfit type scale ──────────────────────────────────────────────────
    final textTheme = GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
      displayLarge:  GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1.0, color: AppColors.textPrimary),
      displayMedium: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.textPrimary),
      headlineLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      headlineMedium: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: AppColors.textPrimary),
      headlineSmall: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleLarge:    GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.2, color: AppColors.textPrimary),
      titleMedium:   GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleSmall:    GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
      bodyLarge:     GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      bodyMedium:    GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      bodySmall:     GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textMuted),
      labelLarge:    GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.textPrimary),
      labelMedium:   GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: AppColors.textSecondary),
      labelSmall:    GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.textSecondary),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.goldMid,
        brightness: Brightness.dark,
        surface: AppColors.bg1,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.bg0,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: null,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.bg1,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
