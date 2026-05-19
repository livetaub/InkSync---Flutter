import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primaryColor = Color(0xFF10B981); // Emerald
  static const bgColor = Color(0xFFF1F5F9);
  
  static ThemeData get lightTheme {
    return ThemeData(
      scaffoldBackgroundColor: bgColor,
      colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
      textTheme: GoogleFonts.interTextTheme(),
      useMaterial3: true,
    );
  }
}
