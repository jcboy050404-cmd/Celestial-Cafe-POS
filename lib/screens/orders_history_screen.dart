import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../services/auth_service.dart';
import '../theme/celestial_theme.dart';
import '../widgets/receipt_dialog.dart';
import '../widgets/order_details_dialog.dart';
import '../widgets/top_notification.dart';

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  String _searchQuery = '';
  OrderStatus? _statusFilter;
  bool _onlineOnlyFilter = false;

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final auth = Provider.of<AuthService>(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    // Combine local POS orders and incoming real-time online orders
    final allOrders = [
      ...posProvider.incomingOnlineOrders,
      ...posProvider.orders.where((o) => !posProvider.incomingOnlineOrders.any((io) => io.id == o.id)),
    ];

    final filteredOrders = allOrders.where((order) {
      final q = _searchQuery.trim().toLowerCase();
      final numMatch = order.orderNumber.toLowerCase();
      final cust = order.customerName.toLowerCase();
      final cashier = order.cashierName.toLowerCase();

      final matchesQuery = q.isEmpty ||
          numMatch.contains(q) ||
          cust.contains(q) ||
          cashier.contains(q) ||
          order.items.any((i) => i.menuItem.name.toLowerCase().contains(q));

      final matchesStatus = _statusFilter == null || order.status == _statusFilter;
      final isOnline = order.id.startsWith('online_') || order.cashierName.toLowerCase().contains('online');
      final matchesOnline = !_onlineOnlyFilter || isOnline;

      return matchesQuery && matchesStatus && matchesOnline;
    }).toList();

    return Scaffold(
      backgroundColor: CelestialTheme.bgDark,
      body: Column(
        children: [
          // Header Bar with Actions & Search
          _buildHeader(posProvider, auth, isMobile),

          const Divider(height: 1),

          // Orders Table List
          Expanded(
            child: filteredOrders.isEmpty
                ? _buildEmptyState()
                : _buildOrdersList(context, posProvider, auth, filteredOrders, isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(PosProvider provider, AuthService auth, bool isMobile) {
    final isOwner = auth.isOwner;
    final actionButtons = <Widget>[
      if (isOwner) ...[
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
                content: Text(
                  'This will reset the order numbering so your next order starts at #1.',
                  style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      provider.resetOrderSequence(startNumber: 1);
                      Navigator.pop(ctx);
                      TopNotification.showSuccess(
                        context,
                        'Order counter reset: Next order will be #1',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CelestialTheme.goldPrimary,
                      foregroundColor: CelestialTheme.primaryBtnText,
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
        OutlinedButton.icon(
          onPressed: () => _confirmDeleteAllHistory(context, provider),
          icon: Icon(Icons.delete_sweep_rounded, size: 14, color: CelestialTheme.roseAlert),
          label: Text('Clear History', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CelestialTheme.roseAlert)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      color: CelestialTheme.bgSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: CelestialTheme.goldPrimary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order History',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: CelestialTheme.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < actionButtons.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    actionButtons[i],
                  ],
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: CelestialTheme.goldPrimary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order History',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: CelestialTheme.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (int i = 0; i < actionButtons.length; i++) ...[
                  const SizedBox(width: 8),
                  actionButtons[i],
                ],
              ],
            ),
          ],
          if (provider.pendingOnlineOrdersCount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CelestialTheme.goldPrimary.withValues(alpha: 0.25),
                    CelestialTheme.caramelAccent.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CelestialTheme.goldPrimary, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: CelestialTheme.goldPrimary, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.notifications_active_rounded, color: Colors.black, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${provider.pendingOnlineOrdersCount} NEW ONLINE ORDER${provider.pendingOnlineOrdersCount > 1 ? 'S' : ''} WAITING!',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: CelestialTheme.goldLight),
                        ),
                        Text(
                          'Review customer order details below and accept to send to kitchen.',
                          style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => setState(() => _onlineOnlyFilter = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CelestialTheme.goldPrimary,
                      foregroundColor: CelestialTheme.primaryBtnText,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Filter Online', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                  ),
                ],
              ),
            ),
          ],
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
              style: TextStyle(fontSize: 12, color: CelestialTheme.textLight),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
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
                _buildFilterChip('All', null, provider.orders.length + provider.incomingOnlineOrders.where((io) => !provider.orders.any((o) => o.id == io.id)).length),
                const SizedBox(width: 6),
                _buildOnlineFilterChip(provider),
                const SizedBox(width: 6),
                _buildFilterChip('Completed', OrderStatus.completed, provider.completedOrders.length, CelestialTheme.emeraldReady),
                const SizedBox(width: 6),
                _buildFilterChip('Ready', OrderStatus.ready, provider.readyOrders.length, CelestialTheme.emeraldReady),
                const SizedBox(width: 6),
                _buildFilterChip('Brewing', OrderStatus.preparing, provider.preparingOrders.length, CelestialTheme.amberBrewing),
                const SizedBox(width: 6),
                _buildFilterChip('Pending', OrderStatus.pending, provider.pendingOrders.length + provider.pendingOnlineOrdersCount, CelestialTheme.goldPrimary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineFilterChip(PosProvider provider) {
    final allOrders = [
      ...provider.incomingOnlineOrders,
      ...provider.orders.where((o) => !provider.incomingOnlineOrders.any((io) => io.id == o.id)),
    ];
    final onlineCount = allOrders.where((o) => o.id.startsWith('online_') || o.cashierName.toLowerCase().contains('online')).length;
    final pendingCount = provider.pendingOnlineOrdersCount;
    final isSelected = _onlineOnlyFilter;
    final activeColor = pendingCount > 0 ? CelestialTheme.caramelAccent : CelestialTheme.goldLight;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌐 Online'),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isSelected ? activeColor : (pendingCount > 0 ? CelestialTheme.roseAlert : CelestialTheme.bgSurface),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              pendingCount > 0 ? '$onlineCount ($pendingCount NEW)' : '$onlineCount',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isSelected ? CelestialTheme.bgDark : Colors.white,
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
        color: isSelected ? activeColor : (pendingCount > 0 ? CelestialTheme.caramelAccent : Colors.white.withValues(alpha: 0.06)),
      ),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? CelestialTheme.textLight : CelestialTheme.textMuted,
      ),
      onSelected: (sel) => setState(() {
        _onlineOnlyFilter = sel;
        if (sel) _statusFilter = null;
      }),
    );
  }

  Widget _buildFilterChip(String label, OrderStatus? status, int count, [Color? color]) {
    final isSelected = !_onlineOnlyFilter && _statusFilter == status;
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

  Widget _buildOrdersList(BuildContext context, PosProvider provider, AuthService auth, List<Order> orders, bool isMobile) {
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
                        if (order.orderType == OrderType.delivery)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: CelestialTheme.caramelAccent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: CelestialTheme.caramelAccent.withValues(alpha: 0.6)),
                                ),
                                child: Text(
                                  '🛵 DELIVERY',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: CelestialTheme.caramelAccent,
                                  ),
                                ),
                              ),
                              if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '📍 ${order.deliveryAddress}',
                                    style: TextStyle(fontSize: 10, color: CelestialTheme.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          )
                        else if (order.orderType == OrderType.takeaway)
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
                            style: TextStyle(fontSize: 10, color: CelestialTheme.goldLight),
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
                      TopNotification.showSuccess(
                        context,
                        'Order ${order.orderNumber} status updated to: ${newStatus.label}',
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
                              Icon(Icons.check_rounded, size: 14, color: CelestialTheme.goldLight),
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
                      Icon(Icons.chevron_right_rounded, size: 14, color: CelestialTheme.caramelAccent),
                    ],
                  ),
                ),
              ),



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
                          style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
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
                                    style: TextStyle(
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: CelestialTheme.blueInfo.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.payments_rounded, size: 12, color: CelestialTheme.blueInfo),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'RECEIVED',
                                      style: TextStyle(fontSize: 8.5, letterSpacing: 0.5, color: CelestialTheme.textSubtle),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '₱${order.amountTendered.toStringAsFixed(0)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: CelestialTheme.blueInfo,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 26,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
                              const SizedBox(width: 5),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CHANGE DUE',
                                      style: TextStyle(fontSize: 8.5, letterSpacing: 0.5, color: CelestialTheme.textSubtle),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '₱${order.changeDue.toStringAsFixed(0)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: order.changeDue > 0
                                            ? CelestialTheme.emeraldReady
                                            : CelestialTheme.textMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
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
                              const SizedBox(width: 3),
                              Text(
                                order.paymentMethod.label.split(' / ').first,
                                style: TextStyle(
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

              if (order.id.startsWith('online_') || order.cashierName.toLowerCase().contains('online')) ...[
                const SizedBox(height: 10),
                if (order.status == OrderStatus.pending) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await provider.acceptOnlineOrder(order);
                            TopNotification.showSuccess(
                              context,
                              'Online Order ${order.orderNumber} accepted & sent to kitchen!',
                            );
                          },
                          icon: const Icon(Icons.check_circle_rounded, size: 16),
                          label: const Text(
                            'Accept & Prepare Order',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CelestialTheme.emeraldReady,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await provider.cancelOnlineOrder(order);
                          TopNotification.show(
                            context,
                            message: 'Online Order ${order.orderNumber} rejected.',
                            icon: Icons.cancel_outlined,
                          );
                        },
                        icon: Icon(Icons.close_rounded, size: 15, color: CelestialTheme.roseAlert),
                        label: Text('Reject', style: TextStyle(color: CelestialTheme.roseAlert, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ] else if (order.status == OrderStatus.preparing) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await provider.markOnlineOrderReady(order);
                        TopNotification.showSuccess(
                          context,
                          'Online Order ${order.orderNumber} is Ready!',
                        );
                      },
                      icon: const Icon(Icons.notifications_active_rounded, size: 16),
                      label: const Text(
                        'Mark Order Ready for Pickup / Serving',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CelestialTheme.goldPrimary,
                        foregroundColor: CelestialTheme.primaryBtnText,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ] else if (order.status == OrderStatus.ready) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await provider.completeOnlineOrder(order);
                        TopNotification.showSuccess(
                          context,
                          'Online Order ${order.orderNumber} completed & delivered!',
                        );
                      },
                      icon: const Icon(Icons.done_all_rounded, size: 16),
                      label: const Text(
                        'Complete & Hand Over Order',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CelestialTheme.emeraldReady,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ] else if (order.status == OrderStatus.pending) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      provider.updateOrderStatus(order.id, OrderStatus.completed);
                      TopNotification.show(
                        context,
                        message: 'Order ${order.orderNumber} settled & completed!',
                        icon: Icons.check_circle_rounded,
                      );
                    },
                    icon: Icon(Icons.check_circle_rounded, size: 16, color: CelestialTheme.primaryBtnText),
                    label: Text(
                      'Confirm & Complete Order (₱${order.totalAmount.toStringAsFixed(0)})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: CelestialTheme.primaryBtnText,
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
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('MMM d, hh:mm a').format(order.createdAt),
                      style: TextStyle(fontSize: 10.5, color: CelestialTheme.textSubtle),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: () => OrderDetailsDialog.show(context, order),
                    icon: Icon(Icons.visibility_outlined, size: 13, color: CelestialTheme.goldLight),
                    label: Text(
                      isMobile ? 'Details' : 'View Details',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.goldLight,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => ReceiptDialog(order: order),
                      );
                    },
                    icon: Icon(Icons.receipt_rounded, color: CelestialTheme.goldPrimary, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Reprint Receipt',
                  ),
                  if (auth.isOwner) ...[
                    const SizedBox(width: 2),
                    IconButton(
                      onPressed: () => _confirmDeleteSingleOrder(context, provider, order),
                      icon: Icon(Icons.delete_outline_rounded, color: CelestialTheme.roseAlert, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Delete Order Record',
                    ),
                  ],
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
      case OrderStatus.outForDelivery:
        return CelestialTheme.caramelAccent;
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

  void _confirmDeleteSingleOrder(BuildContext context, PosProvider provider, Order order) {
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
            Icon(Icons.warning_amber_rounded, color: CelestialTheme.roseAlert),
            const SizedBox(width: 8),
            Text(
              'Delete Order ${order.orderNumber}?',
              style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete Order ${order.orderNumber} (${order.customerName}, ₱${order.totalAmount.toStringAsFixed(0)})?\n\nThis record will be permanently removed from sales history.',
          style: TextStyle(fontSize: 13, color: CelestialTheme.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.deleteOrderCompletely(order.id, restock: false);
              ScaffoldMessenger.of(context).clearSnackBars();
              TopNotification.showError(
                context,
                'Order ${order.orderNumber} permanently deleted from history.',
              );
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text('Delete Permanently'),
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.roseAlert,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAllHistory(BuildContext context, PosProvider provider) {
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
            Icon(Icons.delete_sweep_rounded, color: CelestialTheme.roseAlert),
            const SizedBox(width: 8),
            Text(
              'Clear Order History?',
              style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Choose what you would like to delete:\n\n'
          '• Completed & Cancelled Only (${provider.orders.where((o) => o.status == OrderStatus.completed || o.status == OrderStatus.cancelled).length} orders):\n  Clears old history while preserving active kitchen tickets.\n\n'
          '• Wipe All Orders (${provider.orders.length} orders):\n  Clears every order and resets the order counter back to #1.',
          style: TextStyle(fontSize: 13, color: CelestialTheme.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await provider.clearOrderHistoryOnly();
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                TopNotification.showSuccess(
                  context,
                  'Completed & cancelled history orders cleared!',
                );
              }
            },
            icon: Icon(Icons.history_rounded, size: 15, color: CelestialTheme.amberBrewing),
            label: Text('Clear Completed Only', style: TextStyle(color: CelestialTheme.amberBrewing, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: CelestialTheme.amberBrewing.withValues(alpha: 0.5)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await provider.clearAllOrdersAndResetCounter(startNumber: 1);
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                TopNotification.showSuccess(
                  context,
                  'All orders cleared! Next order is #1.',
                );
              }
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text('Wipe All Orders & Reset'),
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.roseAlert,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}