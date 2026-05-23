import 'package:flutter/material.dart';

class AppColors {
  // Primary & Accents (Derived directly from the "Local Vyapari" Logo)
  static const Color primary = Color(0xFF112E51);      // Navy Blue ("LOCAL")
  static const Color primaryLight = Color(0xFF3B5D8C); // Lighter Navy
  static const Color primaryDark = Color(0xFF0B1F38);  // Darker Navy
  static const Color accent = Color(0xFF5C8E32);       // Grass Green ("VYAPARI")
  
  // Backgrounds & Surfaces
  static const Color background = Color(0xFFF8FAFC);   // Slate 50 (Very clean off-white)
  static const Color surface = Colors.white;
  static const Color surfaceElevated = Color(0xFFF1F5F9); // Slate 100

  // Text
  static const Color textPrimary = Color(0xFF0F172A);  // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textHint = Color(0xFF94A3B8);      // Slate 400

  // Status
  static const Color success = Color(0xFF5C8E32);      // Brand Green
  static const Color error = Color(0xFFEF4444);        // Red 500
  static const Color warning = Color(0xFFF59E0B);      // Amber 500
  static const Color info = Color(0xFF3B82F6);         // Blue 500

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);       // Slate 200
  static const Color divider = Color(0xFFF1F5F9);      // Slate 100
}
