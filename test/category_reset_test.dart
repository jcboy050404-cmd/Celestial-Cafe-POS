import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celestial_pos/models/menu_item.dart';
import 'package:celestial_pos/providers/pos_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Category Management & Reset Tests', () {
    test('PosProvider loads default categories and menu items on start', () async {
      final provider = PosProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(provider.menuItems.isNotEmpty, true);
      expect(provider.allCategoryTabs.length, 10); // 'all' + 9 system categories

      // Check that built-in categories have items
      final coffeeItems = provider.menuItems.where((i) => i.category == ItemCategory.coffee).length;
      expect(coffeeItems > 0, true);
    });

    test('Adding custom categories updates allCategoryTabs and menu item assignment', () async {
      final provider = PosProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      provider.addCustomCategory(name: 'Seasonal Specials', icon: '🌟', isKitchenDish: true);

      expect(provider.customCategories.length, 1);
      expect(provider.customCategories.first.name, 'Seasonal Specials');
      expect(provider.customCategories.first.icon, '🌟');
      expect(provider.customCategories.first.isKitchenDish, true);

      // allCategoryTabs now contains the custom category
      expect(provider.allCategoryTabs.any((t) => t.id == 'Seasonal Specials'), true);
      expect(provider.allCategoryTabs.length, 11);
    });

    test('resetCategoriesAndMenu clears custom categories and restores standard catalog', () async {
      final provider = PosProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      // Add custom categories and modify menu items
      provider.addCustomCategory(name: 'Custom Cat 1', icon: '🍹');
      provider.addCustomCategory(name: 'Custom Cat 2', icon: '🧇');
      expect(provider.customCategories.length, 2);

      await provider.clearAllMenuItems();
      expect(provider.menuItems.isEmpty, true);

      // Now call resetCategoriesAndMenu
      await provider.resetCategoriesAndMenu();

      expect(provider.customCategories.isEmpty, true);
      expect(provider.menuItems.length, initialCelestialMenu.length);
      expect(provider.selectedCategoryId, 'all');
      expect(provider.selectedCategory, ItemCategory.all);

      // Verify category items count
      for (final cat in ItemCategory.values.where((c) => c != ItemCategory.all && c != ItemCategory.custom)) {
        final count = provider.menuItems.where((i) => i.category == cat && (i.customCategory == null || i.customCategory!.isEmpty)).length;
        expect(count > 0, true, reason: 'Category ${cat.label} should have items after reset');
      }
    });

    test('resetAllData resets custom categories and restores default cafe menu catalog', () async {
      final provider = PosProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      provider.addCustomCategory(name: 'Bakery', icon: '🥐');
      expect(provider.customCategories.length, 1);

      await provider.resetAllData();

      expect(provider.customCategories.isEmpty, true);
      expect(provider.menuItems.length, initialCelestialMenu.length);
      expect(provider.orders.isEmpty, true);
      expect(provider.currentOrderSequence, 1);
    });
  });
}
