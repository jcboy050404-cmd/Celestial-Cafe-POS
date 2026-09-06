import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import '../widgets/kds_hotspot_dialog.dart';
import '../widgets/order_card_kds.dart';
import '../widgets/table_qr_dialog.dart';
import '../widgets/top_notification.dart';

class KdsScreen extends StatefulWidget {
  const KdsScreen({super.key});

  @override
  State<KdsScreen> createState() => _KdsScreenState();
}

class _KdsScreenState extends State<KdsScreen> {
  OrderStatus? _statusFilter;
  String _stationFilter = 'all';
  String _summaryCategoryFilter = 'kitchen';

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    List<Order> filteredOrders = _statusFilter == null
        ? posProvider.activeKdsOrders
        : posProvider.orders.where((o) => o.status == _statusFilter).toList();

    if (_stationFilter == 'kitchen') {
      filteredOrders = filteredOrders.where((o) => o.hasKitchenDishes).toList();
    } else if (_stationFilter == 'barista') {
      filteredOrders = filteredOrders.where((o) => o.hasBaristaDrinks).toList();
    }

    return Container(
      color: CelestialTheme.bgDark,
      child: Column(
        children: [
          // KDS Control Header
          _buildKdsHeader(posProvider, isMobile),

          const Divider(height: 1),

          // Orders View or Kitchen Production Summary View
          Expanded(
            child: _stationFilter == 'summary'
                ? _buildKitchenSummaryView(posProvider, isMobile)
                : filteredOrders.isEmpty
                    ? _buildEmptyState(isMobile)
                : isMobile
                    ? ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
                        itemCount: filteredOrders.length,
                        separatorBuilder: (ctx, idx) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          return OrderCardKds(
                            key: ValueKey(filteredOrders[index].id),
                            order: filteredOrders[index],
                            isMobileList: true,
                          );
                        },
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = 3;
                          double childAspectRatio = 0.75;

                          if (constraints.maxWidth > 1700) {
                            crossAxisCount = 6;
                            childAspectRatio = 0.82;
                          } else if (constraints.maxWidth > 1400) {
                            crossAxisCount = 5;
                            childAspectRatio = 0.80;
                          } else if (constraints.maxWidth > 1100) {
                            crossAxisCount = 4;
                            childAspectRatio = 0.78;
                          } else if (constraints.maxWidth > 800) {
                            crossAxisCount = 3;
                            childAspectRatio = 0.75;
                          } else {
                            crossAxisCount = 2;
                            childAspectRatio = 0.72;
                          }

                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: childAspectRatio,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                            itemCount: filteredOrders.length,
                            itemBuilder: (context, index) {
                              return OrderCardKds(
                                key: ValueKey(filteredOrders[index].id),
                                order: filteredOrders[index],
                                isMobileList: false,
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildKdsHeader(PosProvider provider, bool isMobile) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        color: CelestialTheme.bgSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Title & Server Live Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.coffee_maker_rounded, color: CelestialTheme.goldPrimary, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Celestial Cafe',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const KdsHotspotDialog(),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: provider.kdsServer.isRunning
                          ? CelestialTheme.emeraldReady.withValues(alpha: 0.15)
                          : CelestialTheme.roseAlert.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: provider.kdsServer.isRunning
                            ? CelestialTheme.emeraldReady.withValues(alpha: 0.6)
                            : CelestialTheme.roseAlert.withValues(alpha: 0.6),
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
                            color: provider.kdsServer.isRunning
                                ? CelestialTheme.emeraldReady
                                : CelestialTheme.roseAlert,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          provider.kdsServer.isRunning ? 'Live Server' : 'Offline',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: provider.kdsServer.isRunning
                                ? CelestialTheme.emeraldReady
                                : CelestialTheme.roseAlert,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: Full Width Dual Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => const KdsHotspotDialog(),
                      );
                    },
                    icon: const Icon(Icons.wifi_tethering_rounded, size: 15),
                    label: Text(
                      provider.kdsServer.clientCount > 0
                          ? '${provider.kdsServer.clientCount} Connected'
                          : 'Barista KDS',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: provider.kdsServer.clientCount > 0
                          ? CelestialTheme.emeraldReady
                          : CelestialTheme.goldLight,
                      side: BorderSide(
                        color: provider.kdsServer.clientCount > 0
                            ? CelestialTheme.emeraldReady.withValues(alpha: 0.6)
                            : CelestialTheme.goldPrimary.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => TableQrDialog.show(context),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 15),
                    label: const Text(
                      'Table QR',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CelestialTheme.goldPrimary,
                      foregroundColor: CelestialTheme.bgDark,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            if (provider.readyOrders.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final readyOrders = List.from(provider.readyOrders);
                    for (final o in readyOrders) {
                      provider.updateOrderStatus(o.id, OrderStatus.completed);
                    }
                    ScaffoldMessenger.of(context).clearSnackBars();
                    TopNotification.showSuccess(
                      context,
                      '${readyOrders.length} ready orders completed & handed over!',
                    );
                  },
                  icon: const Icon(Icons.done_all_rounded, size: 16, color: Colors.white),
                  label: Text(
                    'Complete All Ready Tickets (${provider.readyOrders.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Row 3: Status & Station Filter Chips with horizontal scrolling
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusTab('Active Queue', null, provider.activeKdsOrders.length, CelestialTheme.goldPrimary),
                  const SizedBox(width: 6),
                  _buildStatusTab('Confirmed', OrderStatus.confirmed, provider.confirmedOrders.length, const Color(0xFF2EC4B6)),
                  const SizedBox(width: 6),
                  _buildStatusTab('Brewing', OrderStatus.preparing, provider.preparingOrders.length, CelestialTheme.amberBrewing),
                  const SizedBox(width: 6),
                  _buildStatusTab('Ready', OrderStatus.ready, provider.readyOrders.length, CelestialTheme.emeraldReady),
                  const SizedBox(width: 10),
                  Container(width: 1, height: 22, color: Colors.white.withValues(alpha: 0.15)),
                  const SizedBox(width: 10),
                  _buildStationTab(
                    '🍳 Kitchen View',
                    'summary',
                    provider.activeKdsOrders
                        .where((o) => o.status != OrderStatus.ready)
                        .fold(0, (sum, o) => sum + o.items.where((i) => i.isKitchenDish && !i.isPrepared).fold(0, (s, i) => s + i.quantity)),
                    const Color(0xFFFF5722),
                  ),
                  const SizedBox(width: 6),
                  _buildStationTab('Kitchen Food', 'kitchen', provider.activeKdsOrders.where((o) => o.hasKitchenDishes).length, const Color(0xFFFF5722)),
                  const SizedBox(width: 6),
                  _buildStationTab('Barista Drinks', 'barista', provider.activeKdsOrders.where((o) => o.hasBaristaDrinks).length, CelestialTheme.amberBrewing),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Tablet & Desktop Header
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: CelestialTheme.bgSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.coffee_maker_rounded, color: CelestialTheme.goldPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Celestial Cafe',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Live barista order tickets & preparation station',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: CelestialTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Hotspot Barista Phone Connect Button
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const KdsHotspotDialog(),
                  );
                },
                icon: const Icon(Icons.wifi_tethering_rounded, size: 16),
                label: Text(
                  provider.kdsServer.clientCount > 0
                      ? '${provider.kdsServer.clientCount} Phone Connected'
                      : 'Barista KDS Screen',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: provider.kdsServer.clientCount > 0
                      ? CelestialTheme.emeraldReady
                      : CelestialTheme.goldLight,
                  side: BorderSide(
                    color: provider.kdsServer.clientCount > 0
                      ? CelestialTheme.emeraldReady.withValues(alpha: 0.5)
                      : CelestialTheme.goldPrimary.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(width: 10),

              // Table QR Self-Ordering Button
              ElevatedButton.icon(
                onPressed: () => TableQrDialog.show(context),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                label: const Text(
                  'Table QR',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CelestialTheme.goldPrimary,
                  foregroundColor: CelestialTheme.bgDark,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              if (provider.readyOrders.isNotEmpty) ...[
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    final readyOrders = List.from(provider.readyOrders);
                    for (final o in readyOrders) {
                      provider.updateOrderStatus(o.id, OrderStatus.completed);
                    }
                    ScaffoldMessenger.of(context).clearSnackBars();
                    TopNotification.showSuccess(
                      context,
                      '${readyOrders.length} ready orders completed & handed over!',
                    );
                  },
                  icon: const Icon(Icons.done_all_rounded, size: 16, color: Colors.white),
                  label: Text(
                    'Complete All (${provider.readyOrders.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Filter Chips Row with Status & Station Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusTab('Active Queue', null, provider.activeKdsOrders.length, CelestialTheme.goldPrimary),
                const SizedBox(width: 8),
                _buildStatusTab('Confirmed', OrderStatus.confirmed, provider.confirmedOrders.length, const Color(0xFF2EC4B6)),
                const SizedBox(width: 8),
                _buildStatusTab('Brewing / Prep', OrderStatus.preparing, provider.preparingOrders.length, CelestialTheme.amberBrewing),
                const SizedBox(width: 8),
                _buildStatusTab('Ready for Pickup', OrderStatus.ready, provider.readyOrders.length, CelestialTheme.emeraldReady),
                const SizedBox(width: 12),
                Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(width: 12),
                _buildStationTab(
                  '🍳 Kitchen View',
                  'summary',
                  provider.activeKdsOrders
                      .where((o) => o.status != OrderStatus.ready)
                      .fold(0, (sum, o) => sum + o.items.where((i) => i.isKitchenDish && !i.isPrepared).fold(0, (s, i) => s + i.quantity)),
                  const Color(0xFFFF5722),
                ),
                const SizedBox(width: 8),
                _buildStationTab('Kitchen Food', 'kitchen', provider.activeKdsOrders.where((o) => o.hasKitchenDishes).length, const Color(0xFFFF5722)),
                const SizedBox(width: 8),
                _buildStationTab('Barista Drinks', 'barista', provider.activeKdsOrders.where((o) => o.hasBaristaDrinks).length, CelestialTheme.amberBrewing),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String title, OrderStatus? status, int count, Color color) {
    final isSelected = _statusFilter == status;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _statusFilter = status),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.22) : CelestialTheme.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.white.withValues(alpha: 0.1),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? CelestialTheme.textLight : CelestialTheme.textMuted,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? color : CelestialTheme.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? CelestialTheme.bgDark : CelestialTheme.textLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStationTab(String title, String station, int count, Color color) {
    final isSelected = _stationFilter == station;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _stationFilter = isSelected ? 'all' : station;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.22) : CelestialTheme.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.35),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? color : CelestialTheme.textLight,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? color : CelestialTheme.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : CelestialTheme.textLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isMobile ? 64 : 80,
              height: isMobile ? 64 : 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CelestialTheme.bgCard,
                border: Border.all(color: CelestialTheme.emeraldReady.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(Icons.check_circle_outline_rounded, size: isMobile ? 32 : 40, color: CelestialTheme.goldLight),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'All Orders Completed!',
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: CelestialTheme.textLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No active barista tickets pending in this queue.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 11.5 : 12,
                color: CelestialTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKitchenSummaryView(PosProvider provider, bool isMobile) {
    final activeOrders = provider.activeKdsOrders
        .where((o) => o.status == OrderStatus.confirmed || o.status == OrderStatus.preparing)
        .toList();

    final Map<String, _KitchenItemAggregation> itemMap = {};

    for (final order in activeOrders) {
      for (int i = 0; i < order.items.length; i++) {
        final item = order.items[i];
        final isKitchen = item.isKitchenDish;

        if (_summaryCategoryFilter == 'kitchen' && !isKitchen) continue;
        if (_summaryCategoryFilter == 'barista' && isKitchen) continue;

        final key = item.menuItem.name.trim();
        final entry = itemMap.putIfAbsent(
          key,
          () => _KitchenItemAggregation(
            name: key,
            category: item.menuItem.category.name,
            isKitchen: isKitchen,
          ),
        );

        entry.totalQuantity += item.quantity;
        if (item.isPrepared) {
          entry.preparedQuantity += item.quantity;
        }

        final isTakeout = order.orderType == OrderType.takeaway ||
            order.orderType == OrderType.delivery ||
            (order.tableNumber != null && order.tableNumber!.toLowerCase().contains('take'));

        String tableLabel = 'Table 1';
        if (order.tableNumber != null && order.tableNumber!.trim().isNotEmpty) {
          final t = order.tableNumber!.trim();
          tableLabel = t.toLowerCase().startsWith('table') ? t : 'Table $t';
        }
        if (isTakeout) {
          tableLabel = '🥡 Takeout ${order.orderNumber}';
        }

        entry.breakdown.add(_KitchenOrderBreakdown(
          orderId: order.id,
          orderNumber: order.orderNumber,
          tableLabel: tableLabel,
          isTakeout: isTakeout,
          itemIndex: i,
          quantity: item.quantity,
          isPrepared: item.isPrepared,
          notes: item.notes,
          customizations: item.customizations.map((c) => c.summary).toList(),
          createdAt: order.createdAt,
          orderStatus: order.status,
        ));
      }
    }

    final aggregatedList = itemMap.values.toList()
      ..sort((a, b) => b.pendingQuantity.compareTo(a.pendingQuantity));

    final totalItemsToCook = aggregatedList.fold(0, (sum, a) => sum + a.pendingQuantity);

    return Column(
      children: [
        // Kitchen Summary Control Toolbar
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 20,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: CelestialTheme.bgSurface,
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.soup_kitchen_rounded, color: Color(0xFFFF5722), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Kitchen Production View',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile ? 13 : 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFFE0B2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5722).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFF5722).withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '$totalItemsToCook to cook',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF7043),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Category Toggle Pills
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSummaryFilterPill('🍳 Food', 'kitchen'),
                  const SizedBox(width: 6),
                  _buildSummaryFilterPill('☕ Drinks', 'barista'),
                  const SizedBox(width: 6),
                  _buildSummaryFilterPill('📋 All', 'all'),
                ],
              ),
            ],
          ),
        ),

        // Items Grid / List
        Expanded(
          child: aggregatedList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF5722).withValues(alpha: 0.12),
                          border: Border.all(color: const Color(0xFFFF5722).withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded, size: 40, color: Color(0xFFFF7043)),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'All Kitchen Dishes Clear!',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFFE0B2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No active items waiting in this category.',
                        style: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 12 : 20,
                    14,
                    isMobile ? 12 : 20,
                    80,
                  ),
                  itemCount: aggregatedList.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: 14),
                  itemBuilder: (context, idx) {
                    final itemAggr = aggregatedList[idx];
                    return _buildAggregatedItemCard(itemAggr, provider, isMobile);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAggregatedItemCard(
    _KitchenItemAggregation aggr,
    PosProvider provider,
    bool isMobile,
  ) {
    final allDone = aggr.pendingQuantity == 0;
    final isKitchen = aggr.isKitchen;
    final accentColor = isKitchen ? const Color(0xFFFF5722) : CelestialTheme.goldPrimary;

    return Container(
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allDone
              ? CelestialTheme.emeraldReady.withValues(alpha: 0.35)
              : accentColor.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isKitchen
                  ? const Color(0xFFFF5722).withValues(alpha: 0.12)
                  : CelestialTheme.goldPrimary.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(isKitchen ? '🍳' : '☕', style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              aggr.name,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isKitchen ? const Color(0xFFFFE0B2) : Colors.white,
                              ),
                            ),
                            Text(
                              aggr.category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: CelestialTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: allDone ? CelestialTheme.emeraldReady : accentColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${aggr.totalQuantity}x',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0B080D),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0B080D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Subheader: Progress & Batch Mark
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.black.withValues(alpha: 0.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  allDone
                      ? '✓ All Prepared'
                      : '${aggr.preparedQuantity} of ${aggr.totalQuantity} prepared (${aggr.pendingQuantity} pending)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: allDone ? CelestialTheme.emeraldReady : CelestialTheme.textMuted,
                  ),
                ),
                if (!allDone)
                  InkWell(
                    onTap: () {
                      for (final b in aggr.breakdown) {
                        if (!b.isPrepared) {
                          provider.setOrderItemPrepared(b.orderId, b.itemIndex, true);
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: CelestialTheme.emeraldReady.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: CelestialTheme.emeraldReady.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.done_all_rounded, size: 12, color: CelestialTheme.emeraldReady),
                          SizedBox(width: 4),
                          Text(
                            'Mark All Ready',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.emeraldReady,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Table Breakdown Rows
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: aggr.breakdown.map((b) {
                final isTakeout = b.isTakeout;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: b.isPrepared
                        ? CelestialTheme.emeraldReady.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: b.isPrepared
                          ? CelestialTheme.emeraldReady.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Table badge & order number
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          gradient: isTakeout
                              ? const LinearGradient(colors: [Color(0xFFFF9F1C), Color(0xFFE07A00)])
                              : null,
                          color: isTakeout
                              ? null
                              : CelestialTheme.brownWarm.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(6),
                          border: isTakeout ? null : Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          b.tableLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: isTakeout ? Colors.black : CelestialTheme.goldLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        b.orderNumber,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        b.durationString,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: CelestialTheme.textMuted,
                        ),
                      ),

                      const Spacer(),

                      // Quantity
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isKitchen
                              ? const Color(0xFFFF5722).withValues(alpha: 0.25)
                              : CelestialTheme.goldPrimary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isKitchen
                                ? const Color(0xFFFF5722).withValues(alpha: 0.5)
                                : CelestialTheme.goldPrimary.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          '${b.quantity}x',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: isKitchen ? const Color(0xFFFF7043) : CelestialTheme.goldLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Ready Check Button
                      InkWell(
                        onTap: () {
                          provider.setOrderItemPrepared(b.orderId, b.itemIndex, !b.isPrepared);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: b.isPrepared
                                ? CelestialTheme.emeraldReady
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: b.isPrepared
                                  ? CelestialTheme.emeraldReady
                                  : Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            b.isPrepared ? '✓ Ready' : 'Ready',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: b.isPrepared ? const Color(0xFF0D0B10) : CelestialTheme.textLight,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryFilterPill(String title, String category) {
    final isSelected = _summaryCategoryFilter == category;
    return InkWell(
      onTap: () => setState(() => _summaryCategoryFilter = category),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF5722).withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF5722).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? const Color(0xFFFF7043) : CelestialTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _KitchenItemAggregation {
  final String name;
  final String category;
  final bool isKitchen;
  int totalQuantity = 0;
  int preparedQuantity = 0;
  final List<_KitchenOrderBreakdown> breakdown = [];

  _KitchenItemAggregation({
    required this.name,
    required this.category,
    required this.isKitchen,
  });

  int get pendingQuantity => totalQuantity - preparedQuantity;
}

class _KitchenOrderBreakdown {
  final String orderId;
  final String orderNumber;
  final String tableLabel;
  final bool isTakeout;
  final int itemIndex;
  final int quantity;
  final bool isPrepared;
  final String? notes;
  final List<String> customizations;
  final DateTime createdAt;
  final OrderStatus orderStatus;

  _KitchenOrderBreakdown({
    required this.orderId,
    required this.orderNumber,
    required this.tableLabel,
    required this.isTakeout,
    required this.itemIndex,
    required this.quantity,
    required this.isPrepared,
    this.notes,
    required this.customizations,
    required this.createdAt,
    required this.orderStatus,
  });

  String get durationString {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
  }
}
