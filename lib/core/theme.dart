import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Mehta Restaurant';
  static const String currencySymbol = '₹';
  static const String defaultFloor = 'Ground Floor • Main Hall';
  static const int totalTables = 10;
  static const int tableCapacity = 6;
}

class AppColors {
  // Warm Culinary Brand Palette
  static const Color primary = Color(0xFFD94A26); // Rich appetizing terracotta
  static const Color primaryDark = Color(0xFFA53013);
  static const Color primaryLight = Color(0xFFFBECE8);
  static const Color secondary = Color(0xFF1E242B); // Deep charcoal slate
  static const Color accent = Color(0xFFF5A623); // Golden saffron amber
  static const Color accentLight = Color(0xFFFFF6E5);

  // Status Colors
  static const Color statusAvailable = Color(0xFF1B8754); // Fresh emerald green
  static const Color statusAvailableBg = Color(0xFFE8F6ED);
  static const Color statusOccupied = Color(0xFFDC3545);  // Ruby red
  static const Color statusOccupiedBg = Color(0xFFFDECEE);
  static const Color statusBilling = Color(0xFFFD7E14);   // Amber orange
  static const Color statusBillingBg = Color(0xFFFFF1E6);
  static const Color statusKOT = Color(0xFF0D6EFD);       // Royal blue
  static const Color statusKOTBg = Color(0xFFE7F0FF);

  // Neutrals
  static const Color background = Color(0xFFF5F6F8);
  static const Color surface = Colors.white;
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF191D24);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderSubtle = Color(0xFFF0F1F3);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}
