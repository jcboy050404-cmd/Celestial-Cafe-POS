import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:celestial_pos/models/menu_item.dart';
import 'package:celestial_pos/theme/celestial_theme.dart';
import 'package:celestial_pos/widgets/customization_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testItem = MenuItem(
    id: 'item_test_1',
    name: 'Americano',
    category: ItemCategory.coffee,
    price: 90.0,
    icon: '☕',
    stockCount: 50,
    description: 'Freshly pulled espresso with water',
    customizationGroups: [
      CustomizationGroup(
        id: 'temp_group',
        title: 'Temperature',
        isRequired: true,
        options: [
          CustomizationOption(name: 'Hot', extraPrice: 0.0),
          CustomizationOption(name: 'Iced', extraPrice: 0.0),
        ],
      ),
      CustomizationGroup(
        id: 'sweet_group',
        title: 'Sweetness Level',
        isRequired: true,
        options: [
          CustomizationOption(name: 'No Sugar (0%)', extraPrice: 0.0),
          CustomizationOption(name: 'Standard (100%)', extraPrice: 0.0),
        ],
      ),
      CustomizationGroup(
        id: 'addon_group',
        title: 'Add-ons & Extras',
        isMultiSelect: true,
        options: [
          CustomizationOption(name: 'Extra Shot', extraPrice: 25.0),
        ],
      ),
    ],
  );

  testWidgets('CustomizationDialog adapts cleanly to London Bistro theme (Red and Black)', (tester) async {
    CelestialTheme.setThemeMode(PosThemeMode.londonBistro);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomizationDialog(
            item: testItem,
            onAddToCart: (qty, cust, notes) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify dialog loaded with item name and options
    expect(find.text('Americano'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text('Hot'), findsOneWidget);
    expect(find.text('Iced'), findsOneWidget);

    // Verify "Add to Order • ₱90" button uses London Bistro Red
    final btnFinder = find.byKey(const Key('customization_add_to_cart_btn'));
    expect(btnFinder, findsOneWidget);
    final btnContainer = tester.widget<Container>(
      find.descendant(of: btnFinder, matching: find.byType(Container)).first,
    );
    final btnDecoration = btnContainer.decoration as BoxDecoration;
    expect(btnDecoration.color, CelestialTheme.goldPrimary); // London Bistro Red: 0xFFE52538
    expect(btnDecoration.color, const Color(0xFFE52538));

    // Verify stepper buttons use London Bistro Red
    final plusBtn = tester.widget<IconButton>(find.byKey(const Key('customization_qty_plus')));
    expect(plusBtn.color, const Color(0xFFE52538));

    // Switch to Classic Espresso theme and verify it switches to Honey Gold
    CelestialTheme.setThemeMode(PosThemeMode.classicEspresso);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomizationDialog(
            item: testItem,
            onAddToCart: (qty, cust, notes) {},
          ),
        ),
      ),
    );
    await tester.pump();

    final btnContainerClassic = tester.widget<Container>(
      find.descendant(of: btnFinder, matching: find.byType(Container)).first,
    );
    final btnDecorationClassic = btnContainerClassic.decoration as BoxDecoration;
    expect(btnDecorationClassic.color, CelestialTheme.goldPrimary); // Classic Espresso Gold: 0xFFD4A359
    expect(btnDecorationClassic.color, const Color(0xFFD4A359));

    final plusBtnClassic = tester.widget<IconButton>(find.byKey(const Key('customization_qty_plus')));
    expect(plusBtnClassic.color, const Color(0xFFD4A359));
  });
}
