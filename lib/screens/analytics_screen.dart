import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Container(
      color: CelestialTheme.bgDark,
      child: Column(
        children: [
          // Header
          _buildHeader(isMobile),

          const Divider(height: 1),

          // Main Analytics Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Metric Cards Grid / Row
                  _buildKpiSection(posProvider, isMobile),

                  const SizedBox(height: 20),

                  // Charts & Leaderboard Row or Stack
                  if (isMobile) ...[
                    _buildTopSellersCard(posProvider),
                    const SizedBox(height: 16),
                    _buildCategoryBreakdownCard(posProvider),
                    const SizedBox(height: 16),
                    _buildPaymentMethodsCard(posProvider),
                    const SizedBox(height: 16),
                    _buildShiftSummaryCard(context, posProvider),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildTopSellersCard(posProvider)),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: _buildCategoryBreakdownCard(posProvider)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildPaymentMethodsCard(posProvider)),
                        const SizedBox(width: 20),
                        Expanded(flex: 3, child: _buildShiftSummaryCard(context, posProvider)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      color: CelestialTheme.bgSurface,
      child: Row(
        children: [
          const Icon(Icons.insights_rounded, color: CelestialTheme.goldPrimary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Business & Shift Analytics',
                  style: GoogleFonts.outfit(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: CelestialTheme.textLight,
                  ),
                ),
                Text(
                  'Real-time revenue (₱), best sellers & shift reports',
                  style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSection(PosProvider provider, bool isMobile) {
    final cards = [
      _buildKpiCard(
        title: "TODAY'S REVENUE",
        value: '₱${provider.todayTotalSales.toStringAsFixed(0)}',
        subtitle: '${provider.todayOrdersCount} orders placed',
        icon: Icons.payments_rounded,
        iconColor: CelestialTheme.goldPrimary,
        glow: true,
      ),
      _buildKpiCard(
        title: 'TOTAL ORDERS',
        value: '${provider.todayOrdersCount}',
        subtitle: '${provider.activeKdsOrders.length} active in queue',
        icon: Icons.shopping_bag_rounded,
        iconColor: CelestialTheme.amberBrewing,
      ),
      _buildKpiCard(
        title: 'AVG ORDER VALUE',
        value: '₱${provider.averageOrderValue.toStringAsFixed(0)}',
        subtitle: 'Live ticket average',
        icon: Icons.trending_up_rounded,
        iconColor: CelestialTheme.emeraldReady,
      ),
      _buildKpiCard(
        title: 'TERMINAL STATUS',
        value: 'POS Ready',
        subtitle: 'Offline Hotspot Ready',
        icon: Icons.wifi_tethering_rounded,
        iconColor: CelestialTheme.blueInfo,
      ),
    ];

    if (isMobile) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
        children: cards,
      );
    }

    return Row(
      children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    bool glow = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: CelestialTheme.glassCard(
        color: CelestialTheme.bgCard,
        glow: glow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: CelestialTheme.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: CelestialTheme.textLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 10,
              color: CelestialTheme.goldLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTopSellersCard(PosProvider provider) {
    final topItems = provider.topSellingItems;
    final medals = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CelestialTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top 5 Best-Selling Items',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: CelestialTheme.textLight,
                ),
              ),
              const Icon(Icons.star_rounded, color: CelestialTheme.goldPrimary, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          if (topItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 12.0),
              child: Center(
                child: Column(
                  children: [
                    const Text('🌱', style: TextStyle(fontSize: 26)),
                    const SizedBox(height: 8),
                    Text(
                      'Grand Opening — No Sales Recorded Yet',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.textLight,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Best-selling drinks & bites will rank here live as you punch customer orders.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: CelestialTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...topItems.entries.toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final itemName = entry.value.key;
              final qty = entry.value.value;
              final maxQty = topItems.values.first;
              final percent = maxQty > 0 ? (qty / maxQty) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(medals[idx], style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            itemName,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: CelestialTheme.textLight,
                            ),
                          ),
                        ),
                        Text(
                          '$qty sold',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.goldLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 5,
                        backgroundColor: CelestialTheme.bgSurface,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          idx == 0
                              ? CelestialTheme.goldPrimary
                              : idx == 1
                                  ? CelestialTheme.amberWarm
                                  : CelestialTheme.brownWarm,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdownCard(PosProvider provider) {
    final catSales = provider.salesByCategory;
    final total = catSales.values.fold(0.0, (sum, val) => sum + val);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CelestialTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sales by Category',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: CelestialTheme.textLight,
            ),
          ),
          const SizedBox(height: 12),
          if (catSales.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('No category data recorded yet.')),
            )
          else
            ...catSales.entries.map((entry) {
              final cat = entry.key;
              final amount = entry.value;
              final percent = total > 0 ? (amount / total) * 100 : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat,
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: CelestialTheme.textLight),
                          ),
                          Text(
                            '${percent.toStringAsFixed(1)}% of total revenue',
                            style: const TextStyle(fontSize: 10, color: CelestialTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₱${amount.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.goldLight,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsCard(PosProvider provider) {
    final paySales = provider.salesByPaymentMethod;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CelestialTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Methods Split',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: CelestialTheme.textLight,
            ),
          ),
          const SizedBox(height: 12),
          ...PaymentMethod.values.map((method) {
            final amount = paySales[method] ?? 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Text(method.icon, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      method.label,
                      style: GoogleFonts.outfit(fontSize: 12, color: CelestialTheme.textLight),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '₱${amount.toStringAsFixed(0)}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: CelestialTheme.goldLight,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildShiftSummaryCard(BuildContext context, PosProvider provider) {
    final cashTotal = provider.salesByPaymentMethod[PaymentMethod.cash] ?? 0.0;
    const openingFloat = 2000.00;
    final expectedCashInDrawer = openingFloat + cashTotal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: CelestialTheme.goldCardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shift Cash Drawer & Audit',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: CelestialTheme.goldLight,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CelestialTheme.emeraldReady.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SHIFT ACTIVE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: CelestialTheme.emeraldReady,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildDrawerRow('Opening Float', '₱${openingFloat.toStringAsFixed(0)}'),
          _buildDrawerRow('Cash Sales Collected', '₱${cashTotal.toStringAsFixed(0)}'),
          _buildDrawerRow('GCash / Maya Sales', '₱${(provider.todayTotalSales - cashTotal).toStringAsFixed(0)}'),
          const Divider(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Expected Cash in Drawer',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
              ),
              Text(
                '₱${expectedCashInDrawer.toStringAsFixed(0)}',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: CelestialTheme.goldLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: CelestialTheme.bgCard,
                    content: Text('✨ Shift audit report exported. Revenue today: ₱${provider.todayTotalSales.toStringAsFixed(0)}'),
                  ),
                );
              },
              icon: const Icon(Icons.lock_clock_rounded, size: 15),
              label: const Text('Export Shift Close Report', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: CelestialTheme.goldPrimary,
                foregroundColor: CelestialTheme.bgDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: CelestialTheme.textMuted)),
          Text(val, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CelestialTheme.textLight)),
        ],
      ),
    );
  }
}
