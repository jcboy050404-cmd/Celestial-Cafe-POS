import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import '../widgets/cart_panel.dart';
import '../widgets/customer_order_approval_dialog.dart';
import '../widgets/menu_item_card.dart';

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  void _openMobileCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.88,
        child: const CartPanel(isMobileModal: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    return Row(
      children: [
        // Left Menu Workstation
        Expanded(
          child: Container(
            color: CelestialTheme.bgDark,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pending Customer Orders Banner (if any self-orders awaiting approval)
                    if (posProvider.pendingCustomerOrders.isNotEmpty)
                      _buildPendingApprovalsBanner(context, posProvider),

                    // Search Bar & Filter Tags
                    _buildSearchAndFilters(context, posProvider),

                    // Category Tabs Bar
                    _buildCategoryTabs(posProvider),

                    // Menu Items Grid
                    Expanded(
                      child: _buildMenuGrid(posProvider, !isDesktop),
                    ),
                  ],
                ),

                // Floating Mobile Cart Banner (when not in desktop side-by-side mode and cart has items)
                if (!isDesktop && posProvider.cartItemCount > 0)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _buildMobileFloatingCartBar(context, posProvider),
                  ),
              ],
            ),
          ),
        ),

        // Right Order Cart Panel (Desktop / Tablet only)
        if (isDesktop) const CartPanel(),
      ],
    );
  }

  Widget _buildMobileFloatingCartBar(BuildContext context, PosProvider provider) {
    return GestureDetector(
      onTap: () => _openMobileCart(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: CelestialTheme.goldGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: CelestialTheme.bgDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_rounded, size: 16, color: CelestialTheme.goldLight),
                  const SizedBox(width: 6),
                  Text(
                    '${provider.cartItemCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: CelestialTheme.goldLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View Order & Checkout',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: CelestialTheme.bgDark,
                    ),
                  ),
                  Text(
                    '${provider.orderType.label} • ${provider.orderType == OrderType.dineIn ? provider.tableNumber : provider.customerName}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: CelestialTheme.bgDark.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '₱${provider.cartGrandTotal.toStringAsFixed(0)}',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: CelestialTheme.bgDark,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: CelestialTheme.bgDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context, PosProvider provider) {
    final tags = ['All', 'Signature', 'Hot/Iced', 'Classic', '16oz/22oz', 'Sweet', 'Savory', 'Specialty'];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: CelestialTheme.bgSurface,
      child: Column(
        children: [
          Row(
            children: [
              // Search Field
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: CelestialTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: TextField(
                    style: const TextStyle(fontSize: 13, color: CelestialTheme.textLight),
                    onChanged: (val) => provider.setSearchQuery(val),
                    decoration: InputDecoration(
                      hintText: 'Search coffees, milktea, bites...',
                      hintStyle: const TextStyle(fontSize: 12, color: CelestialTheme.textSubtle),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: CelestialTheme.goldPrimary),
                      suffixIcon: provider.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16, color: CelestialTheme.textMuted),
                              onPressed: () => provider.setSearchQuery(''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Catalog Item Counter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: CelestialTheme.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 14, color: CelestialTheme.goldLight),
                    const SizedBox(width: 4),
                    Text(
                      '${provider.filteredMenuItems.length}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.goldLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Tag Filters Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tags.map((tag) {
                final isSelected = provider.selectedTag == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(tag),
                    selected: isSelected,
                    selectedColor: CelestialTheme.goldPrimary.withValues(alpha: 0.25),
                    backgroundColor: CelestialTheme.bgCard,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    side: BorderSide(
                      color: isSelected
                          ? CelestialTheme.goldPrimary
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? CelestialTheme.goldLight : CelestialTheme.textMuted,
                    ),
                    onSelected: (_) => provider.setSelectedTag(tag),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(PosProvider provider) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: CelestialTheme.bgSurface,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ItemCategory.values.length,
        separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = ItemCategory.values[index];
          final isSelected = provider.selectedCategory == cat;

          return InkWell(
            onTap: () => provider.setCategory(cat),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: isSelected ? CelestialTheme.goldGradient : null,
                color: isSelected ? null : CelestialTheme.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? CelestialTheme.goldPrimary
                      : CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                  width: isSelected ? 1.2 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Text(cat.icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? CelestialTheme.bgDark
                          : CelestialTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuGrid(PosProvider provider, bool isMobile) {
    final items = provider.filteredMenuItems;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 12),
            Text(
              'No Celestial Items Found',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: CelestialTheme.textLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try changing your search query or category filter.',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: CelestialTheme.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        double childAspectRatio = 0.70;

        if (constraints.maxWidth > 1200) {
          crossAxisCount = 4;
          childAspectRatio = 1.35;
        } else if (constraints.maxWidth > 900) {
          crossAxisCount = 3;
          childAspectRatio = 1.30;
        } else if (constraints.maxWidth > 550) {
          crossAxisCount = 2;
          childAspectRatio = 1.22;
        } else {
          // Phones: 2 clean compact columns with tight, sleek proportions
          crossAxisCount = 2;
          childAspectRatio = 1.12;
        }

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            isMobile && provider.cartItemCount > 0 ? 80 : 16,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return MenuItemCard(item: items[index]);
          },
        );
      },
    );
  }

  Widget _buildPendingApprovalsBanner(BuildContext context, PosProvider provider) {
    final pending = provider.pendingCustomerOrders;
    final count = pending.length;
    final firstOrder = pending.first;
    final tablesText = pending.map((o) => o.tableNumber ?? 'Dine-In').toSet().take(3).join(', ');

    return InkWell(
      onTap: () {
        if (count == 1) {
          CustomerOrderApprovalDialog.show(context, firstOrder);
        } else {
          CustomerOrderApprovalDialog.showPendingList(context);
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2C1F0E), Color(0xFF1E150B)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: CelestialTheme.goldPrimary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: CelestialTheme.goldPrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.hourglass_top_rounded, color: CelestialTheme.bgDark, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '$count CUSTOMER ORDER${count > 1 ? "S" : ""} AWAITING APPROVAL',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                            color: CelestialTheme.goldLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          tablesText,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 1
                        ? 'Order ${firstOrder.orderNumber} (${firstOrder.customerName}) is ready for payment settlement.'
                        : 'Tap to review and approve incoming table self-orders.',
                    style: const TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: CelestialTheme.goldGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    count == 1 ? 'Review & Pay' : 'View All ($count)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: CelestialTheme.bgDark,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 12, color: CelestialTheme.bgDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
