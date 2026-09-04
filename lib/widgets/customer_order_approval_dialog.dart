import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import 'customization_dialog.dart';
import 'receipt_dialog.dart';

class CustomerOrderApprovalDialog extends StatefulWidget {
  final Order order;

  const CustomerOrderApprovalDialog({
    super.key,
    required this.order,
  });

  static Future<void> show(BuildContext context, Order order) async {
    final approvedOrder = await showDialog<Order>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => CustomerOrderApprovalDialog(order: order),
    );

    if (approvedOrder != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: CelestialTheme.bgCard,
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: CelestialTheme.emeraldReady, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Order ${approvedOrder.orderNumber} approved & moved to kitchen queue.',
                  style: const TextStyle(color: CelestialTheme.textLight, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );

      // Open receipt review & print dialog directly on host app
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.8),
        builder: (ctx) => ReceiptDialog(order: approvedOrder),
      );
    }
  }

  static Future<void> showPendingList(BuildContext context) async {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => const _PendingCustomerOrdersListDialog(),
    );
  }

  @override
  State<CustomerOrderApprovalDialog> createState() => _CustomerOrderApprovalDialogState();
}

class _CustomerOrderApprovalDialogState extends State<CustomerOrderApprovalDialog> {
  late PaymentMethod _selectedPaymentMethod;
  late List<OrderItem> _items;
  final TextEditingController _cashTenderedController = TextEditingController();

  double _discountPercentage = 0.0;
  double _amountTendered = 0.0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethod = widget.order.paymentMethod;
    _discountPercentage = widget.order.discountPercentage;
    _items = widget.order.items.map((i) => i.copyWith()).toList();

    final initialTotal = _calculateTotal();
    _amountTendered = initialTotal;
    _cashTenderedController.text = _amountTendered > 0 ? _amountTendered.toStringAsFixed(0) : '';
  }

  @override
  void dispose() {
    _cashTenderedController.dispose();
    super.dispose();
  }

  double _calculateSubtotal() {
    return _items.fold(0.0, (sum, i) => sum + i.totalPrice);
  }

  double _calculateDiscountAmount() {
    return _calculateSubtotal() * (_discountPercentage / 100);
  }

  double _calculateTotal() {
    return (_calculateSubtotal() - _calculateDiscountAmount()).clamp(0.0, double.infinity);
  }

  void _syncOrderItems() {
    final posProvider = Provider.of<PosProvider>(context, listen: false);
    posProvider.updatePendingOrderItems(
      orderId: widget.order.id,
      newItems: _items,
      orderNotes: widget.order.orderNotes,
    );
    final total = _calculateTotal();
    if (_selectedPaymentMethod == PaymentMethod.cash && _amountTendered < total) {
      _amountTendered = total;
      _cashTenderedController.text = total.toStringAsFixed(0);
    }
  }

  void _incrementItemQuantity(int index) {
    final posProvider = Provider.of<PosProvider>(context, listen: false);
    final item = _items[index];
    final menuItem = posProvider.menuItems.where((m) => m.id == item.menuItem.id).firstOrNull;
    if (menuItem != null && menuItem.stockCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.menuItem.name} is out of stock.'),
          backgroundColor: CelestialTheme.roseAlert,
        ),
      );
      return;
    }
    setState(() {
      _items[index] = item.copyWith(quantity: item.quantity + 1);
      _syncOrderItems();
    });
  }

  void _decrementItemQuantity(int index) {
    setState(() {
      final item = _items[index];
      if (item.quantity > 1) {
        _items[index] = item.copyWith(quantity: item.quantity - 1);
      } else {
        _items.removeAt(index);
      }
      _syncOrderItems();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _syncOrderItems();
    });
  }

  void _handleLoadIntoPosCart() {
    final posProvider = Provider.of<PosProvider>(context, listen: false);
    posProvider.loadPendingOrderIntoPosCart(widget.order.id);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: CelestialTheme.bgCard,
        content: Row(
          children: [
            const Icon(Icons.shopping_cart_checkout_rounded, color: CelestialTheme.goldLight),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Order ${widget.order.orderNumber} loaded into POS Cart for modification.',
                style: const TextStyle(fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => _AddItemModal(
        onItemSelected: (MenuItem menuItem) {
          if (menuItem.customizationGroups.isNotEmpty) {
            showDialog(
              context: context,
              builder: (ctx) => CustomizationDialog(
                item: menuItem,
                onAddToCart: (quantity, customizations, notes) {
                  setState(() {
                    _items.add(OrderItem(
                      id: 'cashier_add_${menuItem.id}_${DateTime.now().millisecondsSinceEpoch}',
                      menuItem: menuItem,
                      quantity: quantity,
                      customizations: customizations,
                      notes: notes,
                    ));
                    _syncOrderItems();
                  });
                },
              ),
            );
          } else {
            setState(() {
              _items.add(OrderItem(
                id: 'cashier_add_${menuItem.id}_${DateTime.now().millisecondsSinceEpoch}',
                menuItem: menuItem,
                quantity: 1,
                customizations: const [],
              ));
              _syncOrderItems();
            });
          }
        },
      ),
    );
  }

  void _selectCashPreset(double amount) {
    setState(() {
      _amountTendered = amount;
      _cashTenderedController.text = amount.toStringAsFixed(0);
    });
  }

  void _handleApproveAndSettle() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot approve order with no items. Add items or decline order.'),
          backgroundColor: CelestialTheme.roseAlert,
        ),
      );
      return;
    }

    final total = _calculateTotal();

    if (_selectedPaymentMethod == PaymentMethod.cash && _amountTendered < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tendered amount cannot be less than total bill.'),
          backgroundColor: CelestialTheme.roseAlert,
        ),
      );
      return;
    }

    final posProvider = Provider.of<PosProvider>(context, listen: false);

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 280));

    final approvedOrder = posProvider.approveAndSettleCustomerOrder(
      orderId: widget.order.id,
      paymentMethod: _selectedPaymentMethod,
      amountTendered: _selectedPaymentMethod == PaymentMethod.cash ? _amountTendered : total,
      discountPercentage: _discountPercentage,
      discountAmount: _calculateDiscountAmount(),
      orderNotes: widget.order.orderNotes,
    );

    if (mounted) setState(() => _isSubmitting = false);
    if (!mounted) return;
    Navigator.pop(context, approvedOrder); // Close approval dialog returning approved order
  }

  void _handleDeclineOrder() {
    bool isDeclining = false;
    final posProvider = Provider.of<PosProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final approvalDialogNavigator = Navigator.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.4)),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: CelestialTheme.roseAlert),
            const SizedBox(width: 8),
            Text(
              'Decline Order ${widget.order.orderNumber}?',
              style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to void and decline this customer order for ${widget.order.customerName} (${widget.order.tableNumber ?? "Dine-In"})?\n\nAll items will be returned to inventory stock.',
          style: const TextStyle(color: CelestialTheme.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          StatefulBuilder(
            builder: (ctx, setDeclineState) {
              return ElevatedButton(
                onPressed: isDeclining
                    ? null
                    : () async {
                        setDeclineState(() => isDeclining = true);
                        await Future.delayed(const Duration(milliseconds: 250));
                        posProvider.rejectCustomerOrder(widget.order.id, restock: true);
                        if (ctx.mounted) Navigator.pop(ctx); // Close confirmation
                        if (mounted) approvalDialogNavigator.pop(); // Close approval dialog
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            backgroundColor: CelestialTheme.bgCard,
                            content: Text('Order ${widget.order.orderNumber} declined and voided.'),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CelestialTheme.roseAlert,
                  foregroundColor: Colors.white,
                ),
                child: isDeclining
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Yes, Decline Order'),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 650;
    final total = _calculateTotal();
    final discountAmount = _calculateDiscountAmount();
    final changeDue = double.parse(((_amountTendered - total).clamp(0.0, double.infinity)).toStringAsFixed(2));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: isMobile ? double.infinity : 640,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * (isMobile ? 0.94 : 0.9),
        ),
        decoration: BoxDecoration(
          color: CelestialTheme.bgSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: CelestialTheme.borderSubtle,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Bar
            _buildHeader(isMobile),

            const Divider(height: 1),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pending Notice Banner
                    _buildPendingNoticeBanner(),

                    const SizedBox(height: 16),

                    // Order Items Breakdown Card
                    _buildItemsBreakdownCard(),

                    const SizedBox(height: 16),

                    // Discounts Selector
                    _buildDiscountSelector(),

                    const SizedBox(height: 16),

                    // Bill Summary Card
                    _buildBillSummaryCard(total, discountAmount),

                    const SizedBox(height: 18),

                    // Payment Method Tabs
                    Text(
                      'Payment Method',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.goldLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPaymentMethodTabs(isMobile),

                    const SizedBox(height: 16),

                    // Payment Method Details (Cash Tender Calculator)
                    if (_selectedPaymentMethod == PaymentMethod.cash)
                      _buildCashTenderCalculator(total, changeDue, isMobile)
                    else
                      _buildDigitalPaymentNotice('GCash Mobile Wallet', Icons.phone_android_rounded, CelestialTheme.blueInfo),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // Footer Action Buttons
            _buildFooterActions(total, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 22,
        vertical: isMobile ? 14 : 18,
      ),
      decoration: const BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CelestialTheme.caramelAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CelestialTheme.caramelAccent.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: CelestialTheme.caramelAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Order ${widget.order.orderNumber}',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 17 : 20,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.creamLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: CelestialTheme.amberBrewing.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: CelestialTheme.amberBrewing.withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          (widget.order.tableNumber ?? 'Dine-In').replaceAll(RegExp(r'^T+able', caseSensitive: false), 'Table'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.amberBrewing,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Guest: ${widget.order.customerName} • Placed ${widget.order.durationString}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: CelestialTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: CelestialTheme.textMuted),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingNoticeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CelestialTheme.amberBrewing.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CelestialTheme.amberBrewing.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: CelestialTheme.amberBrewing, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AWAITING CASHIER CONFIRMATION & PAYMENT',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: CelestialTheme.amberBrewing,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Customer self-ordered from table. Confirm payment to approve and send ticket to the kitchen brewing queue.',
                  style: TextStyle(fontSize: 11, color: CelestialTheme.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsBreakdownCard() {
    final subtotal = _calculateSubtotal();
    final totalCount = _items.fold(0, (s, i) => s + i.quantity);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'ORDER ITEMS ($totalCount)',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: CelestialTheme.creamLight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: CelestialTheme.caramelAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Editable', style: TextStyle(fontSize: 9, color: CelestialTheme.caramelAccent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              Text(
                'Subtotal: ₱${subtotal.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CelestialTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    const Text('All items removed from this order.', style: TextStyle(color: CelestialTheme.textMuted, fontSize: 12)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _showAddItemDialog,
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: const Text('Add Items from Menu', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CelestialTheme.caramelAccent,
                        foregroundColor: CelestialTheme.bgDark,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (ctx, idx) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Divider(height: 1, color: Color(0x15FFFFFF)),
              ),
              itemBuilder: (context, idx) {
                final item = _items[idx];
                final customsText = item.customizations.map((c) => c.summary).join(', ');

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Quantity Stepper Controls (- / qty / +)
                    Container(
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => _decrementItemQuantity(idx),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Icon(Icons.remove, size: 13, color: CelestialTheme.goldLight),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                            ),
                          ),
                          InkWell(
                            onTap: () => _incrementItemQuantity(idx),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Icon(Icons.add, size: 13, color: CelestialTheme.goldLight),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Item Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.menuItem.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: item.isKitchenDish ? const Color(0xFFFFE0B2) : CelestialTheme.textLight,
                                  ),
                                ),
                              ),
                              if (item.isKitchenDish)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  margin: const EdgeInsets.only(left: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF5722).withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFFF5722).withValues(alpha: 0.65)),
                                  ),
                                  child: const Text(
                                    'KITCHEN',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFFF7043),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (customsText.isNotEmpty)
                            Text(
                              customsText,
                              style: const TextStyle(fontSize: 11, color: CelestialTheme.goldLight),
                            ),
                          if (item.notes != null && item.notes!.isNotEmpty)
                            Text(
                              'Note: ${item.notes}',
                              style: const TextStyle(fontSize: 10.5, color: CelestialTheme.roseAlert, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),

                    // Item Price
                    Text(
                      '₱${item.totalPrice.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 4),

                    // Delete button
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: CelestialTheme.textMuted),
                      onPressed: () => _removeItem(idx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      tooltip: 'Remove Item',
                    ),
                  ],
                );
              },
            ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Action Buttons: + Add Item from Menu & Edit in POS Cart
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showAddItemDialog,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 15, color: CelestialTheme.goldLight),
                  label: const Text('+ Add Item', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handleLoadIntoPosCart,
                  icon: const Icon(Icons.shopping_cart_outlined, size: 15, color: CelestialTheme.textLight),
                  label: const Text('Edit in POS Cart', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CelestialTheme.textLight)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountSelector() {
    final discountOptions = [0, 5, 10, 15, 20, 25];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Apply Discount',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: CelestialTheme.goldLight,
              ),
            ),
            if (_discountPercentage > 0)
              Text(
                '${_discountPercentage.toStringAsFixed(0)}% Applied',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CelestialTheme.emeraldReady),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: discountOptions.map((pct) {
            final isSelected = _discountPercentage == pct.toDouble();
            final label = pct == 0 ? 'No Discount' : (pct == 20 ? '20% Senior/PWD' : '$pct% OFF');

            return ChoiceChip(
              label: Text(label),
              selected: isSelected,
              selectedColor: CelestialTheme.goldPrimary,
              backgroundColor: CelestialTheme.bgCard,
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? CelestialTheme.bgDark : CelestialTheme.textLight,
              ),
              side: BorderSide(
                color: isSelected ? CelestialTheme.goldPrimary : Colors.white.withValues(alpha: 0.08),
              ),
              onSelected: (_) {
                setState(() {
                  _discountPercentage = pct.toDouble();
                  final newTotal = _calculateTotal();
                  _amountTendered = newTotal;
                  _cashTenderedController.text = newTotal.toStringAsFixed(0);
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBillSummaryCard(double total, double discountAmount) {
    final subtotal = _calculateSubtotal();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: CelestialTheme.brownGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal Amount', style: TextStyle(fontSize: 12, color: CelestialTheme.textMuted)),
              Text('₱${subtotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: CelestialTheme.textLight)),
            ],
          ),
          if (discountAmount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Discount (${_discountPercentage.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 12, color: CelestialTheme.emeraldReady)),
                Text('-₱${discountAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CelestialTheme.emeraldReady)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0x25FFFFFF)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL TO PAY',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: CelestialTheme.goldLight),
              ),
              Text(
                '₱${total.toStringAsFixed(0)}',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodTabs(bool isMobile) {
    final methods = [
      (PaymentMethod.cash, 'Cash', Icons.payments_outlined),
      (PaymentMethod.mobilePay, 'GCash', Icons.phone_android_rounded),
    ];

    if (isMobile) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.5,
        children: methods.map((m) => _buildMethodChip(m.$1, m.$2, m.$3)).toList(),
      );
    }

    return Row(
      children: methods.map((m) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _buildMethodChip(m.$1, m.$2, m.$3)))).toList(),
    );
  }

  Widget _buildMethodChip(PaymentMethod method, String label, IconData icon) {
    final isSelected = _selectedPaymentMethod == method;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = method;
          if (method != PaymentMethod.cash) {
            _amountTendered = _calculateTotal();
            _cashTenderedController.text = _amountTendered.toStringAsFixed(0);
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? CelestialTheme.goldPrimary.withValues(alpha: 0.2)
              : CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? CelestialTheme.goldPrimary
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? CelestialTheme.goldLight : CelestialTheme.textMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? CelestialTheme.goldLight : CelestialTheme.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashTenderCalculator(double total, double changeDue, bool isMobile) {
    final presets = [
      total,
      100.0,
      200.0,
      500.0,
      1000.0,
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CASH TENDERED',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: CelestialTheme.textMuted,
                ),
              ),
              Text(
                'Enter customer payment',
                style: TextStyle(fontSize: 11, color: CelestialTheme.textSubtle),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Cash Tender Input Field
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: CelestialTheme.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text('₱', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: CelestialTheme.goldPrimary)),
                ),
                Expanded(
                  child: TextField(
                    controller: _cashTenderedController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: CelestialTheme.textLight,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(color: CelestialTheme.textSubtle),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _amountTendered = double.tryParse(val.trim().replaceAll(',', '.')) ?? 0.0;
                      });
                    },
                  ),
                ),
                if (_cashTenderedController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16, color: CelestialTheme.textMuted),
                    onPressed: () {
                      setState(() {
                        _amountTendered = 0.0;
                        _cashTenderedController.clear();
                      });
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Cash Presets Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presets.map((preset) {
                final isExact = (preset - total).abs() < 0.01;
                final label = isExact ? 'Exact (₱${preset.toStringAsFixed(0)})' : '₱${preset.toStringAsFixed(0)}';

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(label),
                    backgroundColor: isExact
                        ? CelestialTheme.goldPrimary.withValues(alpha: 0.25)
                        : CelestialTheme.bgSurface,
                    side: BorderSide(
                      color: isExact
                          ? CelestialTheme.goldPrimary
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isExact ? FontWeight.bold : FontWeight.w600,
                      color: isExact ? CelestialTheme.goldLight : CelestialTheme.textLight,
                    ),
                    onPressed: () => _selectCashPreset(preset),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Change Due Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _amountTendered >= total
                  ? CelestialTheme.emeraldReady.withValues(alpha: 0.12)
                  : CelestialTheme.roseAlert.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _amountTendered >= total
                    ? CelestialTheme.emeraldReady.withValues(alpha: 0.4)
                    : CelestialTheme.roseAlert.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _amountTendered >= total ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                      size: 18,
                      color: _amountTendered >= total ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _amountTendered >= total ? 'CHANGE DUE' : 'AMOUNT SHORT',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: _amountTendered >= total ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                      ),
                    ),
                  ],
                ),
                Text(
                  _amountTendered >= total
                      ? '₱${changeDue.toStringAsFixed(0)}'
                      : '-₱${(total - _amountTendered).toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _amountTendered >= total ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalPaymentNotice(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Collect digital payment from customer, verify reference/receipt, then tap Approve.',
                  style: TextStyle(fontSize: 11, color: CelestialTheme.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions(double total, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 20,
        vertical: isMobile ? 12 : 16,
      ),
      color: CelestialTheme.bgCard,
      child: Row(
        children: [
          // Decline / Void button
          OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _handleDeclineOrder,
            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: CelestialTheme.roseAlert),
            label: const Text('Decline', style: TextStyle(color: CelestialTheme.roseAlert, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 10),

          // Confirm & Approve Button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _handleApproveAndSettle,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: CelestialTheme.bgDark),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 18, color: CelestialTheme.bgDark),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _isSubmitting
                      ? 'Approving Order...'
                      : (isMobile
                          ? 'Approve & Settle (₱${total.toStringAsFixed(0)})'
                          : 'Approve & Settle Payment (₱${total.toStringAsFixed(0)})'),
                  style: GoogleFonts.outfit(
                    fontSize: isMobile ? 13 : 15,
                    fontWeight: FontWeight.bold,
                    color: CelestialTheme.bgDark,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: CelestialTheme.caramelAccent,
                foregroundColor: CelestialTheme.bgDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingCustomerOrdersListDialog extends StatelessWidget {
  const _PendingCustomerOrdersListDialog();

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final pendingOrders = posProvider.pendingCustomerOrders;
    final isMobile = MediaQuery.of(context).size.width < 650;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: isMobile ? double.infinity : 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: CelestialTheme.bgSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: CelestialTheme.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: CelestialTheme.bgCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: CelestialTheme.amberBrewing.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.hourglass_top_rounded, color: CelestialTheme.amberBrewing, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pending Customer Orders',
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.textLight,
                            ),
                          ),
                          Text(
                            '${pendingOrders.length} order(s) awaiting cashier approval & payment',
                            style: const TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: CelestialTheme.textMuted),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content
            Expanded(
              child: pendingOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 48, color: CelestialTheme.emeraldReady),
                          const SizedBox(height: 12),
                          Text(
                            'All Caught Up!',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.textLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'No customer orders are currently awaiting approval.',
                            style: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: pendingOrders.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final order = pendingOrders[idx];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: CelestialTheme.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: CelestialTheme.goldGradient,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  order.orderNumber,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: CelestialTheme.bgDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          order.customerName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: CelestialTheme.textLight,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '• ${(order.tableNumber ?? "Dine-In").replaceAll(RegExp(r"^T+able", caseSensitive: false), "Table")}',
                                          style: const TextStyle(fontSize: 12, color: CelestialTheme.goldLight),
                                        ),
                                        if (order.hasKitchenDishes) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF5722).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFFF5722).withValues(alpha: 0.6)),
                                            ),
                                            child: Text(
                                              '${order.kitchenDishCount} Kitchen',
                                              style: const TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFFFF7043),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${order.totalItemCount} items: ${order.items.map((i) => "${i.quantity}x ${i.menuItem.name}").join(", ")}',
                                      style: const TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Total: ₱${order.totalAmount.toStringAsFixed(0)} • Placed ${order.durationString}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: CelestialTheme.goldLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context); // Close list dialog
                                  CustomerOrderApprovalDialog.show(context, order);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: CelestialTheme.goldPrimary,
                                  foregroundColor: CelestialTheme.bgDark,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text(
                                  'Review & Pay',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
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
    );
  }
}

class _AddItemModal extends StatefulWidget {
  final Function(MenuItem item) onItemSelected;

  const _AddItemModal({required this.onItemSelected});

  @override
  State<_AddItemModal> createState() => _AddItemModalState();
}

class _AddItemModalState extends State<_AddItemModal> {
  String _search = '';
  ItemCategory _selectedCategory = ItemCategory.all;

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final allItems = posProvider.menuItems;
    final categories = ItemCategory.values;

    final filtered = allItems.where((i) {
      final matchesSearch = i.name.toLowerCase().contains(_search.toLowerCase()) ||
          i.description.toLowerCase().contains(_search.toLowerCase());
      final matchesCategory = _selectedCategory == ItemCategory.all || i.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: CelestialTheme.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
            decoration: const BoxDecoration(
              color: CelestialTheme.bgCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_shopping_cart_rounded, color: CelestialTheme.goldPrimary, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Add Item to Customer Order',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: CelestialTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (val) => setState(() => _search = val),
              style: const TextStyle(color: CelestialTheme.textLight, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search menu items to add...',
                hintStyle: const TextStyle(color: CelestialTheme.textSubtle, fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, color: CelestialTheme.goldPrimary, size: 18),
                filled: true,
                fillColor: CelestialTheme.bgCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),

          // Categories
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              itemBuilder: (ctx, idx) {
                final cat = categories[idx];
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('${cat.icon} ${cat.label}'),
                    selected: isSelected,
                    selectedColor: CelestialTheme.goldPrimary,
                    backgroundColor: CelestialTheme.bgCard,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? CelestialTheme.bgDark : CelestialTheme.textLight,
                    ),
                    side: BorderSide(color: isSelected ? CelestialTheme.goldPrimary : Colors.white.withValues(alpha: 0.08)),
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Items List
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No menu items found', style: TextStyle(color: CelestialTheme.textMuted)))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final item = filtered[idx];
                      final isOut = item.stockCount <= 0;

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: CelestialTheme.bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: CelestialTheme.bgSurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(item.category.icon, style: const TextStyle(fontSize: 20)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CelestialTheme.textLight),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        '₱${item.price.toStringAsFixed(0)}',
                                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isOut ? 'Out of Stock' : '${item.stockCount} in stock',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isOut ? CelestialTheme.roseAlert : CelestialTheme.emeraldReady,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: isOut
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      widget.onItemSelected(item);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: CelestialTheme.goldPrimary,
                                foregroundColor: CelestialTheme.bgDark,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                item.customizationGroups.isNotEmpty ? 'Customize' : '+ Add',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
