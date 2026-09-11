import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:celestial_pos/models/menu_item.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:celestial_pos/screens/food_costing_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Food Costing Model Tests', () {
    test('Ingredient calculates line cost correctly from qty and costPerUnit', () {
      const ing = Ingredient(
        name: 'Graham Crushed',
        qty: 200,
        unit: 'g',
        costPerUnit: 0.25,
      );

      expect(ing.name, 'Graham Crushed');
      expect(ing.qty, 200);
      expect(ing.unit, 'g');
      expect(ing.costPerUnit, 0.25);
      expect(ing.cost, 50.0); // 200 * 0.25 = 50
    });

    test('Ingredient falls back to legacy flat cost when qty or costPerUnit is 0', () {
      const legacyIng = Ingredient(
        name: 'Coffee Beans',
        cost: 35.0,
      );

      expect(legacyIng.cost, 35.0);
    });

    test('OtherMaterial serializes and deserializes properly', () {
      const mat = OtherMaterial(name: 'Paper Cup 16oz', cost: 3.50);
      final json = mat.toJson();
      final fromJson = OtherMaterial.fromJson(json);

      expect(fromJson.name, 'Paper Cup 16oz');
      expect(fromJson.cost, 3.50);
    });

    test('MenuItem batch yield and costing computations match spreadsheet formula', () {
      final item = MenuItem(
        id: 'test_graham',
        name: 'Graham Balls (Box of 20)',
        price: 20.0,
        description: 'Graham snack balls',
        icon: '🍪',
        category: ItemCategory.streetBites,
        batchYield: 20,
        desiredMarginPercent: 70.0,
        ingredients: const [
          Ingredient(name: 'Condensed Milk', qty: 1, unit: 'can', costPerUnit: 45.0),
          Ingredient(name: 'Crushed Graham', qty: 200, unit: 'g', costPerUnit: 0.20),
        ],
        otherMaterials: const [
          OtherMaterial(name: 'Packaging Box', cost: 15.0),
        ],
      );

      expect(item.totalIngredientCost, 85.0); // 45 + 40
      expect(item.totalOtherMaterialsCost, 15.0);
      expect(item.totalBatchCost, 100.0);
      expect(item.costPerPiece, 5.0);
      expect(item.suggestedSellingPrice, closeTo(16.67, 0.01));
      expect(item.profitPerPiece, 15.0); // 20.0 price - 5.0 cost
      expect(item.profitMarginPercent, 75.0); // (15 / 20) * 100
    });
  });

  group('PosProvider Costing Analytics Getters', () {
    test('Calculates itemsWithIngredients and average profit margin', () {
      final provider = PosProvider();

      // Default menu items have no ingredients set yet
      expect(provider.itemsWithIngredients.isEmpty, isTrue);
      expect(provider.averageProfitMarginPercent, 0.0);

      // Update an existing item with costing
      final existingItem = provider.menuItems.first;
      final costedItem = existingItem.copyWith(
        price: 120.0,
        ingredients: const [
          Ingredient(name: 'Espresso', qty: 1, unit: 'shot', costPerUnit: 15.0),
          Ingredient(name: 'Fresh Milk', qty: 150, unit: 'ml', costPerUnit: 0.10),
        ],
      );

      provider.updateMenuItem(costedItem);

      expect(provider.itemsWithIngredients.length, 1);
      expect(provider.mostProfitableItem?.id, existingItem.id);
      expect(provider.averageProfitMarginPercent, greaterThan(0));
    });
  });

  group('FoodCostingScreen Widget Tests', () {
    testWidgets('FoodCostingScreen renders KPI headers and tabs', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final posProvider = PosProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<PosProvider>.value(
            value: posProvider,
            child: const Scaffold(body: FoodCostingScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Check Header KPIs
      expect(find.text('AVG PROFIT MARGIN'), findsOneWidget);
      expect(find.text('MOST PROFITABLE'), findsOneWidget);
      expect(find.text('Menu Cost Table'), findsOneWidget);
      expect(find.text('Recipe Calculator'), findsOneWidget);

      // Switch to Recipe Calculator tab
      await tester.tap(find.text('Recipe Calculator'));
      await tester.pumpAndSettle();

      expect(find.text('PRODUCT / RECIPE'), findsOneWidget);
      expect(find.text('INGREDIENT COSTING'), findsOneWidget);
      expect(find.text('COSTING SUMMARY'), findsOneWidget);
      expect(find.text('BREAK-EVEN / SALES ANALYSIS'), findsOneWidget);
    });
  });
}
