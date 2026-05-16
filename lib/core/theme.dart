import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TryMaarTheme {
  TryMaarTheme._();

  // ─── Color Palette (jhumSTUDIOS branding) ───
  static const Color primary = Color(0xFFF54206);        // Ripe pumpkin (matt)
  static const Color primaryDark = Color(0xFFD93A05);    // Darker pumpkin
  static const Color accent = Color(0xFFF54206);         // Same pumpkin for accent unity
  static const Color surface = Color(0xFF1D252A);        // Dark charcoal (matt)
  static const Color surfaceLight = Color(0xFF243038);   // Slightly lighter charcoal
  static const Color surfaceOverlay = Color(0xFF2A3540); // Charcoal overlay
  static const Color background = Color(0xFF1D252A);     // Dark charcoal base
  static const Color textPrimary = Color(0xFFF8FAFC);    // Crisp white text
  static const Color textSecondary = Color(0xFF8A9BAA);  // Muted steel
  static const Color divider = Color(0x14FFFFFF);        // 8% white
  static const Color success = Color(0xFF10B981);        // Green
  static const Color warning = Color(0xFFF59E0B);        // Amber
  static const Color error = Color(0xFFFF5252);          // Red

  // ─── Gradients ───
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accent, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [
      Color(0xFF243038),
      Color(0xFF1D252A),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0x33FFFFFF),
      Color(0x05FFFFFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Border Radius ───
  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;   // 0.5rem minimalist corner
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;

  // ─── Spacing ───
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;
  static const double spaceXxl = 48.0;

  // ─── Glassmorphism Decoration ───
  static BoxDecoration glassCard({double radius = radiusMd}) {
    return BoxDecoration(
      gradient: glassGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.1),
        width: 1.0,
      ),
    );
  }

  static BoxDecoration elevatedCard({double radius = radiusMd}) {
    return BoxDecoration(
      color: surfaceLight,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // ─── Theme Data ───
  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: textSecondary,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: textSecondary,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
      ),
    );
  }
}
