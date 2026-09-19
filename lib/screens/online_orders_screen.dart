import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../services/auth_service.dart';
import '../theme/celestial_theme.dart';
import '../widgets/online_ordering_dialog.dart';
import '../widgets/order_details_dialog.dart';
import '../widgets/receipt_dialog.dart';
import '../widgets/top_notification.dart';

/// Dedicated screen for Store Owners and Cashiers to monitor, review, confirm,
/// and fulfill all customer online orders (delivery, takeout, and dine-in).
class OnlineOrdersScreen extends StatefulWidget {
  const OnlineOrdersScreen({super.key});

  @override
  State<OnlineOrdersScreen> createState() => _OnlineOrdersScreenState();
}

class _OnlineOrdersScreenState extends State<OnlineOrdersScreen> {
  String _searchQuery = '';
  OrderStatus? _statusFilter;
  OrderType? _typeFilter;
  bool _isRefreshing = false;

  Future<void> _refreshOrders(PosProvider provider) async {
    setState(() => _isRefreshing = true);
    await provider.pollOnlineOrders();
    if (mounted) {
      setState(() => _isRefreshing = false);
      TopNotification.showSuccess(context, 'Online orders refreshed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final auth = Provider.of<AuthService>(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    // Combine incoming real-time online orders and any stored orders that originated online
    final Set<String> seenIds = {};
    final List<Order> allOnlineOrders = [];

    for (final o in posProvider.incomingOnlineOrders) {
      final locIdx = posProvider.orders.indexWhere((loc) => loc.id == o.id);
      if (locIdx >= 0) {
        final loc = posProvider.orders[locIdx];
        if (loc.status != o.status && loc.status.index > o.status.index) {
          o.status = loc.status;
        }
      }
      if (seenIds.add(o.id)) {
        allOnlineOrders.add(o);
      }
    }
    for (final o in posProvider.orders) {
      final isOnline = o.id.startsWith('online_') ||
          o.cashierName.toLowerCase().contains('online') ||
          o.cashierName.toLowerCase().contains('web');
      if (isOnline && seenIds.add(o.id)) {
        allOnlineOrders.add(o);
      }
    }

    // Sort: Pending first, then by creation date descending
    allOnlineOrders.sort((a, b) {
      if (a.status == OrderStatus.pending && b.status != OrderStatus.pending) return -1;
      if (b.status == OrderStatus.pending && a.status != OrderStatus.pending) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    final filteredOrders = allOnlineOrders.where((order) {
      final q = _searchQuery.trim().toLowerCase();
      final numMatch = order.orderNumber.toLowerCase();
      final cust = order.customerName.toLowerCase();
      final phone = (order.customerPhone ?? '').toLowerCase();
      final addr = (order.deliveryAddress ?? '').toLowerCase();
      final notes = (order.orderNotes ?? '').toLowerCase();

      final matchesQuery = q.isEmpty ||
          numMatch.contains(q) ||
          cust.contains(q) ||
          phone.contains(q) ||
          addr.contains(q) ||
          notes.contains(q) ||
          order.items.any((i) => i.menuItem.name.toLowerCase().contains(q));

      final matchesStatus = _statusFilter == null || order.status == _statusFilter;
      final matchesType = _typeFilter == null || order.orderType == _typeFilter;

      return matchesQuery && matchesStatus && matchesType;
    }).toList();

    return Scaffold(
      backgroundColor: CelestialTheme.bgDark,
      body: Column(
        children: [
          // Header Bar with store status & quick actions
          _buildTopBar(context, posProvider, auth, isMobile),

          const Divider(height: 1, color: Colors.white10),

          // Search & Filter controls
          _buildFilterBar(context, posProvider, auth, allOnlineOrders, isMobile),

          // Orders List
          Expanded(
            child: filteredOrders.isEmpty
                ? _buildEmptyState(context, posProvider, allOnlineOrders.isEmpty)
                : _buildOrdersList(context, posProvider, auth, filteredOrders, isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreActiveBadge(bool isOpen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: isOpen
            ? CelestialTheme.emeraldReady.withValues(alpha: 0.15)
            : CelestialTheme.roseAlert.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isOpen ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert)
              .withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOpen ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOpen ? 'STORE ACTIVE' : 'STORE PAUSED',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isOpen ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingWaitingBadge(int pendingCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: CelestialTheme.caramelGradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: CelestialTheme.caramelAccent.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        '$pendingCount WAITING',
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    PosProvider pos,
    AuthService auth,
    bool isMobile,
  ) {
    final isOpen = pos.isOnlineOrderOpen;
    final pendingCount = pos.pendingOnlineOrdersCount;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 10 : 14),
      color: CelestialTheme.bgSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.delivery_dining_rounded, color: CelestialTheme.goldLight, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: isMobile
                    ? Text(
                        'Online Orders',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.textLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Online Orders',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.textLight,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStoreActiveBadge(isOpen),
                              if (pendingCount > 0) ...[
                                const SizedBox(width: 8),
                                _buildPendingWaitingBadge(pendingCount),
                              ],
                            ],
                          ),
                          Text(
                            'Review incoming delivery, takeaway, and dine-in customer orders',
                            style: TextStyle(fontSize: 11.5, color: CelestialTheme.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
              ),

              // Actions
              if (!isMobile) ...[
                OutlinedButton.icon(
                  onPressed: _isRefreshing ? null : () => _refreshOrders(pos),
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CelestialTheme.goldLight,
                    side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),

              ] else ...[
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                          )
                        : const Icon(Icons.refresh_rounded, size: 20),
                    color: CelestialTheme.goldLight,
                    onPressed: _isRefreshing ? null : () => _refreshOrders(pos),
                    tooltip: 'Refresh online orders',
                  ),
                ),

              ],
            ],
          ),

          // Second row on Mobile: Badges cleanly separated!
          if (isMobile) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStoreActiveBadge(isOpen),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 8),
                  _buildPendingWaitingBadge(pendingCount),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Incoming orders queue',
                    style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    PosProvider pos,
    AuthService auth,
    List<Order> allOrders,
    bool isMobile,
  ) {
    final pendingCount = allOrders.where((o) => o.status == OrderStatus.pending).length;
    final preparingCount = allOrders.where((o) => o.status == OrderStatus.preparing).length;
    final readyCount = allOrders.where((o) => o.status == OrderStatus.ready || o.status == OrderStatus.outForDelivery).length;
    final completedCount = allOrders.where((o) => o.status == OrderStatus.completed).length;

    return Container(
      padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, 10, isMobile ? 12 : 20, 12),
      color: CelestialTheme.bgSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: CelestialTheme.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              style: TextStyle(fontSize: 12.5, color: CelestialTheme.textLight),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search order #, customer, phone, delivery address...',
                hintStyle: TextStyle(fontSize: 12, color: CelestialTheme.textSubtle),
                prefixIcon: Icon(Icons.search_rounded, size: 16, color: CelestialTheme.goldPrimary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 14),
                        color: CelestialTheme.textSubtle,
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip('All Online', null, allOrders.length),
                const SizedBox(width: 6),
                _buildStatusChip('Pending Review', OrderStatus.pending, pendingCount,
                    isAlert: pendingCount > 0, alertColor: CelestialTheme.goldPrimary),
                const SizedBox(width: 6),
                _buildStatusChip('In Kitchen', OrderStatus.preparing, preparingCount,
                    alertColor: CelestialTheme.amberBrewing),
                const SizedBox(width: 6),
                _buildStatusChip('Ready / Delivering', OrderStatus.ready, readyCount,
                    alertColor: CelestialTheme.emeraldReady),
                const SizedBox(width: 6),
                _buildStatusChip('Completed', OrderStatus.completed, completedCount),
                if (_statusFilter == OrderStatus.completed && completedCount > 0 && auth.isOwnerOrAdmin) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _handleClearAllCompleted(context, pos, allOrders),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: CelestialTheme.roseAlert.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: CelestialTheme.roseAlert.withValues(alpha: 0.45)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_sweep_rounded, size: 14, color: CelestialTheme.roseAlert),
                          const SizedBox(width: 4),
                          Text(
                            'Clear All Completed ($completedCount)',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: CelestialTheme.roseAlert,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                Container(width: 1, height: 20, color: Colors.white12),
                const SizedBox(width: 12),

                // Order Type Filters
                _buildTypeChip('All Types', null),
                const SizedBox(width: 6),
                _buildTypeChip('🛵 Delivery', OrderType.delivery),
                const SizedBox(width: 6),
                _buildTypeChip('🥡 Takeout', OrderType.takeaway),
                const SizedBox(width: 6),
                _buildTypeChip('🍽️ Dine-In', OrderType.dineIn),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    String label,
    OrderStatus? status,
    int count, {
    bool isAlert = false,
    Color? alertColor,
  }) {
    final isSelected = _statusFilter == status;
    final color = alertColor ?? CelestialTheme.goldLight;

    return InkWell(
      onTap: () => setState(() => _statusFilter = status),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isAlert ? CelestialTheme.goldPrimary.withValues(alpha: 0.25) : CelestialTheme.goldPrimary.withValues(alpha: 0.18))
              : CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isAlert ? CelestialTheme.goldPrimary : CelestialTheme.goldPrimary.withValues(alpha: 0.6))
                : (isAlert ? color.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08)),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? CelestialTheme.textLight : CelestialTheme.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isAlert ? (isSelected ? CelestialTheme.goldPrimary : color.withValues(alpha: 0.25)) : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isAlert ? (isSelected ? Colors.black : color) : CelestialTheme.textLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, OrderType? type) {
    final isSelected = _typeFilter == type;
    return InkWell(
      onTap: () => setState(() => _typeFilter = type),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? CelestialTheme.caramelAccent.withValues(alpha: 0.2) : CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? CelestialTheme.caramelAccent : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : CelestialTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersList(
    BuildContext context,
    PosProvider pos,
    AuthService auth,
    List<Order> orders,
    bool isMobile,
  ) {
    return ListView.separated(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(context, pos, auth, order, isMobile);
      },
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    PosProvider pos,
    AuthService auth,
    Order order,
    bool isMobile,
  ) {
    final isPending = order.status == OrderStatus.pending;
    final isPreparing = order.status == OrderStatus.preparing;
    final isReady = order.status == OrderStatus.ready;
    final isOutForDelivery = order.status == OrderStatus.outForDelivery;
    final isCompleted = order.status == OrderStatus.completed;
    final isDelivery = order.orderType == OrderType.delivery;
    final timeStr = DateFormat('hh:mm a').format(order.createdAt);
    final dateStr = DateFormat('MMM dd').format(order.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? CelestialTheme.goldPrimary.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.08),
          width: isPending ? 1.6 : 1.0,
        ),
        boxShadow: [
          if (isPending)
            BoxShadow(
              color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: Order #, Order Type, Time, Status Pill
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: isPending
                  ? CelestialTheme.goldPrimary.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.02),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
            ),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Order Sequence Number
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: CelestialTheme.caramelGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              order.orderNumber,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Order Type Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isDelivery
                                  ? Colors.cyanAccent.withValues(alpha: 0.12)
                                  : (order.orderType == OrderType.takeaway
                                      ? Colors.amber.withValues(alpha: 0.12)
                                      : CelestialTheme.emeraldReady.withValues(alpha: 0.12)),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDelivery
                                    ? Colors.cyanAccent.withValues(alpha: 0.4)
                                    : (order.orderType == OrderType.takeaway
                                        ? Colors.amber.withValues(alpha: 0.4)
                                        : CelestialTheme.emeraldReady.withValues(alpha: 0.4)),
                              ),
                            ),
                            child: Text(
                              isDelivery
                                  ? '🛵 DELIVERY'
                                  : (order.orderType == OrderType.takeaway
                                      ? '🥡 TAKEAWAY'
                                      : '🍽️ DINE-IN ${order.tableNumber != null ? "• ${order.tableNumber}" : ""}'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDelivery
                                    ? Colors.cyanAccent
                                    : (order.orderType == OrderType.takeaway ? Colors.amber : CelestialTheme.emeraldReady),
                              ),
                            ),
                          ),
                          const Spacer(),

                          // Interactive Status Badge Popup
                          _buildStatusPopup(context, pos, order, isMobile: true),
                          if (auth.isOwnerOrAdmin && (order.status == OrderStatus.completed || order.status == OrderStatus.cancelled)) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              color: CelestialTheme.roseAlert,
                              tooltip: 'Delete Order',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              onPressed: () => _handleDeleteOnlineOrder(context, pos, order),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 12, color: CelestialTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '$timeStr • $dateStr',
                            style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      // Order Sequence Number
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: CelestialTheme.caramelGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          order.orderNumber,
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Order Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDelivery
                              ? Colors.cyanAccent.withValues(alpha: 0.12)
                              : (order.orderType == OrderType.takeaway
                                  ? Colors.amber.withValues(alpha: 0.12)
                                  : CelestialTheme.emeraldReady.withValues(alpha: 0.12)),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDelivery
                                ? Colors.cyanAccent.withValues(alpha: 0.4)
                                : (order.orderType == OrderType.takeaway
                                    ? Colors.amber.withValues(alpha: 0.4)
                                    : CelestialTheme.emeraldReady.withValues(alpha: 0.4)),
                          ),
                        ),
                        child: Text(
                          isDelivery
                              ? '🛵 DELIVERY'
                              : (order.orderType == OrderType.takeaway
                                  ? '🥡 TAKEAWAY'
                                  : '🍽️ DINE-IN ${order.tableNumber != null ? "• ${order.tableNumber}" : ""}'),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isDelivery
                                ? Colors.cyanAccent
                                : (order.orderType == OrderType.takeaway ? Colors.amber : CelestialTheme.emeraldReady),
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Time String
                      Text(
                        '$timeStr • $dateStr',
                        style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                      ),
                      const SizedBox(width: 8),

                      // Interactive Status Badge Popup
                      _buildStatusPopup(context, pos, order, isMobile: false),
                      if (auth.isOwnerOrAdmin && (order.status == OrderStatus.completed || order.status == OrderStatus.cancelled)) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          color: CelestialTheme.roseAlert,
                          tooltip: 'Delete Order',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => _handleDeleteOnlineOrder(context, pos, order),
                        ),
                      ],
                    ],
                  ),
          ),

          // Main Body: Customer details, Delivery info & Items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded, size: 16, color: Colors.white70),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  order.customerName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: CelestialTheme.textLight,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (order.customerPhone != null && order.customerPhone!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: order.customerPhone!));
                                    TopNotification.showSuccess(context, 'Phone copied: ${order.customerPhone}');
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.phone_rounded, size: 13, color: CelestialTheme.goldLight),
                                        const SizedBox(width: 4),
                                        Text(
                                          order.customerPhone!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: CelestialTheme.goldLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (isDelivery && order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 14, color: Colors.cyanAccent),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      order.deliveryAddress!,
                                      style: const TextStyle(fontSize: 12, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Payment Method Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Text(
                        '${order.paymentMethod.icon} ${order.paymentMethod.label}',
                        style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Items list
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CelestialTheme.bgSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < order.items.length; i++) ...[
                        if (i > 0) const Divider(height: 12, color: Colors.white10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${order.items[i].quantity}x',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: CelestialTheme.goldLight,
                              ),
                            ),
                            const SizedBox(width: 8),
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
                                      order.items[i].customizations.map((c) => c.summary).join(', '),
                                      style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '₱${order.items[i].totalPrice.toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: CelestialTheme.textLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Special Instructions Notes
                if (order.orderNotes != null && order.orderNotes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.edit_note_rounded, size: 16, color: Colors.amber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Special Notes: ${order.orderNotes!.trim()}',
                            style: const TextStyle(fontSize: 11.5, color: Colors.amberAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Total Price and Assigned Cashier row
                Row(
                  children: [
                    if (order.cashierName.isNotEmpty && !order.cashierName.toLowerCase().contains('online'))
                      Text(
                        'Confirmed by: ${order.cashierName}',
                        style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                      ),
                    const Spacer(),
                    Text(
                      'Total Amount:',
                      style: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '₱${order.totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.goldLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Toolbar
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
            ),
            child: Row(
              children: [
                // Primary Action Button based on status
                if (isPending) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleConfirmOrder(context, pos, auth, order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CelestialTheme.emeraldReady,
                        foregroundColor: Colors.black87,
                        padding: EdgeInsets.symmetric(vertical: isMobile ? 9 : 11, horizontal: isMobile ? 8 : 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 17),
                      label: Text(
                        isMobile ? 'Confirm & Kitchen' : 'Confirm & Send to Kitchen',
                        style: GoogleFonts.outfit(fontSize: isMobile ? 12 : 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _handleDeclineOrder(context, pos, order),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CelestialTheme.roseAlert,
                      side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.5)),
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 9 : 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 15),
                    label: Text(
                      'Decline',
                      style: TextStyle(fontSize: isMobile ? 11.5 : 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else if (isPreparing) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        setState(() {
                          order.status = OrderStatus.ready;
                        });
                        await pos.updateOrderStatus(order.id, OrderStatus.ready);
                        if (context.mounted) {
                          TopNotification.showSuccess(
                            context,
                            'Order ${order.orderNumber} marked Ready for ${isDelivery ? 'Delivery' : 'Pickup'}!',
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CelestialTheme.goldPrimary,
                        foregroundColor: CelestialTheme.primaryBtnText,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
                      label: Text(
                        isDelivery ? 'Mark Ready for Rider' : 'Mark Ready for Pickup',
                        style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else if (isReady) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final nextStatus = isDelivery ? OrderStatus.outForDelivery : OrderStatus.completed;
                        setState(() {
                          order.status = nextStatus;
                        });
                        await pos.updateOrderStatus(order.id, nextStatus);
                        if (context.mounted) {
                          TopNotification.showSuccess(
                            context,
                            'Order ${order.orderNumber} ${isDelivery ? 'Out for Delivery' : 'Completed'}!',
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDelivery ? Colors.cyanAccent : CelestialTheme.emeraldReady,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: Icon(isDelivery ? Icons.delivery_dining_rounded : Icons.verified_rounded, size: 17),
                      label: Text(
                        isDelivery ? 'Hand to Rider' : 'Complete Order',
                        style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else if (isOutForDelivery) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        setState(() {
                          order.status = OrderStatus.completed;
                        });
                        await pos.updateOrderStatus(order.id, OrderStatus.completed);
                        if (context.mounted) {
                          TopNotification.showSuccess(context, 'Order ${order.orderNumber} Completed!');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CelestialTheme.emeraldReady,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.verified_rounded, size: 17),
                      label: Text(
                        'Mark Delivered & Completed',
                        style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else ...[
                  // For completed or cancelled
                  Expanded(
                    child: Text(
                      isCompleted ? '✓ Order has been fulfilled and completed.' : '✕ Order cancelled.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCompleted ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (auth.isOwnerOrAdmin) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _handleDeleteOnlineOrder(context, pos, order),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CelestialTheme.roseAlert,
                        side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 15),
                      label: Text(
                        'Delete',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],

                const SizedBox(width: 6),

                // Order Details modal
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Full Details',
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    color: CelestialTheme.textMuted,
                    onPressed: () => OrderDetailsDialog.show(context, order),
                  ),
                ),

                const SizedBox(width: 2),

                // Receipt Dialog
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'View Receipt',
                    icon: const Icon(Icons.receipt_outlined, size: 18),
                    color: CelestialTheme.textMuted,
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => ReceiptDialog(order: order),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPopup(BuildContext context, PosProvider pos, Order order, {bool isMobile = false}) {
    Color badgeColor;
    String statusText;

    switch (order.status) {
      case OrderStatus.pending:
        badgeColor = CelestialTheme.goldPrimary;
        statusText = isMobile ? 'WAITING' : 'WAITING CONFIRMATION';
        break;
      case OrderStatus.confirmed:
        badgeColor = CelestialTheme.goldPrimary;
        statusText = isMobile ? 'CONFIRMED' : 'IN QUEUE';
        break;
      case OrderStatus.preparing:
        badgeColor = CelestialTheme.amberBrewing;
        statusText = isMobile ? 'PREPARING' : 'KITCHEN PREPARING';
        break;
      case OrderStatus.ready:
        badgeColor = CelestialTheme.emeraldReady;
        statusText = 'READY';
        break;
      case OrderStatus.outForDelivery:
        badgeColor = Colors.cyanAccent;
        statusText = isMobile ? 'DELIVERING' : 'OUT FOR DELIVERY';
        break;
      case OrderStatus.completed:
        badgeColor = CelestialTheme.emeraldReady;
        statusText = 'COMPLETED';
        break;
      case OrderStatus.cancelled:
        badgeColor = CelestialTheme.roseAlert;
        statusText = 'CANCELLED';
        break;
    }

    return PopupMenuButton<OrderStatus>(
      initialValue: order.status,
      tooltip: 'Change Status',
      onSelected: (newStatus) async {
        setState(() {
          order.status = newStatus;
        });
        await pos.updateOrderStatus(order.id, newStatus);
        if (context.mounted) {
          TopNotification.showSuccess(
            context,
            'Order ${order.orderNumber} status changed to ${newStatus.label}',
          );
        }
      },
      itemBuilder: (ctx) => [
        for (final s in OrderStatus.values)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                Text(s.icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text(
                  s.label,
                  style: GoogleFonts.outfit(
                    fontWeight: s == order.status ? FontWeight.bold : FontWeight.normal,
                    color: s == order.status ? CelestialTheme.goldLight : Colors.white,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: badgeColor)),
            const SizedBox(width: 5),
            Text(
              statusText,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 14, color: badgeColor),
          ],
        ),
      ),
    );
  }

  Future<void> _handleConfirmOrder(
    BuildContext context,
    PosProvider pos,
    AuthService auth,
    Order order,
  ) async {
    final cashierName = auth.currentUser?.displayName ??
        (auth.currentUser?.email.split('@').first ?? 'Staff');

    final success = await pos.acceptOnlineOrder(order, cashierName: cashierName);
    if (!mounted) return;
    if (success) {
      TopNotification.showSuccess(
        this.context,
        'Order ${order.orderNumber} confirmed by $cashierName & sent to kitchen!',
      );
    }
  }

  Future<void> _handleDeclineOrder(
    BuildContext context,
    PosProvider pos,
    Order order,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.4)),
        ),
        title: Text(
          'Decline Order ${order.orderNumber}?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: CelestialTheme.roseAlert),
        ),
        content: Text(
          'Are you sure you want to decline this order from ${order.customerName}? The customer tracker will show as Cancelled.',
          style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Order', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.roseAlert,
              foregroundColor: Colors.white,
            ),
            child: const Text('Decline Order'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        order.status = OrderStatus.cancelled;
      });
      await pos.updateOrderStatus(order.id, OrderStatus.cancelled);
      if (mounted) {
        TopNotification.show(this.context, message: 'Order ${order.orderNumber} was declined and cancelled.');
      }
    }
  }

  Future<void> _handleDeleteOnlineOrder(
    BuildContext context,
    PosProvider pos,
    Order order,
  ) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (!auth.isOwnerOrAdmin) {
      TopNotification.showError(context, 'Permission Denied: Cashiers cannot delete orders.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.4)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: CelestialTheme.roseAlert.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_forever_rounded, color: CelestialTheme.roseAlert, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Delete Order ${order.orderNumber}?',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: CelestialTheme.roseAlert, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete order ${order.orderNumber} (${order.customerName})? This will remove it completely from your online orders queue.',
          style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.roseAlert,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await pos.deleteOnlineOrder(order.id);
      if (mounted) {
        if (success) {
          TopNotification.showSuccess(this.context, 'Order ${order.orderNumber} permanently deleted');
        } else {
          TopNotification.showError(this.context, 'Failed to remove order from cloud');
        }
      }
    }
  }

  Future<void> _handleClearAllCompleted(
    BuildContext context,
    PosProvider pos,
    List<Order> allOrders,
  ) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (!auth.isOwnerOrAdmin) {
      TopNotification.showError(context, 'Permission Denied: Cashiers cannot delete orders.');
      return;
    }

    final completedOrders = allOrders.where((o) => o.status == OrderStatus.completed).toList();
    if (completedOrders.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.4)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: CelestialTheme.roseAlert.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_sweep_rounded, color: CelestialTheme.roseAlert, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Clear Completed Orders?',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: CelestialTheme.roseAlert, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete all ${completedOrders.length} completed online order(s)? This action cannot be undone.',
          style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.roseAlert,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.delete_sweep_rounded, size: 16),
            label: Text('Delete All (${completedOrders.length})'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      int count = 0;
      for (final o in completedOrders) {
        final ok = await pos.deleteOnlineOrder(o.id);
        if (ok) count++;
      }
      if (mounted) {
        TopNotification.showSuccess(this.context, 'Cleared $count completed online order(s)');
      }
    }
  }

  Widget _buildEmptyState(
    BuildContext context,
    PosProvider pos,
    bool isCompletelyEmpty,
  ) {
    final auth = Provider.of<AuthService>(context, listen: false);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
              ),
              child: Icon(
                isCompletelyEmpty ? Icons.storefront_rounded : Icons.search_off_rounded,
                size: 36,
                color: CelestialTheme.goldLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isCompletelyEmpty ? 'No Online Orders Yet' : 'No Orders Match Filter',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: CelestialTheme.textLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isCompletelyEmpty
                  ? (auth.isCashier
                      ? 'Waiting for incoming online orders from customers.'
                      : 'Share your online store QR code or link with customers to begin accepting orders.')
                  : 'Try changing your search terms or clearing status filters.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: CelestialTheme.textMuted),
            ),
            const SizedBox(height: 20),
            if (isCompletelyEmpty && !auth.isCashier) ...[
              ElevatedButton.icon(
                onPressed: () => OnlineOrderingDialog.show(context),
                icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                label: const Text('Show Ordering QR Code & Link'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CelestialTheme.goldPrimary,
                  foregroundColor: CelestialTheme.primaryBtnText,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ] else if (!isCompletelyEmpty) ...[
              OutlinedButton(
                onPressed: () => setState(() {
                  _searchQuery = '';
                  _statusFilter = null;
                  _typeFilter = null;
                }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CelestialTheme.goldLight,
                  side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                ),
                child: const Text('Reset All Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
