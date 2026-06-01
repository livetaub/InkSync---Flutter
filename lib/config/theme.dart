import 'package:flutter/material.dart';

/// App Theme Configuration - Million-Dollar Design System (Evernote & Listonic Inspired)
class AppTheme {
  // Brand Colors
  static const Color primaryColor = Color(0xFF05D07D); // Vibrant Emerald Green from Reference
  static const Color primaryLight = Color(0xFF07E78C);
  static const Color primarySubtle = Color(0x1405D07D); // 8% opacity
  static const Color inkBlue = Color(0xFF1E88E5); // Vibrant Blue for accents
  static const Color selectionBlue = Color(0xFF3B82F6); // Blue for sidebar selection

  // Neutral Colors - Light Mode
  static const Color bgPrimary = Color(0xFFF5F7F9); // Very light grey/white
  static const Color surfaceSidebar = Color(0xFF121417); // Deeper Dark Sidebar
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF4A4A4A);
  static const Color textMuted = Color(0xFF757575);
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderSelection = Color(0xFF00A82D);

  // Neutral Colors - Dark Mode
  static const Color bgPrimaryDark = Color(0xFF0E1111);
  static const Color surfaceDark = Color(0xFF1C1F1F);
  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textMutedDark = Color(0xFF707070);

  // Functional Colors
  static const Color success = Color(0xFF00A82D);
  static const Color error = Color(0xFFD92D20);

  // Note Palettes (Header/Darker Accent Colors for light mode)
  static const Map<String, Color> noteColors = {
    'yellow': Color(0xFFFDE68A),
    'green': Color(0xFFA7F3D0),
    'blue': Color(0xFFBAE6FD),
    'pink': Color(0xFFFBCFE8),
    'orange': Color(0xFFFED7AA),
    'purple': Color(0xFFE9D5FF),
    'red': Color(0xFFFECACA),
    'cyan': Color(0xFFA5F3FC),
    // Legacy maps
    'teal': Color(0xFFA5F3FC),
    'gray': Color(0xFFFDE68A),
    'white': Color(0xFFFFFFFF),
  };

  // Note Body Colors (Lighter pastel shades for light mode)
  static const Map<String, Color> noteHeaderColors = {
    'yellow': Color(0xFFFEF3C7),
    'green': Color(0xFFD1FAE5),
    'blue': Color(0xFFE0F2FE),
    'pink': Color(0xFFFCE7F3),
    'orange': Color(0xFFFFEDD5),
    'purple': Color(0xFFF3E8FF),
    'red': Color(0xFFFEE2E2),
    'cyan': Color(0xFFCFFAFE),
    // Legacy maps
    'teal': Color(0xFFCFFAFE),
    'gray': Color(0xFFFEF3C7),
    'white': Color(0xFFFAFAFA),
  };

  // Dark Mode Header Colors
  static const Map<String, Color> noteColorsDark = {
    'yellow': Color(0xFF78350F),
    'green': Color(0xFF064E3B),
    'blue': Color(0xFF1E3A8A),
    'pink': Color(0xFF831843),
    'orange': Color(0xFF7C2D12),
    'purple': Color(0xFF4C1D95),
    'red': Color(0xFF7F1D1D),
    'cyan': Color(0xFF164E63),
    // Legacy maps
    'teal': Color(0xFF164E63),
    'gray': Color(0xFF3F3F46),
    'white': Color(0xFF27272A),
  };

  // Dark Mode Body Colors
  static const Map<String, Color> noteBodyColorsDark = {
    'yellow': Color(0xFF451A03),
    'green': Color(0xFF022C22),
    'blue': Color(0xFF172554),
    'pink': Color(0xFF500724),
    'orange': Color(0xFF431407),
    'purple': Color(0xFF2E1065),
    'red': Color(0xFF450A0A),
    'cyan': Color(0xFF083344),
    // Legacy maps
    'teal': Color(0xFF083344),
    'gray': Color(0xFF18181B),
    'white': Color(0xFF18181B),
  };

  /// Get the accent color for a note
  static Color getNoteColor(String colorKey) {
    return noteColors[colorKey] ?? primaryColor;
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: bgPrimary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        surface: Colors.white,
        onSurface: textPrimary,
        error: error,
      ),
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: textPrimary),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: textPrimary),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, height: 1.6, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, height: 1.5, color: textSecondary),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, height: 1.5, color: textSecondary),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: textMuted),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderLight, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: bgPrimaryDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        brightness: Brightness.dark,
        surface: surfaceDark,
        onSurface: textPrimaryDark,
        error: error,
      ),
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: textPrimaryDark),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: textPrimaryDark),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimaryDark),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimaryDark),
        titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimaryDark),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, height: 1.6, color: textPrimaryDark),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, height: 1.5, color: textSecondaryDark),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, height: 1.5, color: textSecondaryDark),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: textMutedDark),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimaryDark),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}
