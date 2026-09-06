import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:celestial_pos/widgets/settings_dialog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final width in [320.0, 360.0, 390.0, 412.0, 600.0, 768.0, 1280.0]) {
    testWidgets('Test SettingsDialog on width $width - Tab 1 (Availability)', (WidgetTester tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = PosProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<PosProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => const SettingsDialog(initialTab: 1),
                  ),
                  child: const Text('Open Settings'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // Verify no overflow in header and item cards
      expect(find.byType(SettingsDialog), findsOneWidget);
    });

    testWidgets('Test SettingsDialog on width $width - Tab 0 (Store & Branding)', (WidgetTester tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = PosProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<PosProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => const SettingsDialog(initialTab: 0),
                  ),
                  child: const Text('Open Settings'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsDialog), findsOneWidget);
    });
  }
}
