import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../services/kds_server_service.dart';

class PosProvider extends ChangeNotifier {
  static const String _keyMenuItems = 'celestial_menu_items_v1';
  static const String _keyOrders = 'celestial_orders_v1';
  static const String _keyOrderSeq = 'celestial_order_seq_v1';
  static const String _keyActiveCashier = 'celestial_active_cashier_v1';
  static const String _keyCustomLogo = 'celestial_custom_logo_v1';
  static const String _keyStoreName = 'celestial_store_name_v1';
  static const String _keyStoreTagline = 'celestial_store_tagline_v1';
  static const String _keyStoreAddress = 'celestial_store_address_v1';
  static const String _keyBaristaPin = 'celestial_barista_pin_v1';
  static const String _keyUiScale = 'celestial_ui_scale_v1';
  static const String _keyCustomCategories = 'celestial_custom_categories_v1';

  // Display & Text Size Scaling (for Cashiers/Baristas accessibility)
  double _uiScale = 1.0;
  double get uiScale => _uiScale;

  // Store & Branding
  String? _customLogoBase64;
  Uint8List? _customLogoBytes;
  String _storeName = 'CELESTIAL CAFE';
  String _storeTagline = 'COFFEE • MILKTEA • CHEESECAKE • BITES';
  String _storeAddress = 'Celestial Cafe Main Branch\nTel: (02) 8721-4900 • TIN #482-901-382-000';
  String _baristaPin = '1234';
  String get baristaPin => _baristaPin;

  // Hotspot / Local Network KDS Server
  final KdsServerService _kdsServer = KdsServerService();
  KdsServerService get kdsServer => _kdsServer;

  // Menu Catalog & Filtering
  List<MenuItem> _menuItems = [];
  ItemCategory _selectedCategory = ItemCategory.all;
  String _selectedCategoryId = 'all';
  List<CustomCategory> _customCategories = [];
  String _searchQuery = '';
  String _selectedTag = 'All';

  // Navigation
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

        final targetFile = File('$appData/com.celestialcafe/Celestial Cafe POS/shared_preferences.json');
        final backupFile = File('$appData/com.celestialcafe/celestial_pos/shared_preferences.json');

        final filesToCheck = [
          targetFile,
          backupFile,
          File('$appData/Celestial Cafe POS/shared_preferences.json'),
          File('$appData/celestial_pos/shared_preferences.json'),
        ];

        for (final file in filesToCheck) {
          if (!file.existsSync()) continue;
          bool isCorrupt = false;
          try {
            final bytes = file.readAsBytesSync();
            if (bytes.isEmpty || bytes[0] == 0) {
              isCorrupt = true;
            } else {
              jsonDecode(utf8.decode(bytes));
            }
          } catch (_) {
            isCorrupt = true;
          }

          if (isCorrupt) {
            try {
              file.copySync('${file.path}.corrupted_bak');
            } catch (_) {}

            bool restored = false;
            if (file.path != backupFile.path && backupFile.existsSync()) {
              try {
                final backupBytes = backupFile.readAsBytesSync();
                if (backupBytes.isNotEmpty && backupBytes[0] != 0) {
                  jsonDecode(utf8.decode(backupBytes));
                  backupFile.copySync(file.path);
                  restored = true;
                }
              } catch (_) {}
            }

            if (!restored) {
              try {
                file.writeAsStringSync('{}');
              } catch (_) {}
            }
          }
        }
      } catch (_) {}
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      if (e is FormatException) {
        repairCorruptedStorage();
        return await SharedPreferences.getInstance();
      }
      rethrow;
    }
  }

  Future<void> _initData() async {
    // repairCorruptedStorage() is already called from main.dart before runApp()
    // Do NOT call it again here — double filesystem scan on startup
    _menuItems = List.from(initialCelestialMenu);
    await _loadFromLocalStorage();
    _pruneOldOrders(); // H1: remove stale completed/cancelled orders to prevent storage bloat
    _isLoaded = true;
    _startKdsServer();
    notifyListeners();
  }

  /// Auto-prune completed/cancelled orders older than 24 hours to prevent storage bloat.
  void _pruneOldOrders() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final before = _orders.length;
    _orders.removeWhere((o) =>
        (o.status == OrderStatus.completed || o.status == OrderStatus.cancelled) &&
        o.createdAt.isBefore(cutoff));
    if (_orders.length != before) {
      _saveOrdersToStorage();
    }
  }

  void _startKdsServer() async {
    _kdsServer.setBaristaPin(_baristaPin);
    await _kdsServer.start(
      getOrdersCallback: _getActiveOrdersJson,
      onStatusUpdate: _handleRemoteKdsStatusUpdate,
      onOrderItemPrepared: setOrderItemPrepared,
      getMenuCallback: getMenuJsonForCustomer,
      onCustomerOrderSubmitted: _handleCustomerOrderSubmitted,
      onCustomerChangeOrder: _handleCustomerChangeOrder,
      onCustomerCancelOrder: _handleCustomerCancelOrder,
      getOrderByIdCallback: _getOrderById,
      getItemImageCallback: getItemImageBytes,
    );
    notifyListeners();
  }

  Future<void> restartKdsServer({String? manualIp}) async {
    if (manualIp != null && manualIp.trim().isNotEmpty) {
      _kdsServer.setManualIp(manualIp);
    }
    _kdsServer.setBaristaPin(_baristaPin);
    await _kdsServer.stop();
    await _kdsServer.start(
      getOrdersCallback: _getActiveOrdersJson,
      onStatusUpdate: _handleRemoteKdsStatusUpdate,
      onOrderItemPrepared: setOrderItemPrepared,
      getMenuCallback: getMenuJsonForCustomer,
      onCustomerOrderSubmitted: _handleCustomerOrderSubmitted,
      onCustomerChangeOrder: _handleCustomerChangeOrder,
      onCustomerCancelOrder: _handleCustomerCancelOrder,
      getOrderByIdCallback: _getOrderById,
      getItemImageCallback: getItemImageBytes,
    );
    notifyListeners();
  }

  Uint8List? getItemImageBytes(String itemId) {
    final item = _menuItems.where((m) => m.id == itemId).firstOrNull;
    if (item == null) return null;
    if (item.imageBase64 != null && item.imageBase64!.isNotEmpty) {
      try {
        return base64Decode(item.imageBase64!);
      } catch (_) {}
    }
    if (item.imagePath != null && item.imagePath!.isNotEmpty) {
      try {
        final file = File(item.imagePath!);
        if (file.existsSync()) {
          return file.readAsBytesSync();
        }
      } catch (_) {}
    }
    return null;
  }

  Order? _getOrderById(String orderId) {
    final clean = orderId.trim().toLowerCase();
    return _orders.where((o) =>
        o.id.toLowerCase() == clean ||
        o.orderNumber.toLowerCase() == clean ||
        o.orderNumber.toLowerCase().replaceAll('#', '').trim() == clean).firstOrNull;
  }

  Map<String, dynamic> _handleCustomerOrderSubmitted(Map<String, dynamic> rawOrder) {
    try {
      final tableNum = rawOrder['tableNumber'] as String? ?? 'Table 1';
      final custName = rawOrder['customerName'] as String? ?? 'Guest';
      final notes = rawOrder['notes'] as String?;
      final paymentMethodStr = rawOrder['paymentMethod'] as String? ?? 'cash';
      final rawItems = rawOrder['items'] as List<dynamic>? ?? [];

      final orderTypeStr = rawOrder['orderType'] as String? ?? 'dineIn';
      final isTakeout = orderTypeStr.toLowerCase().contains('take') ||
          orderTypeStr.toLowerCase().contains('delivery') ||
          orderTypeStr.toLowerCase() == 'takeaway';
      final orderType = isTakeout ? OrderType.takeaway : OrderType.dineIn;

      final rawT = tableNum.trim();
      final cleanTable = rawT.toLowerCase().startsWith('ttable')
          ? 'Table ${rawT.substring(6).trim()}'
          : (rawT.toLowerCase().startsWith('table')
              ? rawT
              : (rawT.toLowerCase().startsWith('t') && rawT.length > 1 && int.tryParse(rawT.substring(1)) != null
                  ? 'Table ${rawT.substring(1).trim()}'
                  : 'Table $rawT'));

      // Disallow multiple orders on the same table while an order is being prepared (Dine-In only)
      if (!isTakeout) {
        final tableToken = rawOrder['tableToken'] as String? ?? rawOrder['token'] as String?;
        if (!KdsServerService.isValidTableToken(cleanTable, tableToken)) {
          return {
            'success': false,
            'error': 'Table QR verification required. Please scan the physical QR code on $cleanTable to place a Dine-In order.',
            'requiresQrScan': true,
          };
        }

        final existingActive = _orders.where((o) =>
            o.orderType == OrderType.dineIn &&
            o.tableNumber?.toLowerCase() == cleanTable.toLowerCase() &&
            (o.status == OrderStatus.pending ||
                o.status == OrderStatus.confirmed ||
                o.status == OrderStatus.preparing)).firstOrNull;

        if (existingActive != null) {
          return {
            'success': false,
            'error': 'This table already has an order in preparation (${existingActive.orderNumber}). You can order again once it is ready or completed.',
            'existingOrderId': existingActive.id,
            'existingOrderNumber': existingActive.orderNumber,
            'status': existingActive.status.name,
          };
        }
      }

      final paymentMethod = paymentMethodStr.toLowerCase().contains('gcash') ||
              paymentMethodStr.toLowerCase().contains('mobile')
          ? PaymentMethod.mobilePay
          : PaymentMethod.cash;

      final List<OrderItem> orderItems = [];

      for (var rawItem in rawItems) {
        final itemMap = rawItem as Map<String, dynamic>;
        final itemId = itemMap['id'] as String?;
        final qty = (itemMap['quantity'] as num?)?.toInt() ?? 1;
        final itemNotes = itemMap['notes'] as String?;
        final rawCustoms = itemMap['customizations'] as List<dynamic>? ?? [];

        MenuItem? menuItem;
        if (itemId != null) {
          menuItem = _menuItems.where((m) => m.id == itemId).firstOrNull;
        }

        if (menuItem != null) {
          final List<SelectedCustomization> selectedCustoms = [];
          for (var rc in rawCustoms) {
            final rcMap = rc as Map<String, dynamic>;
            selectedCustoms.add(SelectedCustomization(
              groupTitle: rcMap['groupTitle'] as String? ?? '',
              optionName: rcMap['optionName'] as String? ?? '',
              extraPrice: (rcMap['extraPrice'] as num?)?.toDouble() ?? 0.0,
            ));
          }

          orderItems.add(OrderItem(
            id: 'cust_${itemId}_${orderItems.length + 1}',
            menuItem: menuItem,
            quantity: qty,
            customizations: selectedCustoms,
            notes: itemNotes,
          ));
        }
      }

      if (orderItems.isEmpty) {
        return {'success': false, 'error': 'No valid items in order'};
      }

      final createdOrder = submitCustomerSelfOrder(
        orderType: orderType,
        tableNumber: isTakeout ? 'Takeout' : tableNum,
        customerName: custName,
        items: orderItems,
        paymentMethod: paymentMethod,
        orderNotes: notes,
      );

      return {
        'success': true,
        'orderId': createdOrder.id,
        'orderNumber': createdOrder.orderNumber,
        'tableNumber': createdOrder.tableNumber,
        'status': createdOrder.status.name,
        'totalAmount': createdOrder.totalAmount,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Map<String, dynamic> _handleCustomerChangeOrder(String orderId) {
    try {
      final clean = orderId.trim().toLowerCase();
      final order = _orders.where((o) =>
          o.id.toLowerCase() == clean ||
          o.orderNumber.toLowerCase() == clean ||
          o.orderNumber.toLowerCase().replaceAll('#', '').trim() == clean).firstOrNull;

      if (order == null) {
        return {'success': false, 'error': 'Order not found in cafe records'};
      }

      if (order.status != OrderStatus.pending) {
        return {
          'success': false,
          'error': 'This order has already been confirmed and is being prepared in the kitchen. Please speak with the cashier directly.'
        };
      }

      // Restock items for the customer to modify
      for (var cartItem in order.items) {
        final menuIdx = _menuItems.indexWhere((m) => m.id == cartItem.menuItem.id);
        if (menuIdx >= 0) {
          _menuItems[menuIdx].stockCount += cartItem.quantity;
          _menuItems[menuIdx].inStock = true;
        }
      }

      final itemsPayload = order.items.map((i) => {
        'id': i.menuItem.id,
        'name': i.menuItem.name,
        'price': i.menuItem.price,
        'unitPrice': i.unitPrice,
        'extraPrice': i.unitPrice - i.menuItem.price,
        'quantity': i.quantity,
        'notes': i.notes ?? '',
        'customizations': i.customizations.map((c) => {
          'groupTitle': c.groupTitle,
          'optionName': c.optionName,
          'extraPrice': c.extraPrice,
        }).toList(),
      }).toList();

      _orders.removeWhere((o) => o.id == order.id);
      _saveOrdersToStorage();
      _saveMenuToStorage();
      _kdsServer.broadcastOrders();
      notifyListeners();

      return {
        'success': true,
        'message': 'Order unlocked for modification',
        'orderNumber': order.orderNumber,
        'items': itemsPayload,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Map<String, dynamic> _handleCustomerCancelOrder(String orderId) {
    try {
      final clean = orderId.trim().toLowerCase();
      final index = _orders.indexWhere((o) =>
          o.id.toLowerCase() == clean ||
          o.orderNumber.toLowerCase() == clean ||
          o.orderNumber.toLowerCase().replaceAll('#', '').trim() == clean);

      if (index < 0) {
        return {'success': false, 'error': 'Order not found in cafe records'};
      }

      final order = _orders[index];

      if (order.status != OrderStatus.pending) {
        return {
          'success': false,
          'error': 'This order has already been confirmed and is being prepared in the kitchen. Please speak with the cashier directly.'
        };
      }

      // Restock items into inventory
      for (var cartItem in order.items) {
        final menuIdx = _menuItems.indexWhere((m) => m.id == cartItem.menuItem.id);
        if (menuIdx >= 0) {
          _menuItems[menuIdx].stockCount += cartItem.quantity;
          _menuItems[menuIdx].inStock = true;
        }
      }

      order.status = OrderStatus.cancelled;
      _orders.removeAt(index);
      _saveOrdersToStorage();
      _saveMenuToStorage();
      _kdsServer.broadcastOrders();
      _kdsServer.broadcastOrderStatus(order.id, order.orderNumber, 'cancelled');
      notifyListeners();

      return {
        'success': true,
        'message': 'Order cancelled successfully',
        'orderNumber': order.orderNumber,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  void _handleRemoteKdsStatusUpdate(String orderId, String newStatus) {
    if (newStatus == 'cancelled') {
      cancelOrder(orderId, restock: true);
      return;
    }
    final status = OrderStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == newStatus.toLowerCase(),
      orElse: () => OrderStatus.pending,
    );
    updateOrderStatus(orderId, status);
  }

  List<Map<String, dynamic>> _getActiveOrdersJson() {
    return activeKdsOrders.map((o) {
      return {
        'id': o.id,
        'orderNumber': o.orderNumber,
        'orderType': o.orderType.name,
        'tableNumber': o.tableNumber,
        'customerName': o.customerName,
        'subtotal': o.subtotal,
        'taxAmount': o.taxAmount,
        'taxRate': o.taxRate,
        'discountAmount': o.discountAmount,
        'totalAmount': o.totalAmount,
        'status': o.status.name,
        'createdAt': o.createdAt.toIso8601String(),
        'paymentMethod': o.paymentMethod.name,
        'orderNotes': o.orderNotes,
        'hasKitchenDishes': o.hasKitchenDishes,
        'kitchenDishCount': o.kitchenDishCount,
        'hasBaristaDrinks': o.hasBaristaDrinks,
        'baristaDrinkCount': o.baristaDrinkCount,
        'items': o.items.map((i) => {
          'name': i.menuItem.name,
          'quantity': i.quantity,
          'category': i.menuItem.category.name,
          'isKitchen': i.isKitchenDish,
          'notes': i.notes,
          'isPrepared': i.isPrepared,
          'customizations': i.customizations.map((c) => {
            'optionName': c.optionName,
            'summary': c.summary,
          }).toList(),
        }).toList(),
      };
    }).toList();
  }

  // Local Storage Persistence
  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await _getPrefs();

      // 1. Load active cashier
      final savedCashier = prefs.getString(_keyActiveCashier);
      if (savedCashier != null && savedCashier.isNotEmpty) {
        _activeCashier = savedCashier;
      }

      // 2. Load order sequence (Starts from 1, resets on new day)
      final savedSeq = prefs.getInt(_keyOrderSeq);
      final lastDate = prefs.getString('celestial_last_order_date');
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (lastDate != null && lastDate != today) {
        _orderSequence = 1;
        await prefs.setInt(_keyOrderSeq, 1);
        await prefs.setString('celestial_last_order_date', today);
      } else if (savedSeq != null && savedSeq >= 1) {
        _orderSequence = savedSeq;
      } else {
        _orderSequence = 1;
      }

      // 3. Load Menu items & stock
      final savedMenuJson = prefs.getString(_keyMenuItems);
      if (savedMenuJson != null && savedMenuJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(savedMenuJson) as List<dynamic>;
          final loadedMenu = decoded
              .map((m) {
                try {
                  return MenuItem.fromJson(m as Map<String, dynamic>);
                } catch (e) {
                  return null;
                }
              })
              .whereType<MenuItem>()
              .toList();
          if (loadedMenu.isNotEmpty) {
            // Normalize sweetness options (migrate 125% to 75% if found in cached storage)
            for (var idx = 0; idx < loadedMenu.length; idx++) {
              final item = loadedMenu[idx];
              if (item.category == ItemCategory.coffee) {
                final newGroups = <CustomizationGroup>[];
                bool modified = false;
                for (var group in item.customizationGroups) {
                  if (group.id == 'sweetness' && group.options.any((o) => o.name.contains('125%'))) {
                    modified = true;
                    final newOptions = group.options.where((o) => !o.name.contains('125%')).toList();
                    if (!newOptions.any((o) => o.name.contains('75%'))) {
                      final regIdx = newOptions.indexWhere((o) => o.name.contains('100%'));
                      const opt75 = CustomizationOption(name: 'Less Sweet (75%)', extraPrice: 0.00);
                      if (regIdx >= 0) {
                        newOptions.insert(regIdx, opt75);
                      } else {
                        newOptions.add(opt75);
                      }
                    }
                    final newDefIdx = newOptions.indexWhere((o) => o.name.contains('100%'));
                    newGroups.add(CustomizationGroup(
                      id: group.id,
                      title: group.title,
                      isRequired: group.isRequired,
                      isMultiSelect: group.isMultiSelect,
                      defaultIndex: newDefIdx >= 0 ? newDefIdx : group.defaultIndex,
                      options: newOptions,
                    ));
                  } else if (group.id == 'coffee_addons' && group.options.any((o) => o.name.toLowerCase().contains('oat milk'))) {
                    modified = true;
                    final newOptions = group.options.where((o) => !o.name.toLowerCase().contains('oat milk')).toList();
                    newGroups.add(CustomizationGroup(
                      id: group.id,
                      title: group.title,
                      isRequired: group.isRequired,
                      isMultiSelect: group.isMultiSelect,
                      defaultIndex: group.defaultIndex,
                      options: newOptions,
                    ));
                  } else {
                    newGroups.add(group);
                  }
                }
                if (modified) {
                  loadedMenu[idx] = item.copyWith(customizationGroups: newGroups);
                }
              }
            }
            // Ensure all official catalog items from initialCelestialMenu are present
            for (final defaultItem in initialCelestialMenu) {
              if (!loadedMenu.any((m) => m.id == defaultItem.id)) {
                loadedMenu.add(defaultItem);
              }
            }
            _menuItems = loadedMenu;
          }
        } catch (e) {
          if (kDebugMode) print('Error parsing stored menu JSON: $e');
        }
      }

      // 3.5. Load Custom Categories
      final savedCategoriesJson = prefs.getString(_keyCustomCategories);
      if (savedCategoriesJson != null && savedCategoriesJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(savedCategoriesJson) as List<dynamic>;
          _customCategories = decoded
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
      final savedPin = prefs.getString(_keyBaristaPin);
      if (savedPin != null && savedPin.trim().isNotEmpty) {
        _baristaPin = savedPin.trim();
        _kdsServer.setBaristaPin(_baristaPin);
      }
      final savedUiScale = prefs.getDouble(_keyUiScale);
      if (savedUiScale != null && savedUiScale >= 0.80 && savedUiScale <= 1.50) {
        _uiScale = savedUiScale;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading from local storage: $e');
      }
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
  bool get hasCustomLogo => _customLogoBytes != null;
  String get storeName => _storeName;
  String get storeTagline => _storeTagline;
  String get storeAddress => _storeAddress;

  // Getters - Menu & Navigation
  List<MenuItem> get menuItems => _menuItems;
  ItemCategory get selectedCategory => _selectedCategory;
  String get selectedCategoryId => _selectedCategoryId;
  List<CustomCategory> get customCategories => List.unmodifiable(_customCategories);
  String get searchQuery => _searchQuery;
  String get selectedTag => _selectedTag;
  int get currentNavIndex => _currentNavIndex;
  String get activeCashier => _activeCashier;
  List<String> get cashiers => _cashiers;

  List<CategoryTabItem> get allCategoryTabs {
    final list = <CategoryTabItem>[
      const CategoryTabItem(id: 'all', label: 'All Items', icon: '✨'),
    ];
    for (final cat in ItemCategory.values) {
      if (cat == ItemCategory.all || cat == ItemCategory.custom) continue;
      list.add(CategoryTabItem(
        id: cat.name,
        label: cat.label,
        icon: cat.icon,
        isCustom: false,
        isKitchenDish: cat == ItemCategory.streetBites ||
            cat == ItemCategory.pastaDishes ||
            cat == ItemCategory.sandwich ||
            cat == ItemCategory.dinner,
      ));
    }
    for (final cc in _customCategories) {
      list.add(CategoryTabItem(
        id: cc.name,
        label: cc.name,
        icon: cc.icon,
        isCustom: true,
        isKitchenDish: cc.isKitchenDish,
      ));
    }
    return list;
  }

  List<MenuItem> get filteredMenuItems {
    return _menuItems.where((item) {
      final matchesCategory = _selectedCategoryId == 'all' ||
          _selectedCategory == ItemCategory.all ||
          (item.customCategory != null && item.customCategory!.isNotEmpty
              ? item.customCategory == _selectedCategoryId || item.category.name == _selectedCategoryId
              : item.category.name == _selectedCategoryId || item.category == _selectedCategory);
      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.tags.any((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()));
      final matchesTag = _selectedTag == 'All' || item.tags.contains(_selectedTag);

      return matchesCategory && matchesSearch && matchesTag;
    }).toList();
  }

  // Getters - Cart
  List<OrderItem> get cart => _cart;
  OrderType get orderType => _orderType;
  String get tableNumber => _tableNumber;
  String get customerName => _customerName;
  double get discountPercentage => _discountPercentage;
  double get customDiscountAmount => _customDiscountAmount;
  double get taxRate => _taxRate;

  int get cartItemCount => _cart.fold(0, (sum, i) => sum + i.quantity);

  double get cartSubtotal => _cart.fold(0.0, (sum, i) => sum + i.totalPrice);

  double get cartDiscountAmount {
    if (_customDiscountAmount > 0) return _customDiscountAmount;
    return cartSubtotal * (_discountPercentage / 100);
  }

  double get cartTaxAmount => 0.0;

  double get cartGrandTotal {
    return (cartSubtotal - cartDiscountAmount).clamp(0.0, double.infinity);
  }

  // Getters - Orders & KDS
  List<Order> get orders => List.unmodifiable(_orders);

  List<Order> get pendingOrders =>
      _orders.where((o) => o.status == OrderStatus.pending).toList();

  List<Order> get pendingCustomerOrders =>
      _orders.where((o) => o.status == OrderStatus.pending).toList();

  List<Order> get preparingOrders => _orders
      .where((o) =>
          o.status == OrderStatus.confirmed ||
          o.status == OrderStatus.preparing)
      .toList();

  List<Order> get confirmedOrders =>
      _orders.where((o) => o.status == OrderStatus.confirmed).toList();

  List<Order> get readyOrders =>
      _orders.where((o) => o.status == OrderStatus.ready).toList();

  List<Order> get completedOrders =>
      _orders.where((o) => o.status == OrderStatus.completed).toList();

  List<Order> get activeKdsOrders => _orders
      .where((o) =>
          o.status == OrderStatus.confirmed ||
          o.status == OrderStatus.preparing ||
          o.status == OrderStatus.ready)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

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
    _broadcastMenuUpdate();
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
    _broadcastMenuUpdate();
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
    _broadcastMenuUpdate();
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

  void setCashier(String cashier) {
    _activeCashier = cashier;
    _saveCashierToStorage();
    notifyListeners();
  }

  // Cart Operations
  void addToCart(
    MenuItem item, {
    int quantity = 1,
    List<SelectedCustomization> customizations = const [],
    String? notes,
  }) {
    final customHash = customizations.map((c) => '${c.groupTitle}:${c.optionName}').join('|');
    final uniqueId = '${item.id}_${customHash}_${notes ?? ""}';

    final existingIndex = _cart.indexWhere((ci) => ci.id == uniqueId);
    if (existingIndex >= 0) {
      _cart[existingIndex].quantity += quantity;
    } else {
      _cart.add(
        OrderItem(
          id: uniqueId,
          menuItem: item,
          quantity: quantity,
          customizations: customizations,
          notes: notes,
        ),
      );
    }
    notifyListeners();
  }

  void updateCartQuantity(String itemId, int delta) {
    final index = _cart.indexWhere((item) => item.id == itemId);
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

  void removeFromCart(String itemId) {
    _cart.removeWhere((item) => item.id == itemId);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    _discountPercentage = 0.0;
    _customDiscountAmount = 0.0;
    _customerName = '';
    _tableNumber = 'Table 01';
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
    _customerName = name.trim();
    notifyListeners();
  }

  void applyDiscount({double percentage = 0.0, double customAmount = 0.0}) {
    _discountPercentage = percentage;
    _customDiscountAmount = customAmount;
    notifyListeners();
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
      status: OrderStatus.confirmed,
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

    // Persist changes to local storage
    _saveOrdersToStorage();
    _saveMenuToStorage();

    // Broadcast to connected Barista phones
    _kdsServer.broadcastOrders();

    // Haptic feedback — order placed
    HapticFeedback.heavyImpact();

    notifyListeners();
    return newOrder;
  }

  // Customer Self-Ordering via Table QR Code or Takeout
  Order submitCustomerSelfOrder({
    OrderType orderType = OrderType.dineIn,
    required String tableNumber,
    required String customerName,
    required List<OrderItem> items,
    required PaymentMethod paymentMethod,
    String? orderNotes,
  }) {
    final seqNum = _orderSequence++;
    final orderNum = '#$seqNum';
    final subtotal = items.fold(0.0, (sum, i) => sum + i.totalPrice);
    final rawTbl = tableNumber.trim();
    final formattedTable = orderType == OrderType.takeaway
        ? 'Takeout'
        : (rawTbl.toLowerCase().startsWith('ttable')
            ? 'Table ${rawTbl.substring(6).trim()}'
            : (rawTbl.toLowerCase().startsWith('table')
                ? rawTbl
                : (rawTbl.toLowerCase().startsWith('t') && rawTbl.length > 1 && int.tryParse(rawTbl.substring(1)) != null
                    ? 'Table ${rawTbl.substring(1).trim()}'
                    : 'Table $rawTbl')));

    final newOrder = Order(
      id: 'ord_$seqNum',
      orderNumber: orderNum,
      orderType: orderType,
      tableNumber: formattedTable,
      customerName: customerName.trim().isEmpty
          ? (orderType == OrderType.takeaway ? 'Guest (Takeout)' : 'Guest ($formattedTable)')
          : customerName.trim(),
      items: List.from(items),
      subtotal: subtotal,
      taxAmount: 0.0,
      taxRate: 0.0,
      discountAmount: 0.0,
      discountPercentage: 0.0,
      totalAmount: subtotal,
      paymentMethod: paymentMethod,
      amountTendered: 0.0,
      changeDue: 0.0,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
      cashierName: 'Awaiting Cashier',
      orderNotes: orderNotes,
    );

    // Deduct stock
    for (var cartItem in items) {
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
    _saveOrdersToStorage();
    _saveMenuToStorage();
    Future.microtask(() {
      _kdsServer.broadcastOrders();
      notifyListeners();
    });
    return newOrder;
  }

  // Cashier Confirms & Approves Customer Pending Order (Settles Payment & Moves to Preparing)
  Order? approveAndSettleCustomerOrder({
    required String orderId,
    required PaymentMethod paymentMethod,
    required double amountTendered,
    double discountPercentage = 0.0,
    double discountAmount = 0.0,
    String? orderNotes,
  }) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      final existing = _orders[index];
      double effectiveDiscount = discountAmount > 0
          ? discountAmount
          : existing.subtotal * (discountPercentage / 100);
      effectiveDiscount = double.parse(effectiveDiscount.clamp(0.0, existing.subtotal).toStringAsFixed(2));
      final finalTotal = double.parse(((existing.subtotal - effectiveDiscount).clamp(0.0, double.infinity)).toStringAsFixed(2));
      final change = double.parse(((amountTendered - finalTotal).clamp(0.0, double.infinity)).toStringAsFixed(2));

      final updatedOrder = existing.copyWith(
        discountAmount: effectiveDiscount,
        discountPercentage: discountPercentage,
        totalAmount: finalTotal,
        paymentMethod: paymentMethod,
        amountTendered: amountTendered,
        changeDue: change,
        status: OrderStatus.confirmed,
        cashierName: _activeCashier.split(' [').first,
        orderNotes: orderNotes ?? existing.orderNotes,
      );

      _orders[index] = updatedOrder;
      _saveOrdersToStorage();
      _kdsServer.broadcastOrders();
      _kdsServer.broadcastOrderStatus(updatedOrder.id, updatedOrder.orderNumber, 'confirmed');

      HapticFeedback.heavyImpact();
      notifyListeners();
      return updatedOrder;
    }
    return null;
  }

  void rejectCustomerOrder(String orderId, {bool restock = true}) {
    cancelOrder(orderId, restock: restock);
  }

  // Edit / Modify Items in a Pending Customer Order (used by Cashier dialog)
  Order? updatePendingOrderItems({
    required String orderId,
    required List<OrderItem> newItems,
    String? orderNotes,
  }) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      final existing = _orders[index];
      if (existing.status != OrderStatus.pending) return null;

      // 1. Restock previous items
      for (var oldItem in existing.items) {
        final menuIdx = _menuItems.indexWhere((m) => m.id == oldItem.menuItem.id);
        if (menuIdx >= 0) {
          _menuItems[menuIdx].stockCount += oldItem.quantity;
          _menuItems[menuIdx].inStock = true;
        }
      }

      // 2. Deduct stock for new items
      for (var newItem in newItems) {
        final menuIdx = _menuItems.indexWhere((m) => m.id == newItem.menuItem.id);
        if (menuIdx >= 0) {
          _menuItems[menuIdx].stockCount = (_menuItems[menuIdx].stockCount - newItem.quantity).clamp(0, 9999);
          if (_menuItems[menuIdx].stockCount == 0) {
            _menuItems[menuIdx].inStock = false;
          }
        }
      }

      final newSubtotal = newItems.fold(0.0, (sum, i) => sum + i.totalPrice);
      final discountAmt = existing.discountAmount > 0
          ? existing.discountAmount
          : newSubtotal * (existing.discountPercentage / 100);
      final newTotal = (newSubtotal - discountAmt).clamp(0.0, double.infinity);

      final updatedOrder = existing.copyWith(
        items: List.from(newItems),
        subtotal: newSubtotal,
        discountAmount: discountAmt,
        totalAmount: newTotal,
        orderNotes: orderNotes ?? existing.orderNotes,
      );

      _orders[index] = updatedOrder;
      _saveOrdersToStorage();
      _saveMenuToStorage();
      _kdsServer.broadcastOrders();
      notifyListeners();
      return updatedOrder;
    }
    return null;
  }

  // Load a Pending Customer Order directly into the main POS Cart for full modification
  void loadPendingOrderIntoPosCart(String orderId) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      final order = _orders[index];
      // Restock items since cart items are checked out later
      for (var item in order.items) {
        final menuIdx = _menuItems.indexWhere((m) => m.id == item.menuItem.id);
        if (menuIdx >= 0) {
          _menuItems[menuIdx].stockCount += item.quantity;
          _menuItems[menuIdx].inStock = true;
        }
      }

      clearCart();
      for (var item in order.items) {
        _cart.add(item);
      }
      _orderType = order.orderType;
      if (order.tableNumber != null) {
        _tableNumber = order.tableNumber!;
      }
      _customerName = order.customerName;
      _discountPercentage = order.discountPercentage;
      _customDiscountAmount = order.discountAmount;

      _orders.removeAt(index);
      _currentNavIndex = 0; // Switch to POS station

      _saveOrdersToStorage();
      _saveMenuToStorage();
      _kdsServer.broadcastOrders();
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> getMenuJsonForCustomer() {
    return _menuItems.map((item) => {
      'id': item.id,
      'name': item.name,
      'description': item.description,
      'price': item.price,
      'icon': item.icon,
      'imagePath': item.imagePath,
      'imageBase64': item.imageBase64,
      'imageUrl': (item.imagePath != null && item.imagePath!.isNotEmpty) || (item.imageBase64 != null && item.imageBase64!.isNotEmpty)
          ? '/api/item-image?id=${item.id}'
          : null,
      'category': (item.customCategory != null && item.customCategory!.isNotEmpty)
          ? item.customCategory!
          : item.category.name,
      'categoryLabel': item.categoryLabel,
      'customCategory': item.customCategory,
      'inStock': item.inStock,
      'stockCount': item.stockCount,
      'tags': item.tags,
      'customizations': item.customizationGroups.map((cg) => {
        'id': cg.id,
        'groupTitle': cg.title,
        'isRequired': cg.isRequired,
        'isMultiSelect': cg.isMultiSelect,
        'defaultIndex': cg.defaultIndex,
        'options': cg.options.map((opt) => {
          'name': opt.name,
          'priceAdjustment': opt.extraPrice,
          'isAvailable': opt.isAvailable,
          'isDefault': false,
        }).toList(),
      }).toList(),
    }).toList();
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

  // KDS & Order Status Updates
  void toggleOrderItemPrepared(String orderId, int itemIndex) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0 && itemIndex >= 0 && itemIndex < _orders[index].items.length) {
      // Must be actively in preparing status to mark items prepared
      if (_orders[index].status != OrderStatus.preparing) return;

      final newPrepared = !_orders[index].items[itemIndex].isPrepared;
      _orders[index].items[itemIndex].isPrepared = newPrepared;

      // 1. Notify immediately for 60 FPS responsive UI
      notifyListeners();

      // 2. Debounced background storage write (no UI lag or stutter)
      _scheduleSaveOrders();

      // 3. Fast targeted websocket broadcast + debounced full sync
      _kdsServer.broadcastItemPrepared(orderId, itemIndex, newPrepared);
      _kdsServer.broadcastOrders();
    }
  }

  void setOrderItemPrepared(String orderId, int itemIndex, bool isPrepared) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0 && itemIndex >= 0 && itemIndex < _orders[index].items.length) {
      // Must be actively in preparing status to mark items prepared
      if (_orders[index].status != OrderStatus.preparing) return;
      if (_orders[index].items[itemIndex].isPrepared == isPrepared) return;

      _orders[index].items[itemIndex].isPrepared = isPrepared;

      // 1. Notify immediately for 60 FPS responsive UI
      notifyListeners();

      // 2. Debounced background storage write (no UI lag or stutter)
      _scheduleSaveOrders();

      // 3. Fast targeted websocket broadcast + debounced full sync
      _kdsServer.broadcastItemPrepared(orderId, itemIndex, isPrepared);
      _kdsServer.broadcastOrders();
    }
  }

  void updateOrderStatus(String orderId, OrderStatus newStatus) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      if (_orders[index].status == newStatus) return;
      _orders[index].status = newStatus;
      final targetOrder = _orders[index];

      notifyListeners();
      _scheduleSaveOrders();
      _kdsServer.broadcastOrders(immediate: true);
      _kdsServer.broadcastOrderStatus(targetOrder.id, targetOrder.orderNumber, newStatus.name);

      // Haptic pulse on every status change
      switch (newStatus) {
        case OrderStatus.preparing:
          HapticFeedback.mediumImpact();
          break;
        case OrderStatus.ready:
          HapticFeedback.heavyImpact();
          Future.delayed(const Duration(milliseconds: 150), HapticFeedback.heavyImpact);
          Future.delayed(const Duration(milliseconds: 300), HapticFeedback.heavyImpact);
          break;
        case OrderStatus.completed:
          HapticFeedback.lightImpact();
          break;
        default:
          break;
      }
    }
  }

  void cancelOrder(String orderId, {bool restock = true}) {
    final clean = orderId.trim().toLowerCase();
    final index = _orders.indexWhere((o) =>
        o.id.toLowerCase() == clean ||
        o.orderNumber.toLowerCase() == clean ||
        o.orderNumber.toLowerCase().replaceAll('#', '').trim() == clean);
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
      _kdsServer.broadcastOrders();
      _kdsServer.broadcastOrderStatus(order.id, order.orderNumber, 'cancelled');
      notifyListeners();
    }
  }

  void deleteOrderCompletely(String orderId, {bool restock = true}) {
    final clean = orderId.trim().toLowerCase();
    final index = _orders.indexWhere((o) =>
        o.id.toLowerCase() == clean ||
        o.orderNumber.toLowerCase() == clean ||
        o.orderNumber.toLowerCase().replaceAll('#', '').trim() == clean);
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
      _kdsServer.broadcastOrders();
      _kdsServer.broadcastOrderStatus(order.id, order.orderNumber, 'cancelled');
      notifyListeners();
    }
  }

  // Item & Modifier Availability Management (86 List)
  int get totalUnavailableItemsCount => _menuItems.where((item) => !item.inStock).length;
  int get totalUnavailableOptionsCount => _menuItems.fold(0, (sum, item) => sum + item.unavailableOptionsCount);

  void _broadcastMenuUpdate() {
    _kdsServer.broadcastMenu(getMenuJsonForCustomer());
  }

  // Inventory Management
  void updateStockCount(String itemId, int newCount) {
    final index = _menuItems.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      _menuItems[index].stockCount = newCount.clamp(0, 9999);
      _menuItems[index].inStock = newCount > 0;
      _saveMenuToStorage();
      _broadcastMenuUpdate();
      notifyListeners();
    }
  }

  void toggleItemStock(String itemId) {
    final index = _menuItems.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      _menuItems[index].inStock = !_menuItems[index].inStock;
      _saveMenuToStorage();
      _broadcastMenuUpdate();
      notifyListeners();
    }
  }

  void setItemAvailability(String itemId, bool inStock) {
    final index = _menuItems.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      _menuItems[index].inStock = inStock;
      _saveMenuToStorage();
      _broadcastMenuUpdate();
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
    _broadcastMenuUpdate();
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
      _broadcastMenuUpdate();
      notifyListeners();
    }
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
    _broadcastMenuUpdate();
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
    _broadcastMenuUpdate();
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

  Future<void> updateBaristaPin(String newPin) async {
    final clean = newPin.trim();
    if (clean.length >= 4) {
      _baristaPin = clean;
      _kdsServer.setBaristaPin(clean);
      try {
        final prefs = await _getPrefs();
        await prefs.setString(_keyBaristaPin, clean);
      } catch (e) {
        if (kDebugMode) print('Error saving barista pin: $e');
      }
      notifyListeners();
    }
  }

  // Reset All Local Data (e.g. for brand new day/shift or clean reset starting on #1)
  Future<void> resetAllData() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyMenuItems);
    await prefs.remove(_keyOrders);
    await prefs.remove(_keyOrderSeq);
    _menuItems = List.from(initialCelestialMenu);
    _orders.clear();
    _orderSequence = 1;
    clearCart();
    notifyListeners();
  }

  Future<void> clearAllOrdersAndResetCounter({int startNumber = 1}) async {
    // L1 fix: restock all menu items before clearing orders
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

  // Analytics Metrics — H3/H4 fix: all getters filter by TODAY only
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
