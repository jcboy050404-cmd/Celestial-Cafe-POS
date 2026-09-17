import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../services/online_order_service.dart';
import '../theme/celestial_theme.dart';
import '../widgets/client_menu_item_card.dart';
import '../widgets/customization_dialog.dart';
import '../widgets/item_thumbnail.dart';
import '../widgets/top_notification.dart';

/// Public customer-facing web & mobile screen allowing customers anywhere to browse a store's menu and order online.
class CustomerOnlineOrderScreen extends StatefulWidget {
  final String storeId;
  final String? initialTable;
  final bool previewMode;

  const CustomerOnlineOrderScreen({
    super.key,
    required this.storeId,
    this.initialTable,
    this.previewMode = false,
  });

  @override
  State<CustomerOnlineOrderScreen> createState() => _CustomerOnlineOrderScreenState();
}

class _CustomerOnlineOrderScreenState extends State<CustomerOnlineOrderScreen> {
  bool _isLoading = true;
  OnlineStoreProfile? _profile;
  List<MenuItem> _menuItems = [];
  String _selectedCategory = 'all';
  String _searchQuery = '';

  // Cart
  final List<OrderItem> _cart = [];

  // Active Submitted Order (for Live Tracking)
  Order? _submittedOrder;
  Timer? _statusTrackerTimer;
  String? _resolvedStoreId;

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  @override
  void dispose() {
    _statusTrackerTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStoreData() async {
    setState(() => _isLoading = true);
    final resolved = await OnlineOrderService().resolveStoreId(widget.storeId);
    _resolvedStoreId = resolved;
    final data = await OnlineOrderService().fetchStoreCatalog(resolved);
    if (!mounted) return;

    if (data != null) {
      _profile = data['profile'] as OnlineStoreProfile?;
      _menuItems = (data['menu'] as List<MenuItem>?) ?? [];
    }
    setState(() => _isLoading = false);
  }

  void _startOrderTracking(Order order) {
    _submittedOrder = order;
    _statusTrackerTimer?.cancel();
    final targetStore = _resolvedStoreId ?? widget.storeId;
    _statusTrackerTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      final orders = await OnlineOrderService().fetchIncomingOrders(targetStore);
      final updated = orders.firstWhere(
        (o) => o.id == _submittedOrder!.id,
        orElse: () => _submittedOrder!,
      );
      if (mounted && updated.status != _submittedOrder!.status) {
        setState(() {
          _submittedOrder = updated;
        });
      }
    });
  }

  List<({String key, String label, String icon})> get _categoryTabs {
    final tabs = <({String key, String label, String icon})>[
      (key: 'all', label: 'All Items', icon: '✨'),
    ];
    final seen = <String>{};
    for (var item in _menuItems) {
      final key = item.customCategory ?? item.category.name;
      if (!seen.contains(key)) {
        seen.add(key);
        final label = item.customCategory ?? item.category.label;
        final icon = item.customCategory != null ? '🏷️' : item.category.icon;
        tabs.add((key: key, label: label, icon: icon));
      }
    }
    return tabs;
  }

  int _getItemCartCount(String itemId) {
    int count = 0;
    for (final item in _cart) {
      if (item.menuItem.id == itemId) {
        count += item.quantity;
      }
    }
    return count;
  }

  List<MenuItem> get _filteredItems {
    return _menuItems.where((item) {
      final cat = item.customCategory ?? item.category.name;
      final matchesCat = _selectedCategory == 'all' || cat == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();
  }

  double get _cartTotal => _cart.fold(0.0, (sum, i) => sum + i.totalPrice);
  int get _cartItemCount => _cart.fold(0, (sum, i) => sum + i.quantity);

  String _formatPrice(double amount) {
    if (amount % 1 == 0) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }

  MenuItem? get _bestSellerItem {
    if (_menuItems.isEmpty) return null;
    final inStockItems = _menuItems.where((m) => m.inStock).toList();
    if (inStockItems.isEmpty) return null;

    final candidatePool = _selectedCategory == 'all'
        ? inStockItems
        : inStockItems.where((m) => (m.customCategory ?? m.category.name) == _selectedCategory).toList();
    if (candidatePool.isEmpty) return null;

    // Prioritize items tagged with best seller or signature classics
    final tagged = candidatePool.where((m) =>
        m.tags.any((t) =>
            t.toLowerCase().contains('best') ||
            t.toLowerCase().contains('seller') ||
            t.toLowerCase().contains('popular')) ||
        m.name.toLowerCase().contains('spanish latte') ||
        m.name.toLowerCase().contains('caramel macchiato') ||
        m.name.toLowerCase().contains('signature') ||
        m.name.toLowerCase().contains('americano') ||
        m.name.toLowerCase().contains('dirty matcha'));
    if (tagged.isNotEmpty) return tagged.first;

    candidatePool.sort((a, b) => b.rating.compareTo(a.rating));
    return candidatePool.first;
  }

  Widget _buildBestSellerBanner(MenuItem item, bool isOpen) {
    final isAvailable = item.inStock && isOpen;
    final priceStr = _formatPrice(item.price);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Container(
          margin: EdgeInsets.fromLTRB(isMobile ? 12 : 16, 2, isMobile ? 12 : 16, 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2C211A), Color(0xFF1E1712), Color(0xFF15100D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: CelestialTheme.goldPrimary.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.40),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: CelestialTheme.goldPrimary.withValues(alpha: 0.08),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isAvailable ? () => _openCustomizationSheet(item) : null,
              child: Stack(
                children: [
                  // Subtle Coffee Cover Artwork on right
                  Positioned.fill(
                    child: Row(
                      children: [
                        const Spacer(flex: 3),
                        Expanded(
                          flex: 4,
                          child: ShaderMask(
                            shaderCallback: (rect) {
                              return const LinearGradient(
                                colors: [Colors.transparent, Colors.black45, Colors.black],
                                stops: [0.0, 0.35, 1.0],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ).createShader(rect);
                            },
                            blendMode: BlendMode.dstIn,
                            child: ItemThumbnail(
                              item: item,
                              width: double.infinity,
                              borderRadius: BorderRadius.zero,
                              iconSize: 38,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Foreground Content Layer
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 8 : 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Best Seller Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: CelestialTheme.caramelAccent.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.6),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('⭐', style: TextStyle(fontSize: 9)),
                                    const SizedBox(width: 3),
                                    Text(
                                      'BEST SELLER',
                                      style: GoogleFonts.outfit(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        color: CelestialTheme.goldLight,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),

                              // Item Name
                              Text(
                                item.name,
                                style: GoogleFonts.outfit(
                                  fontSize: isMobile ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.creamLight,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),

                              // Subtitle / Description
                              Text(
                                item.description.isNotEmpty
                                    ? item.description
                                    : 'Handcrafted signature house favorite',
                                style: GoogleFonts.outfit(
                                  fontSize: isMobile ? 9.5 : 10.5,
                                  color: CelestialTheme.creamSoft,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),

                              // Price & Quick Order Button
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₱$priceStr',
                                    style: GoogleFonts.outfit(
                                      fontSize: isMobile ? 13.5 : 15,
                                      fontWeight: FontWeight.w900,
                                      color: CelestialTheme.goldLight,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 8 : 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: CelestialTheme.caramelGradient,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.add_rounded, size: 12, color: Colors.white),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Order',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _addToCart(MenuItem item, {List<SelectedCustomization> customizations = const [], String? notes}) {
    final customHash = customizations.map((c) => '${c.groupTitle}:${c.optionName}').join('|');
    final cartItemId = '${item.id}_${customHash}_${notes ?? ''}';

    final idx = _cart.indexWhere((i) => i.id == cartItemId);
    if (idx >= 0) {
      _cart[idx].quantity += 1;
    } else {
      _cart.add(OrderItem(
        id: cartItemId,
        menuItem: item,
        quantity: 1,
        customizations: customizations,
        notes: notes,
      ));
    }
    setState(() {});
  }

  void _openCustomizationSheet(MenuItem item) {
    if (item.customizationGroups.isEmpty) {
      _addToCart(item);
      TopNotification.showSuccess(
        context,
        'Added ${item.name} to cart',
      );
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => CustomizationDialog(
        item: item,
        isCustomerView: true,
        onAddToCart: (quantity, customizations, notes) {
          for (int q = 0; q < quantity; q++) {
            _addToCart(
              item,
              customizations: customizations,
              notes: notes,
            );
          }
          TopNotification.showSuccess(
            context,
            'Added $quantity× ${item.name} to cart',
          );
        },
      ),
    );
  }

  void _openCheckoutSheet() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final tableCtrl = TextEditingController(text: widget.initialTable ?? 'Table 01');
    final addressCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    OrderType selectedType = _profile?.allowTakeaway == true
        ? OrderType.takeaway
        : (_profile?.allowDineIn == true ? OrderType.dineIn : OrderType.delivery);

    PaymentMethod selectedPayment = PaymentMethod.cash;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final isDelivery = selectedType == OrderType.delivery;
          final isDineIn = selectedType == OrderType.dineIn;

          return Container(
            decoration: BoxDecoration(
              color: CelestialTheme.bgSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.35), width: 1.5),
                left: BorderSide(color: CelestialTheme.borderWarm, width: 1),
                right: BorderSide(color: CelestialTheme.borderWarm, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: CelestialTheme.borderWarm,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sheet Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: CelestialTheme.caramelAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: CelestialTheme.goldLight,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Complete Your Order',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.textLight,
                                ),
                              ),
                              Text(
                                '$_cartItemCount items • Total: ₱${_formatPrice(_cartTotal)}',
                                style: GoogleFonts.outfit(
                                  color: CelestialTheme.goldLight,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: CelestialTheme.textMuted, size: 22),
                          onPressed: () => Navigator.pop(sheetCtx),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Order Summary Mini Items Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: CelestialTheme.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 14, color: CelestialTheme.goldLight),
                              const SizedBox(width: 6),
                              Text(
                                'ORDER SUMMARY',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.goldLight,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '$_cartItemCount item${_cartItemCount > 1 ? 's' : ''}',
                                style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 120),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _cart.length,
                              separatorBuilder: (_, _) => Divider(
                                color: CelestialTheme.borderSubtle.withValues(alpha: 0.5),
                                height: 10,
                              ),
                              itemBuilder: (_, idx) {
                                final it = _cart[idx];
                                final customText = it.customizations.map((c) => c.optionName).join(', ');
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${it.quantity}×',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: CelestialTheme.goldLight,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            it.menuItem.name,
                                            style: GoogleFonts.outfit(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: CelestialTheme.textLight,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (customText.isNotEmpty)
                                            Text(
                                              customText,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: CelestialTheme.textMuted,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₱${_formatPrice(it.totalPrice)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: CelestialTheme.goldLight,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Order Type Selector Header
                    Text(
                      'ORDER TYPE',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.goldLight,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Custom Segmented Order Type Pills
                    Row(
                      children: [
                        if (_profile?.allowTakeaway ?? true)
                          Expanded(
                            child: _buildOrderTypePill(
                              label: 'Pickup',
                              icon: '🛍️',
                              isSelected: selectedType == OrderType.takeaway,
                              onTap: () => setSheetState(() => selectedType = OrderType.takeaway),
                            ),
                          ),
                        if ((_profile?.allowTakeaway ?? true) && (_profile?.allowDineIn ?? true))
                          const SizedBox(width: 8),
                        if (_profile?.allowDineIn ?? true)
                          Expanded(
                            child: _buildOrderTypePill(
                              label: 'Dine-In',
                              icon: '🍽️',
                              isSelected: selectedType == OrderType.dineIn,
                              onTap: () => setSheetState(() => selectedType = OrderType.dineIn),
                            ),
                          ),
                        if (((_profile?.allowTakeaway ?? true) || (_profile?.allowDineIn ?? true)) &&
                            (_profile?.allowDelivery ?? true))
                          const SizedBox(width: 8),
                        if (_profile?.allowDelivery ?? true)
                          Expanded(
                            child: _buildOrderTypePill(
                              label: 'Delivery',
                              icon: '🛵',
                              isSelected: selectedType == OrderType.delivery,
                              onTap: () => setSheetState(() => selectedType = OrderType.delivery),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Polished Form Inputs
                    _buildInputField(
                      controller: nameCtrl,
                      hint: 'Your Name *',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 10),
                    _buildInputField(
                      controller: phoneCtrl,
                      hint: 'Mobile Phone Number *',
                      icon: Icons.phone_iphone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),

                    if (isDineIn) ...[
                      _buildInputField(
                        controller: tableCtrl,
                        hint: 'Table Number (e.g. Table 04)',
                        icon: Icons.table_restaurant_outlined,
                      ),
                      const SizedBox(height: 10),
                    ] else if (isDelivery) ...[
                      _buildInputField(
                        controller: addressCtrl,
                        hint: 'Complete Delivery Address & Landmark *',
                        icon: Icons.location_on_outlined,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                    ],

                    _buildInputField(
                      controller: notesCtrl,
                      hint: 'Order notes / cutlery request (Optional)',
                      icon: Icons.edit_note_rounded,
                    ),
                    const SizedBox(height: 16),

                    // Payment Method Section
                    Text(
                      'PAYMENT METHOD',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.goldLight,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPaymentPill(
                          label: 'Cash on Counter/Pickup',
                          icon: '💵',
                          isSelected: selectedPayment == PaymentMethod.cash,
                          onTap: () => setSheetState(() => selectedPayment = PaymentMethod.cash),
                        ),
                        _buildPaymentPill(
                          label: 'GCash',
                          icon: '📱',
                          isSelected: selectedPayment == PaymentMethod.mobilePay,
                          onTap: () => setSheetState(() => selectedPayment = PaymentMethod.mobilePay),
                        ),
                        if (isDelivery)
                          _buildPaymentPill(
                            label: 'Cash on Delivery (COD)',
                            icon: '🛵',
                            isSelected: selectedPayment == PaymentMethod.cod,
                            onTap: () => setSheetState(() => selectedPayment = PaymentMethod.cod),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Place Order CTA Button
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: CelestialTheme.caramelGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: CelestialTheme.caramelAccent.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                final phone = phoneCtrl.text.trim();
                                if (name.isEmpty) {
                                  TopNotification.show(ctx, message: 'Please enter your name', type: TopNotificationType.error);
                                  return;
                                }
                                if (phone.isEmpty) {
                                  TopNotification.show(ctx, message: 'Please enter your phone number', type: TopNotificationType.error);
                                  return;
                                }
                                if (isDelivery && addressCtrl.text.trim().isEmpty) {
                                  TopNotification.show(ctx, message: 'Please enter delivery address', type: TopNotificationType.error);
                                  return;
                                }

                                setSheetState(() => isSubmitting = true);

                                final seq = DateTime.now().millisecondsSinceEpoch % 10000;
                                final newOrder = Order(
                                  id: 'online_${DateTime.now().millisecondsSinceEpoch}',
                                  orderNumber: '#ON-$seq',
                                  orderType: selectedType,
                                  tableNumber: selectedType == OrderType.dineIn ? tableCtrl.text.trim() : null,
                                  customerName: name,
                                  customerPhone: phone,
                                  deliveryAddress: selectedType == OrderType.delivery ? addressCtrl.text.trim() : null,
                                  items: List.from(_cart),
                                  subtotal: _cartTotal,
                                  taxAmount: 0.0,
                                  taxRate: 0.0,
                                  totalAmount: _cartTotal,
                                  paymentMethod: selectedPayment,
                                  amountTendered: _cartTotal,
                                  status: OrderStatus.pending,
                                  createdAt: DateTime.now(),
                                  cashierName: 'Online Web Order',
                                  orderNotes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                                );

                                final success = await OnlineOrderService().submitCustomerOrder(
                                  storeId: _resolvedStoreId ?? widget.storeId,
                                  order: newOrder,
                                );

                                if (!sheetCtx.mounted) return;
                                Navigator.pop(sheetCtx);
                                if (!mounted) return;
                                _cart.clear();
                                _startOrderTracking(newOrder);
                                setState(() {});

                                if (success) {
                                  TopNotification.show(context, message: 'Order sent! Store is confirming your order.', type: TopNotificationType.success);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Place Order • ₱${_formatPrice(_cartTotal)}',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderTypePill({
    required String label,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? CelestialTheme.caramelGradient : null,
          color: isSelected ? null : CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? CelestialTheme.caramelAccent : CelestialTheme.borderWarm,
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: CelestialTheme.caramelAccent.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : CelestialTheme.textLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentPill({
    required String label,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? CelestialTheme.goldPrimary.withValues(alpha: 0.15)
              : CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? CelestialTheme.goldPrimary : CelestialTheme.borderWarm,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? CelestialTheme.goldLight : CelestialTheme.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: CelestialTheme.textMuted.withValues(alpha: 0.7),
          fontSize: 12.5,
        ),
        prefixIcon: Icon(icon, color: CelestialTheme.goldLight.withValues(alpha: 0.75), size: 18),
        filled: true,
        fillColor: CelestialTheme.bgCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: CelestialTheme.borderWarm),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: CelestialTheme.goldPrimary, width: 1.4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_submittedOrder != null) {
      return _buildOrderTrackerView();
    }

    final storeName = _profile?.storeName ?? 'Celestial Cafe';
    final storeTagline = _profile?.storeTagline ?? 'Handcrafted Coffee & Treats';
    final isOpen = _profile?.isOpen ?? true;

    return Scaffold(
      backgroundColor: CelestialTheme.bgSurface,
      body: SafeArea(
        child: Column(
          children: [
            // Store Owner Preview Banner (if previewing from POS)
            if (widget.previewMode)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: CelestialTheme.goldPrimary,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.preview_rounded, color: Colors.black, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Store Owner Preview Mode • Testing Customer View',
                      style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black, size: 16),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

            // Store Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: CelestialTheme.bgCard,
                border: Border(bottom: BorderSide(color: CelestialTheme.borderWarm)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                        ),
                        child: Icon(Icons.coffee_rounded, color: CelestialTheme.goldLight, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              storeName,
                              style: GoogleFonts.outfit(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: CelestialTheme.textLight,
                              ),
                            ),
                            Text(
                              storeTagline,
                              style: TextStyle(fontSize: 11.5, color: CelestialTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isOpen
                              ? CelestialTheme.emeraldReady.withValues(alpha: 0.15)
                              : CelestialTheme.roseAlert.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isOpen ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isOpen ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isOpen ? 'OPEN' : 'PAUSED',
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isOpen ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search Bar
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search drinks, snacks, meals...',
                      hintStyle: TextStyle(color: CelestialTheme.textSubtle, fontSize: 12),
                      prefixIcon: Icon(Icons.search_rounded, color: CelestialTheme.goldLight, size: 18),
                      filled: true,
                      fillColor: CelestialTheme.bgSurface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
                    ),
                  ),
                ],
              ),
            ),

            // Best Seller Spotlight Banner (matching cashier hero spotlight)
            if (_searchQuery.isEmpty && _bestSellerItem != null)
              _buildBestSellerBanner(_bestSellerItem!, isOpen),

            // Category Tabs Bar (matching cashier POS style)
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categoryTabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, idx) {
                  final tab = _categoryTabs[idx];
                  final isSelected = _selectedCategory == tab.key;
                  return InkWell(
                    onTap: () => setState(() => _selectedCategory = tab.key),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: isSelected ? CelestialTheme.caramelGradient : null,
                        color: isSelected ? null : CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? CelestialTheme.caramelAccent
                              : CelestialTheme.borderSubtle,
                          width: isSelected ? 1.2 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (tab.icon.isNotEmpty) ...[
                            Text(tab.icon, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? CelestialTheme.bgDark
                                  : CelestialTheme.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Menu Items Grid (matching cashier POS item layout)
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: CelestialTheme.goldPrimary))
                  : _filteredItems.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                                  ),
                                  child: Icon(
                                    _menuItems.isEmpty ? Icons.restaurant_menu_rounded : Icons.search_off_rounded,
                                    size: 30,
                                    color: CelestialTheme.goldLight,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _menuItems.isEmpty ? 'No Menu Items Available' : 'No Items Found',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: CelestialTheme.textLight,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _menuItems.isEmpty
                                      ? 'This cafe has not published items yet.'
                                      : 'Try searching for something else or pick a different category.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: CelestialTheme.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            int crossAxisCount = 3;
                            double childAspectRatio = 0.64;
                            double spacing = 8.0;
                            EdgeInsets padding = EdgeInsets.fromLTRB(
                              8,
                              6,
                              8,
                              _cart.isNotEmpty ? 90 : 24,
                            );

                            if (constraints.maxWidth >= 1100) {
                              crossAxisCount = 5;
                              childAspectRatio = 0.78;
                              spacing = 12.0;
                              padding = EdgeInsets.fromLTRB(
                                12,
                                8,
                                12,
                                _cart.isNotEmpty ? 90 : 24,
                              );
                            } else if (constraints.maxWidth >= 750) {
                              crossAxisCount = 4;
                              childAspectRatio = 0.76;
                              spacing = 10.0;
                              padding = EdgeInsets.fromLTRB(
                                10,
                                8,
                                10,
                                _cart.isNotEmpty ? 90 : 24,
                              );
                            } else {
                              // Mobile screens: 3 clean columns
                              crossAxisCount = 3;
                              childAspectRatio = 0.64;
                              spacing = 8.0;
                              padding = EdgeInsets.fromLTRB(
                                8,
                                6,
                                8,
                                _cart.isNotEmpty ? 90 : 24,
                              );
                            }

                            return GridView.builder(
                              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                              padding: padding,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: childAspectRatio,
                                crossAxisSpacing: spacing,
                                mainAxisSpacing: spacing,
                              ),
                              itemCount: _filteredItems.length,
                              itemBuilder: (context, idx) {
                                final item = _filteredItems[idx];
                                return ClientMenuItemCard(
                                  item: item,
                                  inCartCount: _getItemCartCount(item.id),
                                  isStoreOpen: isOpen,
                                  onTap: () => _openCustomizationSheet(item),
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),

      // Bottom Floating Cart Bar
      bottomNavigationBar: _cart.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: CelestialTheme.bgCard,
                border: Border(top: BorderSide(color: CelestialTheme.borderWarm)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_cartItemCount item${_cartItemCount == 1 ? '' : 's'} in cart',
                          style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                        ),
                        Text(
                          '₱${_formatPrice(_cartTotal)}',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _openCheckoutSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CelestialTheme.goldPrimary,
                        foregroundColor: CelestialTheme.primaryBtnText,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOrderTrackerView() {
    final order = _submittedOrder!;
    final status = order.status;

    String statusTitle;
    String statusSubtitle;
    IconData statusIcon;
    Color statusColor;

    // Timeline step index: 0 = Sent, 1 = Confirmed, 2 = Preparing, 3 = Ready/Completed
    int currentStep = 0;

    switch (status) {
      case OrderStatus.pending:
        statusTitle = 'Order Sent • Waiting for Cashier Confirmation';
        statusSubtitle = 'The café has received your order. The cashier will review and confirm shortly.';
        statusIcon = Icons.hourglass_top_rounded;
        statusColor = CelestialTheme.amberBrewing;
        currentStep = 0;
        break;
      case OrderStatus.confirmed:
        final hasCashier = order.cashierName.isNotEmpty &&
            !order.cashierName.toLowerCase().contains('online') &&
            !order.cashierName.toLowerCase().contains('web');
        statusTitle = 'Order Confirmed by Cashier!';
        statusSubtitle = hasCashier
            ? 'Confirmed by cashier ${order.cashierName}. Kitchen is preparing your items (~${_profile?.estimatedPrepMinutes ?? 15} mins).'
            : 'Confirmed by cashier! Kitchen is preparing your items (~${_profile?.estimatedPrepMinutes ?? 15} mins).';
        statusIcon = Icons.thumb_up_alt_rounded;
        statusColor = CelestialTheme.goldPrimary;
        currentStep = 1;
        break;
      case OrderStatus.preparing:
        statusTitle = 'Kitchen is Preparing Your Order';
        statusSubtitle = 'Fresh ingredients are being crafted into your favorites (~${_profile?.estimatedPrepMinutes ?? 15} mins).';
        statusIcon = Icons.local_fire_department_rounded;
        statusColor = CelestialTheme.goldPrimary;
        currentStep = 2;
        break;
      case OrderStatus.ready:
        statusTitle = 'Your Order is Ready!';
        statusSubtitle = order.orderType == OrderType.delivery
            ? 'Order packed and ready for delivery rider.'
            : 'Please pick up your order at the counter.';
        statusIcon = Icons.check_circle_rounded;
        statusColor = CelestialTheme.emeraldReady;
        currentStep = 3;
        break;
      case OrderStatus.outForDelivery:
        statusTitle = 'Out for Delivery!';
        statusSubtitle = 'Your rider is on the way to ${order.deliveryAddress ?? 'your address'}.';
        statusIcon = Icons.delivery_dining_rounded;
        statusColor = Colors.cyanAccent;
        currentStep = 3;
        break;
      case OrderStatus.completed:
        statusTitle = 'Order Completed!';
        statusSubtitle = 'Thank you for ordering with us!';
        statusIcon = Icons.verified_rounded;
        statusColor = CelestialTheme.emeraldReady;
        currentStep = 3;
        break;
      case OrderStatus.cancelled:
        statusTitle = 'Order Cancelled';
        statusSubtitle = 'This order was cancelled by the store.';
        statusIcon = Icons.cancel_outlined;
        statusColor = CelestialTheme.roseAlert;
        currentStep = 0;
        break;
    }

    final storeName = _profile?.storeName ?? 'Celestial Cafe';

    return Scaffold(
      backgroundColor: CelestialTheme.bgSurface,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: CelestialTheme.bgCard,
                border: Border(bottom: BorderSide(color: CelestialTheme.borderWarm)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.coffee_rounded, color: CelestialTheme.goldLight, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.textLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Live Order Tracking',
                          style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  // Live Pulse Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: status == OrderStatus.cancelled
                          ? CelestialTheme.roseAlert.withValues(alpha: 0.15)
                          : CelestialTheme.emeraldReady.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: status == OrderStatus.cancelled
                            ? CelestialTheme.roseAlert.withValues(alpha: 0.5)
                            : CelestialTheme.emeraldReady.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: status == OrderStatus.cancelled
                                ? CelestialTheme.roseAlert
                                : CelestialTheme.emeraldReady,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          status == OrderStatus.cancelled ? 'CANCELLED' : 'LIVE TRACKER',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: status == OrderStatus.cancelled
                                ? CelestialTheme.roseAlert
                                : CelestialTheme.emeraldReady,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Column(
                      children: [
                        // Hero Status Circle with double glow rings
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor.withValues(alpha: 0.08),
                              ),
                            ),
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor.withValues(alpha: 0.18),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: Icon(statusIcon, color: statusColor, size: 40),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Order Number Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: CelestialTheme.goldPrimary.withValues(alpha: 0.5),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            order.orderNumber,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: CelestialTheme.goldLight,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Status Title
                        Text(
                          statusTitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.textLight,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Status Subtitle
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            statusSubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: CelestialTheme.textMuted, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Timeline Progress Stepper (Except for cancelled orders)
                        if (status != OrderStatus.cancelled) ...[
                          _buildTimelineStepper(currentStep, order.orderType),
                          const SizedBox(height: 22),
                        ],

                        // Order Summary & Receipt Details Card
                        Container(
                          decoration: BoxDecoration(
                            color: CelestialTheme.bgCard,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: CelestialTheme.borderWarm, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Card Header
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                                child: Row(
                                  children: [
                                    Icon(Icons.receipt_rounded, size: 16, color: CelestialTheme.goldLight),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Order Breakdown',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: CelestialTheme.textLight,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: CelestialTheme.caramelAccent.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        order.orderType.label,
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: CelestialTheme.goldLight,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(color: CelestialTheme.borderWarm, height: 1),

                              // Items List
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    for (int i = 0; i < order.items.length; i++) ...[
                                      if (i > 0)
                                        Divider(
                                          color: CelestialTheme.borderSubtle.withValues(alpha: 0.5),
                                          height: 14,
                                        ),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${order.items[i].quantity}×',
                                              style: GoogleFonts.outfit(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: CelestialTheme.goldLight,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  order.items[i].menuItem.name,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: CelestialTheme.textLight,
                                                  ),
                                                ),
                                                if (order.items[i].customizations.isNotEmpty)
                                                  Text(
                                                    order.items[i].customizations.map((c) => c.optionName).join(', '),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: CelestialTheme.textMuted,
                                                    ),
                                                  ),
                                                if (order.items[i].notes != null && order.items[i].notes!.isNotEmpty)
                                                  Text(
                                                    'Note: ${order.items[i].notes}',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontStyle: FontStyle.italic,
                                                      color: CelestialTheme.creamSoft,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '₱${_formatPrice(order.items[i].totalPrice)}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: CelestialTheme.goldLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Divider(color: CelestialTheme.borderWarm, height: 1),

                              // Customer & Fulfillment details
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    _buildReceiptInfoRow('Customer', '${order.customerName} • ${order.customerPhone}'),
                                    if (order.tableNumber != null && order.tableNumber!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      _buildReceiptInfoRow('Table Number', order.tableNumber!),
                                    ],
                                    if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      _buildReceiptInfoRow('Delivery To', order.deliveryAddress!),
                                    ],
                                    const SizedBox(height: 8),
                                    _buildReceiptInfoRow('Payment Method', order.paymentMethod.label),
                                    if (order.orderNotes != null && order.orderNotes!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      _buildReceiptInfoRow('Special Notes', order.orderNotes!),
                                    ],
                                    const SizedBox(height: 12),
                                    Divider(color: CelestialTheme.borderWarm, height: 1),
                                    const SizedBox(height: 12),

                                    // Total Row (Strictly No .00!)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Total Amount:',
                                          style: GoogleFonts.outfit(
                                            color: CelestialTheme.textLight,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '₱${_formatPrice(order.totalAmount)}',
                                          style: GoogleFonts.outfit(
                                            color: CelestialTheme.goldLight,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Real-Time Helper Note
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: CelestialTheme.bgCard.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: CelestialTheme.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.sync_rounded, size: 16, color: CelestialTheme.goldLight),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Live updating automatically as the cashier confirms your order.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: CelestialTheme.textMuted,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () async {
                                  final targetStore = _resolvedStoreId ?? widget.storeId;
                                  final orders = await OnlineOrderService().fetchIncomingOrders(targetStore);
                                  final updated = orders.firstWhere(
                                    (o) => o.id == _submittedOrder!.id,
                                    orElse: () => _submittedOrder!,
                                  );
                                  if (mounted) {
                                    setState(() => _submittedOrder = updated);
                                    TopNotification.showSuccess(context, 'Status refreshed');
                                  }
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Text(
                                    'Refresh',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: CelestialTheme.goldLight,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Back to Menu Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _submittedOrder = null;
                                _statusTrackerTimer?.cancel();
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.8), width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: CelestialTheme.bgCard,
                            ),
                            icon: Icon(Icons.arrow_back_rounded, size: 16, color: CelestialTheme.goldLight),
                            label: Text(
                              'Back to Menu / Order Again',
                              style: GoogleFonts.outfit(
                                color: CelestialTheme.goldLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStepper(int currentStep, OrderType orderType) {
    final finalStepLabel = orderType == OrderType.delivery ? 'Delivery' : 'Ready';
    final steps = [
      (label: 'Order Sent', icon: Icons.send_rounded),
      (label: 'Confirmed', icon: Icons.thumb_up_alt_rounded),
      (label: 'Preparing', icon: Icons.coffee_maker_rounded),
      (label: finalStepLabel, icon: Icons.celebration_rounded),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CelestialTheme.borderWarm),
      ),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: i <= currentStep
                      ? CelestialTheme.goldPrimary
                      : CelestialTheme.borderSubtle,
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < currentStep
                        ? CelestialTheme.emeraldReady
                        : (i == currentStep
                            ? CelestialTheme.goldPrimary
                            : CelestialTheme.bgSurface),
                    border: Border.all(
                      color: i <= currentStep
                          ? CelestialTheme.goldLight
                          : CelestialTheme.borderWarm,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      i < currentStep
                          ? Icons.check_rounded
                          : steps[i].icon,
                      size: 16,
                      color: i <= currentStep ? Colors.black : CelestialTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  steps[i].label,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: i == currentStep ? FontWeight.bold : FontWeight.w500,
                    color: i == currentStep
                        ? CelestialTheme.goldLight
                        : (i < currentStep ? CelestialTheme.creamSoft : CelestialTheme.textMuted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReceiptInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: CelestialTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.outfit(
              color: CelestialTheme.textLight,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}
