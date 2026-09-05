import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../models/customer_feedback.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import 'order_tracking_qr_dialog.dart';
import 'receipt_dialog.dart';

/// Modal Pop-up Dialog for viewing complete order details
class OrderDetailsDialog extends StatelessWidget {
  final Order order;

  const OrderDetailsDialog({super.key, required this.order});

  static void show(BuildContext context, Order order) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => OrderDetailsDialog(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final posProvider = Provider.of<PosProvider>(context);

    // Look up the freshest copy of the order from provider if available
    final currentOrder = posProvider.orders.firstWhere(
      (o) => o.id == order.id,
      orElse: () => order,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 24,
        vertical: 20,
      ),
      child: Container(
        width: 520,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF15100B),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.85),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: CelestialTheme.caramelAccent.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Modal Drag Pill
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Modal Header
            _buildModalHeader(context, currentOrder),

            const Divider(height: 1, color: Color(0x1FFFFFFF)),

            // Scrollable Order Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meta Information Card (Date, Table, Customer, Cashier)
                    _buildMetaCard(currentOrder),

                    const SizedBox(height: 16),

                    // Items Title & Total items count
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.restaurant_menu_rounded, size: 16, color: CelestialTheme.goldPrimary),
                            const SizedBox(width: 6),
                            Text(
                              'ORDERED ITEMS',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: CelestialTheme.textLight,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${currentOrder.items.fold<int>(0, (sum, i) => sum + i.quantity)} items',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.goldLight,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Itemized Cards List
                    ...currentOrder.items.map((item) => _buildOrderItemCard(item)),

                    const SizedBox(height: 16),

                    // Payment & Bill Breakdown Card
                    _buildPaymentSummaryCard(currentOrder),

                    // Customer Feedback & Rating Card (if submitted by customer)
                    if (currentOrder.customerFeedback != null) ...[
                      const SizedBox(height: 16),
                      _buildCustomerFeedbackCard(currentOrder.customerFeedback!),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0x1FFFFFFF)),

            // Modal Action Buttons Footer
            _buildModalFooter(context, currentOrder),
          ],
        ),
      ),
    );
  }

  Widget _buildModalHeader(BuildContext context, Order order) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Order Number Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2C1C13), Color(0xFF1E130D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: CelestialTheme.goldPrimary.withValues(alpha: 0.5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              order.orderNumber,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: CelestialTheme.goldLight,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Order Type Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Details',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: CelestialTheme.textLight,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (order.orderType == OrderType.takeaway || order.orderType == OrderType.delivery)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9F1C).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFF9F1C).withValues(alpha: 0.55)),
                        ),
                        child: const Text(
                          '🥡 TAKE OUT',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFFB74D),
                          ),
                        ),
                      )
                    else
                      Text(
                        '${order.orderType.label} • ${order.tableNumber ?? "Table"}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: CelestialTheme.goldLight,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _getStatusColor(order.status).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getStatusColor(order.status).withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(order.status.icon, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 5),
                Text(
                  order.status.label.split(' / ').first,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(order.status),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Close Button (X)
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: CelestialTheme.textMuted, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Close Modal',
          ),
        ],
      ),
    );
  }

  Widget _buildMetaCard(Order order) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CelestialTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetaItem(
                  icon: Icons.access_time_rounded,
                  label: 'DATE & TIME',
                  value: DateFormat('MMM d, y • h:mm a').format(order.createdAt),
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetaItem(
                  icon: Icons.person_outline_rounded,
                  label: 'CUSTOMER',
                  value: order.customerName,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0x10FFFFFF)),
          ),
          Row(
            children: [
              Expanded(
                child: _buildMetaItem(
                  icon: Icons.badge_outlined,
                  label: 'CASHIER',
                  value: order.cashierName.isNotEmpty ? order.cashierName : 'POS Terminal',
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetaItem(
                  icon: Icons.payment_rounded,
                  label: 'PAYMENT',
                  value: order.paymentMethod.label,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: CelestialTheme.goldPrimary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.7,
                  color: CelestialTheme.textSubtle,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: CelestialTheme.textLight,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItemCard(OrderItem item) {
    final isKitchen = item.isKitchenDish;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CelestialTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quantity Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: CelestialTheme.caramelAccent.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: CelestialTheme.caramelAccent.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${item.quantity}x',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: CelestialTheme.goldLight,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Item Name & Category Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.menuItem.name,
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.textLight,
                            ),
                          ),
                        ),
                        if (isKitchen)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF7043).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFFF7043).withValues(alpha: 0.55)),
                            ),
                            child: const Text(
                              'KITCHEN',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFF7043),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '₱${item.unitPrice.toStringAsFixed(0)} each',
                      style: const TextStyle(fontSize: 11, color: CelestialTheme.textSubtle),
                    ),
                  ],
                ),
              ),

              // Total Item Price
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

          // Customizations Pills
          if (item.customizations.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: item.customizations.map((c) {
                final extra = c.extraPrice > 0 ? ' (+₱${c.extraPrice.toStringAsFixed(0)})' : '';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Text(
                    '› ${c.optionName}$extra',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: CelestialTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Special Notes
          if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFD9534F).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFD9534F).withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, size: 14, color: Color(0xFFFF8A80)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Note: "${item.notes!}"',
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF8A80),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryCard(Order order) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CelestialTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Subtotal', '₱${order.subtotal.toStringAsFixed(0)}'),
          if (order.discountAmount > 0) ...[
            const SizedBox(height: 5),
            _buildSummaryRow(
              'Discount${order.discountPercentage > 0 ? " (${order.discountPercentage.toStringAsFixed(0)}%)" : ""}',
              '-₱${order.discountAmount.toStringAsFixed(0)}',
              valueColor: CelestialTheme.emeraldReady,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0x18FFFFFF)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL BILL',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: CelestialTheme.goldLight,
                ),
              ),
              Text(
                '₱${order.totalAmount.toStringAsFixed(0)}',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: CelestialTheme.goldLight,
                ),
              ),
            ],
          ),
          if (order.amountTendered > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('Received: ', style: TextStyle(fontSize: 11, color: CelestialTheme.textSubtle)),
                      Text(
                        '₱${order.amountTendered.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CelestialTheme.blueInfo),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Change: ', style: TextStyle(fontSize: 11, color: CelestialTheme.textSubtle)),
                      Text(
                        '₱${order.changeDue.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: order.changeDue > 0 ? CelestialTheme.emeraldReady : CelestialTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerFeedbackCard(CustomerFeedback feedback) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1611),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 18, color: CelestialTheme.goldLight),
                  const SizedBox(width: 6),
                  Text(
                    'CUSTOMER FEEDBACK & RATING',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: CelestialTheme.goldLight,
                    ),
                  ),
                ],
              ),
              // Stars
              Row(
                children: List.generate(5, (index) {
                  final filled = index < feedback.rating;
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 16,
                    color: filled ? const Color(0xFFFFB800) : Colors.white24,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '${feedback.rating} / 5 Stars',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: CelestialTheme.goldLight,
                  ),
                ),
              ),
              if (feedback.customerName.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  'by ${feedback.customerName}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: CelestialTheme.textSubtle,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                DateFormat('MMM d, h:mm a').format(feedback.createdAt),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: CelestialTheme.textMuted,
                ),
              ),
            ],
          ),
          if (feedback.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: feedback.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 11,
                      color: CelestialTheme.textLight,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (feedback.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                '“${feedback.message}”',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: CelestialTheme.textLight,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: CelestialTheme.textMuted)),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? CelestialTheme.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildModalFooter(BuildContext context, Order order) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Tracking QR Button
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              OrderTrackingQrDialog.show(context, order);
            },
            icon: const Icon(Icons.qr_code_2_rounded, size: 16, color: CelestialTheme.goldLight),
            label: const Text('Tracking QR', style: TextStyle(fontSize: 11.5, color: CelestialTheme.goldLight)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 8),

          // Print Receipt Button
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                DialogRoute(
                  context: context,
                  barrierDismissible: false,
                  barrierColor: Colors.black.withValues(alpha: 0.8),
                  builder: (ctx) => ReceiptDialog(order: order),
                ),
              );
            },
            icon: const Icon(Icons.receipt_rounded, size: 16, color: CelestialTheme.goldPrimary),
            label: const Text('Receipt', style: TextStyle(fontSize: 11.5, color: CelestialTheme.goldPrimary)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 8),

          // Close CTA
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: CelestialTheme.goldPrimary,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              child: const Text(
                'Close',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: CelestialTheme.bgDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
      case OrderStatus.ready:
        return CelestialTheme.emeraldReady;
      case OrderStatus.preparing:
        return CelestialTheme.amberBrewing;
      case OrderStatus.confirmed:
      case OrderStatus.pending:
        return CelestialTheme.goldPrimary;
      case OrderStatus.cancelled:
        return CelestialTheme.roseAlert;
    }
  }
}
