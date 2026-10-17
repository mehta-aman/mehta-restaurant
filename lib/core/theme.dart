import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConstants {
  static const String appName = 'Mehta Restaurant';
  static const String currencySymbol = '₹';
  static const String defaultFloor = 'Ground Floor • Main Hall';
  static const int totalTables = 10;
  static const int tableCapacity = 6;
}

class AppColors {
  // Primary Accent & Restaurant Orange
  static const Color primary = Color(0xFFF7931E); // Restaurant Orange
  static const Color primaryDark = Color(0xFFE67E12); // Orange hover / darker variant
  static const Color primaryLight = Color(0xFFFFF3E5); // Pale orange background
  static const Color secondary = Color(0xFF202124); // Dark charcoal navigation
  static const Color secondaryDark = Color(0xFF171819); // Darker navigation
  static const Color accent = Color(0xFFF7931E);
  static const Color accentLight = Color(0xFFFFF3E5);

  // Main Backgrounds & Surfaces
  static const Color background = Color(0xFFF7F7F5); // Warm white / soft neutral application background
  static const Color surface = Colors.white; // Primary surface
  static const Color surfaceCard = Colors.white;
  static const Color surfaceSecondary = Color(0xFFF1F2F0); // Secondary surface

  // Navigation
  static const Color navBg = Color(0xFF202124); // Dark charcoal
  static const Color navBgDarker = Color(0xFF171819);
  static const Color navActiveBg = Color(0xFFF7931E); // Active navigation background

  // Text
  static const Color textPrimary = Color(0xFF242424); // Primary text
  static const Color textSecondary = Color(0xFF777777); // Secondary text
  static const Color textMuted = Color(0xFF9A9A9A); // Muted text
  static const Color textOnDark = Colors.white;

  // Borders
  static const Color border = Color(0xFFE8E8E5); // Default border
  static const Color borderStrong = Color(0xFFDADAD5); // Stronger border
  static const Color borderSubtle = Color(0xFFF1F2F0);

  // Semantic Status Colors (Consistent Across Floor, Orders, and Ledger)
  static const Color statusAvailable = Color(0xFF43A66B); // Available / success
  static const Color statusAvailableBg = Color(0xFFEAF7EE);
  static const Color statusOccupied = Color(0xFFEA5145); // Occupied / danger
  static const Color statusOccupiedBg = Color(0xFFFDEEEE);
  static const Color statusBilling = Color(0xFFF2AD35); // Bill requested / warning
  static const Color statusBillingBg = Color(0xFFFEF6E7);
  static const Color statusCleaning = Color(0xFF4D85D9); // Cleaning / info
  static const Color statusCleaningBg = Color(0xFFEEF5FD);
  static const Color statusKOT = Color(0xFF4D85D9);
  static const Color statusKOTBg = Color(0xFFEEF5FD);

  // Dark Mode Palette
  static const Color darkBackground = Color(0xFF141517);
  static const Color darkCard = Color(0xFF1E2024);
  static const Color darkSurface = Color(0xFF181A1D);
  static const Color darkBorder = Color(0xFF2E3136);
  static const Color darkBorderSubtle = Color(0xFF222428);
  static const Color darkTextPrimary = Color(0xFFF5F5F7);
  static const Color darkTextSecondary = Color(0xFFA0A3A8);

  // Context-Aware Dynamic Colors
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
  static Color dynamicBg(BuildContext context) => isDark(context) ? darkBackground : background;
  static Color dynamicCard(BuildContext context) => isDark(context) ? darkCard : surfaceCard;
  static Color dynamicBorder(BuildContext context) => isDark(context) ? darkBorder : border;
  static Color dynamicText(BuildContext context) => isDark(context) ? darkTextPrimary : textPrimary;
  static Color dynamicTextMuted(BuildContext context) => isDark(context) ? darkTextSecondary : textSecondary;
  static Color dynamicStatusAvailBg(BuildContext context) => isDark(context) ? const Color(0xFF0F3B20) : statusAvailableBg;
  static Color dynamicStatusOccBg(BuildContext context) => isDark(context) ? const Color(0xFF421515) : statusOccupiedBg;
  static Color dynamicStatusBillBg(BuildContext context) => isDark(context) ? const Color(0xFF3E2805) : statusBillingBg;
  static Color dynamicStatusCleanBg(BuildContext context) => isDark(context) ? const Color(0xFF0E2A54) : statusCleaningBg;
}

// --- RIVERPOD THEME MODE STATE NOTIFIER ---
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void toggleTheme() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class AppTheme {
  // LIGHT JOYFUL THEME
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.surfaceCard,
      dividerColor: AppColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.borderSubtle,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
        indicatorColor: AppColors.primary,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        selectedLabelTextStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelTextStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 13),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primaryLight,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary);
          }
          return const IconThemeData(color: AppColors.textSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12);
          }
          return const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 12);
        }),
      ),
    );
  }

  // DARK JOYFUL THEME
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: const Color(0xFFFF7043),
        secondary: const Color(0xFF94A3B8),
        surface: AppColors.darkCard,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      cardColor: AppColors.darkCard,
      dividerColor: AppColors.darkBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkCard,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF7043),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkTextPrimary,
          side: const BorderSide(color: AppColors.darkBorder, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1E293B),
        side: const BorderSide(color: AppColors.darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF7043), width: 2),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.darkCard,
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme: const IconThemeData(color: AppColors.darkTextSecondary),
        indicatorColor: const Color(0xFFFF7043),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        selectedLabelTextStyle: const TextStyle(color: Color(0xFFFF7043), fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelTextStyle: const TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w500, fontSize: 13),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkCard,
        indicatorColor: const Color(0xFF334155),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFFFF7043));
          }
          return const IconThemeData(color: AppColors.darkTextSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: Color(0xFFFF7043), fontWeight: FontWeight.bold, fontSize: 12);
          }
          return const TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w500, fontSize: 12);
        }),
      ),
    );
  }
}
