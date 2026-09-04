import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celestial_pos/models/menu_item.dart';
import 'package:celestial_pos/providers/pos_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CustomCategory Model & MenuItem Integration', () {
    test('CustomCategory serialization and copyWith', () {
      const cat = CustomCategory(
        id: 'cat_desserts_1',
        name: 'Desserts & Sweets',
        icon: '🍰',
        isKitchenDish: true,
      );

      final json = cat.toJson();
      expect(json['id'], 'cat_desserts_1');
      expect(json['name'], 'Desserts & Sweets');
      expect(json['icon'], '🍰');
      expect(json['isKitchenDish'], true);

      final fromJson = CustomCategory.fromJson(json);
      expect(fromJson.id, cat.id);
      expect(fromJson.name, cat.name);
      expect(fromJson.icon, cat.icon);
      expect(fromJson.isKitchenDish, isTrue);

      final updated = cat.copyWith(name: 'Signature Desserts', icon: '🍨', isKitchenDish: false);
      expect(updated.name, 'Signature Desserts');
      expect(updated.icon, '🍨');
      expect(updated.isKitchenDish, isFalse);
    });

    test('MenuItem with customCategory correctly resolves categoryLabel and isKitchenDish', () {
      final item = MenuItem(
        id: 'custom_waffle_1',
        name: 'Belgian Waffle with Ice Cream',
        category: ItemCategory.custom,
        customCategory: 'Desserts',
        price: 120.0,
        description: 'Crispy golden waffle topped with vanilla ice cream',
        icon: '🧇',
        tags: ['Kitchen Cooked'],
      );

      expect(item.category, ItemCategory.custom);
      expect(item.customCategory, 'Desserts');
      expect(item.categoryLabel, 'Desserts');
      expect(item.isKitchenDish, isTrue); // because tags include 'Kitchen Cooked'

      final json = item.toJson();
      expect(json['category'], 'custom');
      expect(json['customCategory'], 'Desserts');
      expect(json['categoryLabel'], 'Desserts');

      final revived = MenuItem.fromJson(json);
      expect(revived.customCategory, 'Desserts');
      expect(revived.categoryLabel, 'Desserts');
      expect(revived.price, 120.0);
    });
  });

  group('PosProvider Custom Category Management & Filtering', () {
    test('PosProvider adds, updates, and deletes custom categories with item re-mapping', () async {
      final provider = PosProvider();

      // Initial state: 0 custom categories, but allCategoryTabs has built-in categories
      expect(provider.customCategories.isEmpty, isTrue);
      final initialTabsCount = provider.allCategoryTabs.length;
      expect(initialTabsCount, greaterThanOrEqualTo(10)); // All + coffee, nonEspresso, milktea, frappe, cheesecake, bites, pasta, sandwich, dinner

      // Add a custom category "Desserts"
      provider.addCustomCategory(name: 'Desserts', icon: '🍨', isKitchenDish: false);
      expect(provider.customCategories.length, 1);
      expect(provider.customCategories.first.name, 'Desserts');
      expect(provider.customCategories.first.icon, '🍨');
      expect(provider.allCategoryTabs.length, initialTabsCount + 1);

      // Create an item assigned to "Desserts"
      final dessertItem = MenuItem(
        id: 'cake_slice_1',
        name: 'Red Velvet Cake Slice',
        category: ItemCategory.custom,
        customCategory: 'Desserts',
        price: 140.0,
        description: 'Rich red velvet cake with cream cheese frosting',
        icon: '🍰',
      );
      provider.addNewMenuItem(dessertItem);

      // Select the custom category tab
      provider.setCategoryById('Desserts');
      expect(provider.selectedCategoryId, 'Desserts');
      expect(provider.filteredMenuItems.any((i) => i.id == 'cake_slice_1'), isTrue);
      // Other categories should not appear in this filtered list
      expect(provider.filteredMenuItems.any((i) => i.category == ItemCategory.coffee), isFalse);

      // Update custom category name: "Desserts" -> "Artisanal Desserts"
      provider.updateCustomCategory(
        provider.customCategories.first.id,
        name: 'Artisanal Desserts',
        icon: '🎂',
        isKitchenDish: true,
      );
      expect(provider.customCategories.first.name, 'Artisanal Desserts');
      expect(provider.customCategories.first.icon, '🎂');
      expect(provider.customCategories.first.isKitchenDish, isTrue);

      // The item's customCategory should automatically update to "Artisanal Desserts"
      final updatedItem = provider.menuItems.firstWhere((i) => i.id == 'cake_slice_1');
      expect(updatedItem.customCategory, 'Artisanal Desserts');

      // Now filter by "Artisanal Desserts"
      provider.setCategoryById('Artisanal Desserts');
      expect(provider.filteredMenuItems.any((i) => i.id == 'cake_slice_1'), isTrue);

      // Delete the custom category
      provider.deleteCustomCategory(provider.customCategories.first.id);
      expect(provider.customCategories.isEmpty, isTrue);

      // The item should be safely reassigned to coffee and customCategory cleared
      final reassignedItem = provider.menuItems.firstWhere((i) => i.id == 'cake_slice_1');
      expect(reassignedItem.category, ItemCategory.coffee);
      expect(reassignedItem.customCategory, isNull);
    });

    test('getCategoryTabsJsonForCustomer exports all tabs including custom categories', () {
      final provider = PosProvider();
      provider.addCustomCategory(name: 'Breakfast Bowls', icon: '🥣', isKitchenDish: true);

      final tabsJson = provider.getCategoryTabsJsonForCustomer();
      expect(tabsJson.any((t) => t['id'] == 'Breakfast Bowls' && t['isCustom'] == true && t['isKitchenDish'] == true), isTrue);
    });
  });
}
