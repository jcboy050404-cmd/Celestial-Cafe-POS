import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import '../widgets/kds_hotspot_dialog.dart';
import '../widgets/order_card_kds.dart';
import '../widgets/table_qr_dialog.dart';

class KdsScreen extends StatefulWidget {
  const KdsScreen({super.key});

  @override
  State<KdsScreen> createState() => _KdsScreenState();
}

class _KdsScreenState extends State<KdsScreen> {
  OrderStatus? _statusFilter;
  String _stationFilter = 'all';

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

          // Orders View
          Expanded(
            child: filteredOrders.isEmpty
                ? _buildEmptyState(isMobile)
                : isMobile
                    ? ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
                        itemCount: filteredOrders.length,
                        separatorBuilder: (ctx, idx) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          return OrderCardKds(
                            order: filteredOrders[index],
                            isMobileList: true,
                          );
                        },
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = 3;
                          double childAspectRatio = 0.75;

                          if (constraints.maxWidth > 1300) {
                            crossAxisCount = 4;
                            childAspectRatio = 0.78;
                          } else if (constraints.maxWidth > 900) {
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
                      'Kitchen Display System',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.textLight,
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
                      'Kitchen Display System (KDS)',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.textLight,
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

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.25),
      backgroundColor: CelestialTheme.bgCard,
      side: BorderSide(
        color: isSelected ? color : Colors.white.withValues(alpha: 0.08),
      ),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? CelestialTheme.textLight : CelestialTheme.textMuted,
      ),
      onSelected: (_) => setState(() => _statusFilter = status),
    );
  }

  Widget _buildStationTab(String title, String station, int count, Color color) {
    final isSelected = _stationFilter == station;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.25),
      backgroundColor: CelestialTheme.bgCard,
      side: BorderSide(
        color: isSelected ? color : color.withValues(alpha: 0.35),
        width: isSelected ? 1.4 : 1,
      ),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        color: isSelected ? color : CelestialTheme.textLight,
      ),
      onSelected: (selected) {
        setState(() {
          _stationFilter = selected ? station : 'all';
        });
      },
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
                    color: CelestialTheme.emeraldReady.withValues(alpha: 0.15),
                    blurRadius: 16,
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
}
