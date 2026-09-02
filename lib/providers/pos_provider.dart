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
  String _searchQuery = '';
  String _selectedTag = 'All';

  // Navigation
  int _currentNavIndex = 0;

  // Active Cart State
  final List<OrderItem> _cart = [];
  OrderType _orderType = OrderType.dineIn;
  String _tableNumber = 'Table 01';
  String _customerName = 'Guest Patron';
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

  Future<void> _initData() async {
    _menuItems = List.from(initialCelestialMenu);
    await _loadFromLocalStorage();
    _isLoaded = true;
    _startKdsServer();
    notifyListeners();
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

      final cleanTable = tableNum.trim().toLowerCase().startsWith('table')
          ? tableNum.trim()
          : 'Table ${tableNum.trim()}';

      // Disallow multiple orders on the same table while an order is being prepared (Dine-In only)
      if (!isTakeout) {
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
      final json = o.toJson();
      json['hasKitchenDishes'] = o.hasKitchenDishes;
      json['kitchenDishCount'] = o.kitchenDishCount;
      json['hasBaristaDrinks'] = o.hasBaristaDrinks;
      json['baristaDrinkCount'] = o.baristaDrinkCount;
      json['items'] = o.items.map((i) => {
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
      }).toList();
      return json;
    }).toList();
  }

  // Local Storage Persistence
  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Load active cashier
      final savedCashier = prefs.getString(_keyActiveCashier);
      if (savedCashier != null && savedCashier.isNotEmpty) {
        _activeCashier = savedCashier;
      }

      // 2. Load order sequence (Starts from 1)
      final savedSeq = prefs.getInt(_keyOrderSeq);
      if (savedSeq != null && savedSeq >= 1) {
        _orderSequence = savedSeq;
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
            _menuItems = loadedMenu;
          }
        } catch (e) {
          if (kDebugMode) print('Error parsing stored menu JSON: $e');
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
      final prefs = await SharedPreferences.getInstance();
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
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_menuItems.map((m) => m.toJson()).toList());
      await prefs.setString(_keyMenuItems, jsonStr);
    } catch (e) {
      if (kDebugMode) print('Error saving menu to storage: $e');
    }
  }

  Future<void> _saveOrdersToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_orders.map((o) => o.toJson()).toList());
      await prefs.setString(_keyOrders, jsonStr);
      await prefs.setInt(_keyOrderSeq, _orderSequence);
    } catch (e) {
      if (kDebugMode) print('Error saving orders to storage: $e');
    }
  }

  Future<void> _saveCashierToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
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
  String get searchQuery => _searchQuery;
  String get selectedTag => _selectedTag;
  int get currentNavIndex => _currentNavIndex;
  String get activeCashier => _activeCashier;
  List<String> get cashiers => _cashiers;

  List<MenuItem> get filteredMenuItems {
    return _menuItems.where((item) {
      final matchesCategory = _selectedCategory == ItemCategory.all ||
          item.category == _selectedCategory;
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
    _customerName = 'Guest Patron';
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
    _customerName = name.trim().isEmpty ? 'Guest Patron' : name.trim();
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
    final formattedTable = orderType == OrderType.takeaway
        ? 'Takeout'
        : (tableNumber.trim().toLowerCase().startsWith('table')
            ? tableNumber.trim()
            : 'Table ${tableNumber.trim()}');

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
      'category': item.category.name,
      'categoryLabel': item.category.label,
      'inStock': item.inStock,
      'stockCount': item.stockCount,
      'tags': item.tags,
      'customizations': item.customizationGroups.map((cg) => {
        'groupTitle': cg.title,
        'isRequired': cg.isRequired,
        'isMultiSelect': cg.isMultiSelect,
        'options': cg.options.map((opt) => {
          'name': opt.name,
          'priceAdjustment': opt.extraPrice,
          'isDefault': false,
        }).toList(),
      }).toList(),
    }).toList();
  }

  // KDS & Order Status Updates
  void toggleOrderItemPrepared(String orderId, int itemIndex) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0 && itemIndex >= 0 && itemIndex < _orders[index].items.length) {
      _orders[index].items[itemIndex].isPrepared = !_orders[index].items[itemIndex].isPrepared;
      _saveOrdersToStorage();
      _kdsServer.broadcastOrders();
      notifyListeners();
    }
  }

  void setOrderItemPrepared(String orderId, int itemIndex, bool isPrepared) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0 && itemIndex >= 0 && itemIndex < _orders[index].items.length) {
      _orders[index].items[itemIndex].isPrepared = isPrepared;
      _saveOrdersToStorage();
      _kdsServer.broadcastOrders();
      notifyListeners();
    }
  }

  void updateOrderStatus(String orderId, OrderStatus newStatus) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      _orders[index].status = newStatus;
      final targetOrder = _orders[index];
      _saveOrdersToStorage();
      _kdsServer.broadcastOrders();
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

      notifyListeners();
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
      final prefs = await SharedPreferences.getInstance();
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
      final prefs = await SharedPreferences.getInstance();
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
      final prefs = await SharedPreferences.getInstance();
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyBaristaPin, clean);
      } catch (e) {
        if (kDebugMode) print('Error saving barista pin: $e');
      }
      notifyListeners();
    }
  }

  // Reset All Local Data (e.g. for brand new day/shift or clean reset starting on #1)
  Future<void> resetAllData() async {
    final prefs = await SharedPreferences.getInstance();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOrders);
    _orders.clear();
    _orderSequence = startNumber;
    await prefs.setInt(_keyOrderSeq, startNumber);
    clearCart();
    notifyListeners();
  }

  // Analytics Metrics
  double get todayTotalSales =>
      _orders.where((o) => o.status != OrderStatus.cancelled).fold(0.0, (sum, o) => sum + o.totalAmount);

  int get todayOrdersCount =>
      _orders.where((o) => o.status != OrderStatus.cancelled).length;

  double get averageOrderValue =>
      todayOrdersCount > 0 ? (todayTotalSales / todayOrdersCount) : 0.0;

  Map<String, int> get topSellingItems {
    final map = <String, int>{};
    for (var order in _orders) {
      if (order.status != OrderStatus.cancelled) {
        for (var item in order.items) {
          map[item.menuItem.name] = (map[item.menuItem.name] ?? 0) + item.quantity;
        }
      }
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(5));
  }

  Map<String, double> get salesByCategory {
    final map = <String, double>{};
    for (var order in _orders) {
      if (order.status != OrderStatus.cancelled) {
        for (var item in order.items) {
          final cat = item.menuItem.category.label;
          map[cat] = (map[cat] ?? 0.0) + item.totalPrice;
        }
      }
    }
    return map;
  }

  Map<PaymentMethod, double> get salesByPaymentMethod {
    final map = <PaymentMethod, double>{};
    for (var order in _orders) {
      if (order.status != OrderStatus.cancelled) {
        map[order.paymentMethod] = (map[order.paymentMethod] ?? 0.0) + order.totalAmount;
      }
    }
    return map;
  }
}
