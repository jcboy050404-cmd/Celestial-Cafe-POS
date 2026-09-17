import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';
import 'inventory_screen.dart';
import '../theme/celestial_theme.dart';
import '../widgets/cart_panel.dart';
import '../widgets/category_management_dialog.dart';
import '../widgets/customization_dialog.dart';
import '../widgets/menu_item_card.dart';
import '../widgets/signature_banner_dialog.dart';

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1000;
    final bool isWindows = (!kIsWeb && Platform.isWindows) || defaultTargetPlatform == TargetPlatform.windows;
    final bool useLeftCategorySidebar = (isWindows && screenWidth >= 700) || screenWidth >= 1150;
    final bool showSidebar = useLeftCategorySidebar && posProvider.isCategoryPanelVisible;

    return Row(
      children: [
        // 1. Left Category Sidebar (Windows & wide desktop workstation)
        if (showSidebar)
          _buildLeftCategorySidebar(context, posProvider),

        // 2. Center Menu Workstation
        Expanded(
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // STICKY Search Bar (Search field + Counter + Category Sidebar Toggle)
                    _buildStickySearchBar(
                      context,
                      posProvider,
                      useLeftCategorySidebar: useLeftCategorySidebar,
                    ),

                    // Scrollable Area (Signature Craft Banner + Categories (if mobile or sidebar hidden) + Menu Items Grid)
                    Expanded(
                      child: _buildScrollableMenuArea(
                        context,
                        posProvider,
                        isDesktop,
                        showTopCategoryTabs: !showSidebar,
                      ),
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
    if (provider.menuItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: CelestialTheme.bgCard,
          content: Text(
            'No menu items created yet. Add items in Menu & Stock.',
            style: TextStyle(color: CelestialTheme.goldLight),
          ),
        ),
      );
      return;
    }

    final targetId = provider.signatureBannerItemId;
    final item = provider.menuItems.firstWhere(
      (i) => i.id == targetId,
      orElse: () => provider.menuItems.firstWhere(
        (i) => i.id == 'nesp_1' || i.name.toLowerCase().contains('celestial signature latte'),
        orElse: () => provider.menuItems.firstWhere(
          (i) => i.name.toLowerCase().contains('latte'),
          orElse: () => provider.menuItems.first,
        ),
      ),
    );

    // Make the signature item appear right in the menu catalog list below
    provider.setCategory(ItemCategory.all);
    provider.setSearchQuery(item.name);

    // Also open the customization dialog for it
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
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
                side: BorderSide(
                  color: CelestialTheme.borderSubtle,
                ),
              ),
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: CelestialTheme.caramelAccent, size: 20),
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
    if (!provider.signatureBannerEnabled) {
      return const SizedBox.shrink();
    }

    final badgeText = provider.signatureBannerBadge.isNotEmpty
        ? provider.signatureBannerBadge
        : (isDesktop ? 'CELESTIAL SIGNATURE CRAFT' : 'SIGNATURE CRAFT');
    final titleText = provider.signatureBannerTitle.isNotEmpty
        ? provider.signatureBannerTitle
        : 'Celestial Signature Latte';
    final subtitleText = provider.signatureBannerSubtitle.isNotEmpty
        ? provider.signatureBannerSubtitle
        : 'House specialty handcrafted celestial latte blend with silky sweet foam';
    final buttonText = provider.signatureBannerButtonText.isNotEmpty
        ? provider.signatureBannerButtonText
        : (isDesktop ? 'Order Signature' : 'Order');

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
                        child: provider.hasCustomSignatureBannerImage
                            ? Image.memory(
                                provider.signatureBannerImageBytes!,
                                fit: BoxFit.cover,
                                alignment: Alignment.centerRight,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(color: CelestialTheme.bgCardHover),
                              )
                            : Image.asset(
                                'assets/images/hero_coffee_splash.jpg',
                                fit: BoxFit.cover,
                                alignment: Alignment.centerRight,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(color: CelestialTheme.bgCardHover),
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
                                    badgeText,
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
                            titleText,
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
                            subtitleText,
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
                    // Quick customize button
                    IconButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierColor: Colors.black.withValues(alpha: 0.85),
                          builder: (ctx) => const SignatureBannerDialog(),
                        );
                      },
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      tooltip: 'Customize Signature Banner',
                      color: CelestialTheme.goldLight.withValues(alpha: 0.85),
                      style: IconButton.styleFrom(
                        backgroundColor: CelestialTheme.bgSurface.withValues(alpha: 0.75),
                        padding: const EdgeInsets.all(7),
                        minimumSize: const Size(34, 34),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: CelestialTheme.caramelAccent.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Quick explore / order button
                    ElevatedButton.icon(
                      onPressed: () => _openSignatureLatte(context, provider),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                      label: Text(
                        buttonText,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CelestialTheme.caramelAccent,
                        foregroundColor: CelestialTheme.primaryBtnText,
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
                  Icon(Icons.shopping_bag_rounded, size: 16, color: CelestialTheme.goldLight),
                  const SizedBox(width: 6),
                  Text(
                    '${provider.cartItemCount}',
                    style: TextStyle(
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
                      color: CelestialTheme.primaryBtnText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${provider.orderType.label} • ${provider.orderType == OrderType.dineIn ? provider.tableNumber : provider.customerName}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: CelestialTheme.primaryBtnText.withValues(alpha: 0.85),
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
                color: CelestialTheme.primaryBtnText,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: CelestialTheme.primaryBtnText),
          ],
        ),
      ),
    );
  }

  Widget _buildStickySearchBar(
    BuildContext context,
    PosProvider provider, {
    bool useLeftCategorySidebar = false,
  }) {
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
          // Sidebar Toggle Button on Desktop / Windows
          if (useLeftCategorySidebar) ...[
            Tooltip(
              message: provider.isCategoryPanelVisible
                  ? 'Hide Category Panel'
                  : 'Show Category Panel',
              child: InkWell(
                onTap: () => provider.toggleCategoryPanel(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: provider.isCategoryPanelVisible
                        ? CelestialTheme.bgCard
                        : CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: provider.isCategoryPanelVisible
                          ? CelestialTheme.borderSubtle
                          : CelestialTheme.goldPrimary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        provider.isCategoryPanelVisible
                            ? Icons.view_sidebar_outlined
                            : Icons.view_sidebar_rounded,
                        size: 18,
                        color: provider.isCategoryPanelVisible
                            ? CelestialTheme.textMuted
                            : CelestialTheme.goldLight,
                      ),
                      if (!provider.isCategoryPanelVisible) ...[
                        const SizedBox(width: 6),
                        Text(
                          'Categories',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.goldLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],

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
                style: TextStyle(fontSize: 13, color: CelestialTheme.textLight),
                onChanged: (val) => provider.setSearchQuery(val),
                decoration: InputDecoration(
                  hintText: 'Search coffees, milktea, bites...',
                  hintStyle: TextStyle(fontSize: 12, color: CelestialTheme.warmGray),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: CelestialTheme.caramelAccent),
                  suffixIcon: provider.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, size: 16, color: CelestialTheme.textMuted),
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
                Icon(Icons.auto_awesome_rounded, size: 14, color: CelestialTheme.caramelAccent),
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

  Widget _buildLeftCategorySidebar(BuildContext context, PosProvider provider) {
    final tabs = provider.allCategoryTabs;

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF0C0A09),
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.category_rounded, size: 15, color: CelestialTheme.goldLight),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'CATEGORIES',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                            color: CelestialTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.tune_rounded, size: 16, color: CelestialTheme.textMuted),
                      tooltip: 'Manage Categories',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      splashRadius: 16,
                      onPressed: () {
                        CategoryManagementDialog.show(context, provider);
                      },
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      icon: Icon(Icons.first_page_rounded, size: 18, color: CelestialTheme.goldLight),
                      tooltip: 'Hide Category Panel',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      splashRadius: 16,
                      onPressed: () {
                        provider.toggleCategoryPanel();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),

          // Vertical Category List
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              itemCount: tabs.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final isSelected = provider.selectedCategoryId == tab.id ||
                    (tab.id == 'all' && provider.selectedCategory == ItemCategory.all);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => provider.setCategoryById(tab.id),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected ? CelestialTheme.caramelGradient : null,
                        color: isSelected ? null : (Colors.white.withValues(alpha: 0.02)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? CelestialTheme.caramelAccent.withValues(alpha: 0.6)
                              : Colors.transparent,
                          width: 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (tab.icon.trim().isNotEmpty) ...[
                            Text(tab.icon, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              tab.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected
                                    ? CelestialTheme.primaryBtnText
                                    : CelestialTheme.textLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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

          return Material(
            color: Colors.transparent,
            child: InkWell(
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
                    if (tab.icon.trim().isNotEmpty) ...[
                      Text(tab.icon, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                    ],
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildScrollableMenuArea(
    BuildContext context,
    PosProvider provider,
    bool isDesktop, {
    bool showTopCategoryTabs = true,
  }) {
    final items = provider.filteredMenuItems;

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        double childAspectRatio = 0.70;

        if (constraints.maxWidth > 1750) {
          crossAxisCount = 6;
          childAspectRatio = 0.84;
        } else if (constraints.maxWidth >= 820) {
          // 5 columns of items for desktop and workstations
          crossAxisCount = 5;
          childAspectRatio = 0.80;
        } else if (constraints.maxWidth >= 640) {
          crossAxisCount = 4;
          childAspectRatio = 0.78;
        } else if (constraints.maxWidth >= 480) {
          crossAxisCount = 3;
          childAspectRatio = 0.76;
        } else {
          // Phones / compact screens: 2 clean columns
          crossAxisCount = 2;
          childAspectRatio = 0.74;
        }

        return CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // 1. Signature Craft Banner (Hero Barista Spotlight)
            if (provider.searchQuery.isEmpty && provider.signatureBannerEnabled && provider.menuItems.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: _buildHeroBaristaSpotlight(context, provider, isDesktop),
                ),
              ),

            // 2. Category Tabs Bar (Only when left sidebar is not active)
            if (showTopCategoryTabs)
              SliverToBoxAdapter(
                child: _buildCategoryTabs(provider),
              ),

            // 3. Menu Items Grid or Empty State
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                          ),
                          child: Icon(
                            provider.menuItems.isEmpty ? Icons.restaurant_menu_rounded : Icons.search_off_rounded,
                            size: 32,
                            color: CelestialTheme.goldLight,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          provider.menuItems.isEmpty ? 'No Menu Items Yet' : 'No Items Found',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.textLight,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          provider.menuItems.isEmpty
                              ? 'Your catalog is fresh and empty. Add your dishes and drinks to get started!'
                              : 'Try changing your search query or category filter.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: CelestialTheme.textMuted,
                          ),
                        ),
                        if (provider.menuItems.isEmpty) ...[
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const InventoryScreen()),
                                  );
                                },
                                icon: const Icon(Icons.add_circle_outline, size: 16),
                                label: const Text('Add Items in Menu & Stock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: CelestialTheme.goldPrimary,
                                  foregroundColor: CelestialTheme.primaryBtnText,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await provider.loadSampleMenu();
                                },
                                icon: const Icon(Icons.download_rounded, size: 16),
                                label: const Text('Load Sample Cafe Menu', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: CelestialTheme.goldLight,
                                  side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
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
}