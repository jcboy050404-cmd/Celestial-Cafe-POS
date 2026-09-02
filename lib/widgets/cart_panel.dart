import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import 'checkout_modal.dart';
import 'receipt_dialog.dart';

class CartPanel extends StatelessWidget {
  final bool isMobileModal;

  const CartPanel({
    super.key,
    this.isMobileModal = false,
  });

  void _showDiscountDialog(BuildContext context, PosProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: CelestialTheme.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
          ),
          title: Text(
            'Apply Order Discount',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: CelestialTheme.goldLight,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [0, 5, 10, 15, 20, 25].map((pct) {
                  final isSelected = provider.discountPercentage == pct.toDouble() && provider.customDiscountAmount == 0;
                  return ChoiceChip(
                    label: Text(pct == 0 ? 'No Discount' : '$pct% OFF'),
                    selected: isSelected,
                    selectedColor: CelestialTheme.goldPrimary,
                    backgroundColor: CelestialTheme.bgCard,
                    labelStyle: TextStyle(
                      color: isSelected ? CelestialTheme.bgDark : CelestialTheme.textLight,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (selected) {
                      provider.applyDiscount(percentage: pct.toDouble());
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTableSelector(BuildContext context, PosProvider provider) {
    final tables = List.generate(12, (i) => 'Table ${(i + 1).toString().padLeft(2, "0")}')..addAll(['VIP Lounge 1', 'Patio Bar']);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: CelestialTheme.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
          ),
          title: Text(
            'Select Table / Area',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: CelestialTheme.goldLight,
            ),
          ),
          content: SizedBox(
            width: 320,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tables.map((tbl) {
                final isSelected = provider.tableNumber == tbl;
                return ChoiceChip(
                  label: Text(tbl),
                  selected: isSelected,
                  selectedColor: CelestialTheme.goldPrimary,
                  backgroundColor: CelestialTheme.bgCard,
                  labelStyle: TextStyle(
                    color: isSelected ? CelestialTheme.bgDark : CelestialTheme.textLight,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      provider.setTableNumber(tbl);
                      Navigator.pop(ctx);
                    }
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);

    return Container(
      width: isMobileModal ? double.infinity : 380,
      decoration: BoxDecoration(
        color: CelestialTheme.bgSurface,
        borderRadius: isMobileModal
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.zero,
        border: isMobileModal
            ? Border(
                top: BorderSide(
                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              )
            : Border(
                left: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
      ),
      child: Column(
        children: [
          // Drag handle for mobile modal
          if (isMobileModal) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],

          // Order Header & Clear button
          _buildCartHeader(context, posProvider),

          if (posProvider.pendingCustomerOrders.isNotEmpty)
            InkWell(
              onTap: () {
                if (isMobileModal) Navigator.pop(context);
                posProvider.setNavIndex(1);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                  border: Border(
                    bottom: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.6), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top_rounded, size: 16, color: CelestialTheme.goldLight),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${posProvider.pendingCustomerOrders.length} Pending Table Order${posProvider.pendingCustomerOrders.length > 1 ? 's' : ''} • Tap to Review',
                        style: const TextStyle(
                          color: CelestialTheme.goldLight,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: CelestialTheme.goldLight),
                  ],
                ),
              ),
            ),

          const Divider(height: 1),

          // Order Type Selector (Dine-in, Takeaway, Delivery)
          _buildOrderTypeSelector(context, posProvider),

          const Divider(height: 1),

          // Cart Items List
          Expanded(
            child: posProvider.cart.isEmpty
                ? _buildEmptyCart()
                : _buildCartItemsList(posProvider),
          ),

          const Divider(height: 1),

          // Bill Summary & Checkout Button
          _buildSummaryAndCheckout(context, posProvider),
        ],
      ),
    );
  }

  Widget _buildCartHeader(BuildContext context, PosProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      color: CelestialTheme.bgCard,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, color: CelestialTheme.goldPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Current Order',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: CelestialTheme.textLight,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${provider.cartItemCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: CelestialTheme.goldLight,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (provider.cart.isNotEmpty)
                TextButton.icon(
                  onPressed: () => provider.clearCart(),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: CelestialTheme.roseAlert),
                  label: const Text(
                    'Clear',
                    style: TextStyle(color: CelestialTheme.roseAlert, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              if (isMobileModal) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: CelestialTheme.textMuted),
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTypeSelector(BuildContext context, PosProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: CelestialTheme.bgSurface,
      child: Column(
        children: [
          Row(
            children: OrderType.values.map((type) {
              final isSelected = provider.orderType == type;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => provider.setOrderType(type),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? CelestialTheme.goldPrimary
                            : CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? CelestialTheme.goldPrimary
                              : Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(type.icon, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              type.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? CelestialTheme.bgDark
                                    : CelestialTheme.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (provider.orderType == OrderType.dineIn) ...[
                Expanded(
                  child: InkWell(
                    onTap: () => _showTableSelector(context, provider),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.table_restaurant_rounded, size: 16, color: CelestialTheme.goldLight),
                              const SizedBox(width: 6),
                              Text(
                                provider.tableNumber,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CelestialTheme.textLight),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_drop_down, color: CelestialTheme.goldPrimary, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: CelestialTheme.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 15, color: CelestialTheme.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          style: const TextStyle(fontSize: 12, color: CelestialTheme.textLight),
                          decoration: const InputDecoration(
                            hintText: 'Customer Name',
                            hintStyle: TextStyle(fontSize: 11, color: CelestialTheme.textSubtle),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) => provider.setCustomerName(val),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CelestialTheme.bgCard,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Center(
                child: Icon(Icons.coffee_rounded, size: 32, color: CelestialTheme.goldPrimary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Tray is Empty',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: CelestialTheme.textLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Select coffee, milktea, frappes & bites from the menu on the left.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: CelestialTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemsList(PosProvider provider) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: provider.cart.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = provider.cart[index];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CelestialTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Price & Remove
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.menuItem.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.menuItem.name,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.textLight,
                          ),
                        ),
                        Text(
                          '₱${item.unitPrice.toStringAsFixed(0)} each',
                          style: const TextStyle(
                            fontSize: 11,
                            color: CelestialTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₱${item.totalPrice.toStringAsFixed(0)}',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: CelestialTheme.goldLight,
                    ),
                  ),
                ],
              ),

              // Customizations pills
              if (item.customizations.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: item.customizations.map((c) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CelestialTheme.brownWarm.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        c.summary,
                        style: const TextStyle(
                          fontSize: 10,
                          color: CelestialTheme.goldLight,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Notes
              if (item.notes != null && item.notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Note: "${item.notes}"',
                  style: const TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: CelestialTheme.amberWarm,
                  ),
                ),
              ],

              const SizedBox(height: 8),

              // Quantity Controls & Trash
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: CelestialTheme.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => provider.updateCartQuantity(item.id, -1),
                          icon: const Icon(Icons.remove_rounded, size: 14),
                          color: CelestialTheme.goldPrimary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.textLight,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => provider.updateCartQuantity(item.id, 1),
                          icon: const Icon(Icons.add_rounded, size: 14),
                          color: CelestialTheme.goldPrimary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed: () => provider.removeFromCart(item.id),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: CelestialTheme.textSubtle),
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryAndCheckout(BuildContext context, PosProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: CelestialTheme.bgCard,
      child: Column(
        children: [
          // Subtotal
          _buildRow('Subtotal', '₱${provider.cartSubtotal.toStringAsFixed(0)}'),

          // Discount Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Discount',
                    style: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _showDiscountDialog(context, provider),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: CelestialTheme.goldPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        provider.discountPercentage > 0
                            ? '${provider.discountPercentage.toStringAsFixed(0)}% OFF'
                            : '+ Add',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.goldLight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '-₱${provider.cartDiscountAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: provider.cartDiscountAmount > 0
                      ? CelestialTheme.roseAlert
                      : CelestialTheme.textMuted,
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),

          // Grand Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Grand Total',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: CelestialTheme.textLight,
                ),
              ),
              Text(
                '₱${provider.cartGrandTotal.toStringAsFixed(0)}',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: CelestialTheme.goldLight,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Charge Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: provider.cart.isEmpty
                  ? null
                  : () async {
                      if (isMobileModal) {
                        Navigator.pop(context); // Close bottom sheet before opening checkout modal
                      }
                      final createdOrder = await showDialog<Order>(
                        context: context,
                        barrierDismissible: false,
                        barrierColor: Colors.black.withValues(alpha: 0.8),
                        builder: (ctx) => const CheckoutModal(),
                      );

                      if (createdOrder != null && context.mounted) {
                        // Open Receipt Dialog directly on host app
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          barrierColor: Colors.black.withValues(alpha: 0.8),
                          builder: (ctx) => ReceiptDialog(order: createdOrder),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: CelestialTheme.goldPrimary,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.06),
                foregroundColor: CelestialTheme.bgDark,
                elevation: 6,
                shadowColor: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.flash_on_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Charge • ₱${provider.cartGrandTotal.toStringAsFixed(0)}',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CelestialTheme.textLight),
          ),
        ],
      ),
    );
  }
}
