import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../services/auth_service.dart';
import '../services/cloud_backup_service.dart';
import '../theme/celestial_theme.dart';

class PosProvider extends ChangeNotifier {
  static const String _keyThemeMode = 'celestial_theme_mode_v1';
  static const String _keyMenuItems = 'celestial_menu_items_v1';
  static const String _keyOrders = 'celestial_orders_v1';
  static const String _keyOrderSeq = 'celestial_order_seq_v1';
  static const String _keyActiveCashier = 'celestial_active_cashier_v1';
  static const String _keyCustomLogo = 'celestial_custom_logo_v1';
  static const String _keyStoreName = 'celestial_store_name_v1';
  static const String _keyStoreTagline = 'celestial_store_tagline_v1';
  static const String _keyStoreAddress = 'celestial_store_address_v1';
  static const String _keyUiScale = 'celestial_ui_scale_v1';
  static const String _keyCustomCategories = 'celestial_custom_categories_v1';
  static const String _keySigBannerEnabled = 'celestial_sig_banner_enabled_v1';
  static const String _keySigBannerBadge = 'celestial_sig_banner_badge_v1';
  static const String _keySigBannerTitle = 'celestial_sig_banner_title_v1';
  static const String _keySigBannerSubtitle = 'celestial_sig_banner_subtitle_v1';
  static const String _keySigBannerButtonText = 'celestial_sig_banner_btn_text_v1';
  static const String _keySigBannerItemId = 'celestial_sig_banner_item_id_v1';
  static const String _keySigBannerImage = 'celestial_sig_banner_image_v1';

  // Display & Text Size Scaling (for Cashiers accessibility)
  double _uiScale = 1.0;
  double get uiScale => _uiScale;

  // Store & Branding
  String? _customLogoBase64;
  Uint8List? _customLogoBytes;
  String _storeName = 'CELESTIAL CAFE';
  String _storeTagline = '';
  String _storeAddress = 'Celestial Cafe Main Branch\nTel: (02) 8721-4900 • TIN #482-901-382-000';

  // Signature Craft Hero Banner Customization
  bool _signatureBannerEnabled = true;
  String _signatureBannerBadge = 'CELESTIAL SIGNATURE CRAFT';
  String _signatureBannerTitle = 'Celestial Signature Latte';
  String _signatureBannerSubtitle = 'House specialty handcrafted celestial latte blend with silky sweet foam';
  String _signatureBannerButtonText = 'Order';
  String _signatureBannerItemId = 'nesp_1';
  String? _signatureBannerImageBase64;
  Uint8List? _signatureBannerImageBytes;

  // Menu Catalog & Filtering
  List<MenuItem> _menuItems = List.from(initialCelestialMenu);
  ItemCategory _selectedCategory = ItemCategory.all;
  String _selectedCategoryId = 'all';
  List<CustomCategory> _customCategories = [];
  String _searchQuery = '';
  String _selectedTag = 'All';

  // Navigation (0: POS, 1: History, 2: Stock, 3: Analytics)
  int _currentNavIndex = 0;

  // Active Cart State
  final List<OrderItem> _cart = [];
  OrderType _orderType = OrderType.dineIn;
  String _tableNumber = 'Table 01';
  String _customerName = '';
  double _discountPercentage = 0.0;
  double _customDiscountAmount = 0.0;
  final double _taxRate = 0.0; // All menu prices are inclusive of tax

  // Staff & Cashier
  String _activeCashier = 'Main POS';
  final List<String> _cashiers = [
    'Main POS',
  ];

  // Order Sequences & Storage (Persistent across app restarts, starts on #1)
  int _orderSequence = 1;
  final List<Order> _orders = [];
  bool _isLoaded = false;

  PosProvider() {
    _initData();
  }

  bool get isLoaded => _isLoaded;
  int get currentOrderSequence => _orderSequence;

  void resetOrderSequence({int startNumber = 1}) {
    _orderSequence = startNumber;
    _saveOrdersToStorage();
    notifyListeners();
  }

  static void repairCorruptedStorage() {
    if (!kIsWeb && Platform.isWindows) {
      try {
        final appData = Platform.environment['APPDATA'];
        if (appData == null || appData.isEmpty) return;

        final sharedPrefsDir = Directory('$appData\\celestial_pos\\shared_preferences');
        if (sharedPrefsDir.existsSync()) {
          final files = sharedPrefsDir.listSync();
          for (var file in files) {
            if (file is File && file.path.endsWith('.json')) {
              try {
                final content = file.readAsStringSync();
                if (content.trim().isEmpty || !content.trim().startsWith('{')) {
                  file.writeAsStringSync('{}');
                }
              } catch (_) {
                try {
                  file.writeAsStringSync('{}');
                } catch (_) {}
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print('Error checking Windows shared_preferences files: $e');
      }
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      if (kDebugMode) print('Warning: SharedPreferences threw error: $e');
      try {
        repairCorruptedStorage();
        return await SharedPreferences.getInstance();
      } catch (_) {
        // ignore: invalid_use_of_visible_for_testing_member
        SharedPreferences.setMockInitialValues({});
        return await SharedPreferences.getInstance();
      }
    }
  }

  Future<void> _initData() async {
    try {
      final prefs = await _getPrefs();

      // 1. Order Sequence
      final lastSavedDate = prefs.getString('celestial_last_order_date');
      final todayDate = DateTime.now().toIso8601String().substring(0, 10);
      final savedSeq = prefs.getInt(_keyOrderSeq);

      if (lastSavedDate != null && lastSavedDate != todayDate) {
        _orderSequence = 1;
        await prefs.setInt(_keyOrderSeq, 1);
        await prefs.setString('celestial_last_order_date', todayDate);
      } else {
        _orderSequence = savedSeq ?? 1;
        if (savedSeq == null) {
          await prefs.setInt(_keyOrderSeq, 1);
          await prefs.setString('celestial_last_order_date', todayDate);
        }
      }

      // 2. Load menu items
      final savedMenuJson = prefs.getString(_keyMenuItems);
      if (savedMenuJson != null && savedMenuJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(savedMenuJson) as List<dynamic>;
          _menuItems = decoded
              .map((item) => MenuItem.fromJson(item as Map<String, dynamic>))
              .toList();
          if (_menuItems.isEmpty) {
            _menuItems = List.from(initialCelestialMenu);
            await _saveMenuToStorage();
          }
        } catch (e) {
          if (kDebugMode) print('Error parsing stored menu JSON: $e');
          _menuItems = List.from(initialCelestialMenu);
          await _saveMenuToStorage();
        }
      } else {
        _menuItems = List.from(initialCelestialMenu);
        await _saveMenuToStorage();
      }

      // 3. Load custom categories
      final savedCategoriesJson = prefs.getString(_keyCustomCategories);
      if (savedCategoriesJson != null && savedCategoriesJson.isNotEmpty) {
        try {
          final decodedCats = jsonDecode(savedCategoriesJson) as List<dynamic>;
          _customCategories = decodedCats
              .map((c) => CustomCategory.fromJson(c as Map<String, dynamic>))
              .toList();
        } catch (e) {
          if (kDebugMode) print('Error parsing stored custom categories: $e');
        }
      }

      // 4. Load orders
      final savedOrdersJson = prefs.getString(_keyOrders);
      if (savedOrdersJson != null && savedOrdersJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(savedOrdersJson) as List<dynamic>;
          final loadedOrders = decoded
              .map((o) {
                try {
                  return Order.fromJson(o as Map<String, dynamic>);
                } catch (e) {
                  return null;
                }
              })
              .whereType<Order>()
              .toList();
          _orders.clear();
          _orders.addAll(loadedOrders);
        } catch (e) {
          if (kDebugMode) print('Error parsing stored orders JSON: $e');
        }
      }

      // 5. Load Custom Logo & Store details
      final savedLogo = prefs.getString(_keyCustomLogo);
      if (savedLogo != null && savedLogo.isNotEmpty) {
        _customLogoBase64 = savedLogo;
        try {
          _customLogoBytes = base64Decode(savedLogo);
        } catch (_) {}
      }
      final savedStoreName = prefs.getString(_keyStoreName);
      if (savedStoreName != null && savedStoreName.isNotEmpty) {
        _storeName = savedStoreName;
      }
      final savedTagline = prefs.getString(_keyStoreTagline);
      if (savedTagline != null && savedTagline.isNotEmpty) {
        _storeTagline = savedTagline;
      }
      final savedAddress = prefs.getString(_keyStoreAddress);
      if (savedAddress != null && savedAddress.isNotEmpty) {
        _storeAddress = savedAddress;
      }
      final savedUiScale = prefs.getDouble(_keyUiScale);
      if (savedUiScale != null && savedUiScale >= 0.80 && savedUiScale <= 1.50) {
        _uiScale = savedUiScale;
      }

      // 6. Cashier
      final savedCashier = prefs.getString(_keyActiveCashier);
      if (savedCashier != null && savedCashier.isNotEmpty) {
        _activeCashier = savedCashier;
        if (!_cashiers.contains(_activeCashier)) {
          _cashiers.add(_activeCashier);
        }
      }

      // 7. Signature Craft Banner Customization
      final savedSigBannerEnabled = prefs.getBool(_keySigBannerEnabled);
      if (savedSigBannerEnabled != null) {
        _signatureBannerEnabled = savedSigBannerEnabled;
      }
      final savedSigBannerBadge = prefs.getString(_keySigBannerBadge);
      if (savedSigBannerBadge != null && savedSigBannerBadge.isNotEmpty) {
        _signatureBannerBadge = savedSigBannerBadge;
      }
      final savedSigBannerTitle = prefs.getString(_keySigBannerTitle);
      if (savedSigBannerTitle != null && savedSigBannerTitle.isNotEmpty) {
        _signatureBannerTitle = savedSigBannerTitle;
      }
      final savedSigBannerSubtitle = prefs.getString(_keySigBannerSubtitle);
      if (savedSigBannerSubtitle != null && savedSigBannerSubtitle.isNotEmpty) {
        _signatureBannerSubtitle = savedSigBannerSubtitle;
      }
      final savedSigBannerBtnText = prefs.getString(_keySigBannerButtonText);
      if (savedSigBannerBtnText != null && savedSigBannerBtnText.isNotEmpty) {
        _signatureBannerButtonText = savedSigBannerBtnText;
      }
      final savedSigBannerItemId = prefs.getString(_keySigBannerItemId);
      if (savedSigBannerItemId != null && savedSigBannerItemId.isNotEmpty) {
        _signatureBannerItemId = savedSigBannerItemId;
      }
      final savedSigBannerImage = prefs.getString(_keySigBannerImage);
      if (savedSigBannerImage != null && savedSigBannerImage.isNotEmpty) {
        _signatureBannerImageBase64 = savedSigBannerImage;
        try {
          _signatureBannerImageBytes = base64Decode(savedSigBannerImage);
        } catch (_) {}
      }
      final savedTheme = prefs.getString(_keyThemeMode);
      if (savedTheme == PosThemeMode.londonBistro.name) {
        CelestialTheme.setThemeMode(PosThemeMode.londonBistro);
      } else {
        CelestialTheme.setThemeMode(PosThemeMode.classicEspresso);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading from local storage: $e');
      }
    }

    _pruneOldOrders();
    _isLoaded = true;
    notifyListeners();
  }

  PosThemeMode get themeMode => CelestialTheme.currentMode;

  Future<void> setThemeMode(PosThemeMode mode) async {
    CelestialTheme.setThemeMode(mode);
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_keyThemeMode, mode.name);
    } catch (e) {
      if (kDebugMode) print('Error saving theme mode: $e');
    }
    notifyListeners();
  }

  void _pruneOldOrders() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 48));
    final before = _orders.length;
    _orders.removeWhere((o) =>
        (o.status == OrderStatus.completed || o.status == OrderStatus.cancelled) &&
        o.createdAt.isBefore(cutoff));
    if (_orders.length != before) {
      _saveOrdersToStorage();
    }
  }

  Future<void> setUiScale(double scale) async {
    final clamped = scale.clamp(0.85, 1.45);
    _uiScale = double.parse(clamped.toStringAsFixed(2));
    notifyListeners();
    try {
      final prefs = await _getPrefs();
      await prefs.setDouble(_keyUiScale, _uiScale);
    } catch (e) {
      if (kDebugMode) print('Error saving UI scale: $e');
    }
  }

  Future<void> resetUiScale() async {
    await setUiScale(1.0);
  }

  Future<void> _saveMenuToStorage() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = jsonEncode(_menuItems.map((m) => m.toJson()).toList());
      await prefs.setString(_keyMenuItems, jsonStr);
    } catch (e) {
      if (kDebugMode) print('Error saving menu to storage: $e');
    }
  }

  Future<void> _saveCustomCategoriesToStorage() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = jsonEncode(_customCategories.map((c) => c.toJson()).toList());
      await prefs.setString(_keyCustomCategories, jsonStr);
    } catch (e) {
      if (kDebugMode) print('Error saving custom categories to storage: $e');
    }
  }

  Timer? _saveOrdersDebounceTimer;

  void _scheduleSaveOrders() {
    _saveOrdersDebounceTimer?.cancel();
    _saveOrdersDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveOrdersToStorage();
    });
  }

  Future<void> _saveOrdersToStorage() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = jsonEncode(_orders.map((o) => o.toJson()).toList());
      await prefs.setString(_keyOrders, jsonStr);
      await prefs.setInt(_keyOrderSeq, _orderSequence);
      await prefs.setString('celestial_last_order_date', DateTime.now().toIso8601String().substring(0, 10));
    } catch (e) {
      if (kDebugMode) print('Error saving orders to storage: $e');
    }
  }

  Future<void> _saveCashierToStorage() async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_keyActiveCashier, _activeCashier);
    } catch (e) {
      if (kDebugMode) print('Error saving cashier to storage: $e');
    }
  }

  // Getters - Store & Branding
  Uint8List? get customLogoBytes => _customLogoBytes;
  String? get customLogoBase64 => _customLogoBase64;
  bool get hasCustomLogo => _customLogoBytes != null;
  String get storeName => _storeName;
  String get storeTagline => _storeTagline;
  String get storeAddress => _storeAddress;

  // Getters - Signature Craft Hero Banner
  bool get signatureBannerEnabled => _signatureBannerEnabled;
  String get signatureBannerBadge => _signatureBannerBadge;
  String get signatureBannerTitle => _signatureBannerTitle;
  String get signatureBannerSubtitle => _signatureBannerSubtitle;
  String get signatureBannerButtonText => _signatureBannerButtonText;
  String get signatureBannerItemId => _signatureBannerItemId;
  Uint8List? get signatureBannerImageBytes => _signatureBannerImageBytes;
  bool get hasCustomSignatureBannerImage => _signatureBannerImageBytes != null;

  // Getters - Menu & Navigation
  List<MenuItem> get menuItems => _menuItems;
  ItemCategory get selectedCategory => _selectedCategory;
  String get selectedCategoryId => _selectedCategoryId;
  List<CustomCategory> get customCategories => List.unmodifiable(_customCategories);

  List<CategoryTabItem> get allCategoryTabs {
    final list = <CategoryTabItem>[
      const CategoryTabItem(id: 'all', label: 'All Items', icon: '✨'),
      const CategoryTabItem(id: 'coffee', label: 'Coffee', icon: '☕'),
      const CategoryTabItem(id: 'nonEspresso', label: 'Non Espresso', icon: '🍵'),
      const CategoryTabItem(id: 'milktea', label: 'Milktea', icon: '🧋'),
      const CategoryTabItem(id: 'frappe', label: 'Frappe', icon: '🥤'),
      const CategoryTabItem(id: 'cheesecakeSeries', label: 'Cheesecake Series', icon: '🍰'),
      const CategoryTabItem(id: 'streetBites', label: 'Street Bites', icon: '🍟'),
      const CategoryTabItem(id: 'pastaDishes', label: 'Pasta Dishes', icon: '🍝', isKitchenDish: true),
      const CategoryTabItem(id: 'sandwich', label: 'Sandwich', icon: '🥪', isKitchenDish: true),
      const CategoryTabItem(id: 'dinner', label: 'Dinner & Rice Meals', icon: '🍛', isKitchenDish: true),
    ];
    for (final custom in _customCategories) {
      list.add(CategoryTabItem(
        id: custom.name,
        label: custom.name,
        icon: custom.icon,
        isCustom: true,
        isKitchenDish: custom.isKitchenDish,
      ));
    }
    return list;
  }

  List<Map<String, dynamic>> getCategoryTabsJsonForCustomer() {
    return allCategoryTabs.map((t) => {
      'id': t.id,
      'label': t.label,
      'icon': t.icon,
      'isCustom': t.isCustom,
      'isKitchenDish': t.isKitchenDish,
    }).toList();
  }

  String get searchQuery => _searchQuery;
  String get selectedTag => _selectedTag;
  int get currentNavIndex => _currentNavIndex;

  // Filtered Menu Items
  List<MenuItem> get filteredMenuItems {
    return _menuItems.where((item) {
      if (_selectedCategoryId == 'all') {
        // Show all
      } else if (_selectedCategory != ItemCategory.custom && _selectedCategory != ItemCategory.all) {
        if (item.category != _selectedCategory) return false;
      } else {
        if (item.customCategory != _selectedCategoryId) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = item.name.toLowerCase().contains(query);
        final matchDesc = item.description.toLowerCase().contains(query);
        final matchTag = item.tags.any((tag) => tag.toLowerCase().contains(query));
        if (!matchName && !matchDesc && !matchTag) return false;
      }

      if (_selectedTag != 'All') {
        if (!item.tags.contains(_selectedTag)) return false;
      }

      return true;
    }).toList();
  }

  // Getters - Cart State
  List<OrderItem> get cart => List.unmodifiable(_cart);
  OrderType get orderType => _orderType;
  String get tableNumber => _tableNumber;
  String get customerName => _customerName;
  double get discountPercentage => _discountPercentage;
  double get customDiscountAmount => _customDiscountAmount;
  double get taxRate => _taxRate;
  String get activeCashier => _activeCashier;
  List<String> get cashiers => List.unmodifiable(_cashiers);

  int get cartItemCount =>
      _cart.fold(0, (sum, item) => sum + item.quantity);

  double get cartSubtotal =>
      _cart.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get cartDiscountAmount {
    if (_customDiscountAmount > 0) return _customDiscountAmount;
    return cartSubtotal * (_discountPercentage / 100);
  }

  double get cartTaxAmount => 0.0;

  double get cartGrandTotal {
    return (cartSubtotal - cartDiscountAmount).clamp(0.0, double.infinity);
  }

  // Getters - Orders
  List<Order> get orders => List.unmodifiable(_orders);

  List<Order> get pendingOrders =>
      _orders.where((o) => o.status == OrderStatus.pending).toList();

  List<Order> get activeOrders => _orders
      .where((o) =>
          o.status == OrderStatus.confirmed ||
          o.status == OrderStatus.preparing ||
          o.status == OrderStatus.ready)
      .toList()
    ..sort((a, b) {
      final comp = a.createdAt.compareTo(b.createdAt);
      if (comp != 0) return comp;
      return a.orderNumber.compareTo(b.orderNumber);
    });

  List<Order> get preparingOrders =>
      _orders.where((o) => o.status == OrderStatus.preparing).toList();

  List<Order> get readyOrders =>
      _orders.where((o) => o.status == OrderStatus.ready).toList();

  List<Order> get completedOrders =>
      _orders.where((o) => o.status == OrderStatus.completed).toList();

  List<Order> get cancelledOrders =>
      _orders.where((o) => o.status == OrderStatus.cancelled).toList();

  // Navigation Setters
  void setNavIndex(int index) {
    _currentNavIndex = index;
    notifyListeners();
  }

  void setCategory(ItemCategory category) {
    _selectedCategory = category;
    _selectedCategoryId = category.name;
    notifyListeners();
  }

  void setCategoryById(String categoryId) {
    _selectedCategoryId = categoryId;
    final matchedEnum = ItemCategory.values.firstWhere(
      (c) => c.name == categoryId,
      orElse: () => ItemCategory.custom,
    );
    _selectedCategory = matchedEnum;
    notifyListeners();
  }

  void addCustomCategory({required String name, String icon = '🏷️', bool isKitchenDish = false}) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    final exists = _customCategories.any((c) => c.name.toLowerCase() == cleanName.toLowerCase());
    if (exists) return;

    final newCat = CustomCategory(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      icon: icon.trim().isEmpty ? '🏷️' : icon.trim(),
      isKitchenDish: isKitchenDish,
    );
    _customCategories.add(newCat);
    _saveCustomCategoriesToStorage();
    notifyListeners();
  }

  void updateCustomCategory(String id, {required String name, required String icon, required bool isKitchenDish}) {
    final index = _customCategories.indexWhere((c) => c.id == id);
    if (index < 0) return;
    final oldName = _customCategories[index].name;
    final newName = name.trim().isEmpty ? oldName : name.trim();
    final updated = _customCategories[index].copyWith(
      name: newName,
      icon: icon.trim().isEmpty ? _customCategories[index].icon : icon.trim(),
      isKitchenDish: isKitchenDish,
    );
    _customCategories[index] = updated;

    if (oldName != newName) {
      for (var i = 0; i < _menuItems.length; i++) {
        if (_menuItems[i].customCategory == oldName) {
          _menuItems[i] = _menuItems[i].copyWith(customCategory: newName);
        }
      }
      if (_selectedCategoryId == oldName) {
        _selectedCategoryId = newName;
      }
      _saveMenuToStorage();
    }

    _saveCustomCategoriesToStorage();
    notifyListeners();
  }

  void deleteCustomCategory(String id) {
    final index = _customCategories.indexWhere((c) => c.id == id);
    if (index < 0) return;
    final deletedName = _customCategories[index].name;
    _customCategories.removeAt(index);

    bool menuModified = false;
    for (var i = 0; i < _menuItems.length; i++) {
      if (_menuItems[i].customCategory == deletedName) {
        _menuItems[i] = _menuItems[i].copyWith(
          category: ItemCategory.coffee,
          clearCustomCategory: true,
        );
        menuModified = true;
      }
    }
    if (menuModified) {
      _saveMenuToStorage();
    }
    if (_selectedCategoryId == deletedName) {
      _selectedCategoryId = 'all';
      _selectedCategory = ItemCategory.all;
    }
    _saveCustomCategoriesToStorage();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedTag(String tag) {
    _selectedTag = tag;
    notifyListeners();
  }

  // Cart Management
  void addToCart(
    MenuItem item, {
    int quantity = 1,
    List<SelectedCustomization> customizations = const [],
    String? notes,
  }) {
    // Generate unique composite key based on customizations and notes
    final customHash = customizations.map((c) => '${c.groupTitle}:${c.optionName}').join('|');
    final cartItemId = '${item.id}_${customHash}_${notes ?? ''}';

    final existingIndex = _cart.indexWhere((i) => i.id == cartItemId);
    if (existingIndex >= 0) {
      _cart[existingIndex].quantity += quantity;
    } else {
      _cart.add(
        OrderItem(
          id: cartItemId,
          menuItem: item,
          quantity: quantity,
          customizations: List.from(customizations),
          notes: notes,
        ),
      );
    }
    notifyListeners();
  }

  void removeFromCart(dynamic identifier) {
    if (identifier is int) {
      if (identifier >= 0 && identifier < _cart.length) {
        _cart.removeAt(identifier);
        notifyListeners();
      }
    } else if (identifier is String) {
      _cart.removeWhere((item) => item.id == identifier);
      notifyListeners();
    }
  }

  void updateCartQuantity(String itemId, int delta) {
    final index = _cart.indexWhere((i) => i.id == itemId);
    if (index >= 0) {
      final newQty = _cart[index].quantity + delta;
      if (newQty <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index].quantity = newQty;
      }
      notifyListeners();
    }
  }

  void updateCartItemQuantity(int index, int newQuantity) {
    if (index >= 0 && index < _cart.length) {
      if (newQuantity <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index].quantity = newQuantity;
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _cart.clear();
    _discountPercentage = 0.0;
    _customDiscountAmount = 0.0;
    _customerName = '';
    notifyListeners();
  }

  void setOrderType(OrderType type) {
    _orderType = type;
    notifyListeners();
  }

  void setTableNumber(String table) {
    _tableNumber = table;
    notifyListeners();
  }

  void setCustomerName(String name) {
    _customerName = name;
    notifyListeners();
  }

  void setDiscountPercentage(double percentage) {
    _discountPercentage = percentage;
    _customDiscountAmount = 0.0;
    notifyListeners();
  }

  void setCustomDiscountAmount(double amount) {
    _customDiscountAmount = amount;
    _discountPercentage = 0.0;
    notifyListeners();
  }

  void applyDiscount({double percentage = 0.0, double customAmount = 0.0}) {
    if (customAmount > 0) {
      setCustomDiscountAmount(customAmount);
    } else {
      setDiscountPercentage(percentage);
    }
  }

  void setActiveCashier(String cashier) {
    _activeCashier = cashier;
    _saveCashierToStorage();
    notifyListeners();
  }

  void addCashier(String name) {
    if (!_cashiers.contains(name) && name.trim().isNotEmpty) {
      _cashiers.add(name.trim());
      notifyListeners();
    }
  }

  // Checkout & Order Creation
  Order completeCheckout({
    required PaymentMethod paymentMethod,
    required double amountTendered,
    String? specialOrderNotes,
  }) {
    final seqNum = _orderSequence++;
    final orderNum = '#$seqNum';
    final change = double.parse(((amountTendered - cartGrandTotal).clamp(0.0, double.infinity)).toStringAsFixed(2));

    final newOrder = Order(
      id: 'ord_$seqNum',
      orderNumber: orderNum,
      orderType: _orderType,
      tableNumber: _orderType == OrderType.dineIn ? _tableNumber : null,
      customerName: _customerName,
      items: List.from(_cart),
      subtotal: cartSubtotal,
      taxAmount: cartTaxAmount,
      taxRate: _taxRate,
      discountAmount: cartDiscountAmount,
      discountPercentage: _discountPercentage,
      totalAmount: cartGrandTotal,
      paymentMethod: paymentMethod,
      amountTendered: amountTendered,
      changeDue: change,
      status: OrderStatus.completed,
      createdAt: DateTime.now(),
      cashierName: _activeCashier.split(' [').first,
      orderNotes: specialOrderNotes,
    );

    // Deduct stock
    for (var cartItem in _cart) {
      final menuIdx = _menuItems.indexWhere((m) => m.id == cartItem.menuItem.id);
      if (menuIdx >= 0) {
        _menuItems[menuIdx].stockCount =
            (_menuItems[menuIdx].stockCount - cartItem.quantity).clamp(0, 9999);
        if (_menuItems[menuIdx].stockCount == 0) {
          _menuItems[menuIdx].inStock = false;
        }
      }
    }

    _orders.insert(0, newOrder);
    clearCart();

    _saveOrdersToStorage();
    _saveMenuToStorage();

    HapticFeedback.heavyImpact();
    notifyListeners();
    return newOrder;
  }

  int _findOrderIndex(String orderId) {
    final clean = orderId.trim().toLowerCase();
    final cleanNum = clean.replaceAll('#', '').trim();
    return _orders.indexWhere((o) {
      final oId = o.id.trim().toLowerCase();
      final oNum = o.orderNumber.trim().toLowerCase();
      final oNumClean = oNum.replaceAll('#', '').trim();
      return oId == clean ||
          oId == cleanNum ||
          oNum == clean ||
          oNumClean == clean ||
          oNumClean == cleanNum;
    });
  }

  void updateOrderStatus(String orderId, OrderStatus newStatus) {
    final index = _findOrderIndex(orderId);
    if (index >= 0) {
      if (_orders[index].status == newStatus) return;
      _orders[index].status = newStatus;
      notifyListeners();
      _scheduleSaveOrders();
      HapticFeedback.lightImpact();
    }
  }

  void cancelOrder(String orderId, {bool restock = true}) {
    final index = _findOrderIndex(orderId);
    if (index >= 0) {
      final order = _orders[index];
      order.status = OrderStatus.cancelled;

      if (restock) {
        for (var cartItem in order.items) {
          final menuIdx = _menuItems.indexWhere((m) => m.id == cartItem.menuItem.id);
          if (menuIdx >= 0) {
            _menuItems[menuIdx].stockCount += cartItem.quantity;
            _menuItems[menuIdx].inStock = true;
          }
        }
        _saveMenuToStorage();
      }

      _saveOrdersToStorage();
      notifyListeners();
    }
  }

  void deleteOrderCompletely(String orderId, {bool restock = true}) {
    final index = _findOrderIndex(orderId);
    if (index >= 0) {
      final order = _orders[index];
      if (restock && order.status != OrderStatus.cancelled) {
        for (var cartItem in order.items) {
          final menuIdx = _menuItems.indexWhere((m) => m.id == cartItem.menuItem.id);
          if (menuIdx >= 0) {
            _menuItems[menuIdx].stockCount += cartItem.quantity;
            _menuItems[menuIdx].inStock = true;
          }
        }
        _saveMenuToStorage();
      }

      _orders.removeAt(index);
      _saveOrdersToStorage();
      notifyListeners();
    }
  }

  // Item & Modifier Availability Management (86 List)
  int get totalUnavailableItemsCount => _menuItems.where((item) => !item.inStock).length;
  int get totalUnavailableOptionsCount => _menuItems.fold(0, (sum, item) => sum + item.unavailableOptionsCount);

  // ── Food Costing Getters ─────────────────────────────────────────────────
  List<MenuItem> get itemsWithIngredients =>
      _menuItems.where((m) => m.ingredients.isNotEmpty).toList();

  double get averageProfitMarginPercent {
    final items = itemsWithIngredients;
    if (items.isEmpty) return 0.0;
    final margins = items.map((m) => m.profitMarginPercent ?? 0.0);
    return margins.fold(0.0, (a, b) => a + b) / items.length;
  }

  MenuItem? get highestCostItem {
    if (itemsWithIngredients.isEmpty) return null;
    return itemsWithIngredients.reduce(
        (a, b) => a.totalBatchCost >= b.totalBatchCost ? a : b);
  }

  MenuItem? get mostProfitableItem {
    if (itemsWithIngredients.isEmpty) return null;
    return itemsWithIngredients.reduce((a, b) =>
        (a.profitMarginPercent ?? 0) >= (b.profitMarginPercent ?? 0) ? a : b);
  }

  int get thinMarginItemsCount =>
      itemsWithIngredients.where((m) => (m.profitMarginPercent ?? 100) < 35).length;



  // Inventory Management
  void updateStockCount(String itemId, int newCount) {
    final index = _menuItems.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      _menuItems[index].stockCount = newCount.clamp(0, 9999);
      _menuItems[index].inStock = newCount > 0;
      _saveMenuToStorage();
      notifyListeners();
    }
  }

  void toggleItemStock(String itemId) {
    final index = _menuItems.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      _menuItems[index].inStock = !_menuItems[index].inStock;
      _saveMenuToStorage();
      notifyListeners();
    }
  }

  void setItemAvailability(String itemId, bool inStock) {
    final index = _menuItems.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      _menuItems[index].inStock = inStock;
      _saveMenuToStorage();
      notifyListeners();
    }
  }

  void toggleOptionAvailability(String itemId, String groupId, String optionName, [bool? isAvailable]) {
    final itemIdx = _menuItems.indexWhere((m) => m.id == itemId);
    if (itemIdx < 0) return;
    final item = _menuItems[itemIdx];
    final updatedGroups = item.customizationGroups.map((group) {
      if (group.id != groupId) return group;
      final updatedOptions = group.options.map((opt) {
        if (opt.name != optionName) return opt;
        final newAvail = isAvailable ?? !opt.isAvailable;
        return opt.copyWith(isAvailable: newAvail);
      }).toList();
      return group.copyWith(options: updatedOptions);
    }).toList();

    _menuItems[itemIdx] = item.copyWith(customizationGroups: updatedGroups);
    _saveMenuToStorage();
    notifyListeners();
  }

  void toggleOptionAvailabilityGlobally(String optionName, bool isAvailable) {
    bool anyModified = false;
    final cleanTarget = optionName.toLowerCase().trim();
    for (int i = 0; i < _menuItems.length; i++) {
      final item = _menuItems[i];
      bool itemModified = false;
      final updatedGroups = item.customizationGroups.map((group) {
        final updatedOptions = group.options.map((opt) {
          if (opt.name.toLowerCase().trim() == cleanTarget) {
            if (opt.isAvailable != isAvailable) {
              itemModified = true;
              return opt.copyWith(isAvailable: isAvailable);
            }
          }
          return opt;
        }).toList();
        return group.copyWith(options: updatedOptions);
      }).toList();

      if (itemModified) {
        _menuItems[i] = item.copyWith(customizationGroups: updatedGroups);
        anyModified = true;
      }
    }

    if (anyModified) {
      _saveMenuToStorage();
      notifyListeners();
    }
  }

  void updateCustomizationOptionPrice({
    required String itemId,
    required String groupId,
    required String optionName,
    required double newExtraPrice,
    bool applyGlobally = false,
  }) {
    final cleanPrice = double.parse(newExtraPrice.clamp(0.0, 99999.0).toStringAsFixed(2));
    final cleanTarget = optionName.toLowerCase().trim();

    if (applyGlobally) {
      bool anyModified = false;
      for (int i = 0; i < _menuItems.length; i++) {
        final item = _menuItems[i];
        bool itemModified = false;
        final updatedGroups = item.customizationGroups.map((group) {
          final updatedOptions = group.options.map((opt) {
            if (opt.name.toLowerCase().trim() == cleanTarget) {
              if (opt.extraPrice != cleanPrice) {
                itemModified = true;
                return opt.copyWith(extraPrice: cleanPrice);
              }
            }
            return opt;
          }).toList();
          return group.copyWith(options: updatedOptions);
        }).toList();

        if (itemModified) {
          _menuItems[i] = item.copyWith(customizationGroups: updatedGroups);
          anyModified = true;
        }
      }

      if (anyModified) {
        _saveMenuToStorage();
        notifyListeners();
      }
    } else {
      final itemIdx = _menuItems.indexWhere((m) => m.id == itemId);
      if (itemIdx < 0) return;
      final item = _menuItems[itemIdx];

      final updatedGroups = item.customizationGroups.map((group) {
        if (group.id != groupId) return group;
        final updatedOptions = group.options.map((opt) {
          if (opt.name.toLowerCase().trim() != cleanTarget) return opt;
          return opt.copyWith(extraPrice: cleanPrice);
        }).toList();
        return group.copyWith(options: updatedOptions);
      }).toList();

      _menuItems[itemIdx] = item.copyWith(customizationGroups: updatedGroups);
      _saveMenuToStorage();
      notifyListeners();
    }
  }

  void updateGroupOptionPriceGlobally({
    required String optionName,
    required double newExtraPrice,
  }) {
    updateCustomizationOptionPrice(
      itemId: '',
      groupId: '',
      optionName: optionName,
      newExtraPrice: newExtraPrice,
      applyGlobally: true,
    );
  }

  void resetAllItemOptionsAvailability(String itemId) {
    final itemIdx = _menuItems.indexWhere((m) => m.id == itemId);
    if (itemIdx < 0) return;
    final item = _menuItems[itemIdx];
    final updatedGroups = item.customizationGroups.map((group) {
      final updatedOptions = group.options.map((opt) {
        return opt.copyWith(isAvailable: true);
      }).toList();
      return group.copyWith(options: updatedOptions);
    }).toList();

    _menuItems[itemIdx] = item.copyWith(customizationGroups: updatedGroups);
    _saveMenuToStorage();
    notifyListeners();
  }

  void resetAllAvailability() {
    for (int i = 0; i < _menuItems.length; i++) {
      final item = _menuItems[i];
      item.inStock = true;
      final updatedGroups = item.customizationGroups.map((group) {
        final updatedOptions = group.options.map((opt) {
          return opt.copyWith(isAvailable: true);
        }).toList();
        return group.copyWith(options: updatedOptions);
      }).toList();
      _menuItems[i] = item.copyWith(
        inStock: true,
        customizationGroups: updatedGroups,
      );
    }
    _saveMenuToStorage();
    notifyListeners();
  }

  void addNewMenuItem(MenuItem newItem) {
    _menuItems.insert(0, newItem);
    _saveMenuToStorage();
    notifyListeners();
  }

  void updateMenuItem(MenuItem updatedItem) {
    final index = _menuItems.indexWhere((item) => item.id == updatedItem.id);
    if (index >= 0) {
      _menuItems[index] = updatedItem;
      _saveMenuToStorage();
      notifyListeners();
    }
  }

  void updateItemPrice(String itemId, double newPrice) {
    final index = _menuItems.indexWhere((item) => item.id == itemId);
    if (index >= 0 && newPrice >= 0) {
      _menuItems[index] = _menuItems[index].copyWith(price: newPrice);
      _saveMenuToStorage();
      notifyListeners();
    }
  }

  void bulkAdjustPrices({double flatAmount = 0.0, double percentage = 0.0, ItemCategory? category}) {
    for (int i = 0; i < _menuItems.length; i++) {
      if (category == null || _menuItems[i].category == category) {
        double currentPrice = _menuItems[i].price;
        if (percentage != 0.0) {
          currentPrice += currentPrice * (percentage / 100);
        }
        currentPrice += flatAmount;
        _menuItems[i] = _menuItems[i].copyWith(price: currentPrice.clamp(0.0, 99999.0));
      }
    }
    _saveMenuToStorage();
    notifyListeners();
  }

  void deleteMenuItem(String itemId) {
    _menuItems.removeWhere((item) => item.id == itemId);
    _saveMenuToStorage();
    notifyListeners();
  }

  // Branding & Logo Management
  Future<void> setCustomLogo(Uint8List bytes) async {
    _customLogoBytes = bytes;
    _customLogoBase64 = base64Encode(bytes);
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_keyCustomLogo, _customLogoBase64!);
    } catch (e) {
      if (kDebugMode) print('Error saving logo: $e');
    }
    notifyListeners();
  }

  Future<void> resetToDefaultLogo() async {
    _customLogoBytes = null;
    _customLogoBase64 = null;
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_keyCustomLogo);
    } catch (e) {
      if (kDebugMode) print('Error removing logo: $e');
    }
    notifyListeners();
  }

  Future<void> updateStoreDetails({
    required String name,
    required String tagline,
    required String address,
  }) async {
    _storeName = name.trim().isEmpty ? 'CELESTIAL CAFE' : name.trim();
    _storeTagline = tagline.trim();
    _storeAddress = address.trim();
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_keyStoreName, _storeName);
      await prefs.setString(_keyStoreTagline, _storeTagline);
      await prefs.setString(_keyStoreAddress, _storeAddress);
    } catch (e) {
      if (kDebugMode) print('Error saving store details: $e');
    }
    notifyListeners();
  }

  /// Synchronizes store branding & logo to Firebase Cloud if the user is PRO.
  /// Does not block offline POS usage and handles connection loss gracefully.
  Future<bool> syncProCloudBackup(AppUser? user) async {
    if (user == null || (!user.isPro && !user.isAdmin)) return false;
    return await CloudBackupService().backupProData(
      user: user,
      storeName: _storeName,
      storeTagline: _storeTagline,
      storeAddress: _storeAddress,
      logoBytes: _customLogoBytes,
      logoBase64: _customLogoBase64,
    );
  }

  /// Restores store branding and custom logo from a Pro cloud backup.
  /// Saves directly to local SharedPreferences so data survives offline use.
  Future<bool> restoreFromProCloudBackup(Map<String, dynamic> backup) async {
    try {
      final name = backup['storeName'] as String?;
      final tagline = backup['storeTagline'] as String?;
      final address = backup['storeAddress'] as String?;

      if (name != null && name.trim().isNotEmpty) {
        _storeName = name.trim();
      }
      if (tagline != null) {
        _storeTagline = tagline.trim();
      }
      if (address != null) {
        _storeAddress = address.trim();
      }

      final logoBase64 = backup['customLogoBase64'] as String?;
      if (logoBase64 != null && logoBase64.isNotEmpty) {
        try {
          _customLogoBase64 = logoBase64;
          _customLogoBytes = base64Decode(logoBase64);
        } catch (_) {}
      }

      final prefs = await _getPrefs();
      await prefs.setString(_keyStoreName, _storeName);
      await prefs.setString(_keyStoreTagline, _storeTagline);
      await prefs.setString(_keyStoreAddress, _storeAddress);
      if (_customLogoBase64 != null) {
        await prefs.setString(_keyCustomLogo, _customLogoBase64!);
      }

      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('PosProvider: restoreFromProCloudBackup error: $e');
      return false;
    }
  }

  Future<void> updateSignatureBanner({
    bool? enabled,
    String? badge,
    String? title,
    String? subtitle,
    String? buttonText,
    String? itemId,
    Uint8List? imageBytes,
    bool removeCustomImage = false,
  }) async {
    if (enabled != null) _signatureBannerEnabled = enabled;
    if (badge != null) _signatureBannerBadge = badge.trim().isEmpty ? 'CELESTIAL SIGNATURE CRAFT' : badge.trim();
    if (title != null) _signatureBannerTitle = title.trim().isEmpty ? 'Celestial Signature Latte' : title.trim();
    if (subtitle != null) _signatureBannerSubtitle = subtitle.trim();
    if (buttonText != null) _signatureBannerButtonText = buttonText.trim().isEmpty ? 'Order' : buttonText.trim();
    if (itemId != null) _signatureBannerItemId = itemId.trim().isEmpty ? 'nesp_1' : itemId.trim();

    if (removeCustomImage) {
      _signatureBannerImageBytes = null;
      _signatureBannerImageBase64 = null;
    } else if (imageBytes != null) {
      _signatureBannerImageBytes = imageBytes;
      _signatureBannerImageBase64 = base64Encode(imageBytes);
    }

    try {
      final prefs = await _getPrefs();
      await prefs.setBool(_keySigBannerEnabled, _signatureBannerEnabled);
      await prefs.setString(_keySigBannerBadge, _signatureBannerBadge);
      await prefs.setString(_keySigBannerTitle, _signatureBannerTitle);
      await prefs.setString(_keySigBannerSubtitle, _signatureBannerSubtitle);
      await prefs.setString(_keySigBannerButtonText, _signatureBannerButtonText);
      await prefs.setString(_keySigBannerItemId, _signatureBannerItemId);
      if (removeCustomImage) {
        await prefs.remove(_keySigBannerImage);
      } else if (_signatureBannerImageBase64 != null) {
        await prefs.setString(_keySigBannerImage, _signatureBannerImageBase64!);
      }
    } catch (e) {
      if (kDebugMode) print('Error saving signature banner customization: $e');
    }
    notifyListeners();
  }

  Future<void> resetSignatureBanner() async {
    _signatureBannerEnabled = true;
    _signatureBannerBadge = 'CELESTIAL SIGNATURE CRAFT';
    _signatureBannerTitle = 'Celestial Signature Latte';
    _signatureBannerSubtitle = 'House specialty handcrafted celestial latte blend with silky sweet foam';
    _signatureBannerButtonText = 'Order';
    _signatureBannerItemId = 'nesp_1';
    _signatureBannerImageBytes = null;
    _signatureBannerImageBase64 = null;

    try {
      final prefs = await _getPrefs();
      await prefs.remove(_keySigBannerEnabled);
      await prefs.remove(_keySigBannerBadge);
      await prefs.remove(_keySigBannerTitle);
      await prefs.remove(_keySigBannerSubtitle);
      await prefs.remove(_keySigBannerButtonText);
      await prefs.remove(_keySigBannerItemId);
      await prefs.remove(_keySigBannerImage);
    } catch (e) {
      if (kDebugMode) print('Error resetting signature banner: $e');
    }
    notifyListeners();
  }

  // Reset Data
  Future<void> resetAllData() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyMenuItems);
    await prefs.remove(_keyOrders);
    await prefs.remove(_keyOrderSeq);
    await prefs.remove(_keyCustomCategories);
    await prefs.remove(_keySigBannerEnabled);
    await prefs.remove(_keySigBannerBadge);
    await prefs.remove(_keySigBannerTitle);
    await prefs.remove(_keySigBannerSubtitle);
    await prefs.remove(_keySigBannerButtonText);
    await prefs.remove(_keySigBannerItemId);
    await prefs.remove(_keySigBannerImage);
    _signatureBannerEnabled = true;
    _signatureBannerBadge = 'CELESTIAL SIGNATURE CRAFT';
    _signatureBannerTitle = 'Celestial Signature Latte';
    _signatureBannerSubtitle = 'House specialty handcrafted celestial latte blend with silky sweet foam';
    _signatureBannerButtonText = 'Order';
    _signatureBannerItemId = 'nesp_1';
    _signatureBannerImageBytes = null;
    _signatureBannerImageBase64 = null;
    _customCategories.clear();
    _menuItems = List.from(initialCelestialMenu);
    await _saveMenuToStorage();
    await _saveCustomCategoriesToStorage();
    _orders.clear();
    _orderSequence = 1;
    clearCart();
    notifyListeners();
  }

  Future<void> resetCategoriesAndMenu() async {
    _customCategories.clear();
    await _saveCustomCategoriesToStorage();
    _menuItems = List.from(initialCelestialMenu);
    await _saveMenuToStorage();
    _selectedCategoryId = 'all';
    _selectedCategory = ItemCategory.all;
    notifyListeners();
  }

  Future<void> loadSampleMenu() async {
    _menuItems = List.from(initialCelestialMenu);
    await _saveMenuToStorage();
    notifyListeners();
  }

  Future<void> clearAllMenuItems() async {
    _menuItems.clear();
    await _saveMenuToStorage();
    notifyListeners();
  }

  Future<void> clearAllOrdersAndResetCounter({int startNumber = 1}) async {
    for (final order in _orders) {
      if (order.status != OrderStatus.cancelled) {
        for (final item in order.items) {
          final idx = _menuItems.indexWhere((m) => m.id == item.menuItem.id);
          if (idx >= 0) {
            _menuItems[idx].stockCount += item.quantity;
            _menuItems[idx].inStock = true;
          }
        }
      }
    }
    final prefs = await _getPrefs();
    await prefs.remove(_keyOrders);
    _orders.clear();
    _orderSequence = startNumber;
    await prefs.setInt(_keyOrderSeq, startNumber);
    _saveMenuToStorage();
    clearCart();
    notifyListeners();
  }

  Future<void> clearOrderHistoryOnly() async {
    _orders.removeWhere((o) => o.status == OrderStatus.completed || o.status == OrderStatus.cancelled);
    _saveOrdersToStorage();
    notifyListeners();
  }

  // Analytics Metrics
  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  List<Order> get _todayOrders =>
      _orders.where((o) => o.status != OrderStatus.cancelled && _isToday(o.createdAt)).toList();

  double get todayTotalSales =>
      _todayOrders.fold(0.0, (sum, o) => sum + o.totalAmount);

  int get todayOrdersCount => _todayOrders.length;

  double get averageOrderValue =>
      todayOrdersCount > 0 ? (todayTotalSales / todayOrdersCount) : 0.0;

  Map<String, int> get topSellingItems {
    final map = <String, int>{};
    for (var order in _todayOrders) {
      for (var item in order.items) {
        map[item.menuItem.name] = (map[item.menuItem.name] ?? 0) + item.quantity;
      }
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(5));
  }

  Map<String, double> get salesByCategory {
    final map = <String, double>{};
    for (var order in _todayOrders) {
      for (var item in order.items) {
        final cat = item.menuItem.category.label;
        map[cat] = (map[cat] ?? 0.0) + item.totalPrice;
      }
    }
    return map;
  }

  Map<PaymentMethod, double> get salesByPaymentMethod {
    final map = <PaymentMethod, double>{};
    for (var order in _todayOrders) {
      map[order.paymentMethod] = (map[order.paymentMethod] ?? 0.0) + order.totalAmount;
    }
    return map;
  }
}
