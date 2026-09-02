import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import '../widgets/customer_order_approval_dialog.dart';

class PendingOrdersScreen extends StatefulWidget {
  const PendingOrdersScreen({super.key});

  @override
  State<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();
    // Update live elapsed times every 30 seconds
    _tickerTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _formatElapsedTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isTablet = MediaQuery.of(context).size.width >= 768 && MediaQuery.of(context).size.width < 1100;

    final allPending = posProvider.pendingCustomerOrders;

    // Filter pending orders by search query (Order number e.g. #1, 1, table, customer name, items)
    final filteredPending = allPending.where((order) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      final numStr = order.orderNumber.toLowerCase().replaceAll('#', '').trim();
      final fullNum = order.orderNumber.toLowerCase();
      final cust = order.customerName.toLowerCase();
      final table = (order.tableNumber ?? '').toLowerCase();
      final itemsText = order.items.map((i) => i.menuItem.name.toLowerCase()).join(' ');

      return fullNum.contains(q) ||
          numStr.contains(q) ||
          cust.contains(q) ||
          table.contains(q) ||
          itemsText.contains(q);
    }).toList();

    final totalPendingAmount = allPending.fold(0.0, (sum, o) => sum + o.totalAmount);

    return Container(
      color: CelestialTheme.bgDark,
      child: Column(
        children: [
          // Top Search & Stats Header Bar
          _buildSearchAndStatsHeader(posProvider, allPending.length, totalPendingAmount, isMobile),

          const Divider(height: 1, color: Color(0x1FFFFFFF)),

          // Main Pending Orders Content
          Expanded(
            child: allPending.isEmpty
                ? _buildEmptyState(posProvider)
                : filteredPending.isEmpty
                    ? _buildNoSearchResultsState()
                    : _buildOrdersList(context, posProvider, filteredPending, isMobile, isTablet),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndStatsHeader(
    PosProvider posProvider,
    int totalCount,
    double totalAmount,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 24,
        vertical: isMobile ? 12 : 16,
      ),
      color: CelestialTheme.bgSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Title & Stats Chips
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: CelestialTheme.goldPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Pending Customer Orders',
                            style: GoogleFonts.cinzel(
                              fontSize: isMobile ? 15 : 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: CelestialTheme.goldPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (totalCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: CelestialTheme.goldPrimary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$totalCount Awaiting Payment',
                              style: const TextStyle(
                                color: CelestialTheme.bgDark,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Table QR self-orders awaiting cashier confirmation & payment settlement',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile ? 11 : 12,
                        color: CelestialTheme.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!isMobile && totalCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: CelestialTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Total Value: ',
                        style: TextStyle(color: CelestialTheme.textMuted, fontSize: 12),
                      ),
                      Text(
                        '₱${totalAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(
                          color: CelestialTheme.goldLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Row 2: Search Input
          Container(
            decoration: BoxDecoration(
              color: CelestialTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _searchQuery.isNotEmpty
                    ? CelestialTheme.goldPrimary
                    : Colors.white.withValues(alpha: 0.12),
                width: 1.2,
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(color: CelestialTheme.textLight, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Search by Order # (e.g. #1, 1), Table number, or Customer name...',
                hintStyle: const TextStyle(color: CelestialTheme.textSubtle, fontSize: 12.5),
                prefixIcon: const Icon(Icons.search_rounded, color: CelestialTheme.goldLight, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: CelestialTheme.textMuted, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(
    BuildContext context,
    PosProvider posProvider,
    List<Order> orders,
    bool isMobile,
    bool isTablet,
  ) {
    if (isMobile) {
      return ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (ctx, idx) => _buildPendingOrderCard(context, posProvider, orders[idx], isMobile),
      );
    }

    final crossAxisCount = isTablet ? 2 : 3;

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isTablet ? 0.78 : 0.86,
      ),
      itemCount: orders.length,
      itemBuilder: (ctx, idx) => _buildPendingOrderCard(context, posProvider, orders[idx], isMobile),
    );
  }

  Widget _buildPendingOrderCard(
    BuildContext context,
    PosProvider posProvider,
    Order order,
    bool isMobile,
  ) {
    final elapsedStr = _formatElapsedTime(order.createdAt);
    final timeFormatted = DateFormat('hh:mm a').format(order.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Ticket Badge, Table, and Elapsed Time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: CelestialTheme.goldPrimary.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
            ),
            child: Row(
              children: [
                // Ticket Number
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: CelestialTheme.goldPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.orderNumber,
                    style: GoogleFonts.cinzel(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: CelestialTheme.bgDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Table Pill
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: CelestialTheme.bgDark,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Text(
                      order.tableNumber ?? 'Dine-In',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.goldLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (order.hasKitchenDishes) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5722).withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFF5722).withValues(alpha: 0.65), width: 1),
                    ),
                    child: Text(
                      '${order.kitchenDishCount} Kitchen',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF7043),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                // Elapsed Time
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 12, color: CelestialTheme.textMuted),
                    const SizedBox(width: 3),
                    Text(
                      '$timeFormatted ($elapsedStr)',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: CelestialTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Customer info & Payment method tag
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 14, color: CelestialTheme.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      order.customerName,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: CelestialTheme.textLight,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.paymentMethod.label,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: CelestialTheme.goldLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 8, indent: 14, endIndent: 14, color: Color(0x15FFFFFF)),

          // Items List Preview (Dynamic Column for Mobile, Scrollable for Desktop Grid)
          if (isMobile)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: order.items.map((item) {
                  final customs = item.customizations.map((c) => c.optionName).join(', ');
                  final isKitchen = item.isKitchenDish;

                  final itemContent = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${item.quantity}x',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isKitchen ? const Color(0xFFFF7043) : CelestialTheme.goldPrimary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                if (isKitchen) ...[
                                  Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF5722).withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('KITCHEN', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFFFF7043))),
                                  ),
                                ],
                                Expanded(
                                  child: Text(
                                    item.menuItem.name,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: isKitchen ? const Color(0xFFFFE0B2) : CelestialTheme.textLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₱${item.totalPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.goldLight,
                            ),
                          ),
                        ],
                      ),
                      if (customs.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 22, top: 1),
                          child: Text(
                            '› $customs',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: CelestialTheme.textMuted,
                            ),
                          ),
                        ),
                      if (item.notes != null && item.notes!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 22, top: 1),
                          child: Text(
                            'Note: "${item.notes}"',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: CelestialTheme.roseAlert,
                            ),
                          ),
                        ),
                    ],
                  );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: isKitchen
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5722).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFF5722).withValues(alpha: 0.35)),
                            ),
                            child: itemContent,
                          )
                        : itemContent,
                  );
                }).toList(),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                itemCount: order.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (ctx, iIdx) {
                  final item = order.items[iIdx];
                  final customs = item.customizations.map((c) => c.optionName).join(', ');
                  final isKitchen = item.isKitchenDish;

                  final itemContent = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${item.quantity}x',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isKitchen ? const Color(0xFFFF7043) : CelestialTheme.goldPrimary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                if (isKitchen) ...[
                                  Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF5722).withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('KITCHEN', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFFFF7043))),
                                  ),
                                ],
                                Expanded(
                                  child: Text(
                                    item.menuItem.name,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: isKitchen ? const Color(0xFFFFE0B2) : CelestialTheme.textLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₱${item.totalPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.goldLight,
                            ),
                          ),
                        ],
                      ),
                      if (customs.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 22, top: 1),
                          child: Text(
                            '› $customs',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: CelestialTheme.textMuted,
                            ),
                          ),
                        ),
                      if (item.notes != null && item.notes!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 22, top: 1),
                          child: Text(
                            'Note: "${item.notes}"',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: CelestialTheme.roseAlert,
                            ),
                          ),
                        ),
                    ],
                  );

                  return isKitchen
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5722).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFF5722).withValues(alpha: 0.35)),
                          ),
                          child: itemContent,
                        )
                      : itemContent;
                },
              ),
            ),

          // Notes if present
          if (order.orderNotes != null && order.orderNotes!.trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: CelestialTheme.amberBrewing.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: CelestialTheme.amberBrewing.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.speaker_notes_rounded, size: 12, color: CelestialTheme.amberBrewing),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Order Note: ${order.orderNotes}',
                      style: const TextStyle(fontSize: 11, color: CelestialTheme.amberBrewing),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Total and Primary Action Button Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CelestialTheme.bgSurface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(fontSize: 12, color: CelestialTheme.textMuted, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '₱${order.totalAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: CelestialTheme.goldLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Reject / Void
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined, color: CelestialTheme.roseAlert, size: 20),
                      tooltip: 'Decline Order',
                      onPressed: () => _confirmDecline(context, posProvider, order),
                    ),
                    const SizedBox(width: 4),
                    // Primary Review & Approve Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => CustomerOrderApprovalDialog.show(context, order),
                        icon: const Icon(Icons.payments_outlined, size: 16, color: CelestialTheme.bgDark),
                        label: const Text(
                          'Review & Settle',
                          style: TextStyle(
                            color: CelestialTheme.bgDark,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CelestialTheme.goldPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDecline(BuildContext context, PosProvider provider, Order order) {
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
              'Decline Order ${order.orderNumber}?',
              style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to decline this order for ${order.customerName} (${order.tableNumber ?? 'Dine-In'})? All reserved items will be returned to inventory stock.',
          style: const TextStyle(color: CelestialTheme.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.rejectCustomerOrder(order.id, restock: true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Order ${order.orderNumber} was declined & restocked.'),
                  backgroundColor: CelestialTheme.bgCard,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: CelestialTheme.roseAlert),
            child: const Text('Decline & Restock', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(PosProvider posProvider) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CelestialTheme.goldPrimary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.25)),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 48,
                color: CelestialTheme.goldLight,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'All Orders Cleared',
              style: GoogleFonts.cinzel(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: CelestialTheme.goldPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'There are no pending customer orders awaiting cashier approval.\nNew orders placed by customers from their tables will appear here instantly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: CelestialTheme.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => posProvider.setNavIndex(0),
              icon: const Icon(Icons.point_of_sale_rounded, size: 16),
              label: const Text('Go to POS Station'),
              style: OutlinedButton.styleFrom(
                foregroundColor: CelestialTheme.goldLight,
                side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResultsState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 40,
                color: CelestialTheme.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No Pending Orders Match "$_searchQuery"',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: CelestialTheme.textLight,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Please check the order number or search terms and try again.',
              style: TextStyle(fontSize: 12.5, color: CelestialTheme.textMuted),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              icon: const Icon(Icons.clear_rounded, size: 16, color: CelestialTheme.goldPrimary),
              label: const Text('Clear Search', style: TextStyle(color: CelestialTheme.goldPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}
