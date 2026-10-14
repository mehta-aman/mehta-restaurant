import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Mehta Restaurant';
  static const String currencySymbol = '₹';
  static const String defaultFloor = 'Main Hall';
  static const int totalTables = 10;
  static const int tableCapacity = 6;
}

class AppColors {
  // Brand palette
  static const Color primary = Color(0xFFC84B31); // Warm terracotta / restaurant red
  static const Color primaryDark = Color(0xFF992E18);
  static const Color primaryLight = Color(0xFFFAEDE8);
  static const Color secondary = Color(0xFF2D4059); // Deep slate navy
  static const Color accent = Color(0xFFFFB26B); // Warm amber
  
  // Status Colors
  static const Color statusAvailable = Color(0xFF2E7D32); // Emerald Green
  static const Color statusOccupied = Color(0xFFD32F2F);  // Crimson Red
  static const Color statusBilling = Color(0xFFF57C00);   // Amber Orange
  static const Color statusKOT = Color(0xFF1976D2);       // Royal Blue

  // Neutrals
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF757575);
  static const Color border = Color(0xFFE0E0E0);
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
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }
}
