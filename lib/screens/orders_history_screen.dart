import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import '../widgets/customer_order_approval_dialog.dart';
import '../widgets/receipt_dialog.dart';
import '../widgets/order_tracking_qr_dialog.dart';
import '../widgets/order_details_dialog.dart';
import '../widgets/customer_feedback_dialog.dart';

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  String _searchQuery = '';
  OrderStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    final filteredOrders = posProvider.orders.where((order) {
      if (_searchQuery.isEmpty) return _statusFilter == null || order.status == _statusFilter;

      final q = _searchQuery.toLowerCase().trim();
      final numStr = order.orderNumber.toLowerCase().replaceAll('#', '').trim();
      final fullNum = order.orderNumber.toLowerCase();
      final cust = order.customerName.toLowerCase();
      final table = (order.tableNumber ?? '').toLowerCase();
      final cashier = order.cashierName.toLowerCase();
      final itemsText = order.items.map((i) => i.menuItem.name.toLowerCase()).join(' ');

      final matchesSearch = fullNum.contains(q) ||
          numStr.contains(q) ||
          cust.contains(q) ||
          table.contains(q) ||
          cashier.contains(q) ||
          itemsText.contains(q);

      final matchesStatus = _statusFilter == null || order.status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();

    return Container(
      color: CelestialTheme.bgDark,
      child: Column(
        children: [
          // Filter & Search Header
          _buildHeader(posProvider, isMobile),

          const Divider(height: 1),

          // Orders Table List
          Expanded(
            child: filteredOrders.isEmpty
                ? _buildEmptyState()
                : _buildOrdersList(context, posProvider, filteredOrders, isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(PosProvider provider, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      color: CelestialTheme.bgSurface,
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: CelestialTheme.goldPrimary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Order History',
                  style: GoogleFonts.outfit(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: CelestialTheme.textLight,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showCustomerFeedbackDialog(context, provider),
                icon: const Icon(Icons.rate_review_rounded, size: 14, color: CelestialTheme.goldLight),
                label: Text(
                  'Feedback (${provider.customerFeedbacks.length})',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CelestialTheme.goldLight,
                  side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: CelestialTheme.bgSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                      ),
                      title: Text(
                        'Reset Order Counter',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: CelestialTheme.goldLight),
                      ),
                      content: const Text(
                        'This will reset the order numbering so your next order starts at #1.',
                        style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            provider.resetOrderSequence(startNumber: 1);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: CelestialTheme.bgCard,
                                content: Text('Order counter reset: Next order will be #1'),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CelestialTheme.goldPrimary,
                            foregroundColor: CelestialTheme.bgDark,
                          ),
                          child: const Text('Reset to #1'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.restart_alt_rounded, size: 14),
                label: const Text('Start at #1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CelestialTheme.goldLight,
                  side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Search Input
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: CelestialTheme.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              style: const TextStyle(fontSize: 12, color: CelestialTheme.textLight),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Search order #, guest, table...',
                hintStyle: TextStyle(fontSize: 12, color: CelestialTheme.textSubtle),
                prefixIcon: Icon(Icons.search_rounded, size: 16, color: CelestialTheme.goldPrimary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Status Chips (horizontal scroll)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', null, provider.orders.length),
                const SizedBox(width: 6),
                _buildFilterChip('Completed', OrderStatus.completed, provider.completedOrders.length, CelestialTheme.emeraldReady),
                const SizedBox(width: 6),
                _buildFilterChip('Ready', OrderStatus.ready, provider.readyOrders.length, CelestialTheme.emeraldReady),
                const SizedBox(width: 6),
                _buildFilterChip('Brewing', OrderStatus.preparing, provider.preparingOrders.length, CelestialTheme.amberBrewing),
                const SizedBox(width: 6),
                _buildFilterChip('Pending', OrderStatus.pending, provider.pendingOrders.length, CelestialTheme.goldPrimary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, OrderStatus? status, int count, [Color? color]) {
    final isSelected = _statusFilter == status;
    final activeColor = color ?? CelestialTheme.goldPrimary;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isSelected ? activeColor : CelestialTheme.bgSurface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isSelected ? CelestialTheme.bgDark : CelestialTheme.textLight,
              ),
            ),
          ),
        ],
      ),
      selected: isSelected,
      selectedColor: activeColor.withValues(alpha: 0.25),
      backgroundColor: CelestialTheme.bgCard,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      side: BorderSide(
        color: isSelected ? activeColor : Colors.white.withValues(alpha: 0.06),
      ),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? CelestialTheme.textLight : CelestialTheme.textMuted,
      ),
      onSelected: (_) => setState(() => _statusFilter = status),
    );
  }

  Widget _buildOrdersList(BuildContext context, PosProvider provider, List<Order> orders, bool isMobile) {
    return ListView.separated(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      itemCount: orders.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final order = orders[index];

        return Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: CelestialTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Number, Name, Table & Status Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: CelestialTheme.brownGradient,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      order.orderNumber,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
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
                          order.customerName,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.textLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (order.orderType == OrderType.takeaway || order.orderType == OrderType.delivery)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9F1C).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFFF9F1C).withValues(alpha: 0.6)),
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
                            order.orderType == OrderType.dineIn
                                ? '${order.orderType.label} • ${order.tableNumber ?? "Table"}'
                                : order.orderType.label,
                            style: const TextStyle(fontSize: 10, color: CelestialTheme.goldLight),
                          ),
                      ],
                    ),
                  ),
                  // Interactive Status Badge (Tap to change status)
                  PopupMenuButton<OrderStatus>(
                    initialValue: order.status,
                    tooltip: 'Change Order Status',
                    onSelected: (newStatus) {
                      provider.updateOrderStatus(order.id, newStatus);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: CelestialTheme.bgCard,
                          duration: const Duration(seconds: 1),
                          content: Text('Order ${order.orderNumber} status updated to: ${newStatus.label}'),
                        ),
                      );
                    },
                    color: CelestialTheme.bgCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                    ),
                    itemBuilder: (ctx) => OrderStatus.values.map((s) {
                      return PopupMenuItem<OrderStatus>(
                        value: s,
                        child: Row(
                          children: [
                            Text(s.icon, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Text(
                              s.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: s == order.status ? FontWeight.bold : FontWeight.normal,
                                color: _getStatusColor(s),
                              ),
                            ),
                            if (s == order.status) ...[
                              const Spacer(),
                              const Icon(Icons.check_rounded, size: 14, color: CelestialTheme.goldLight),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getStatusBgColor(order.status),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _getStatusColor(order.status).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(order.status.icon, style: const TextStyle(fontSize: 10)),
                          const SizedBox(width: 3),
                          Text(
                            order.status.label.split(' / ').first,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(order.status),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_drop_down_rounded, size: 12, color: _getStatusColor(order.status)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Items Summary (Tap to View Full Details Modal)
              InkWell(
                onTap: () => OrderDetailsDialog.show(context, order),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.items.map((i) => '${i.quantity}x ${i.menuItem.name}').join(', '),
                          style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, size: 14, color: CelestialTheme.caramelAccent),
                    ],
                  ),
                ),
              ),

              // Customer Review snippet (if submitted)
              if (order.customerFeedback != null) ...[
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => OrderDetailsDialog.show(context, order),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF221710),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Row(
                          children: List.generate(5, (idx) {
                            return Icon(
                              idx < order.customerFeedback!.rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 13,
                              color: idx < order.customerFeedback!.rating
                                  ? const Color(0xFFFFB800)
                                  : Colors.white24,
                            );
                          }),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${order.customerFeedback!.rating}.0',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.goldLight,
                          ),
                        ),
                        if (order.customerFeedback!.message.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '“${order.customerFeedback!.message}”',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontStyle: FontStyle.italic,
                                color: CelestialTheme.textLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 13, color: CelestialTheme.goldLight),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 8),

              // Payment Summary: Received Money & Change
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: CelestialTheme.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  children: [
                    // Total & Discount row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Bill',
                          style: const TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                        ),
                        Row(
                          children: [
                            if (order.discountAmount > 0)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: CelestialTheme.emeraldReady.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: CelestialTheme.emeraldReady.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    '-₱${order.discountAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: CelestialTheme.emeraldReady,
                                    ),
                                  ),
                                ),
                              ),
                            Text(
                              '₱${order.totalAmount.toStringAsFixed(0)}',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: CelestialTheme.goldLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    const Divider(height: 1, color: Color(0x18FFFFFF)),
                    const SizedBox(height: 5),
                    // Received & Change row
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: CelestialTheme.blueInfo.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.payments_rounded, size: 12, color: CelestialTheme.blueInfo),
                              ),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'RECEIVED',
                                    style: TextStyle(fontSize: 9, letterSpacing: 0.8, color: CelestialTheme.textSubtle),
                                  ),
                                  Text(
                                    '₱${order.amountTendered.toStringAsFixed(0)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: CelestialTheme.blueInfo,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: order.changeDue > 0
                                      ? CelestialTheme.emeraldReady.withValues(alpha: 0.15)
                                      : CelestialTheme.textMuted.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.price_check_rounded,
                                  size: 12,
                                  color: order.changeDue > 0
                                      ? CelestialTheme.emeraldReady
                                      : CelestialTheme.textMuted,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CHANGE DUE',
                                    style: TextStyle(fontSize: 9, letterSpacing: 0.8, color: CelestialTheme.textSubtle),
                                  ),
                                  Text(
                                    '₱${order.changeDue.toStringAsFixed(0)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: order.changeDue > 0
                                          ? CelestialTheme.emeraldReady
                                          : CelestialTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Payment Method Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: CelestialTheme.brownWarm.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(order.paymentMethod.icon, style: const TextStyle(fontSize: 11)),
                              const SizedBox(width: 4),
                              Text(
                                order.paymentMethod.label.split(' / ').first,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.goldLight,
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

              if (order.status == OrderStatus.pending) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => CustomerOrderApprovalDialog.show(context, order),
                    icon: const Icon(Icons.check_circle_rounded, size: 16, color: CelestialTheme.bgDark),
                    label: Text(
                      'Confirm & Settle Payment (₱${order.totalAmount.toStringAsFixed(0)})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: CelestialTheme.bgDark,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CelestialTheme.goldPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 3,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 6),

              // Bottom Row: Meta (Time + Cashier) & Print CTA
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('MMM d, hh:mm a').format(order.createdAt),
                      style: const TextStyle(fontSize: 10.5, color: CelestialTheme.textSubtle),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => OrderDetailsDialog.show(context, order),
                    icon: const Icon(Icons.visibility_outlined, size: 13, color: CelestialTheme.goldLight),
                    label: const Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.goldLight,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => OrderTrackingQrDialog.show(context, order),
                    icon: const Icon(Icons.qr_code_2_rounded, color: CelestialTheme.goldLight, size: 19),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Customer Tracking QR',
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => ReceiptDialog(order: order),
                      );
                    },
                    icon: const Icon(Icons.receipt_rounded, color: CelestialTheme.goldPrimary, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Reprint Receipt',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return CelestialTheme.emeraldReady;
      case OrderStatus.ready:
        return CelestialTheme.emeraldReady;
      case OrderStatus.preparing:
        return CelestialTheme.amberBrewing;
      case OrderStatus.confirmed:
        return CelestialTheme.goldPrimary;
      case OrderStatus.pending:
        return CelestialTheme.goldPrimary;
      case OrderStatus.cancelled:
        return CelestialTheme.roseAlert;
    }
  }

  Color _getStatusBgColor(OrderStatus status) {
    return _getStatusColor(status).withValues(alpha: 0.15);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📜', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          Text(
            'No Matching Orders Found',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your search criteria or status filter.',
            style: GoogleFonts.outfit(fontSize: 12, color: CelestialTheme.textMuted),
          ),
        ],
      ),
    );
  }

  void _showCustomerFeedbackDialog(BuildContext context, PosProvider provider) {
    CustomerFeedbackDialog.show(context);
  }
}
