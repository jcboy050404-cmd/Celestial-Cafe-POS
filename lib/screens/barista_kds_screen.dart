import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../services/auth_service.dart';
import '../theme/celestial_theme.dart';
import '../widgets/header_bar.dart';
import '../widgets/top_notification.dart';

/// Dedicated screen for Barista and KDS (Kitchen Display System) staff.
///
/// Shows live incoming orders (both POS-originated and online) with
/// one-tap status update buttons:  Pending → Preparing → Ready → Done.
///
/// Staff can only view orders — no POS, inventory, analytics, or settings.
class BaristaKDSScreen extends StatefulWidget {
  const BaristaKDSScreen({super.key});

  @override
  State<BaristaKDSScreen> createState() => _BaristaKDSScreenState();
}

class _BaristaKDSScreenState extends State<BaristaKDSScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isRefreshing = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    // Trigger an initial poll when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _doRefresh(silent: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _doRefresh({bool silent = false}) async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    final pos = Provider.of<PosProvider>(context, listen: false);
    await pos.pollOnlineOrders();
    if (mounted) {
      setState(() => _isRefreshing = false);
      if (!silent) {
        TopNotification.showSuccess(context, 'Orders refreshed');
      }
    }
  }

  Future<void> _markPreparing(Order order) async {
    final pos = Provider.of<PosProvider>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final staffName = auth.currentUser?.displayName ?? auth.currentUser?.email.split('@').first ?? 'Staff';
    final success = await pos.acceptOnlineOrder(order, cashierName: staffName);
    if (mounted) {
      if (success) {
        TopNotification.showSuccess(context, 'Order ${order.orderNumber} — Now Preparing ☕');
      } else {
        TopNotification.show(context, message: 'Could not update order status', backgroundColor: CelestialTheme.roseAlert);
      }
    }
  }

  Future<void> _markReady(Order order) async {
    final pos = Provider.of<PosProvider>(context, listen: false);
    final success = await pos.markOnlineOrderReady(order);
    if (mounted) {
      final label = order.orderType == OrderType.delivery ? 'Out for Delivery 🛵' : 'Ready for Pickup ✨';
      if (success) {
        TopNotification.showSuccess(context, 'Order ${order.orderNumber} — $label');
      } else {
        TopNotification.show(context, message: 'Could not update order status', backgroundColor: CelestialTheme.roseAlert);
      }
    }
  }

  Future<void> _markComplete(Order order) async {
    final pos = Provider.of<PosProvider>(context, listen: false);
    final success = await pos.completeOnlineOrder(order);
    if (mounted) {
      if (success) {
        TopNotification.showSuccess(context, 'Order ${order.orderNumber} — Completed ✅');
      } else {
        TopNotification.show(context, message: 'Could not update order status', backgroundColor: CelestialTheme.roseAlert);
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final auth = Provider.of<AuthService>(context);
    final isMobile = MediaQuery.of(context).size.width < 768;
    final user = auth.currentUser;

    // ── Collect orders ──
    final cutoff = DateTime.now().subtract(const Duration(hours: 2));

    // Online orders (from Firebase live queue)
    final onlineOrders = posProvider.incomingOnlineOrders.where((o) {
      final isFinal = o.status == OrderStatus.completed || o.status == OrderStatus.cancelled;
      return !isFinal || o.createdAt.isAfter(cutoff);
    }).toList();

    // POS orders (locally originated, today)
    final posOrders = posProvider.orders.where((o) {
      final isOnline = o.id.startsWith('online_') ||
          o.cashierName.toLowerCase().contains('online') ||
          o.cashierName.toLowerCase().contains('web');
      if (isOnline) return false; // Already in online tab
      final isFinal = o.status == OrderStatus.completed || o.status == OrderStatus.cancelled;
      return !isFinal || o.createdAt.isAfter(cutoff);
    }).toList();

    // Sort: active first, then by time
    int orderPriority(Order o) {
      if (o.status == OrderStatus.pending) return 0;
      if (o.status == OrderStatus.confirmed) return 1;
      if (o.status == OrderStatus.preparing) return 2;
      if (o.status == OrderStatus.ready || o.status == OrderStatus.outForDelivery) return 3;
      return 4;
    }

    onlineOrders.sort((a, b) {
      final p = orderPriority(a).compareTo(orderPriority(b));
      return p != 0 ? p : b.createdAt.compareTo(a.createdAt);
    });
    posOrders.sort((a, b) {
      final p = orderPriority(a).compareTo(orderPriority(b));
      return p != 0 ? p : b.createdAt.compareTo(a.createdAt);
    });

    final pendingOnlineCount = onlineOrders.where((o) => o.status == OrderStatus.pending).length;
    final preparingCount = (onlineOrders + posOrders).where((o) => o.status == OrderStatus.preparing).length;

    return Scaffold(
      backgroundColor: CelestialTheme.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header ──────────────────────────────────────────────────
            _buildHeader(context, user, auth, pendingOnlineCount, preparingCount, isMobile),

            // ── Status summary bar ──────────────────────────────────────────
            _buildStatusBar(onlineOrders, posOrders),

            // ── Tab Bar ─────────────────────────────────────────────────────
            Container(
              color: CelestialTheme.bgSurface,
              child: TabBar(
                controller: _tabController,
                indicatorColor: CelestialTheme.goldPrimary,
                indicatorWeight: 2.5,
                labelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
                unselectedLabelStyle: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w500),
                labelColor: CelestialTheme.goldLight,
                unselectedLabelColor: CelestialTheme.textMuted,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('☕ Online Orders'),
                        if (pendingOnlineCount > 0) ...[
                          const SizedBox(width: 6),
                          _pulseBadge(pendingOnlineCount),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🖥️ POS Orders'),
                        if (posOrders.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.preparing).isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _pulseBadge(posOrders.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.preparing).length),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ─────────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOrdersList(context, onlineOrders, isOnline: true),
                  _buildOrdersList(context, posOrders, isOnline: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, AppUser? user, AuthService auth,
      int pendingCount, int preparingCount, bool isMobile) {
    final posProvider = Provider.of<PosProvider>(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CelestialTheme.bgSurface,
        border: Border(
          bottom: BorderSide(color: CelestialTheme.borderSubtle, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo / Icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.35), width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: posProvider.hasCustomLogo && posProvider.customLogoBytes != null
                  ? Image.memory(
                      posProvider.customLogoBytes!,
                      fit: BoxFit.cover,
                      key: ValueKey(posProvider.customLogoBase64?.hashCode ?? 1),
                    )
                  : Image.asset(
                      'assets/images/Logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.coffee_rounded, color: CelestialTheme.goldLight, size: 20),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Title & user info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        posProvider.storeName.isNotEmpty && posProvider.storeName != 'CELESTIAL CAFE'
                            ? 'BARISTA / KDS • ${posProvider.storeName.toUpperCase()}'
                            : 'BARISTA / KDS',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.goldLight,
                          letterSpacing: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    HeaderBar.buildRoleBadge(user),
                  ],
                ),
                if (user != null)
                  Text(
                    user.displayName.isNotEmpty ? user.displayName : user.email,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: CelestialTheme.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Live status pill
          if (preparingCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: CelestialTheme.amberBrewing.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CelestialTheme.amberBrewing.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department_rounded, color: CelestialTheme.amberBrewing, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$preparingCount Brewing',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: CelestialTheme.amberBrewing,
                    ),
                  ),
                ],
              ),
            ),

          // Refresh button
          IconButton(
            onPressed: _isRefreshing ? null : _doRefresh,
            tooltip: 'Refresh orders',
            icon: _isRefreshing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: CelestialTheme.goldPrimary,
                    ),
                  )
                : Icon(Icons.refresh_rounded, color: CelestialTheme.textMuted, size: 20),
          ),

          // Sign out
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: CelestialTheme.textMuted, size: 20),
            color: CelestialTheme.bgCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) async {
              if (val == 'signout') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: CelestialTheme.bgSurface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text('Sign Out', style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontWeight: FontWeight.bold)),
                    content: Text('Sign out of your Barista station?', style: GoogleFonts.outfit(color: CelestialTheme.textMuted)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CelestialTheme.roseAlert,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await Provider.of<AuthService>(context, listen: false).signOut();
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: CelestialTheme.roseAlert, size: 16),
                    const SizedBox(width: 8),
                    Text('Sign Out', style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Status summary bar ──────────────────────────────────────────────────────

  Widget _buildStatusBar(List<Order> onlineOrders, List<Order> posOrders) {
    final allOrders = [...onlineOrders, ...posOrders];
    final pending = allOrders.where((o) => o.status == OrderStatus.pending).length;
    final preparing = allOrders.where((o) => o.status == OrderStatus.preparing).length;
    final ready = allOrders.where((o) =>
        o.status == OrderStatus.ready || o.status == OrderStatus.outForDelivery).length;
    final done = allOrders.where((o) =>
        o.status == OrderStatus.completed || o.status == OrderStatus.cancelled).length;

    if (allOrders.isEmpty) return const SizedBox.shrink();

    return Container(
      color: CelestialTheme.bgSurfaceLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statusPill('Pending', pending, CelestialTheme.goldPrimary, Icons.hourglass_empty_rounded),
          _statusPill('Brewing', preparing, CelestialTheme.amberBrewing, Icons.local_fire_department_rounded),
          _statusPill('Ready', ready, CelestialTheme.emeraldReady, Icons.check_circle_outline_rounded),
          _statusPill('Done', done, CelestialTheme.textSubtle, Icons.done_all_rounded),
        ],
      ),
    );
  }

  Widget _statusPill(String label, int count, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          '$count $label',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: count > 0 ? color : CelestialTheme.textSubtle,
          ),
        ),
      ],
    );
  }

  // ── Orders List ─────────────────────────────────────────────────────────────

  Widget _buildOrdersList(BuildContext context, List<Order> orders, {required bool isOnline}) {
    if (orders.isEmpty) {
      return _buildEmptyState(isOnline);
    }

    return RefreshIndicator(
      onRefresh: _doRefresh,
      color: CelestialTheme.goldPrimary,
      backgroundColor: CelestialTheme.bgCard,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;
          if (isWide) {
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _OrderCard(
                        order: orders[i],
                        onPreparing: _markPreparing,
                        onReady: _markReady,
                        onComplete: _markComplete,
                      ),
                      childCount: orders.length,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 360,
                    ),
                  ),
                ),
              ],
            );
          }
          // Single-column on mobile
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) => _OrderCard(
              order: orders[i],
              onPreparing: _markPreparing,
              onReady: _markReady,
              onComplete: _markComplete,
            ),
          );
        },
      ),
    );
  }


  Widget _buildEmptyState(bool isOnline) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.wifi_tethering_rounded : Icons.point_of_sale_rounded,
            size: 52,
            color: CelestialTheme.textSubtle.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 14),
          Text(
            isOnline ? 'No active online orders' : 'No active POS orders',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: CelestialTheme.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isOnline
                ? 'New customer orders will appear here in real-time'
                : 'POS orders placed at the counter will show up here',
            style: GoogleFonts.outfit(fontSize: 12, color: CelestialTheme.textSubtle),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _doRefresh,
            icon: Icon(Icons.refresh_rounded, size: 16, color: CelestialTheme.goldPrimary),
            label: Text('Refresh', style: GoogleFonts.outfit(color: CelestialTheme.goldPrimary, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pulseBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: CelestialTheme.roseAlert,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}

// ── Order Card ─────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final Order order;
  final Future<void> Function(Order) onPreparing;
  final Future<void> Function(Order) onReady;
  final Future<void> Function(Order) onComplete;

  const _OrderCard({
    required this.order,
    required this.onPreparing,
    required this.onReady,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final type = order.orderType;
    final isFinal = status == OrderStatus.completed || status == OrderStatus.cancelled;

    final statusColor = _statusColor(status);
    final cardBorderColor = isFinal
        ? Colors.white.withValues(alpha: 0.06)
        : statusColor.withValues(alpha: 0.55);

    return Container(
      decoration: BoxDecoration(
        color: isFinal ? CelestialTheme.bgCard.withValues(alpha: 0.6) : CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorderColor, width: isFinal ? 0.7 : 1.5),
        boxShadow: isFinal
            ? null
            : [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card Header ─────────────────────────────────────────────────
            Row(
              children: [
                // Order type icon badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _typeColor(type).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _typeColor(type).withValues(alpha: 0.45), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(type.icon, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        type.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: _typeColor(type),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(status.icon, style: const TextStyle(fontSize: 10)),
                      const SizedBox(width: 4),
                      Text(
                        status.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Order number + customer ─────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  order.orderNumber,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isFinal ? CelestialTheme.textMuted : CelestialTheme.textLight,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order.customerName.isNotEmpty)
                        Text(
                          order.customerName,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: CelestialTheme.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (order.tableNumber != null && order.tableNumber!.isNotEmpty)
                        Text(
                          order.tableNumber!,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: CelestialTheme.goldPrimary.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                // Elapsed time
                Text(
                  order.durationString,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: _isUrgent(order) ? CelestialTheme.roseAlert : CelestialTheme.textSubtle,
                    fontWeight: _isUrgent(order) ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
            const SizedBox(height: 10),

            // ── Items list ──────────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: order.items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return Padding(
                  padding: EdgeInsets.only(top: i > 0 ? 6 : 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '×${item.quantity}',
                          style: TextStyle(
                            fontSize: 10,
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
                              item.menuItem.name,
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isFinal ? CelestialTheme.textSubtle : CelestialTheme.textLight,
                              ),
                            ),
                            if (item.customizations.isNotEmpty)
                              Wrap(
                                spacing: 4,
                                runSpacing: 2,
                                children: item.customizations.map((c) => Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: CelestialTheme.bgCardHover,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  child: Text(
                                    c.summary,
                                    style: TextStyle(fontSize: 9.5, color: CelestialTheme.warmBeige),
                                  ),
                                )).toList(),
                              ),
                            if (item.notes != null && item.notes!.isNotEmpty)
                              Text(
                                '📝 ${item.notes}',
                                style: TextStyle(fontSize: 10, color: CelestialTheme.goldPrimary.withValues(alpha: 0.8), fontStyle: FontStyle.italic),
                              ),
                          ],
                        ),
                      ),
                      // Kitchen / Barista tag
                      if (item.isKitchenDish)
                        Container(
                          margin: const EdgeInsets.only(left: 4, top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: CelestialTheme.roseAlert.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: CelestialTheme.roseAlert.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'KDS',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.roseAlert,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),

            // ── Notes ───────────────────────────────────────────────────────
            if (order.orderNotes != null && order.orderNotes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sticky_note_2_outlined, size: 13, color: CelestialTheme.goldPrimary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        order.orderNotes!,
                        style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.goldLight, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Delivery address ────────────────────────────────────────────
            if (order.orderType == OrderType.delivery &&
                order.deliveryAddress != null &&
                order.deliveryAddress!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_rounded, size: 13, color: CelestialTheme.blueInfo),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.deliveryAddress!,
                      style: TextStyle(fontSize: 11, color: CelestialTheme.blueInfo.withValues(alpha: 0.85)),
                    ),
                  ),
                ],
              ),
            ],

            // ── Action button ───────────────────────────────────────────────
            if (!isFinal) ...[
              const SizedBox(height: 10),
              _buildActionButton(context),
            ] else ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  status == OrderStatus.completed ? '✅ Completed' : '❌ Cancelled',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: status == OrderStatus.completed ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    final status = order.status;

    if (status == OrderStatus.pending || status == OrderStatus.confirmed) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => onPreparing(order),
          icon: const Icon(Icons.local_fire_department_rounded, size: 16),
          label: Text('Start Preparing', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: CelestialTheme.amberBrewing,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      );
    }

    if (status == OrderStatus.preparing) {
      final isDelivery = order.orderType == OrderType.delivery;
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => onReady(order),
          icon: Icon(
            isDelivery ? Icons.delivery_dining_rounded : Icons.check_circle_rounded,
            size: 16,
          ),
          label: Text(
            isDelivery ? 'Mark: Out for Delivery' : 'Mark: Ready for Pickup',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12.5),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: CelestialTheme.emeraldReady,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      );
    }

    if (status == OrderStatus.ready || status == OrderStatus.outForDelivery) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => onComplete(order),
          icon: const Icon(Icons.done_all_rounded, size: 16),
          label: Text('Mark as Completed', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: CelestialTheme.blueInfo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
      case OrderStatus.confirmed:
        return CelestialTheme.goldPrimary;
      case OrderStatus.preparing:
        return CelestialTheme.amberBrewing;
      case OrderStatus.ready:
      case OrderStatus.outForDelivery:
        return CelestialTheme.emeraldReady;
      case OrderStatus.completed:
        return CelestialTheme.textSubtle;
      case OrderStatus.cancelled:
        return CelestialTheme.roseAlert;
    }
  }

  Color _typeColor(OrderType type) {
    switch (type) {
      case OrderType.dineIn:
        return CelestialTheme.goldPrimary;
      case OrderType.takeaway:
        return CelestialTheme.caramelAccent;
      case OrderType.delivery:
        return CelestialTheme.blueInfo;
    }
  }

  bool _isUrgent(Order order) {
    if (order.status == OrderStatus.completed || order.status == OrderStatus.cancelled) {
      return false;
    }
    return DateTime.now().difference(order.createdAt).inMinutes >= 15;
  }
}
