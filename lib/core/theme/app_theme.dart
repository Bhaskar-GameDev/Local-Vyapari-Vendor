import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_radius.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.8,
        shadowColor: AppColors.border,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Poppins').copyWith(
        displayLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        displayMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        headlineLarge: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleMedium: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        bodyLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
        bodyMedium: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
        labelLarge: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
        bodySmall: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textHint),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMedium),
          textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMedium),
          textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        hintStyle: const TextStyle(fontFamily: 'Poppins', color: AppColors.textHint, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: AppRadius.borderMedium, borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.borderMedium, borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.borderMedium, borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: AppRadius.borderMedium, borderSide: const BorderSide(color: AppColors.error)),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.8), width: 0.7),
        ),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        contentTextStyle: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 0.7),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.accent : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.accent.withValues(alpha: 0.35) : null),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryLight,
        secondary: AppColors.accent,
        surface: Color(0xFF1A1A2E),
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F0F1A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A2E),
        elevation: 0,
        scrolledUnderElevation: 0.8,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Poppins').copyWith(
        displayLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
        displayMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
        headlineLarge: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
        titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        titleMedium: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.white),
        bodyMedium: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.white70),
        labelLarge: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryLight),
        bodySmall: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Colors.white38),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMedium),
          textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMedium),
          textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E2E),
        hintStyle: const TextStyle(fontFamily: 'Poppins', color: Colors.white38, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: AppRadius.borderMedium, borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.borderMedium, borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.borderMedium, borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: AppRadius.borderMedium, borderSide: const BorderSide(color: AppColors.error)),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A2E),
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10, width: 0.7),
        ),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        contentTextStyle: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(color: Colors.white10, thickness: 0.7),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.accent : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.accent.withValues(alpha: 0.35) : null),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1A1A2E),
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
