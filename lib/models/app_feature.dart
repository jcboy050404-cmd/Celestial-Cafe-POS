import 'package:flutter/material.dart';

/// Represents configurable application features that can be granted or restricted per user account.
class AppFeature {
  static const String foodCosting = 'food_costing';
  static const String analytics = 'analytics';
  static const String inventory = 'inventory';
  static const String orderHistory = 'order_history';
  static const String storeSettings = 'store_settings';

  static const List<AppFeatureItem> allFeatures = [
    AppFeatureItem(
      key: foodCosting,
      title: 'Food Costing & Recipes',
      description: 'Recipe costing, raw ingredients, and profit margin analysis.',
      icon: Icons.calculate_outlined,
    ),
    AppFeatureItem(
      key: analytics,
      title: 'Analytics & Reports',
      description: 'Sales summaries, hourly charts, and top-selling product metrics.',
      icon: Icons.bar_chart_rounded,
    ),
    AppFeatureItem(
      key: inventory,
      title: 'Menu & Stock Management',
      description: 'Add or edit items, categories, ingredients, and adjust stock counts.',
      icon: Icons.inventory_2_outlined,
    ),
    AppFeatureItem(
      key: orderHistory,
      title: 'Order History & Receipts',
      description: 'Review previous transactions, reprint receipts, and process refunds.',
      icon: Icons.history_rounded,
    ),
    AppFeatureItem(
      key: storeSettings,
      title: 'Store Settings & Hardware',
      description: 'Printer setups, discounts, tax rates, atmosphere, and cloud sync.',
      icon: Icons.settings_outlined,
    ),
  ];
}

class AppFeatureItem {
  final String key;
  final String title;
  final String description;
  final IconData icon;

  const AppFeatureItem({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
  });
}
