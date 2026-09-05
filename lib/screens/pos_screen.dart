import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import '../widgets/cart_panel.dart';
import '../widgets/customer_order_approval_dialog.dart';
import '../widgets/customization_dialog.dart';
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
            color: Colors.black,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pending Customer Orders Banner (if any self-orders awaiting approval)
                    if (posProvider.pendingCustomerOrders.isNotEmpty)
                      _buildPendingApprovalsBanner(context, posProvider),

                    // STICKY Search Bar (Search field + Counter, slide tag buttons removed)
                    _buildStickySearchBar(context, posProvider),

                    // Scrollable Area (Signature Craft Banner + Categories + Menu Items Grid)
                    Expanded(
                      child: _buildScrollableMenuArea(context, posProvider, isDesktop),
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

  void _openSignatureLatte(BuildContext context, PosProvider provider) {
    final item = provider.menuItems.firstWhere(
      (i) => i.id == 'nesp_1' || i.name.toLowerCase().contains('celestial signature latte'),
      orElse: () => provider.menuItems.firstWhere(
        (i) => i.name.toLowerCase().contains('latte'),
        orElse: () => provider.menuItems.first,
      ),
    );

    // Make the Celestial Signature Latte item appear right in the menu catalog list below
    provider.setCategory(ItemCategory.all);
    provider.setSearchQuery(item.name);

    // Also open the customization dialog for it
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => CustomizationDialog(
        item: item,
        onAddToCart: (quantity, customizations, notes) {
          provider.addToCart(
            item,
            quantity: quantity,
            customizations: customizations,
            notes: notes,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: CelestialTheme.bgSurfaceLight,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(
                  color: CelestialTheme.borderSubtle,
                ),
              ),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: CelestialTheme.caramelAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Added ${item.name} to order',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  // Micro-Skeuomorphism (Hero Elements): Tactile realism with realistic product photography
  Widget _buildHeroBaristaSpotlight(BuildContext context, PosProvider provider, bool isDesktop) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: CelestialTheme.tactileHero(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openSignatureLatte(context, provider),
          child: Stack(
            children: [
              // Background realistic coffee photography with soft smooth vignette
              Positioned.fill(
                child: Row(
                  children: [
                    const Spacer(flex: 2),
                    Expanded(
                      flex: 3,
                      child: ShaderMask(
                        shaderCallback: (rect) {
                          return const LinearGradient(
                            colors: [Colors.transparent, Colors.black54, Colors.black],
                            stops: [0.0, 0.4, 1.0],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ).createShader(rect);
                        },
                        blendMode: BlendMode.dstIn,
                        child: Image.asset(
                          'assets/images/hero_coffee_splash.jpg',
                          fit: BoxFit.cover,
                          alignment: Alignment.centerRight,
                          errorBuilder: (context, error, stackTrace) => Container(color: CelestialTheme.bgCardHover),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content Layer
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 20 : 14,
                  vertical: isDesktop ? 14 : 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: CelestialTheme.caramelAccent.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: CelestialTheme.caramelAccent.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('✨', style: TextStyle(fontSize: 11)),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    isDesktop ? 'CELESTIAL SIGNATURE CRAFT' : 'SIGNATURE CRAFT',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: CelestialTheme.goldLight,
                                      letterSpacing: 0.6,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Celestial Signature Latte',
                            style: GoogleFonts.outfit(
                              fontSize: isDesktop ? 17 : 13.5,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.creamLight,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'House specialty handcrafted celestial latte blend with silky sweet foam',
                            style: GoogleFonts.outfit(
                              fontSize: isDesktop ? 11.5 : 10,
                              color: CelestialTheme.creamSoft,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Quick explore button
                    ElevatedButton.icon(
                      onPressed: () => _openSignatureLatte(context, provider),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                      label: Text(
                        isDesktop ? 'Order Signature Latte' : 'Order',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CelestialTheme.caramelAccent,
                        foregroundColor: CelestialTheme.bgDark,
                        elevation: 2,
                        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 14 : 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileFloatingCartBar(BuildContext context, PosProvider provider) {
    return GestureDetector(
      onTap: () => _openMobileCart(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: CelestialTheme.caramelGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
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
                mainAxisSize: MainAxisSize.min,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${provider.orderType.label} • ${provider.orderType == OrderType.dineIn ? provider.tableNumber : provider.customerName}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: CelestialTheme.bgDark.withValues(alpha: 0.75),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

  Widget _buildStickySearchBar(BuildContext context, PosProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // Search Field
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: CelestialTheme.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CelestialTheme.borderSubtle),
              ),
              child: TextField(
                style: const TextStyle(fontSize: 13, color: CelestialTheme.textLight),
                onChanged: (val) => provider.setSearchQuery(val),
                decoration: InputDecoration(
                  hintText: 'Search coffees, milktea, bites...',
                  hintStyle: const TextStyle(fontSize: 12, color: CelestialTheme.warmGray),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: CelestialTheme.caramelAccent),
                  suffixIcon: provider.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16, color: CelestialTheme.textMuted),
                          onPressed: () => provider.setSearchQuery(''),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
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
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CelestialTheme.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 14, color: CelestialTheme.caramelAccent),
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
    );
  }

  Widget _buildCategoryTabs(PosProvider provider) {
    final tabs = provider.allCategoryTabs;
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      color: Colors.black,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = provider.selectedCategoryId == tab.id ||
              (tab.id == 'all' && provider.selectedCategory == ItemCategory.all);

          return InkWell(
            onTap: () => provider.setCategoryById(tab.id),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: isSelected ? CelestialTheme.caramelGradient : null,
                color: isSelected ? null : CelestialTheme.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? CelestialTheme.caramelAccent
                      : CelestialTheme.borderSubtle,
                  width: isSelected ? 1.2 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tab.icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? CelestialTheme.bgDark
                          : CelestialTheme.textLight,
                    ),
                  ),
                  if (tab.isCustom) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? CelestialTheme.bgDark : CelestialTheme.goldLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScrollableMenuArea(BuildContext context, PosProvider provider, bool isDesktop) {
    final items = provider.filteredMenuItems;

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        double childAspectRatio = 0.70;

        if (constraints.maxWidth > 1600) {
          crossAxisCount = 6;
          childAspectRatio = 0.85;
        } else if (constraints.maxWidth > 1300) {
          crossAxisCount = 5;
          childAspectRatio = 0.85;
        } else if (constraints.maxWidth > 1050) {
          crossAxisCount = 4;
          childAspectRatio = 0.82;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 3;
          childAspectRatio = 0.80;
        } else if (constraints.maxWidth > 550) {
          crossAxisCount = 2;
          childAspectRatio = 0.78;
        } else {
          // Phones: 2 clean columns
          crossAxisCount = 2;
          childAspectRatio = 0.75;
        }

        return CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // 1. Signature Craft Banner (Hero Barista Spotlight)
            if (provider.searchQuery.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: _buildHeroBaristaSpotlight(context, provider, isDesktop),
                ),
              ),

            // 2. Category Tabs Bar
            SliverToBoxAdapter(
              child: _buildCategoryTabs(provider),
            ),

            // 3. Menu Items Grid or Empty State
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
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
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  !isDesktop && provider.cartItemCount > 0 ? 80 : 16,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: childAspectRatio,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return MenuItemCard(item: items[index]);
                    },
                    childCount: items.length,
                  ),
                ),
              ),
          ],
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
          provider.setNavIndex(1);
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CelestialTheme.caramelAccent.withValues(alpha: 0.45), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: CelestialTheme.caramelAccent,
                borderRadius: BorderRadius.circular(10),
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
                      Expanded(
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
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: CelestialTheme.caramelAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: CelestialTheme.caramelAccent.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            tablesText,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                mainAxisSize: MainAxisSize.min,
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
