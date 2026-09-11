import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:celestial_pos/models/menu_item.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:celestial_pos/widgets/price_editor_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PosProvider updates single customization option price', () {
    final provider = PosProvider();
    final combo = provider.menuItems.firstWhere((m) => m.id == 'dn_1'); // Special Combo Meal
    final garlicOption = combo.customizationGroups
        .firstWhere((g) => g.id == 'rice_choice')
        .options
        .firstWhere((o) => o.name.contains('Garlic Fried Rice'));

    expect(garlicOption.extraPrice, 15.0);

    // Update Garlic Fried Rice to ₱25
    provider.updateCustomizationOptionPrice(
      itemId: combo.id,
      groupId: 'rice_choice',
      optionName: 'Garlic Fried Rice',
      newExtraPrice: 25.0,
      applyGlobally: false,
    );

    final updatedCombo = provider.menuItems.firstWhere((m) => m.id == 'dn_1');
    final updatedGarlic = updatedCombo.customizationGroups
        .firstWhere((g) => g.id == 'rice_choice')
        .options
        .firstWhere((o) => o.name.contains('Garlic Fried Rice'));

    expect(updatedGarlic.extraPrice, 25.0);
  });

  test('PosProvider updates flavor & spice and add-on price globally', () {
    final provider = PosProvider();

    // Update Spicy flavor to +₱10 globally
    provider.updateCustomizationOptionPrice(
      itemId: 'dn_1',
      groupId: 'dinner_flavor',
      optionName: 'Spicy (Chili Flakes & Scallions)',
      newExtraPrice: 10.0,
      applyGlobally: true,
    );

    // Update Extra 1 Pc BBQ Skewer to +₱40 globally
    provider.updateCustomizationOptionPrice(
      itemId: 'dn_1',
      groupId: 'dinner_addons',
      optionName: 'Extra 1 Pc BBQ Skewer',
      newExtraPrice: 40.0,
      applyGlobally: true,
    );

    // Verify across dinner items
    for (final item in provider.menuItems.where((m) => m.category == ItemCategory.dinner)) {
      final flavorGroup = item.customizationGroups.where((g) => g.id == 'dinner_flavor');
      if (flavorGroup.isNotEmpty) {
        final spicyOpt = flavorGroup.first.options.firstWhere((o) => o.name.contains('Spicy'));
        expect(spicyOpt.extraPrice, 10.0);
      }

      final addonGroup = item.customizationGroups.where((g) => g.id == 'dinner_addons');
      if (addonGroup.isNotEmpty) {
        final bbqOpt = addonGroup.first.options.firstWhere((o) => o.name.contains('BBQ Skewer'));
        expect(bbqOpt.extraPrice, 40.0);
      }
    }

    // Verify provider menu item reflects updated modifier price
    final comboItem = provider.menuItems.firstWhere((m) => m.id == 'dn_1');
    final flavorGroup = comboItem.customizationGroups.firstWhere((g) => g.id == 'dinner_flavor');
    final spicyOption = flavorGroup.options.firstWhere((o) => o.name.contains('Spicy'));
    expect(spicyOption.extraPrice, 10.0);
  });

  testWidgets('PriceEditorDialog opens and allows editing option prices', (tester) async {
    final provider = PosProvider();
    final combo = provider.menuItems.firstWhere((m) => m.id == 'dn_1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => PriceEditorDialog.showQuickPrice(context, provider, combo),
                child: const Text('Open Price Editor'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Price Editor'));
    await tester.pumpAndSettle();

    // Verify dialog loaded
    expect(find.text('Price Control & Modifiers'), findsOneWidget);
    expect(find.text('Special Combo Meal'), findsOneWidget);
    expect(find.text('BASE ITEM PRICE (₱)'), findsOneWidget);
    expect(find.text('ADD-ONS, FLAVORS & OPTIONS PRICING'), findsOneWidget);

    // Verify modifier group titles
    expect(find.text('Rice Choice'), findsOneWidget);
    expect(find.text('Flavor & Spice'), findsOneWidget);
    expect(find.text('Add-ons & Sides'), findsOneWidget);

    // Verify option names are visible
    expect(find.text('Steamed White Rice'), findsOneWidget);
    expect(find.text('Garlic Fried Rice'), findsOneWidget);
    expect(find.text('Extra 1 Pc BBQ Skewer'), findsOneWidget);
  });
}
