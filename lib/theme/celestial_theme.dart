import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CelestialTheme {
  // Brand Canvas & Dark Espresso Surfaces (Black & Brown Theme)
  static const Color bgDark = Color(0xFF000000);         // Pure sleek black canvas (#000000)
  static const Color bgSurface = Color(0xFF000000);      // Pure sleek black surface (#000000)
  static const Color bgSurfaceLight = Color(0xFF0A0A0A); // Soft elevated dark mocha
  static const Color bgCard = Color(0xFF14100D);         // Warm dark espresso card base
  static const Color bgCardHover = Color(0xFF1F1814);    // Hovered card
  static const Color bgCardActive = Color(0xFF2B201A);   // Selected / active card

  // Warm Neutral / Earth Tone Palette
  static const Color creamLight = Color(0xFFF6EFE9);     // Steamed milk froth / pure warm cream
  static const Color creamSoft = Color(0xFFD6C8BD);      // Cafe au lait / soft warm cream
  static const Color warmBeige = Color(0xFFC8B29E);      // Toasted hazelnut / warm beige
  static const Color warmGray = Color(0xFF8A7B70);       // Warm stone gray / muted roast
  static const Color borderSubtle = Color(0x1CFAF0E6);   // Gentle warm hairline border
  static const Color borderHover = Color(0x44D4A359);    // Warm caramel-gold hover border
  static const Color borderWarm = Color(0xFF3A2D25);     // Defined warm mocha border

  // Coffee Brown Palette
  static const Color brownDeep = Color(0xFF140F0C);
  static const Color brownRich = Color(0xFF241812);
  static const Color brownWarm = Color(0xFF5A3E2D);
  static const Color brownCaramel = Color(0xFFB8783E);
  static const Color brownMocha = Color(0xFF3D2A20);
  static const Color darkBrown = Color(0xFF1C120C);      // Rich dark espresso brown

  // Warm Caramel & Honey Gold Accents (Refined & Soft, Non-Neon)
  static const Color caramelAccent = Color(0xFFC48248);  // Artisan caramel
  static const Color goldPrimary = Color(0xFFD4A359);    // Soft brushed warm honey gold
  static const Color goldLight = Color(0xFFEED09D);      // Creamy gold highlight
  static const Color goldDark = Color(0xFFA67A32);
  static const Color amberWarm = Color(0xFFDF9548);

  // Status & Utility Colors (Softened & Earth-Harmonious)
  static const Color emeraldReady = Color(0xFF38B293);   // Sage / mint emerald
  static const Color amberBrewing = Color(0xFFD98236);   // Warm roasted amber
  static const Color roseAlert = Color(0xFFD9534F);      // Warm terracotta rose
  static const Color blueInfo = Color(0xFF5B92E5);       // Slate blue

  // Text Colors
  static const Color textLight = Color(0xFFF6EFE9);      // Steamed milk cream (primary text)
  static const Color textMuted = Color(0xFFD6C8BD);      // Soft cafe au lait (secondary text)
  static const Color textSubtle = Color(0xFF8A7B70);     // Warm stone gray (hints, sub-labels)

  // Gradients
  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFF1E1510), Color(0xFF000000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brownGradient = LinearGradient(
    colors: [Color(0xFF241812), Color(0xFF080605)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF18120E), Color(0xFF0E0B09)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient caramelGradient = LinearGradient(
    colors: [Color(0xFFDC9E5E), Color(0xFFB8783E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFEED09D), Color(0xFFD4A359), Color(0xFFB8863A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldCardGradient = LinearGradient(
    colors: [Color(0xFF22180F), Color(0xFF120C07)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient nebulaGradient = LinearGradient(
    colors: [Color(0xFF1E1410), Color(0xFF0C0907), Color(0xFF000000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Liquid Glass Gradient for Headers & Floating Overlays
  static const LinearGradient liquidGlassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xF01C120C), // Luminous dark espresso refraction
      Color(0xF5140C08), // Viscous dark mocha core
      Color(0xFA0B0704), // Deep espresso-black base
    ],
    stops: [0.0, 0.50, 1.0],
  );

  // Liquid Glass Header Box Decoration (Refractive glass depth, top specular rim, warm gold bottom rim)
  static BoxDecoration liquidGlassHeader({bool isMobile = false, bool isScrolled = false}) {
    return BoxDecoration(
      gradient: isScrolled
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xF5140C07), // Deeper condensed dark espresso
                Color(0xFA0E0805), // Viscous dark core
                Color(0xFF070402), // Deep base
              ],
              stops: [0.0, 0.50, 1.0],
            )
          : liquidGlassGradient,
      border: Border(
        top: BorderSide(
          color: Colors.white.withValues(alpha: isScrolled ? 0.10 : 0.08),
          width: 1.0,
        ),
        bottom: BorderSide(
          color: isScrolled
              ? goldPrimary.withValues(alpha: 0.35)
              : goldPrimary.withValues(alpha: 0.15),
          width: isScrolled ? 1.2 : 1.0,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isScrolled ? 0.80 : 0.65),
          blurRadius: isScrolled ? 26 : 20,
          offset: Offset(0, isScrolled ? 8 : 6),
        ),
        BoxShadow(
          color: caramelAccent.withValues(alpha: isScrolled ? 0.10 : 0.04),
          blurRadius: isScrolled ? 28 : 24,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // Soft UI / Card-Based Minimalism Box Decoration
  static BoxDecoration softCard({
    Color? color,
    BorderRadius? borderRadius,
    Border? border,
    bool isHovered = false,
    bool isElevated = false,
  }) {
    return BoxDecoration(
      color: color ?? (isHovered ? bgCardHover : bgCard),
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: border ??
          Border.all(
            color: isHovered ? caramelAccent.withValues(alpha: 0.45) : borderSubtle,
            width: 1.0,
          ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isElevated ? 0.35 : 0.20),
          blurRadius: isElevated ? 16 : 8,
          offset: Offset(0, isElevated ? 6 : 3),
        ),
        if (isHovered)
          BoxShadow(
            color: caramelAccent.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
      ],
    );
  }

  // Micro-Skeuomorphism (Hero Elements): Tactile realism with subtle top bevel & soft layered depth
  static BoxDecoration tactileHero({
    Color? color,
    BorderRadius? borderRadius,
    Border? border,
  }) {
    return BoxDecoration(
      color: color ?? bgCard,
      borderRadius: borderRadius ?? BorderRadius.circular(22),
      border: border ??
          Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1.0,
          ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: caramelAccent.withValues(alpha: 0.06),
          blurRadius: 30,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // Glass/Soft Card for backwards compatibility (cleansed of harsh glow halos)
  static BoxDecoration glassCard({
    Color? color,
    BorderRadius? borderRadius,
    Border? border,
    bool glow = false,
  }) {
    return BoxDecoration(
      color: color ?? bgCard,
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: border ??
          Border.all(
            color: glow ? caramelAccent.withValues(alpha: 0.4) : borderSubtle,
            width: 1.0,
          ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
        if (glow)
          BoxShadow(
            color: caramelAccent.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 2),
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
        secondary: caramelAccent,
        surface: bgSurface,
        error: roseAlert,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBrown,
        foregroundColor: textLight,
        elevation: 0,
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
        color: Colors.white.withValues(alpha: 0.06),
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: borderSubtle,
            width: 1.0,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgSurfaceLight,
        contentTextStyle: GoogleFonts.outfit(
          color: textLight,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: goldLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(
            color: borderSubtle,
          ),
        ),
      ),
    );
  }
}
