import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:celestial_pos/models/menu_item.dart';
import 'package:celestial_pos/models/order.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:celestial_pos/services/kds_server_service.dart';
import 'package:celestial_pos/widgets/customization_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Item & Modifier Availability (86) Models', () {
    test('CustomizationOption defaults to isAvailable true and supports copyWith/toJson/fromJson', () {
      const opt = CustomizationOption(name: 'Oat Milk', extraPrice: 30);
      expect(opt.isAvailable, isTrue);

      final unavailableOpt = opt.copyWith(isAvailable: false);
      expect(unavailableOpt.isAvailable, isFalse);
      expect(unavailableOpt.name, 'Oat Milk');
      expect(unavailableOpt.extraPrice, 30);

      final json = unavailableOpt.toJson();
      expect(json['isAvailable'], isFalse);

      final fromJson = CustomizationOption.fromJson(json);
      expect(fromJson.name, 'Oat Milk');
      expect(fromJson.isAvailable, isFalse);
      expect(fromJson.extraPrice, 30.0);
    });

    test('MenuItem computed availability getters correctly count and detect unavailable options', () {
      final testItem = MenuItem(
        id: 'test_item_1',
        name: 'Celestial Latte',
        description: 'Test coffee latte',
        price: 150,
        category: ItemCategory.coffee,
        icon: '☕',
        inStock: true,
        customizationGroups: [
          CustomizationGroup(
            id: 'temp',
            title: 'Temperature',
            options: [
              CustomizationOption(name: 'Hot', isAvailable: true),
              CustomizationOption(name: 'Iced', isAvailable: false),
            ],
          ),
          CustomizationGroup(
            id: 'milk',
            title: 'Milk Choice',
            options: [
              CustomizationOption(name: 'Dairy', isAvailable: true),
              CustomizationOption(name: 'Oat Milk', isAvailable: false),
            ],
          ),
        ],
      );

      expect(testItem.hasUnavailableOptions, isTrue);
      expect(testItem.unavailableOptionsCount, 2);
      expect(testItem.allUnavailableOptions.length, 2);
      expect(testItem.allUnavailableOptions[0].name, 'Iced');
      expect(testItem.allUnavailableOptions[1].name, 'Oat Milk');
    });
  });

  group('PosProvider Availability Controls', () {
    test('setItemAvailability updates inStock and triggers updates', () {
      final provider = PosProvider();
      final firstItem = provider.menuItems.first;
      final originalStock = firstItem.inStock;

      provider.setItemAvailability(firstItem.id, !originalStock);
      expect(provider.menuItems.firstWhere((i) => i.id == firstItem.id).inStock, !originalStock);

      // Revert back
      provider.setItemAvailability(firstItem.id, originalStock);
      expect(provider.menuItems.firstWhere((i) => i.id == firstItem.id).inStock, originalStock);
    });

    test('toggleOptionAvailability updates modifier availability per item', () {
      final provider = PosProvider();
      final itemWithCustom = provider.menuItems.firstWhere(
        (m) => m.customizationGroups.isNotEmpty && m.customizationGroups.first.options.isNotEmpty,
      );
      final group = itemWithCustom.customizationGroups.first;
      final opt = group.options.first;

      // Mark option unavailable
      provider.toggleOptionAvailability(itemWithCustom.id, group.id, opt.name, false);
      var currentItem = provider.menuItems.firstWhere((m) => m.id == itemWithCustom.id);
      var currentOpt = currentItem.customizationGroups
          .firstWhere((g) => g.id == group.id)
          .options
          .firstWhere((o) => o.name == opt.name);
      expect(currentOpt.isAvailable, isFalse);
      expect(currentItem.hasUnavailableOptions, isTrue);

      // Reset item options
      provider.resetAllItemOptionsAvailability(itemWithCustom.id);
      currentItem = provider.menuItems.firstWhere((m) => m.id == itemWithCustom.id);
      currentOpt = currentItem.customizationGroups
          .firstWhere((g) => g.id == group.id)
          .options
          .firstWhere((o) => o.name == opt.name);
      expect(currentOpt.isAvailable, isTrue);
    });

    test('toggleOptionAvailabilityGlobally updates modifier across all menu items', () {
      final provider = PosProvider();
      const targetOptName = 'Oat Milk';

      // 86 globally
      provider.toggleOptionAvailabilityGlobally(targetOptName, false);
      for (final item in provider.menuItems) {
        for (final group in item.customizationGroups) {
          for (final opt in group.options) {
            if (opt.name.trim() == targetOptName) {
              expect(opt.isAvailable, isFalse);
            }
          }
        }
      }

      // Reset all availability
      provider.resetAllAvailability();
      expect(provider.totalUnavailableItemsCount, 0);
      expect(provider.totalUnavailableOptionsCount, 0);
    });
  });

  group('CustomizationDialog Availability UI & Fallback', () {
    testWidgets('CustomizationDialog auto-selects available option when default is 86\'d', (tester) async {
      final itemWithUnavailableDefault = MenuItem(
        id: 'test_fallback_item',
        name: 'Iced Caramel Machiato',
        description: 'Test coffee with fallback',
        price: 160,
        category: ItemCategory.coffee,
        icon: '☕',
        inStock: true,
        customizationGroups: [
          CustomizationGroup(
            id: 'temp',
            title: 'Temperature',
            defaultIndex: 0,
            options: [
              CustomizationOption(name: 'Hot', isAvailable: false), // Default is 86'd
              CustomizationOption(name: 'Iced', isAvailable: true),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomizationDialog(
              item: itemWithUnavailableDefault,
              onAddToCart: (qty, custs, notes) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // "86'd" badge must be rendered for the Hot option
      expect(find.text("86'd"), findsWidgets);

      // "Hot" and "Iced" should be rendered
      expect(find.text('Hot'), findsOneWidget);
      expect(find.text('Iced'), findsOneWidget);

      // Tapping unavailable option triggers warning snackbar
      await tester.tap(find.text('Hot'));
      await tester.pump();
      expect(find.textContaining('is currently 86\'d'), findsOneWidget);
    });
  });

  group('Dinner & Rice Meals Category & Combo Item', () {
    test('Special Combo Meal and dinner items exist with correct category and pricing', () {
      final provider = PosProvider();
      final dinnerItems = provider.menuItems.where((i) => i.category == ItemCategory.dinner).toList();
      expect(dinnerItems.isNotEmpty, isTrue);

      final comboMeal = dinnerItems.firstWhere((i) => i.id == 'dn_1');
      expect(comboMeal.name, 'Special Combo Meal');
      expect(comboMeal.price, 99.00);
      expect(comboMeal.imagePath, 'assets/images/special_combo_meal.jpg');
      expect(comboMeal.tags.contains('Combo Meal'), isTrue);
      expect(comboMeal.isKitchenDish, isTrue);

      // Verify all dinner items are recognized as kitchen dishes for KDS
      for (final item in dinnerItems) {
        expect(item.isKitchenDish, isTrue, reason: '${item.name} should be kitchen dish');
        expect(item.customizationGroups.any((g) => g.id == 'rice_choice'), isTrue);
      }
    });

    testWidgets('CustomizationDialog renders Dinner customizations (Rice Choice & Add-ons)', (tester) async {
      final provider = PosProvider();
      final comboMeal = provider.menuItems.firstWhere((i) => i.id == 'dn_1');

      int addedQty = 0;
      List<SelectedCustomization> addedCusts = [];
      String? addedNotes;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomizationDialog(
              item: comboMeal,
              onAddToCart: (qty, custs, notes) {
                addedQty = qty;
                addedCusts = custs;
                addedNotes = notes;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header info
      expect(find.text('Special Combo Meal'), findsOneWidget);
      expect(find.text('Rice Choice'), findsOneWidget);
      expect(find.text('Steamed White Rice'), findsOneWidget);
      expect(find.text('Garlic Fried Rice'), findsOneWidget);

      // Tap Add to Cart
      await tester.tap(find.textContaining('Add to Order'));
      await tester.pumpAndSettle();

      expect(addedQty, 1);
      expect(addedCusts.any((c) => c.optionName == 'Steamed White Rice'), isTrue);
      expect(addedNotes, isNull);
    });
  });

  group('Table QR Code Security & Verification', () {
    test('getTableToken generates unique, deterministic tokens per table', () {
      final token1 = KdsServerService.getTableToken('1');
      final token2 = KdsServerService.getTableToken('2');
      final tokenTable1 = KdsServerService.getTableToken('Table 1');

      expect(token1.isNotEmpty, isTrue);
      expect(token2.isNotEmpty, isTrue);
      expect(token1, equals(tokenTable1), reason: 'Table 1 and 1 must produce identical token');
      expect(token1, isNot(equals(token2)), reason: 'Table 1 and Table 2 must produce distinct tokens');
    });

    test('parseTableAndToken parses both combined string (T1-TOKEN) and separate query params', () {
      final token1 = KdsServerService.getTableToken('1');
      final parsedCombined = KdsServerService.parseTableAndToken('T1-$token1', null);
      expect(parsedCombined.tableNumber, '1');
      expect(parsedCombined.token, token1);

      final parsedSeparate = KdsServerService.parseTableAndToken('1', token1);
      expect(parsedSeparate.tableNumber, '1');
      expect(parsedSeparate.token, token1);

      final parsedNoToken = KdsServerService.parseTableAndToken('2', null);
      expect(parsedNoToken.tableNumber, '2');
      expect(parsedNoToken.token, isNull);
    });

    test('isValidTableToken accurately authenticates only matching table and token', () {
      final token1 = KdsServerService.getTableToken('1');
      final token2 = KdsServerService.getTableToken('2');

      // Combined format e.g. T1-C7E30D12
      expect(KdsServerService.isValidTableToken('T1-$token1', null), isTrue);
      expect(KdsServerService.isValidTableToken('T2-$token2', null), isTrue);

      // Separate format
      expect(KdsServerService.isValidTableToken('1', token1), isTrue);
      expect(KdsServerService.isValidTableToken('Table 1', token1), isTrue);
      expect(KdsServerService.isValidTableToken('2', token2), isTrue);

      // Attacker changes link from Table 1 to Table 2 (token mismatch or missing)
      expect(KdsServerService.isValidTableToken('T2-$token1', null), isFalse, reason: 'Table 1 token cannot access Table 2');
      expect(KdsServerService.isValidTableToken('2', token1), isFalse, reason: 'Table 1 token cannot access Table 2');
      expect(KdsServerService.isValidTableToken('1', token2), isFalse, reason: 'Table 2 token cannot access Table 1');
      expect(KdsServerService.isValidTableToken('2', null), isFalse, reason: 'Accessing table=2 directly without unique code is rejected');
      expect(KdsServerService.isValidTableToken('T2', null), isFalse);
      expect(KdsServerService.isValidTableToken('2', ''), isFalse);
      expect(KdsServerService.isValidTableToken('2', 'forged_fake_token'), isFalse);
    });

    test('getTableOrderUrl generates unique table URL with unique alphanumeric code per table', () {
      final server = KdsServerService();
      final urlTable1 = server.getTableOrderUrl('1');
      final urlTable2 = server.getTableOrderUrl('2');

      final token1 = KdsServerService.getTableToken('1');
      final token2 = KdsServerService.getTableToken('2');

      expect(urlTable1, contains('table=T1-$token1'));
      expect(urlTable2, contains('table=T2-$token2'));
      expect(urlTable1, isNot(equals(urlTable2)));
    });
  });
}
