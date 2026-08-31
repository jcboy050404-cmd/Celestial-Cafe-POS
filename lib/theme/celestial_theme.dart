import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CelestialTheme {
  // Brand Colors
  static const Color bgDark = Color(0xFF0D0B10);
  static const Color bgSurface = Color(0xFF17131B);
  static const Color bgSurfaceLight = Color(0xFF241D26);
  static const Color bgCard = Color(0xFF1E1720);
  static const Color bgCardHover = Color(0xFF2B202E);

  // Coffee Brown Palette
  static const Color brownDeep = Color(0xFF261814);
  static const Color brownRich = Color(0xFF3F271E);
  static const Color brownWarm = Color(0xFF6B442E);
  static const Color brownCaramel = Color(0xFF9E653F);
  static const Color brownMocha = Color(0xFF4E3629);

  // Celestial Gold & Amber Accents
  static const Color goldPrimary = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF3D079);
  static const Color goldDark = Color(0xFFA68018);
  static const Color amberWarm = Color(0xFFE59840);

  // Status & Utility Colors
  static const Color emeraldReady = Color(0xFF2EC4B6);
  static const Color amberBrewing = Color(0xFFFF9F1C);
  static const Color roseAlert = Color(0xFFE71D36);
  static const Color blueInfo = Color(0xFF4CC9F0);

  // Text Colors
  static const Color textLight = Color(0xFFF7EFE8);
  static const Color textMuted = Color(0xFFAFA399);
  static const Color textSubtle = Color(0xFF6E645D);

  // Gradients
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF3D079), Color(0xFFD4AF37), Color(0xFFA68018)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brownGradient = LinearGradient(
    colors: [Color(0xFF3F271E), Color(0xFF1F120E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF221A25), Color(0xFF151018)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient goldCardGradient = LinearGradient(
    colors: [Color(0xFF332517), Color(0xFF1D140C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient nebulaGradient = LinearGradient(
    colors: [Color(0xFF2D1836), Color(0xFF17131B), Color(0xFF201614)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Box Decorations
  static BoxDecoration glassCard({
    Color? color,
    BorderRadius? borderRadius,
    Border? border,
    bool glow = false,
  }) {
    return BoxDecoration(
      color: color ?? bgCard,
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      border: border ??
          Border.all(
            color: glow
                ? goldPrimary.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.07),
            width: 1,
          ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
        if (glow)
          BoxShadow(
            color: goldPrimary.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: 1,
          ),
      ],
    );
  }

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: goldPrimary,
      colorScheme: const ColorScheme.dark(
        primary: goldPrimary,
        secondary: brownCaramel,
        surface: bgSurface,
        error: roseAlert,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: textLight,
        displayColor: textLight,
      ),
      iconTheme: const IconThemeData(
        color: textLight,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF241D26),
        contentTextStyle: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: goldLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
      ),
    );
  }
}
