import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum PosThemeMode {
  classicEspresso(
    'Classic Warm Espresso',
    'Warm roasted espresso, honey gold & toasted caramel',
    Icons.coffee_rounded,
    Color(0xFFD4A359),
  ),
  londonBistro(
    'London Bistro Black & Red',
    'Obsidian matte black & British royal red (Pure Black & Red)',
    Icons.local_bar_rounded,
    Color(0xFFE52538),
  );

  final String label;
  final String description;
  final IconData icon;
  final Color accentColor;
  const PosThemeMode(this.label, this.description, this.icon, this.accentColor);
}

class CelestialTheme {
  static PosThemeMode _currentMode = PosThemeMode.classicEspresso;
  static PosThemeMode get currentMode => _currentMode;
  static bool get isLondon => _currentMode == PosThemeMode.londonBistro;

  static void setThemeMode(PosThemeMode mode) {
    _currentMode = mode;
  }

  // Brand Canvas & Surfaces
  static Color get bgDark => isLondon ? const Color(0xFF060608) : const Color(0xFF000000);
  static Color get bgSurface => isLondon ? const Color(0xFF09090C) : const Color(0xFF000000);
  static Color get bgSurfaceLight => isLondon ? const Color(0xFF121014) : const Color(0xFF0A0A0A);
  static Color get bgCard => isLondon ? const Color(0xFF141014) : const Color(0xFF14100D);
  static Color get bgCardHover => isLondon ? const Color(0xFF221419) : const Color(0xFF1F1814);
  static Color get bgCardActive => isLondon ? const Color(0xFF33141D) : const Color(0xFF2B201A);

  // Warm Neutral / Ivory Palette
  static Color get creamLight => isLondon ? const Color(0xFFFBF8F6) : const Color(0xFFF6EFE9);
  static Color get creamSoft => isLondon ? const Color(0xFFDDD2D0) : const Color(0xFFD6C8BD);
  static Color get warmBeige => isLondon ? const Color(0xFFC7B3B0) : const Color(0xFFC8B29E);
  static Color get warmGray => isLondon ? const Color(0xFF8C7A7C) : const Color(0xFF8A7B70);
  static Color get borderSubtle => isLondon ? const Color(0x24FFFFFF) : const Color(0x1CFAF0E6);
  static Color get borderHover => isLondon ? const Color(0x80E52538) : const Color(0x44D4A359);
  static Color get borderWarm => isLondon ? const Color(0xFF4A141D) : const Color(0xFF3A2D25);

  // Deep Tones
  static Color get brownDeep => isLondon ? const Color(0xFF12070A) : const Color(0xFF140F0C);
  static Color get brownRich => isLondon ? const Color(0xFF1E090E) : const Color(0xFF241812);
  static Color get brownWarm => isLondon ? const Color(0xFF4A141D) : const Color(0xFF5A3E2D);
  static Color get brownCaramel => isLondon ? const Color(0xFFC8102E) : const Color(0xFFB8783E);
  static Color get brownMocha => isLondon ? const Color(0xFF2C0D14) : const Color(0xFF3D2A20);
  static Color get darkBrown => isLondon ? const Color(0xFF14080B) : const Color(0xFF1C120C);

  // Signature Accents
  static Color get caramelAccent => isLondon ? const Color(0xFFC8102E) : const Color(0xFFC48248);
  static Color get goldPrimary => isLondon ? const Color(0xFFE52538) : const Color(0xFFD4A359);
  static Color get goldLight => isLondon ? const Color(0xFFFF5263) : const Color(0xFFEED09D);
  static Color get goldDark => isLondon ? const Color(0xFFA61022) : const Color(0xFFA67A32);
  static Color get amberWarm => isLondon ? const Color(0xFFDC2626) : const Color(0xFFDF9548);
  static Color get amberBrewing => isLondon ? const Color(0xFFDC2626) : const Color(0xFFD98236);

  // Status & Utility Colors
  static Color get emeraldReady => isLondon ? const Color(0xFF10B981) : const Color(0xFF38B293);
  static Color get roseAlert => isLondon ? const Color(0xFFFF334B) : const Color(0xFFD9534F);
  static Color get blueInfo => isLondon ? const Color(0xFF3B82F6) : const Color(0xFF5B92E5);

  // Text Colors
  static Color get textLight => isLondon ? const Color(0xFFFAF7F5) : const Color(0xFFF6EFE9);
  static Color get textMuted => isLondon ? const Color(0xFFD4C8C8) : const Color(0xFFD6C8BD);
  static Color get textSubtle => isLondon ? const Color(0xFF948284) : const Color(0xFF8A7B70);
  /// Text & icon color for controls/buttons with [goldPrimary] background.
  /// On London Bistro (Red button), this is crisp pure white [Colors.white].
  /// On Classic Espresso (Gold button), this is deep espresso [bgDark].
  static Color get primaryBtnText => isLondon ? Colors.white : bgDark;

  // Dynamic Gradients
  static LinearGradient get warmGradient => LinearGradient(
        colors: isLondon
            ? const [Color(0xFF280B12), Color(0xFF060608)]
            : const [Color(0xFF1E1510), Color(0xFF000000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get brownGradient => LinearGradient(
        colors: isLondon
            ? const [Color(0xFF22080D), Color(0xFF090607)]
            : const [Color(0xFF241812), Color(0xFF080605)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get cardGradient => LinearGradient(
        colors: isLondon
            ? const [Color(0xFF181115), Color(0xFF0F0B0E)]
            : const [Color(0xFF18120E), Color(0xFF0E0B09)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  static LinearGradient get caramelGradient => LinearGradient(
        colors: isLondon
            ? const [Color(0xFFFF3B53), Color(0xFFB81424)]
            : const [Color(0xFFDC9E5E), Color(0xFFB8783E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get goldGradient => LinearGradient(
        colors: isLondon
            ? const [Color(0xFFFF5466), Color(0xFFE52538), Color(0xFFA61022)]
            : const [Color(0xFFEED09D), Color(0xFFD4A359), Color(0xFFB8863A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get goldCardGradient => LinearGradient(
        colors: isLondon
            ? const [Color(0xFF2A0D15), Color(0xFF14080B)]
            : const [Color(0xFF22180F), Color(0xFF120C07)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get nebulaGradient => LinearGradient(
        colors: isLondon
            ? const [Color(0xFF240A10), Color(0xFF0E0709), Color(0xFF050506)]
            : const [Color(0xFF1E1410), Color(0xFF0C0907), Color(0xFF000000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get liquidGlassGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isLondon
            ? const [
                Color(0xF5240B12),
                Color(0xFA15080C),
                Color(0xFF080608),
              ]
            : const [
                Color(0xF01C120C),
                Color(0xF5140C08),
                Color(0xFA0B0704),
              ],
        stops: const [0.0, 0.50, 1.0],
      );

  // Liquid Glass Header Box Decoration
  static BoxDecoration liquidGlassHeader({bool isMobile = false, bool isScrolled = false}) {
    return BoxDecoration(
      gradient: isScrolled
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isLondon
                  ? const [
                      Color(0xF81C080E),
                      Color(0xFD120609),
                      Color(0xFF060507),
                    ]
                  : const [
                      Color(0xF5140C07),
                      Color(0xFA0E0805),
                      Color(0xFF070402),
                    ],
              stops: const [0.0, 0.50, 1.0],
            )
          : liquidGlassGradient,
      border: Border(
        top: BorderSide(
          color: Colors.white.withValues(alpha: isScrolled ? 0.12 : 0.08),
          width: 1.0,
        ),
        bottom: BorderSide(
          color: isScrolled
              ? goldPrimary.withValues(alpha: isLondon ? 0.50 : 0.35)
              : goldPrimary.withValues(alpha: isLondon ? 0.25 : 0.15),
          width: isScrolled ? 1.3 : 1.0,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isScrolled ? 0.85 : 0.65),
          blurRadius: isScrolled ? 26 : 20,
          offset: Offset(0, isScrolled ? 8 : 6),
        ),
        BoxShadow(
          color: (isLondon ? goldPrimary : caramelAccent).withValues(alpha: isScrolled ? 0.12 : 0.05),
          blurRadius: isScrolled ? 30 : 24,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // Soft UI / Card Box Decoration
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
            color: isHovered
                ? (isLondon ? goldPrimary.withValues(alpha: 0.60) : caramelAccent.withValues(alpha: 0.45))
                : borderSubtle,
            width: 1.0,
          ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isElevated ? 0.40 : 0.22),
          blurRadius: isElevated ? 16 : 8,
          offset: Offset(0, isElevated ? 6 : 3),
        ),
        if (isHovered)
          BoxShadow(
            color: (isLondon ? goldPrimary : caramelAccent).withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
      ],
    );
  }

  // Tactile Hero Box Decoration
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
            color: isLondon ? goldPrimary.withValues(alpha: 0.20) : Colors.white.withValues(alpha: 0.10),
            width: 1.0,
          ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.48),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: (isLondon ? goldPrimary : caramelAccent).withValues(alpha: 0.07),
          blurRadius: 30,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // Glass Card Box Decoration
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
            color: glow ? (isLondon ? goldPrimary.withValues(alpha: 0.40) : borderWarm) : borderSubtle,
            width: 1.0,
          ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 10,
          offset: const Offset(0, 4),
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
      colorScheme: ColorScheme.dark(
        primary: goldPrimary,
        secondary: caramelAccent,
        surface: bgSurface,
        error: roseAlert,
      ),
      appBarTheme: AppBarTheme(
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
      iconTheme: IconThemeData(
        color: textLight,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: isLondon ? 0.08 : 0.06),
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isLondon ? borderWarm : borderSubtle,
            width: 1.0,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: goldPrimary,
          foregroundColor: primaryBtnText,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
          side: BorderSide(
            color: borderWarm,
          ),
        ),
      ),
    );
  }
}
