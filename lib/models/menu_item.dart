enum ItemCategory {
  all('All Items', '✨'),
  coffee('Coffee', '☕'),
  nonEspresso('Non Espresso', '🍵'),
  milktea('Milktea', '🧋'),
  frappe('Frappe', '🥤'),
  cheesecakeSeries('Cheesecake Series', '🍰'),
  streetBites('Street Bites', '🍟'),
  pastaDishes('Pasta Dishes', '🍝'),
  sandwich('Sandwich', '🥪'),
  dinner('Dinner & Rice Meals', '🍛'),
  custom('Custom', '🏷️');

  final String label;
  final String icon;
  const ItemCategory(this.label, this.icon);
}

class CustomCategory {
  final String id;
  final String name;
  final String icon;
  final bool isKitchenDish;

  const CustomCategory({
    required this.id,
    required this.name,
    this.icon = '🏷️',
    this.isKitchenDish = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'isKitchenDish': isKitchenDish,
      };

  factory CustomCategory.fromJson(Map<String, dynamic> json) => CustomCategory(
        id: json['id'] as String? ?? 'custom_${json['name'] ?? 'cat'}',
        name: json['name'] as String? ?? 'Custom',
        icon: json['icon'] as String? ?? '🏷️',
        isKitchenDish: json['isKitchenDish'] as bool? ?? false,
      );

  CustomCategory copyWith({
    String? id,
    String? name,
    String? icon,
    bool? isKitchenDish,
  }) {
    return CustomCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      isKitchenDish: isKitchenDish ?? this.isKitchenDish,
    );
  }
}

class CategoryTabItem {
  final String id;
  final String label;
  final String icon;
  final bool isCustom;
  final bool isKitchenDish;

  const CategoryTabItem({
    required this.id,
    required this.label,
    required this.icon,
    this.isCustom = false,
    this.isKitchenDish = false,
  });
}

class CustomizationOption {
  final String name;
  final double extraPrice;
  final bool isAvailable;

  const CustomizationOption({
    required this.name,
    this.extraPrice = 0.0,
    this.isAvailable = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'extraPrice': extraPrice,
        'isAvailable': isAvailable,
      };

  factory CustomizationOption.fromJson(Map<String, dynamic> json) {
    return CustomizationOption(
      name: json['name'] as String? ?? '',
      extraPrice: (json['extraPrice'] as num?)?.toDouble() ?? 0.0,
      isAvailable: json['isAvailable'] as bool? ?? true,
    );
  }

  CustomizationOption copyWith({
    String? name,
    double? extraPrice,
    bool? isAvailable,
  }) {
    return CustomizationOption(
      name: name ?? this.name,
      extraPrice: extraPrice ?? this.extraPrice,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

class CustomizationGroup {
  final String id;
  final String title;
  final List<CustomizationOption> options;
  final bool isMultiSelect;
  final bool isRequired;
  final int defaultIndex;

  const CustomizationGroup({
    required this.id,
    required this.title,
    required this.options,
    this.isMultiSelect = false,
    this.isRequired = false,
    this.defaultIndex = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'options': options.map((o) => o.toJson()).toList(),
        'isMultiSelect': isMultiSelect,
        'isRequired': isRequired,
        'defaultIndex': defaultIndex,
      };

  factory CustomizationGroup.fromJson(Map<String, dynamic> json) {
    return CustomizationGroup(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((o) => CustomizationOption.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
      isMultiSelect: json['isMultiSelect'] as bool? ?? false,
      isRequired: json['isRequired'] as bool? ?? false,
      defaultIndex: json['defaultIndex'] as int? ?? 0,
    );
  }

  CustomizationGroup copyWith({
    String? id,
    String? title,
    List<CustomizationOption>? options,
    bool? isMultiSelect,
    bool? isRequired,
    int? defaultIndex,
  }) {
    return CustomizationGroup(
      id: id ?? this.id,
      title: title ?? this.title,
      options: options ?? this.options,
      isMultiSelect: isMultiSelect ?? this.isMultiSelect,
      isRequired: isRequired ?? this.isRequired,
      defaultIndex: defaultIndex ?? this.defaultIndex,
    );
  }
}

class MenuItem {
  final String id;
  final String name;
  final ItemCategory category;
  final String? customCategory;
  final double price;
  final String description;
  final String icon;
  final List<String> tags;
  bool inStock;
  int stockCount;
  final double rating;
  final String? imagePath;
  final String? imageBase64;
  final List<CustomizationGroup> customizationGroups;

  MenuItem({
    required this.id,
    required this.name,
    required this.category,
    this.customCategory,
    required this.price,
    required this.description,
    required this.icon,
    this.tags = const [],
    this.inStock = true,
    this.stockCount = 50,
    this.rating = 4.9,
    this.imagePath,
    this.imageBase64,
    this.customizationGroups = const [],
  });

  String get categoryLabel {
    if (customCategory != null && customCategory!.trim().isNotEmpty) {
      return customCategory!.trim();
    }
    return category.label;
  }

  bool get isKitchenDish {
    if (tags.any((t) => t.toLowerCase().contains('kitchen'))) return true;
    if (category == ItemCategory.streetBites ||
        category == ItemCategory.pastaDishes ||
        category == ItemCategory.sandwich ||
        category == ItemCategory.dinner) {
      return true;
    }
    final n = name.toLowerCase();
    return n.contains('buffalo') ||
        n.contains('wing') ||
        n.contains('fries') ||
        n.contains('stick') ||
        n.contains('lumpia') ||
        n.contains('shanghai') ||
        n.contains('pasta') ||
        n.contains('carbonara') ||
        n.contains('aglio') ||
        n.contains('sandwich') ||
        n.contains('toast') ||
        n.contains('bbq') ||
        n.contains('barbeque') ||
        n.contains('combo') ||
        n.contains('rice') ||
        n.contains('inasal') ||
        n.contains('sisig');
  }

  bool get hasUnavailableOptions {
    for (final group in customizationGroups) {
      for (final option in group.options) {
        if (!option.isAvailable) return true;
      }
    }
    return false;
  }

  int get unavailableOptionsCount {
    int count = 0;
    for (final group in customizationGroups) {
      for (final option in group.options) {
        if (!option.isAvailable) count++;
      }
    }
    return count;
  }

  List<CustomizationOption> get allUnavailableOptions {
    final list = <CustomizationOption>[];
    for (final group in customizationGroups) {
      for (final option in group.options) {
        if (!option.isAvailable) list.add(option);
      }
    }
    return list;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'customCategory': customCategory,
        'categoryLabel': categoryLabel,
        'price': price,
        'description': description,
        'icon': icon,
        'tags': tags,
        'inStock': inStock,
        'stockCount': stockCount,
        'rating': rating,
        'imagePath': imagePath,
        'imageBase64': imageBase64,
        'customizationGroups': customizationGroups.map((g) => g.toJson()).toList(),
      };

  /// Lightweight representation specifically for order items (excludes heavy Base64 image blobs)
  Map<String, dynamic> toOrderJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'customCategory': customCategory,
        'categoryLabel': categoryLabel,
        'price': price,
        'description': description,
        'icon': icon,
        'tags': tags,
        'inStock': inStock,
        'stockCount': stockCount,
        'rating': rating,
        'imagePath': imagePath,
      };

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final catName = json['category'] as String? ?? 'coffee';
    final cat = ItemCategory.values.firstWhere(
      (c) => c.name == catName,
      orElse: () => ItemCategory.coffee,
    );
    final customCat = json['customCategory'] as String?;

    return MenuItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: cat,
      customCategory: customCat,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '☕',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      inStock: json['inStock'] as bool? ?? true,
      stockCount: json['stockCount'] as int? ?? 50,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      imagePath: json['imagePath'] as String?,
      imageBase64: json['imageBase64'] as String?,
      customizationGroups: (json['customizationGroups'] as List<dynamic>?)
              ?.map((g) => CustomizationGroup.fromJson(g as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  MenuItem copyWith({
    String? id,
    String? name,
    ItemCategory? category,
    String? customCategory,
    bool clearCustomCategory = false,
    double? price,
    String? description,
    String? icon,
    List<String>? tags,
    bool? inStock,
    int? stockCount,
    double? rating,
    String? imagePath,
    String? imageBase64,
    List<CustomizationGroup>? customizationGroups,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      customCategory: clearCustomCategory ? null : (customCategory ?? this.customCategory),
      price: price ?? this.price,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      tags: tags ?? this.tags,
      inStock: inStock ?? this.inStock,
      stockCount: stockCount ?? this.stockCount,
      rating: rating ?? this.rating,
      imagePath: imagePath ?? this.imagePath,
      imageBase64: imageBase64 ?? this.imageBase64,
      customizationGroups: customizationGroups ?? this.customizationGroups,
    );
  }

  // Standard Coffee Customizations
  static List<CustomizationGroup> get defaultCoffeeCustomizations => [
    const CustomizationGroup(
      id: 'temp',
      title: 'Temperature',
      isRequired: true,
      defaultIndex: 1,
      options: [
        CustomizationOption(name: 'Hot', extraPrice: 0.00),
        CustomizationOption(name: 'Iced', extraPrice: 0.00),
      ],
    ),
    const CustomizationGroup(
      id: 'sweetness',
      title: 'Sweetness Level',
      isRequired: true,
      defaultIndex: 3,
      options: [
        CustomizationOption(name: 'No Sugar (0%)', extraPrice: 0.00),
        CustomizationOption(name: 'Less Sweet (50%)', extraPrice: 0.00),
        CustomizationOption(name: 'Less Sweet (75%)', extraPrice: 0.00),
        CustomizationOption(name: 'Regular (100%)', extraPrice: 0.00),
      ],
    ),
    const CustomizationGroup(
      id: 'coffee_addons',
      title: 'Add-ons & Extras',
      isMultiSelect: true,
      options: [
        CustomizationOption(name: 'Extra Espresso Shot', extraPrice: 25.00),
        CustomizationOption(name: 'Caramel Drizzle', extraPrice: 15.00),
        CustomizationOption(name: 'Vanilla Syrup', extraPrice: 15.00),
        CustomizationOption(name: 'Hazelnut Syrup', extraPrice: 15.00),
      ],
    ),
  ];

  // Milktea Customizations (16oz base, 22oz +₱10)
  static List<CustomizationGroup> get defaultMilkteaCustomizations => [
    const CustomizationGroup(
      id: 'size',
      title: 'Cup Size',
      isRequired: true,
      defaultIndex: 0,
      options: [
        CustomizationOption(name: '16oz', extraPrice: 0.00),
        CustomizationOption(name: '22oz', extraPrice: 10.00),
      ],
    ),
    const CustomizationGroup(
      id: 'sweetness',
      title: 'Sugar Level',
      isRequired: true,
      defaultIndex: 2,
      options: [
        CustomizationOption(name: '0% Sugar', extraPrice: 0.00),
        CustomizationOption(name: '25% Sugar', extraPrice: 0.00),
        CustomizationOption(name: '50% Sugar', extraPrice: 0.00),
        CustomizationOption(name: '75% Sugar', extraPrice: 0.00),
        CustomizationOption(name: '100% Regular', extraPrice: 0.00),
      ],
    ),
    const CustomizationGroup(
      id: 'milktea_addons',
      title: 'Sinkers & Add-ons',
      isMultiSelect: true,
      options: [
        CustomizationOption(name: 'Black Tapioca Pearls', extraPrice: 10.00),
        CustomizationOption(name: 'Cream Cheese Foam', extraPrice: 20.00),
        CustomizationOption(name: 'Nata de Coco', extraPrice: 10.00),
        CustomizationOption(name: 'Crushed Oreo', extraPrice: 15.00),
        CustomizationOption(name: 'Egg Pudding', extraPrice: 15.00),
      ],
    ),
  ];

  // Cheesecake Series Customizations (16oz base, 22oz varies)
  static List<CustomizationGroup> getCheesecakeCustomizations({double sizeDiff = 20.00}) => [
    CustomizationGroup(
      id: 'size',
      title: 'Cup Size',
      isRequired: true,
      defaultIndex: 0,
      options: [
        const CustomizationOption(name: '16oz', extraPrice: 0.00),
        CustomizationOption(name: '22oz', extraPrice: sizeDiff),
      ],
    ),
    const CustomizationGroup(
      id: 'sweetness',
      title: 'Sugar Level',
      isRequired: true,
      defaultIndex: 2,
      options: [
        CustomizationOption(name: '50% Sugar', extraPrice: 0.00),
        CustomizationOption(name: '75% Sugar', extraPrice: 0.00),
        CustomizationOption(name: '100% Regular', extraPrice: 0.00),
      ],
    ),
    const CustomizationGroup(
      id: 'cheesecake_addons',
      title: 'Cheesecake Add-ons',
      isMultiSelect: true,
      options: [
        CustomizationOption(name: 'Extra Cream Cheese Wall', extraPrice: 25.00),
        CustomizationOption(name: 'Extra Tapioca Pearls', extraPrice: 10.00),
        CustomizationOption(name: 'Extra Nutella Drizzle', extraPrice: 20.00),
        CustomizationOption(name: 'Extra Crushed Oreo', extraPrice: 15.00),
      ],
    ),
  ];

  // Frappe Customizations
  static List<CustomizationGroup> get defaultFrappeCustomizations => [
    const CustomizationGroup(
      id: 'whipped_cream',
      title: 'Whipped Cream',
      isRequired: true,
      defaultIndex: 0,
      options: [
        CustomizationOption(name: 'With Whipped Cream', extraPrice: 0.00),
        CustomizationOption(name: 'No Whipped Cream', extraPrice: 0.00),
      ],
    ),
    const CustomizationGroup(
      id: 'frappe_addons',
      title: 'Frappe Add-ons',
      isMultiSelect: true,
      options: [
        CustomizationOption(name: 'Extra Espresso Shot', extraPrice: 25.00),
        CustomizationOption(name: 'Caramel Syrup Drizzle', extraPrice: 15.00),
        CustomizationOption(name: 'Dark Chocolate Drizzle', extraPrice: 15.00),
        CustomizationOption(name: 'Crushed Cookies', extraPrice: 15.00),
      ],
    ),
  ];

  // Food / Bites / Pasta / Sandwich Customizations
  static List<CustomizationGroup> get defaultFoodCustomizations => [
    const CustomizationGroup(
      id: 'prep',
      title: 'Preparation',
      isRequired: true,
      defaultIndex: 0,
      options: [
        CustomizationOption(name: 'Serve Freshly Cooked / Warm', extraPrice: 0.00),
        CustomizationOption(name: 'Packed for Takeout', extraPrice: 0.00),
      ],
    ),
    const CustomizationGroup(
      id: 'food_addons',
      title: 'Sides & Dips',
      isMultiSelect: true,
      options: [
        CustomizationOption(name: 'Garlic Mayo Dip', extraPrice: 15.00),
        CustomizationOption(name: 'Spicy Cheese Sauce', extraPrice: 15.00),
        CustomizationOption(name: 'Sweet Chili Sauce', extraPrice: 10.00),
        CustomizationOption(name: 'Extra Parmesan Cheese', extraPrice: 20.00),
      ],
    ),
  ];

  // Dinner & Rice Meals Customizations
  static List<CustomizationGroup> get defaultDinnerCustomizations => [
    const CustomizationGroup(
      id: 'rice_choice',
      title: 'Rice Choice',
      isRequired: true,
      defaultIndex: 0,
      options: [
        CustomizationOption(name: 'Steamed White Rice', extraPrice: 0.00),
        CustomizationOption(name: 'Garlic Fried Rice', extraPrice: 15.00),
        CustomizationOption(name: 'Extra Steamed Rice', extraPrice: 20.00),
      ],
    ),
    const CustomizationGroup(
      id: 'dinner_flavor',
      title: 'Flavor & Spice',
      isRequired: true,
      defaultIndex: 0,
      options: [
        CustomizationOption(name: 'Regular (Sweet BBQ Glaze)', extraPrice: 0.00),
        CustomizationOption(name: 'Spicy (Chili Flakes & Scallions)', extraPrice: 0.00),
      ],
    ),
    const CustomizationGroup(
      id: 'dinner_addons',
      title: 'Add-ons & Sides',
      isMultiSelect: true,
      options: [
        CustomizationOption(name: 'Extra 1 Pc BBQ Skewer', extraPrice: 35.00),
        CustomizationOption(name: 'Extra 2 Pcs Lumpia Shanghai', extraPrice: 30.00),
        CustomizationOption(name: 'Fried Egg (Sunny-Side Up)', extraPrice: 20.00),
        CustomizationOption(name: 'House Blend Iced Tea (16oz)', extraPrice: 25.00),
        CustomizationOption(name: 'Spicy Vinegar Dip', extraPrice: 10.00),
        CustomizationOption(name: 'Sweet Chili Sauce', extraPrice: 10.00),
      ],
    ),
  ];
}

// Complete Official Celestial Cafe Menu
final List<MenuItem> initialCelestialMenu = [
  // 1. COFFEE
  MenuItem(
    id: 'cof_1',
    name: 'Americano',
    category: ItemCategory.coffee,
    price: 90.00,
    description: 'Rich freshly pulled espresso shots diluted with hot or iced filtered water.',
    icon: '☕',
    imagePath: 'assets/images/hero_coffee_splash.jpg',
    tags: ['Classic', 'Hot/Iced'],
    stockCount: 100,
    customizationGroups: MenuItem.defaultCoffeeCustomizations,
  ),
  MenuItem(
    id: 'cof_2',
    name: 'Spanish Latte',
    category: ItemCategory.coffee,
    price: 95.00,
    description: 'Espresso with textured milk and sweet condensed milk for a creamy finish.',
    icon: '☕',
    imagePath: 'assets/images/hero_latte_art.jpg',
    tags: ['Sweet Cream', 'Hot/Iced'],
    stockCount: 80,
    customizationGroups: MenuItem.defaultCoffeeCustomizations,
  ),
  MenuItem(
    id: 'cof_3',
    name: 'Caramel Macchiato',
    category: ItemCategory.coffee,
    price: 90.00,
    description: 'Freshly steamed milk with vanilla, marked with espresso and finished with caramel drizzle.',
    icon: '🌟',
    imagePath: 'assets/images/hero_iced_caramel.jpg',
    tags: ['Caramel Drizzle', 'Classic'],
    stockCount: 75,
    customizationGroups: MenuItem.defaultCoffeeCustomizations,
  ),
  MenuItem(
    id: 'cof_4',
    name: 'Dirty Matcha',
    category: ItemCategory.coffee,
    price: 120.00,
    description: 'Premium ceremonial Japanese matcha layered with fresh milk and a bold espresso shot.',
    icon: '🍵',
    tags: ['Specialty', 'Signature'],
    stockCount: 60,
    customizationGroups: MenuItem.defaultCoffeeCustomizations,
  ),
  MenuItem(
    id: 'cof_5',
    name: 'Hazelnut Latte',
    category: ItemCategory.coffee,
    price: 100.00,
    description: 'Smooth espresso, roasted hazelnut syrup infusion, and velvety textured milk.',
    icon: '🌰',
    tags: ['Nutty & Rich'],
    stockCount: 70,
    customizationGroups: MenuItem.defaultCoffeeCustomizations,
  ),
  MenuItem(
    id: 'cof_6',
    name: 'Iced Latte',
    category: ItemCategory.coffee,
    price: 90.00,
    description: 'Chilled espresso poured over fresh milk and ice cubes.',
    icon: '🧊',
    imagePath: 'assets/images/hero_latte_art.jpg',
    tags: ['Refreshing', 'Classic'],
    stockCount: 85,
    customizationGroups: MenuItem.defaultCoffeeCustomizations,
  ),

  // 2. NON ESPRESSO
  MenuItem(
    id: 'nesp_1',
    name: 'Celestial Signature Latte',
    category: ItemCategory.nonEspresso,
    price: 100.00,
    description: 'House specialty handcrafted celestial latte blend with silky sweet foam.',
    icon: '✨',
    imagePath: 'assets/images/hero_coffee_splash.jpg',
    tags: ['Signature', 'House Special'],
    stockCount: 90,
    customizationGroups: MenuItem.defaultCoffeeCustomizations,
  ),
  MenuItem(
    id: 'nesp_2',
    name: 'Matcha Latte',
    category: ItemCategory.nonEspresso,
    price: 115.00,
    description: 'Authentic stone-ground green tea whisked with rich steamed or iced milk.',
    icon: '🍵',
    tags: ['Superfood', 'Specialty'],
    stockCount: 65,
    customizationGroups: MenuItem.defaultCoffeeCustomizations,
  ),
  MenuItem(
    id: 'nesp_3',
    name: 'Iced Chocolate',
    category: ItemCategory.nonEspresso,
    price: 95.00,
    description: 'Decadent dark cocoa melted with fresh milk and served chilled over ice.',
    icon: '🍫',
    tags: ['Rich Cocoa', 'Chilled'],
    stockCount: 75,
    customizationGroups: MenuItem.defaultCoffeeCustomizations,
  ),

  // 3. MILKTEA (16oz: ₱29, 22oz: ₱39)
  MenuItem(
    id: 'mt_1',
    name: 'Dark Choco Milktea',
    category: ItemCategory.milktea,
    price: 29.00,
    description: 'Deep cocoa infused black tea with creamy milk and chewy brown sugar pearls (16oz / 22oz).',
    icon: '🧋',
    tags: ['Rich Chocolate', '16oz/22oz'],
    stockCount: 120,
    customizationGroups: MenuItem.defaultMilkteaCustomizations,
  ),
  MenuItem(
    id: 'mt_2',
    name: 'Salted Caramel Milktea',
    category: ItemCategory.milktea,
    price: 29.00,
    description: 'Artisanal black tea, buttery caramel, Himalayan sea salt, and cream (16oz / 22oz).',
    icon: '🧋',
    tags: ['Sweet & Salty', '16oz/22oz'],
    stockCount: 110,
    customizationGroups: MenuItem.defaultMilkteaCustomizations,
  ),
  MenuItem(
    id: 'mt_3',
    name: 'Cookies & Cream Milktea',
    category: ItemCategory.milktea,
    price: 29.00,
    description: 'Creamy milktea blended with crushed chocolate sandwich cookie bits (16oz / 22oz).',
    icon: '🧋',
    tags: ['Cookies & Cream', '16oz/22oz'],
    stockCount: 130,
    customizationGroups: MenuItem.defaultMilkteaCustomizations,
  ),
  MenuItem(
    id: 'mt_4',
    name: 'Wintermelon Milktea',
    category: ItemCategory.milktea,
    price: 29.00,
    description: 'Classic caramel-sweet wintermelon syrup blended with robust milk tea (16oz / 22oz).',
    icon: '🧋',
    tags: ['Classic Tea', '16oz/22oz'],
    stockCount: 140,
    customizationGroups: MenuItem.defaultMilkteaCustomizations,
  ),
  MenuItem(
    id: 'mt_5',
    name: 'Okinawa Milktea',
    category: ItemCategory.milktea,
    price: 29.00,
    description: 'Roasted brown sugar infused Japanese Okinawa milk tea (16oz / 22oz).',
    icon: '🧋',
    tags: ['Brown Sugar', '16oz/22oz'],
    stockCount: 115,
    customizationGroups: MenuItem.defaultMilkteaCustomizations,
  ),

  // 4. FRAPPE
  MenuItem(
    id: 'fr_1',
    name: 'Caramel Frappe',
    category: ItemCategory.frappe,
    price: 120.00,
    description: 'Ice-blended espresso and sweet caramel syrup, topped with fluffy whipped cream and caramel drizzle.',
    icon: '🥤',
    tags: ['Ice Blended', 'Caramel'],
    stockCount: 60,
    customizationGroups: MenuItem.defaultFrappeCustomizations,
  ),
  MenuItem(
    id: 'fr_2',
    name: 'Mochaccino Frappe',
    category: ItemCategory.frappe,
    price: 115.00,
    description: 'Blended espresso with rich dark chocolate, fresh milk, and whipped chocolate cream.',
    icon: '🥤',
    tags: ['Chocolatey', 'Ice Blended'],
    stockCount: 55,
    customizationGroups: MenuItem.defaultFrappeCustomizations,
  ),
  MenuItem(
    id: 'fr_3',
    name: 'French Vanilla Frappe',
    category: ItemCategory.frappe,
    price: 115.00,
    description: 'Smooth French vanilla ice-blended beverage topped with vanilla bean whipped cream.',
    icon: '🥤',
    tags: ['Smooth & Sweet', 'Ice Blended'],
    stockCount: 50,
    customizationGroups: MenuItem.defaultFrappeCustomizations,
  ),

  // 5. CHEESECAKE SERIES
  MenuItem(
    id: 'cs_1',
    name: 'Nuttella Oreo Cheesecake',
    category: ItemCategory.cheesecakeSeries,
    price: 95.00,
    description: 'Rich cream cheese wall, real Nutella spread, and crushed Oreos (16oz: ₱95, 22oz: ₱105).',
    icon: '🍰',
    tags: ['Signature Cheesecake', '16oz/22oz'],
    stockCount: 50,
    customizationGroups: MenuItem.getCheesecakeCustomizations(sizeDiff: 10.00),
  ),
  MenuItem(
    id: 'cs_2',
    name: 'Oreo Cheesecake',
    category: ItemCategory.cheesecakeSeries,
    price: 95.00,
    description: 'Signature cream cheese spread with generous crushed Oreo cookies (16oz: ₱95, 22oz: ₱115).',
    icon: '🍰',
    tags: ['Cream Cheese', '16oz/22oz'],
    stockCount: 55,
    customizationGroups: MenuItem.getCheesecakeCustomizations(sizeDiff: 20.00),
  ),
  MenuItem(
    id: 'cs_3',
    name: 'Dark Choco Nuttela Cheesecake',
    category: ItemCategory.cheesecakeSeries,
    price: 95.00,
    description: 'Decadent dark chocolate, creamy Nutella swirl, and rich cheesecake blend (16oz: ₱95, 22oz: ₱115).',
    icon: '🍰',
    tags: ['Ultra Decadent', '16oz/22oz'],
    stockCount: 45,
    customizationGroups: MenuItem.getCheesecakeCustomizations(sizeDiff: 20.00),
  ),

  // 6. STREET BITES
  MenuItem(
    id: 'sb_1',
    name: 'French Fries',
    category: ItemCategory.streetBites,
    price: 70.00,
    description: 'Crispy golden potato fries seasoned to perfection with dipping sauce.',
    icon: '🍟',
    tags: ['Crispy Snack', 'Hot'],
    stockCount: 80,
    customizationGroups: MenuItem.defaultFoodCustomizations,
  ),
  MenuItem(
    id: 'sb_2',
    name: 'Buffalo Wings',
    category: ItemCategory.streetBites,
    price: 99.00,
    description: 'Crispy fried chicken wings tossed in tangy spicy buffalo glaze.',
    icon: '🍗',
    tags: ['Spicy Glazed', 'Savory'],
    stockCount: 40,
    customizationGroups: MenuItem.defaultFoodCustomizations,
  ),
  MenuItem(
    id: 'sb_3',
    name: 'Cheese Stick',
    category: ItemCategory.streetBites,
    price: 60.00,
    description: 'Crispy spring rolls filled with gooey melted cheddar cheese.',
    icon: '🧀',
    tags: ['Cheesy', 'Finger Food'],
    stockCount: 65,
    customizationGroups: MenuItem.defaultFoodCustomizations,
  ),
  MenuItem(
    id: 'sb_4',
    name: 'Lumpia Shanghai',
    category: ItemCategory.streetBites,
    price: 80.00,
    description: 'Traditional savory pork spring rolls fried extra crisp with sweet chili sauce.',
    icon: '🥢',
    tags: ['Filipino Favorite', 'Crispy'],
    stockCount: 50,
    customizationGroups: MenuItem.defaultFoodCustomizations,
  ),

  // 7. PASTA DISHES
  MenuItem(
    id: 'pas_1',
    name: 'Aglio (Aglio Olio)',
    category: ItemCategory.pastaDishes,
    price: 99.00,
    description: 'Al dente spaghetti tossed in extra virgin olive oil, sautéed garlic, chili flakes & herbs.',
    icon: '🍝',
    tags: ['Garlic & Herbs', 'Savory'],
    stockCount: 35,
    customizationGroups: MenuItem.defaultFoodCustomizations,
  ),
  MenuItem(
    id: 'pas_2',
    name: 'Carbonara',
    category: ItemCategory.pastaDishes,
    price: 99.00,
    description: 'Creamy pasta tossed with crispy bacon bits, egg yolk cream, and grated parmesan.',
    icon: '🍝',
    tags: ['Bacon & Cream', 'Pasta'],
    stockCount: 40,
    customizationGroups: MenuItem.defaultFoodCustomizations,
  ),

  // 8. SANDWICH
  MenuItem(
    id: 'snd_1',
    name: 'Korean Sandwich',
    category: ItemCategory.sandwich,
    price: 99.00,
    description: 'Korean street-style egg drop sandwich with fluffy scrambled eggs, ham & sweet mayo glaze.',
    icon: '🥪',
    tags: ['Signature Toast', 'Hot'],
    stockCount: 35,
    customizationGroups: MenuItem.defaultFoodCustomizations,
  ),
  MenuItem(
    id: 'snd_2',
    name: 'Club House Sandwich',
    category: ItemCategory.sandwich,
    price: 99.00,
    description: 'Triple-decker toasted sandwich layered with chicken spread, ham, cheese, egg & lettuce.',
    icon: '🥪',
    tags: ['Classic Club', 'Heavy Snack'],
    stockCount: 30,
    customizationGroups: MenuItem.defaultFoodCustomizations,
  ),
  MenuItem(
    id: 'snd_3',
    name: 'French Toast',
    category: ItemCategory.sandwich,
    price: 99.00,
    description: 'Golden brioche toast dipped in rich vanilla custard and grilled with maple syrup & butter.',
    icon: '🍞',
    tags: ['Sweet Toast', 'Breakfast'],
    stockCount: 30,
    customizationGroups: MenuItem.defaultFoodCustomizations,
  ),

  // 9. DINNER & RICE MEALS
  MenuItem(
    id: 'dn_1',
    name: 'Special Combo Meal',
    category: ItemCategory.dinner,
    price: 99.00,
    description: '2 pcs savory grilled pork barbeque & 3 pcs crispy lumpia shanghai served with steamed rice, toasted garlic, chili & dipping sauce.',
    icon: '🍛',
    imagePath: 'assets/images/special_combo_meal.jpg',
    tags: ['Dinner Special', 'Combo Meal', 'Best Seller', 'Hot Rice Meal'],
    stockCount: 50,
    customizationGroups: MenuItem.defaultDinnerCustomizations,
  ),
  MenuItem(
    id: 'dn_2',
    name: 'Pork Barbeque Rice Meal',
    category: ItemCategory.dinner,
    price: 89.00,
    description: '3 pcs tender skewered pork barbeque grilled in signature sweet savory Filipino glaze, served with steamed rice.',
    icon: '🍢',
    tags: ['Pork BBQ', 'Dinner Meal'],
    stockCount: 45,
    customizationGroups: MenuItem.defaultDinnerCustomizations,
  ),
  MenuItem(
    id: 'dn_3',
    name: 'Lumpia Shanghai Rice Meal',
    category: ItemCategory.dinner,
    price: 85.00,
    description: '6 pcs crispy golden pork spring rolls served with steamed rice and sweet chili dipping sauce.',
    icon: '🥢',
    tags: ['Crispy Lumpia', 'Dinner Meal'],
    stockCount: 50,
    customizationGroups: MenuItem.defaultDinnerCustomizations,
  ),
  MenuItem(
    id: 'dn_4',
    name: 'Chicken Inasal Rice Meal',
    category: ItemCategory.dinner,
    price: 99.00,
    description: 'Char-grilled marinated chicken quarter infused with lemongrass, calamansi and achuete oil, served with garlic rice.',
    icon: '🍗',
    tags: ['Chicken Inasal', 'Chef Special'],
    stockCount: 40,
    customizationGroups: MenuItem.defaultDinnerCustomizations,
  ),
  MenuItem(
    id: 'dn_5',
    name: 'Sizzling Pork Sisig Rice Meal',
    category: ItemCategory.dinner,
    price: 109.00,
    description: 'Crispy minced pork seasoned with calamansi, onions, chili peppers, topped with egg and served with steamed rice.',
    icon: '🍳',
    tags: ['Sizzling Sisig', 'Filipino Classic'],
    stockCount: 35,
    customizationGroups: MenuItem.defaultDinnerCustomizations,
  ),
];
