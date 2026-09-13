import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:celestial_pos/theme/celestial_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Primary Button Text Contrast Tests', () {
    test('London Bistro theme returns pure white primary button text', () {
      CelestialTheme.setThemeMode(PosThemeMode.londonBistro);
      expect(CelestialTheme.isLondon, isTrue);
      expect(CelestialTheme.primaryBtnText, equals(Colors.white));
      expect(CelestialTheme.themeData.elevatedButtonTheme.style?.foregroundColor?.resolve({}), equals(Colors.white));
    });

    test('Classic Espresso theme returns bgDark for primary button text', () {
      CelestialTheme.setThemeMode(PosThemeMode.classicEspresso);
      expect(CelestialTheme.isLondon, isFalse);
      expect(CelestialTheme.primaryBtnText, equals(CelestialTheme.bgDark));
      expect(CelestialTheme.themeData.elevatedButtonTheme.style?.foregroundColor?.resolve({}), equals(CelestialTheme.bgDark));
    });

    tearDown(() {
      CelestialTheme.setThemeMode(PosThemeMode.classicEspresso);
    });
  });
}
