import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../services/online_order_service.dart';
import '../theme/celestial_theme.dart';
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
    final data = await OnlineOrderService().fetchStoreCatalog(widget.storeId);
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
    _statusTrackerTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      final orders = await OnlineOrderService().fetchIncomingOrders(widget.storeId);
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

  List<String> get _categories {
    final set = <String>{'all'};
    for (var item in _menuItems) {
      set.add(item.customCategory ?? item.category.name);
    }
    return set.toList();
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
      return;
    }

    final selected = <String, SelectedCustomization>{};
    final notesCtrl = TextEditingController();

    // Defaults
    for (var group in item.customizationGroups) {
      if (group.isRequired && group.options.isNotEmpty) {
        selected[group.title] = SelectedCustomization(
          groupTitle: group.title,
          optionName: group.options.first.name,
          extraPrice: group.options.first.extraPrice,
        );
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CelestialTheme.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          double itemTotal = item.price;
          for (var c in selected.values) {
            itemTotal += c.extraPrice;
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            builder: (_, scrollCtrl) => SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: CelestialTheme.borderWarm, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(item.name, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: CelestialTheme.textLight)),
                  Text(item.description, style: TextStyle(fontSize: 12, color: CelestialTheme.textMuted)),
                  const SizedBox(height: 16),

                  ...item.customizationGroups.map((group) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.title.toUpperCase(),
                          style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: group.options.map((option) {
                            final isSel = selected[group.title]?.optionName == option.name;
                            return ChoiceChip(
                              label: Text(
                                option.extraPrice > 0
                                    ? '${option.name} (+₱${option.extraPrice.toStringAsFixed(0)})'
                                    : option.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: isSel ? CelestialTheme.primaryBtnText : CelestialTheme.textLight,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              selected: isSel,
                              selectedColor: CelestialTheme.goldPrimary,
                              backgroundColor: CelestialTheme.bgCard,
                              onSelected: (val) {
                                setSheetState(() {
                                  if (val) {
                                    selected[group.title] = SelectedCustomization(
                                      groupTitle: group.title,
                                      optionName: option.name,
                                      extraPrice: option.extraPrice,
                                    );
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }),

                  TextField(
                    controller: notesCtrl,
                    style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Special instructions (e.g. less ice, extra shot)',
                      hintStyle: TextStyle(color: CelestialTheme.textSubtle, fontSize: 12),
                      filled: true,
                      fillColor: CelestialTheme.bgCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _addToCart(
                          item,
                          customizations: selected.values.toList(),
                          notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CelestialTheme.goldPrimary,
                        foregroundColor: CelestialTheme.primaryBtnText,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Add to Cart • ₱${itemTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
      backgroundColor: CelestialTheme.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: CelestialTheme.borderWarm, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Complete Your Order', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: CelestialTheme.textLight)),
                  Text('$_cartItemCount items • Total: ₱${_cartTotal.toStringAsFixed(2)}', style: TextStyle(color: CelestialTheme.goldLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),

                  // Order Type Selector
                  Text('ORDER TYPE', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_profile?.allowTakeaway ?? true)
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('🛍️ Pickup')),
                            selected: selectedType == OrderType.takeaway,
                            selectedColor: CelestialTheme.goldPrimary,
                            onSelected: (_) => setSheetState(() => selectedType = OrderType.takeaway),
                          ),
                        ),
                      if ((_profile?.allowTakeaway ?? true) && (_profile?.allowDineIn ?? true)) const SizedBox(width: 8),
                      if (_profile?.allowDineIn ?? true)
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('🍽️ Dine-In')),
                            selected: selectedType == OrderType.dineIn,
                            selectedColor: CelestialTheme.goldPrimary,
                            onSelected: (_) => setSheetState(() => selectedType = OrderType.dineIn),
                          ),
                        ),
                      if ((_profile?.allowDineIn ?? true) && (_profile?.allowDelivery ?? true)) const SizedBox(width: 8),
                      if (_profile?.allowDelivery ?? true)
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('🛵 Delivery')),
                            selected: selectedType == OrderType.delivery,
                            selectedColor: CelestialTheme.goldPrimary,
                            onSelected: (_) => setSheetState(() => selectedType = OrderType.delivery),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Inputs
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Your Name *',
                      filled: true,
                      fillColor: CelestialTheme.bgCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Mobile Phone Number *',
                      filled: true,
                      fillColor: CelestialTheme.bgCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (selectedType == OrderType.dineIn) ...[
                    TextField(
                      controller: tableCtrl,
                      style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Table Number (e.g. Table 04)',
                        filled: true,
                        fillColor: CelestialTheme.bgCard,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else if (selectedType == OrderType.delivery) ...[
                    TextField(
                      controller: addressCtrl,
                      maxLines: 2,
                      style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Complete Delivery Address & Landmark *',
                        filled: true,
                        fillColor: CelestialTheme.bgCard,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  TextField(
                    controller: notesCtrl,
                    style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Order notes / cutlery request (Optional)',
                      filled: true,
                      fillColor: CelestialTheme.bgCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Payment Method
                  Text('PAYMENT METHOD', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('💵 Cash on Counter/Pickup'),
                        selected: selectedPayment == PaymentMethod.cash,
                        selectedColor: CelestialTheme.goldPrimary,
                        onSelected: (_) => setSheetState(() => selectedPayment = PaymentMethod.cash),
                      ),
                      ChoiceChip(
                        label: const Text('📱 GCash'),
                        selected: selectedPayment == PaymentMethod.mobilePay,
                        selectedColor: CelestialTheme.goldPrimary,
                        onSelected: (_) => setSheetState(() => selectedPayment = PaymentMethod.mobilePay),
                      ),
                      if (selectedType == OrderType.delivery)
                        ChoiceChip(
                          label: const Text('🛵 Cash on Delivery (COD)'),
                          selected: selectedPayment == PaymentMethod.cod,
                          selectedColor: CelestialTheme.goldPrimary,
                          onSelected: (_) => setSheetState(() => selectedPayment = PaymentMethod.cod),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
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
                                storeId: widget.storeId,
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
                        backgroundColor: CelestialTheme.goldPrimary,
                        foregroundColor: CelestialTheme.primaryBtnText,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.black)
                          : Text('Place Order • ₱${_cartTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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

            // Category Chips Bar
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                separatorBuilder: (_, index) => const SizedBox(width: 8),
                itemBuilder: (_, idx) {
                  final cat = _categories[idx];
                  final isSel = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(
                      cat == 'all' ? 'All' : cat,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: isSel ? CelestialTheme.primaryBtnText : CelestialTheme.textLight,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSel,
                    selectedColor: CelestialTheme.goldPrimary,
                    backgroundColor: CelestialTheme.bgCard,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  );
                },
              ),
            ),

            // Menu Items Grid/List
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: CelestialTheme.goldPrimary))
                  : _filteredItems.isEmpty
                      ? Center(
                          child: Text(
                            'No menu items found',
                            style: TextStyle(color: CelestialTheme.textMuted),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredItems.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 12),
                          itemBuilder: (_, idx) {
                            final item = _filteredItems[idx];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: CelestialTheme.bgCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: CelestialTheme.borderWarm),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: CelestialTheme.goldPrimary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.coffee_rounded, color: CelestialTheme.goldLight, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                                        ),
                                        if (item.description.isNotEmpty)
                                          Text(
                                            item.description,
                                            style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₱${item.price.toStringAsFixed(2)}',
                                          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: !isOpen ? null : () => _openCustomizationSheet(item),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: CelestialTheme.goldPrimary,
                                      foregroundColor: CelestialTheme.primaryBtnText,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ],
                              ),
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
                          '₱${_cartTotal.toStringAsFixed(2)}',
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

    switch (status) {
      case OrderStatus.pending:
        statusTitle = 'Order Sent • Waiting for Cashier Confirmation';
        statusSubtitle = 'The café has received your order. The cashier will review and confirm shortly.';
        statusIcon = Icons.hourglass_top_rounded;
        statusColor = CelestialTheme.amberBrewing;
        break;
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
        final hasCashier = order.cashierName.isNotEmpty &&
            !order.cashierName.toLowerCase().contains('online') &&
            !order.cashierName.toLowerCase().contains('web');
        statusTitle = 'Order Confirmed by Cashier!';
        statusSubtitle = hasCashier
            ? 'Confirmed by cashier ${order.cashierName}. Kitchen is preparing your items (~${_profile?.estimatedPrepMinutes ?? 15} mins).'
            : 'Confirmed by cashier! Kitchen is preparing your items (~${_profile?.estimatedPrepMinutes ?? 15} mins).';
        statusIcon = Icons.local_fire_department_rounded;
        statusColor = CelestialTheme.goldPrimary;
        break;
      case OrderStatus.ready:
        statusTitle = 'Your Order is Ready!';
        statusSubtitle = order.orderType == OrderType.delivery
            ? 'Order packed and ready for delivery rider.'
            : 'Please pick up your order at the counter.';
        statusIcon = Icons.check_circle_rounded;
        statusColor = CelestialTheme.emeraldReady;
        break;
      case OrderStatus.outForDelivery:
        statusTitle = 'Out for Delivery!';
        statusSubtitle = 'Your rider is on the way to ${order.deliveryAddress ?? 'your address'}.';
        statusIcon = Icons.delivery_dining_rounded;
        statusColor = Colors.cyanAccent;
        break;
      case OrderStatus.completed:
        statusTitle = 'Order Completed!';
        statusSubtitle = 'Thank you for ordering with us!';
        statusIcon = Icons.verified_rounded;
        statusColor = CelestialTheme.emeraldReady;
        break;
      case OrderStatus.cancelled:
        statusTitle = 'Order Cancelled';
        statusSubtitle = 'This order was cancelled by the store.';
        statusIcon = Icons.cancel_outlined;
        statusColor = CelestialTheme.roseAlert;
        break;
    }

    return Scaffold(
      backgroundColor: CelestialTheme.bgSurface,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 2),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 54),
                ),
                const SizedBox(height: 24),
                Text(
                  order.orderNumber,
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight),
                ),
                const SizedBox(height: 8),
                Text(
                  statusTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                ),
                const SizedBox(height: 6),
                Text(
                  statusSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: CelestialTheme.textMuted),
                ),
                const SizedBox(height: 28),

                // Order Details Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CelestialTheme.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: CelestialTheme.borderWarm),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order Type:', style: TextStyle(color: CelestialTheme.textMuted, fontSize: 12)),
                          Text(order.orderType.label, style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      if (order.tableNumber != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Table:', style: TextStyle(color: CelestialTheme.textMuted, fontSize: 12)),
                            Text(order.tableNumber!, style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Amount:', style: TextStyle(color: CelestialTheme.textMuted, fontSize: 12)),
                          Text('₱${order.totalAmount.toStringAsFixed(2)}', style: GoogleFonts.outfit(color: CelestialTheme.goldLight, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _submittedOrder = null;
                      _statusTrackerTimer?.cancel();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: CelestialTheme.goldPrimary),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(Icons.arrow_back_rounded, size: 16, color: CelestialTheme.goldPrimary),
                  label: Text('Back to Menu / Order Again', style: TextStyle(color: CelestialTheme.goldPrimary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
