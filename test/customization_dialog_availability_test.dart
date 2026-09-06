import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:celestial_pos/models/menu_item.dart';
import 'package:celestial_pos/models/order.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:celestial_pos/widgets/customization_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MenuItem createSampleItem() {
    return MenuItem(
      id: 'item_sample_coffee',
      name: 'Caramel Macchiato',
      description: 'Rich espresso with vanilla syrup and caramel drizzle',
      price: 140,
      category: ItemCategory.coffee,
      icon: '☕',
      inStock: true,
      customizationGroups: [
        CustomizationGroup(
          id: 'temp',
          title: 'Temperature',
          isRequired: true,
          isMultiSelect: false,
          defaultIndex: 0,
          options: [
            const CustomizationOption(name: 'Hot', isAvailable: true),
            const CustomizationOption(name: 'Iced', isAvailable: true),
          ],
        ),
        CustomizationGroup(
          id: 'addons',
          title: 'Add-ons & Extras',
          isRequired: false,
          isMultiSelect: true,
          options: [
            const CustomizationOption(name: 'Extra Espresso Shot', extraPrice: 30, isAvailable: true),
            const CustomizationOption(name: 'Caramel Drizzle', extraPrice: 20, isAvailable: true),
            const CustomizationOption(name: 'Vanilla Syrup', extraPrice: 20, isAvailable: false),
          ],
        ),
      ],
    );
  }

  group('CustomizationDialog Availability Controls', () {
    testWidgets('Does not display [86 STOCK] and [REQUIRED] badges in headers', (tester) async {
      final sampleItem = createSampleItem();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomizationDialog(
              item: sampleItem,
              onAddToCart: (qty, customs, notes) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clean headers: neither 86 STOCK nor REQUIRED should be displayed
      expect(find.text('86 STOCK'), findsNothing);
      expect(find.text('86 STOCK (!)'), findsNothing);
      expect(find.text('REQUIRED'), findsNothing);
      expect(find.text('OPTIONAL'), findsNothing);
    });

    testWidgets('Long-pressing group header opens group availability sheet with option switches', (tester) async {
      final sampleItem = createSampleItem();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomizationDialog(
              item: sampleItem,
              onAddToCart: (qty, customs, notes) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long-press Temperature group header to open availability sheet
      await tester.longPress(find.text('Temperature'));
      await tester.pumpAndSettle();

      // Verify availability dialog header
      expect(find.text('Temperature Availability'), findsOneWidget);
      expect(find.text('Apply to all menu items'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Verify both Hot and Iced are in the dialog list with IN STOCK badges
      expect(find.text('IN STOCK'), findsNWidgets(2));

      // Close dialog
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Temperature Availability'), findsNothing);
    });

    testWidgets('Long-pressing Temperature option toggles its availability and auto-adjusts selection', (tester) async {
      final sampleItem = createSampleItem();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomizationDialog(
              item: sampleItem,
              onAddToCart: (qty, customs, notes) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially "Hot" is selected and available
      // Long-press "Hot" to mark it 86'd
      await tester.longPress(find.text('Hot'));
      await tester.pumpAndSettle();

      // Toast confirms 86'd
      expect(find.text('"Hot" is now 86\'d (sold out).'), findsOneWidget);

      // "Not Available" badge now appears on Hot
      expect(find.text("Not Available"), findsWidgets);

      // Tapping unavailable "Hot" shows warning with RESTOCK action
      await tester.tap(find.text('Hot'));
      await tester.pumpAndSettle();

      expect(find.textContaining('is currently 86\'d'), findsOneWidget);
      expect(find.text('RESTOCK'), findsOneWidget);

      // Tap RESTOCK to make Hot available again
      await tester.tap(find.text('RESTOCK'));
      await tester.pumpAndSettle();

      // Toast confirms restock
      expect(find.text('"Hot" is now available in stock.'), findsOneWidget);
    });

    testWidgets('Long-pressing Add-on row toggles availability directly', (tester) async {
      final sampleItem = createSampleItem();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomizationDialog(
              item: sampleItem,
              onAddToCart: (qty, customs, notes) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll so Extra Espresso Shot is fully in view
      await tester.ensureVisible(find.text('Extra Espresso Shot'));
      await tester.pumpAndSettle();

      // Long press "Extra Espresso Shot" to 86 it
      await tester.longPress(find.text('Extra Espresso Shot'));
      await tester.pumpAndSettle();

      expect(find.text('"Extra Espresso Shot" is now 86\'d (sold out).'), findsOneWidget);

      // Long press it again to make it available
      await tester.ensureVisible(find.text('Extra Espresso Shot'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Extra Espresso Shot'));
      await tester.pumpAndSettle();

      expect(find.text('"Extra Espresso Shot" is now available in stock.'), findsOneWidget);
    });

    testWidgets('Syncs availability with PosProvider when present', (tester) async {
      final pos = PosProvider();
      final targetItem = pos.menuItems.firstWhere(
        (m) => m.customizationGroups.any((g) => g.id == 'temp'),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<PosProvider>.value(
          value: pos,
          child: MaterialApp(
            home: Scaffold(
              body: CustomizationDialog(
                item: targetItem,
                onAddToCart: (qty, customs, notes) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long press Hot to 86 it
      await tester.longPress(find.text('Hot'));
      await tester.pumpAndSettle();

      // Verify posProvider has Hot marked as not available for this item
      final updatedItem = pos.menuItems.firstWhere((m) => m.id == targetItem.id);
      final hotOpt = updatedItem.customizationGroups
          .firstWhere((g) => g.id == 'temp')
          .options
          .firstWhere((o) => o.name == 'Hot');
      expect(hotOpt.isAvailable, isFalse);

      // Restock Hot
      await tester.longPress(find.text('Hot'));
      await tester.pumpAndSettle();

      final restockedItem = pos.menuItems.firstWhere((m) => m.id == targetItem.id);
      final restockedHot = restockedItem.customizationGroups
          .firstWhere((g) => g.id == 'temp')
          .options
          .firstWhere((o) => o.name == 'Hot');
      expect(restockedHot.isAvailable, isTrue);
    });

    testWidgets('CustomizationDialog displays "Not Available" badge without overflow on compact viewports', (tester) async {
      final item = MenuItem(
        id: 'test_compact',
        name: 'Americano',
        description: 'Rich freshly pulled espresso shots diluted with hot or iced filtered water.',
        price: 90,
        category: ItemCategory.coffee,
        icon: '☕',
        inStock: true,
        customizationGroups: [
          CustomizationGroup(
            id: 'temp',
            title: 'Temperature',
            isRequired: true,
            isMultiSelect: false,
            defaultIndex: 1,
            options: [
              const CustomizationOption(name: 'Hot', isAvailable: false),
              const CustomizationOption(name: 'Iced', isAvailable: true),
            ],
          ),
          CustomizationGroup(
            id: 'addons',
            title: 'Add-ons & Extras',
            isRequired: false,
            isMultiSelect: true,
            options: [
              const CustomizationOption(name: 'Extra Espresso Shot', extraPrice: 30, isAvailable: false),
              const CustomizationOption(name: 'Vanilla Syrup', extraPrice: 20, isAvailable: true),
            ],
          ),
        ],
      );

      for (final width in [320.0, 360.0, 390.0, 412.0, 800.0]) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomizationDialog(
                item: item,
                onAddToCart: (qty, custs, notes) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Not Available'), findsWidgets);
        expect(tester.takeException(), isNull, reason: 'Must not throw any exceptions on width $width');
      }
    });
  });
}

