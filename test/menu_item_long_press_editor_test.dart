import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:celestial_pos/models/menu_item.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:celestial_pos/widgets/menu_item_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MenuItemCard long press opens quick availability & edit sheet with all management controls', (tester) async {
    final posProvider = PosProvider();
    final testItem = MenuItem(
      id: 'test_item_americano',
      name: 'Americano',
      description: 'Rich espresso with hot water',
      price: 90,
      category: ItemCategory.coffee,
      icon: '☕',
      inStock: true,
      customizationGroups: [
        const CustomizationGroup(
          id: 'size',
          title: 'Cup Size',
          isRequired: true,
          options: [
            CustomizationOption(name: '16oz Regular', extraPrice: 0),
            CustomizationOption(name: '22oz Large', extraPrice: 20),
          ],
        ),
      ],
    );

    // Make sure item exists in provider
    posProvider.addNewMenuItem(testItem);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<PosProvider>.value(
          value: posProvider,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 220,
                height: 300,
                child: MenuItemCard(item: testItem),
              ),
            ),
          ),
        ),
      ),
    );

    // Find card and long press
    final cardFinder = find.byType(MenuItemCard);
    expect(cardFinder, findsOneWidget);

    await tester.longPress(cardFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Verify modal sheet opened with header and action buttons
    expect(find.text('Edit Item'), findsOneWidget);
    expect(find.byTooltip('Delete Menu Item'), findsOneWidget);
    expect(find.text('Item Availability'), findsOneWidget);
    expect(find.text('MODIFIERS & OPTION CATEGORIES'), findsOneWidget);
    expect(find.text('Add Category'), findsOneWidget);
    expect(find.byTooltip('Advanced Customization Studio'), findsOneWidget);

    // Verify category header & badges
    expect(find.text('Cup Size'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
    expect(find.byTooltip('Edit Category'), findsOneWidget);
    expect(find.byTooltip('Delete Category'), findsOneWidget);

    // Verify option chips & Add Option button
    expect(find.text('16oz Regular'), findsOneWidget);
    expect(find.text('22oz Large'), findsOneWidget);
    expect(find.text('Add Option'), findsOneWidget);

    // Verify Quick Price & Stock cards
    expect(find.text('PRICE'), findsOneWidget);
    expect(find.text('STOCK'), findsOneWidget);
    expect(find.text('₱90'), findsWidgets);
    expect(find.text('50'), findsOneWidget);

    // Test Price Stepper +10
    await tester.tap(find.text('+10'));
    await tester.pumpAndSettle();
    expect(posProvider.menuItems.firstWhere((m) => m.id == testItem.id).price, 100.0);

    // Test Stock Stepper -1
    await tester.tap(find.text('-1'));
    await tester.pumpAndSettle();
    expect(posProvider.menuItems.firstWhere((m) => m.id == testItem.id).stockCount, 49);

    // Test Edit Price Dialog
    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();

    expect(find.text('Edit Price: Americano'), findsOneWidget);
    final priceDialogFinder = find.byType(AlertDialog);
    expect(priceDialogFinder, findsOneWidget);
    await tester.enterText(
      find.descendant(of: priceDialogFinder, matching: find.byType(TextField)).first,
      '125',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: priceDialogFinder, matching: find.byType(ElevatedButton)));
    await tester.pumpAndSettle();
    expect(posProvider.menuItems.firstWhere((m) => m.id == testItem.id).price, 125.0);

    // Test Edit Stock Dialog
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();

    expect(find.text('Edit Stock: Americano'), findsOneWidget);
    final stockDialogFinder = find.byType(AlertDialog);
    expect(stockDialogFinder, findsOneWidget);
    await tester.tap(find.descendant(of: stockDialogFinder, matching: find.text('100')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: stockDialogFinder, matching: find.byType(ElevatedButton)));
    await tester.pumpAndSettle();
    expect(posProvider.menuItems.firstWhere((m) => m.id == testItem.id).stockCount, 100);

    // Test Add Category flow
    await tester.tap(find.text('Add Category'));
    await tester.pumpAndSettle();

    expect(find.text('New Option Category'), findsOneWidget);
    expect(find.text('QUICK PRESETS'), findsOneWidget);

    // Pick Temperature preset
    await tester.tap(find.text('Temperature'));
    await tester.pumpAndSettle();

    // Tap Add Category button inside dialog
    final catDialogFinder = find.byType(AlertDialog);
    expect(catDialogFinder, findsOneWidget);
    await tester.tap(find.descendant(of: catDialogFinder, matching: find.byType(ElevatedButton)));
    await tester.pumpAndSettle();

    // Verify 'Temperature' category now appears in the modal
    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text('Hot'), findsOneWidget);
    expect(find.text('Iced'), findsOneWidget);

    // Test Add Option flow in the 'Temperature' category
    final addOptionButtons = find.text('Add Option');
    expect(addOptionButtons, findsWidgets);

    await tester.ensureVisible(addOptionButtons.last);
    await tester.pumpAndSettle();

    await tester.tap(addOptionButtons.last);
    await tester.pumpAndSettle();

    expect(find.text('Add Option to "Temperature"'), findsOneWidget);
    final optDialogFinder = find.byType(AlertDialog);
    expect(optDialogFinder, findsOneWidget);
    await tester.enterText(
      find.descendant(of: optDialogFinder, matching: find.byType(TextField)).first,
      'Warm 50°C',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: optDialogFinder, matching: find.byType(ElevatedButton)));
    await tester.pumpAndSettle();

    // Verify new option appears
    expect(find.text('Warm 50°C'), findsOneWidget);

    // Verify Section position badges
    expect(find.text('1ST'), findsWidgets);
    expect(find.text('#2'), findsOneWidget);

    // Initial order: Cup Size is first, Temperature is second
    final americanoBefore = posProvider.menuItems.firstWhere((m) => m.id == testItem.id);
    expect(americanoBefore.customizationGroups.first.title, 'Cup Size');
    expect(americanoBefore.customizationGroups.last.title, 'Temperature');

    // Test moving 'Temperature' to become the 1st section
    final moveToFirstBtn = find.byTooltip('Move to 1st section');
    expect(moveToFirstBtn, findsOneWidget);
    await tester.ensureVisible(moveToFirstBtn);
    await tester.pumpAndSettle();
    await tester.tap(moveToFirstBtn);
    await tester.pumpAndSettle();

    // Verify order swapped: Temperature is now first section!
    final americanoAfter = posProvider.menuItems.firstWhere((m) => m.id == testItem.id);
    expect(americanoAfter.customizationGroups.first.title, 'Temperature');
    expect(americanoAfter.customizationGroups.last.title, 'Cup Size');

    // Tap Done to close
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Item Availability'), findsNothing);

    // Test PosProvider category tab reordering
    final tabsBefore = posProvider.allCategoryTabs.where((t) => t.id != 'all').toList();
    expect(tabsBefore.first.id, 'coffee');

    posProvider.moveCategoryToFirst('milktea');
    final tabsAfter = posProvider.allCategoryTabs.where((t) => t.id != 'all').toList();
    expect(tabsAfter.first.id, 'milktea');
  });
}
