import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../providers/pos_provider.dart';
import '../services/auth_service.dart';
import '../theme/celestial_theme.dart';
import '../widgets/category_management_dialog.dart';
import '../widgets/ingredients_editor_dialog.dart';
import '../widgets/item_editor_dialog.dart';
import '../widgets/item_thumbnail.dart';
import '../widgets/modifier_availability_dialog.dart';
import '../widgets/price_editor_dialog.dart';
import '../widgets/settings_dialog.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _searchQuery = '';
  String? _categoryFilterId;

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final auth = Provider.of<AuthService?>(context);
    final isOwner = auth?.isOwner ?? true;
    final isMobile = MediaQuery.of(context).size.width < 768;

    final items = posProvider.menuItems.where((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat = _categoryFilterId == null ||
          _categoryFilterId == 'all' ||
          (item.customCategory != null && item.customCategory!.isNotEmpty
              ? item.customCategory == _categoryFilterId || item.category.name == _categoryFilterId
              : item.category.name == _categoryFilterId);
      return matchesSearch && matchesCat;
    }).toList();

    return Scaffold(
      backgroundColor: CelestialTheme.bgDark,
      body: SafeArea(
        child: Material(
          color: CelestialTheme.bgDark,
          child: isMobile
              ? Column(
                  children: [
                    _buildHeader(context, posProvider, isMobile: true, isOwner: isOwner),
                    Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                    Expanded(child: _buildItemsList(context, posProvider, items, true, isOwner: isOwner)),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Category Sidebar for Windows / Desktop
                    if (posProvider.isCategoryPanelVisible)
                      _buildLeftCategorySidebar(context, posProvider, isOwner: isOwner),
                    // Main Content Area
                    Expanded(
                      child: Column(
                        children: [
                          _buildHeader(context, posProvider, isMobile: false, isOwner: isOwner),
                          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                          Expanded(child: _buildItemsList(context, posProvider, items, false, isOwner: isOwner)),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildLeftCategorySidebar(BuildContext context, PosProvider provider, {required bool isOwner}) {
    final tabs = provider.allCategoryTabs;
    final totalCategoriesCount = tabs.where((t) => t.id != 'all').length;

    return Container(
      width: 220,
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
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.category_rounded, size: 15, color: CelestialTheme.goldLight),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'CATEGORIES ($totalCategoriesCount)',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                            color: CelestialTheme.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isOwner) ...[
                      IconButton(
                        icon: Icon(Icons.tune_rounded, size: 16, color: CelestialTheme.textMuted),
                        tooltip: 'Manage Categories',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        splashRadius: 16,
                        onPressed: () {
                          CategoryManagementDialog.show(
                            context,
                            provider,
                            onUpdated: () => setState(() {
                              if (_categoryFilterId != null && _categoryFilterId != 'all') {
                                final exists = provider.allCategoryTabs.any((t) => t.id == _categoryFilterId);
                                if (!exists) _categoryFilterId = null;
                              }
                            }),
                          );
                        },
                      ),
                      const SizedBox(width: 2),
                    ],
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

          // Categories List
          Expanded(
            child: tabs.length <= 1
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.category_outlined, size: 28, color: CelestialTheme.textMuted),
                          const SizedBox(height: 8),
                          Text(
                            'No Categories',
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isOwner
                                ? 'Reset or add new categories to organize items.'
                                : 'No categories configured by store owner.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, color: CelestialTheme.textMuted),
                          ),
                          if (isOwner) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => CategoryManagementDialog.show(
                                context,
                                provider,
                                onUpdated: () => setState(() {}),
                              ),
                              icon: const Icon(Icons.add, size: 13),
                              label: const Text('Add Category', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: CelestialTheme.goldLight,
                                side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    itemCount: tabs.length,
                    separatorBuilder: (ctx, idx) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final tab = tabs[index];
                      final isSelected = (_categoryFilterId == null && tab.id == 'all') || (_categoryFilterId == tab.id);

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _categoryFilterId = tab.id == 'all' ? null : tab.id;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: isSelected ? CelestialTheme.caramelGradient : null,
                              color: isSelected ? null : Colors.white.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(10),
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

  Widget _buildItemsList(BuildContext context, PosProvider posProvider, List<MenuItem> items, bool isMobile, {required bool isOwner}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: CelestialTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              'No Menu Items Found',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your search or category filter.',
              style: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
            ),
            if (isOwner && posProvider.menuItems.isEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  await posProvider.resetCategoriesAndMenu();
                },
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('Restore Default Categories & Menu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CelestialTheme.goldPrimary,
                  foregroundColor: CelestialTheme.primaryBtnText,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, isMobile ? 12 : 16, isMobile ? 12 : 20, 80),
      itemCount: items.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final isLowStock = item.inStock && item.stockCount <= 15;

        return isMobile
            ? _buildMobileItemCard(context, posProvider, item, isLowStock, isOwner: isOwner)
            : _buildDesktopItemRow(context, posProvider, item, isLowStock, isOwner: isOwner);
      },
    );
  }

  /// Desktop / Windows streamlined single-row item layout
  Widget _buildDesktopItemRow(BuildContext context, PosProvider posProvider, MenuItem item, bool isLowStock, {required bool isOwner}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: !item.inStock
              ? CelestialTheme.roseAlert.withValues(alpha: 0.3)
              : isLowStock
                  ? CelestialTheme.amberBrewing.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          // 1. Thumbnail
          GestureDetector(
            onTap: isOwner ? () => ItemEditorDialog.show(context, posProvider, item) : null,
            child: ItemThumbnail(
              item: item,
              width: 48,
              height: 48,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // 2. Name, Category, Price & Description
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.textLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: CelestialTheme.brownWarm.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.categoryLabel,
                        style: TextStyle(fontSize: 9.5, color: CelestialTheme.goldLight),
                      ),
                    ),
                    if (isOwner && item.profitMarginPercent != null) ...[
                      const SizedBox(width: 6),
                      Builder(builder: (ctx) {
                        final m = item.profitMarginPercent!;
                        final Color mc = m >= 60
                            ? CelestialTheme.emeraldReady
                            : m >= 35
                                ? CelestialTheme.amberBrewing
                                : CelestialTheme.roseAlert;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: mc.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: mc.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '💰 ${m.toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 9.5, color: mc, fontWeight: FontWeight.bold),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    // Quick Price Change Chip
                    if (isOwner)
                      InkWell(
                        onTap: () => PriceEditorDialog.showQuickPrice(context, posProvider, item),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₱${item.price.toStringAsFixed(0)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.goldLight,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.edit, size: 10, color: CelestialTheme.goldPrimary),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '₱${item.price.toStringAsFixed(0)}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.goldLight,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.description,
                        style: TextStyle(fontSize: 11.5, color: CelestialTheme.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // 3. Stock Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: !item.inStock
                  ? CelestialTheme.roseAlert.withValues(alpha: 0.15)
                  : isLowStock
                      ? CelestialTheme.amberBrewing.withValues(alpha: 0.15)
                      : CelestialTheme.emeraldReady.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: !item.inStock
                    ? CelestialTheme.roseAlert.withValues(alpha: 0.5)
                    : isLowStock
                        ? CelestialTheme.amberBrewing.withValues(alpha: 0.5)
                        : CelestialTheme.emeraldReady.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              !item.inStock
                  ? 'SOLD OUT'
                  : isLowStock
                      ? 'LOW (${item.stockCount})'
                      : 'IN STOCK (${item.stockCount})',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: !item.inStock
                    ? CelestialTheme.roseAlert
                    : isLowStock
                        ? CelestialTheme.amberBrewing
                        : CelestialTheme.emeraldReady,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 4. Adjuster Controls: (-) Count (+) and (+20) (Owner only)
          if (isOwner)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: item.stockCount > 0
                      ? () => posProvider.updateStockCount(item.id, item.stockCount - 1)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  color: CelestialTheme.goldPrimary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  tooltip: '-1 Stock',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 28),
                    child: Text(
                      '${item.stockCount}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.textLight,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => posProvider.updateStockCount(item.id, item.stockCount + 1),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  color: CelestialTheme.goldPrimary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  tooltip: '+1 Stock',
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () => posProvider.updateStockCount(item.id, item.stockCount + 20),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CelestialTheme.goldLight,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('+20', style: TextStyle(fontSize: 11)),
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Qty: ${item.stockCount}',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CelestialTheme.textMuted,
                ),
              ),
            ),

          const SizedBox(width: 10),

          // 5. Modifiers Button
          if (item.customizationGroups.isNotEmpty) ...[
            Tooltip(
              message: 'Manage modifier availability (${item.customizationGroups.fold(0, (s, g) => s + g.options.length)} options)',
              child: OutlinedButton.icon(
                onPressed: isOwner
                    ? () => ModifierAvailabilityDialog.show(
                        context,
                        posProvider,
                        item,
                        onUpdated: () => setState(() {}),
                      )
                    : null,
                icon: Icon(
                  item.hasUnavailableOptions ? Icons.warning_amber_rounded : Icons.tune_rounded,
                  size: 13,
                  color: item.hasUnavailableOptions ? CelestialTheme.amberBrewing : CelestialTheme.goldLight,
                ),
                label: Text(
                  item.hasUnavailableOptions ? '${item.unavailableOptionsCount} Off' : 'Modifiers',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: item.hasUnavailableOptions ? CelestialTheme.amberBrewing : CelestialTheme.goldLight,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: item.hasUnavailableOptions ? CelestialTheme.amberBrewing : CelestialTheme.goldLight,
                  side: BorderSide(
                    color: item.hasUnavailableOptions
                        ? CelestialTheme.amberBrewing
                        : Colors.white.withValues(alpha: 0.15),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  minimumSize: Size.zero,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // 6. Ingredients Cost Button (Owner only)
          if (isOwner) ...[
            Tooltip(
              message: item.ingredients.isEmpty
                  ? 'Set ingredient costs to calculate profit margin'
                  : 'Ingredient cost: ₱${item.totalIngredientCost.toStringAsFixed(2)} · Margin: ${item.profitMarginPercent?.toStringAsFixed(1) ?? "—"}%',
              child: OutlinedButton.icon(
                onPressed: () => IngredientsEditorDialog.show(context, posProvider, item),
                icon: Icon(
                  Icons.calculate_outlined,
                  size: 13,
                  color: item.ingredients.isNotEmpty
                      ? CelestialTheme.emeraldReady
                      : CelestialTheme.goldLight,
                ),
                label: Text(
                  item.ingredients.isEmpty
                      ? 'Ingredients'
                      : '₱${item.totalIngredientCost.toStringAsFixed(0)} cost',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: item.ingredients.isNotEmpty
                      ? CelestialTheme.emeraldReady
                      : CelestialTheme.goldLight,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: item.ingredients.isNotEmpty
                      ? CelestialTheme.emeraldReady
                      : CelestialTheme.goldLight,
                  side: BorderSide(
                    color: item.ingredients.isNotEmpty
                        ? CelestialTheme.emeraldReady.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.15),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  minimumSize: Size.zero,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // 7. Toggle Switch
          Tooltip(
            message: item.inStock ? 'In Stock (Visible to POS)' : 'Sold Out',
            child: SizedBox(
              height: 24,
              width: 38,
              child: Switch(
                value: item.inStock,
                activeThumbColor: CelestialTheme.emeraldReady,
                onChanged: isOwner ? (_) => posProvider.toggleItemStock(item.id) : null,
              ),
            ),
          ),

          if (isOwner) ...[
            const SizedBox(width: 8),
            // 8. Edit and Delete Action Buttons
            IconButton(
              onPressed: () => ItemEditorDialog.show(context, posProvider, item),
              icon: Icon(Icons.edit_note_rounded, size: 20, color: CelestialTheme.goldLight),
              tooltip: 'Edit Item',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              onPressed: () => _confirmDeleteItem(context, posProvider, item),
              icon: Icon(Icons.delete_outline, size: 17, color: CelestialTheme.roseAlert),
              tooltip: 'Delete Item',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ],
      ),
    );
  }

  /// Confirmation dialog before deleting a menu item
  Future<void> _confirmDeleteItem(BuildContext context, PosProvider posProvider, MenuItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CelestialTheme.bgCard,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: CelestialTheme.roseAlert, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Delete Item?',
                style: GoogleFonts.outfit(
                  color: CelestialTheme.textLight,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
          style: TextStyle(color: CelestialTheme.textMuted, fontSize: 13),
        ),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      posProvider.deleteMenuItem(item.id);
    }
  }

  /// Clean & user-friendly mobile item card layout
  Widget _buildMobileItemCard(BuildContext context, PosProvider posProvider, MenuItem item, bool isLowStock, {required bool isOwner}) {
    final bool isOutOfStock = !item.inStock;
    final int optionsCount = item.customizationGroups.fold(0, (s, g) => s + g.options.length);

    return Container(
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOutOfStock
              ? CelestialTheme.roseAlert.withValues(alpha: 0.35)
              : isLowStock
                  ? CelestialTheme.amberBrewing.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Thumbnail + Title/Category/Price + Active Switch
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Thumbnail
                GestureDetector(
                  onTap: isOwner ? () => ItemEditorDialog.show(context, posProvider, item) : null,
                  child: Stack(
                    children: [
                      ItemThumbnail(
                        item: item,
                        width: 50,
                        height: 50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOutOfStock
                              ? CelestialTheme.roseAlert.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      if (isOutOfStock)
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Title, Category, Price & Margin
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name & Category Badge
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.name,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isOutOfStock
                                    ? CelestialTheme.textMuted
                                    : CelestialTheme.textLight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: CelestialTheme.brownWarm.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              item.categoryLabel,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: CelestialTheme.goldLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Price chip + Profit margin badge
                      Row(
                        children: [
                          if (isOwner)
                            InkWell(
                              onTap: () => PriceEditorDialog.showQuickPrice(context, posProvider, item),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '₱${item.price.toStringAsFixed(0)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: CelestialTheme.goldLight,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.edit, size: 10, color: CelestialTheme.goldPrimary),
                                  ],
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '₱${item.price.toStringAsFixed(0)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.goldLight,
                                ),
                              ),
                            ),
                          if (isOwner && item.profitMarginPercent != null) ...[
                            const SizedBox(width: 6),
                            Builder(builder: (ctx) {
                              final m = item.profitMarginPercent!;
                              final Color mc = m >= 60
                                  ? CelestialTheme.emeraldReady
                                  : m >= 35
                                      ? CelestialTheme.amberBrewing
                                      : CelestialTheme.roseAlert;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: mc.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: mc.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  '💰 ${m.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: mc,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Availability Switch (Right side of header)
                Tooltip(
                  message: item.inStock ? 'Visible on POS (Tap to mark Sold Out)' : 'Sold Out (Tap to enable)',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: 0.85,
                        child: Switch(
                          value: item.inStock,
                          activeThumbColor: CelestialTheme.emeraldReady,
                          activeTrackColor: CelestialTheme.emeraldReady.withValues(alpha: 0.35),
                          inactiveThumbColor: CelestialTheme.textMuted,
                          inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                          onChanged: isOwner ? (_) => posProvider.toggleItemStock(item.id) : null,
                        ),
                      ),
                      Text(
                        item.inStock ? 'ACTIVE' : 'OFF',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: item.inStock
                              ? CelestialTheme.emeraldReady
                              : CelestialTheme.roseAlert,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (item.description.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  item.description,
                  style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            const SizedBox(height: 10),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            const SizedBox(height: 10),

            // Row 2: Stock Status Badge (Left) + Quantity Stepper (Right)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                // Stock Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isOutOfStock
                        ? CelestialTheme.roseAlert.withValues(alpha: 0.15)
                        : isLowStock
                            ? CelestialTheme.amberBrewing.withValues(alpha: 0.15)
                            : CelestialTheme.emeraldReady.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isOutOfStock
                          ? CelestialTheme.roseAlert.withValues(alpha: 0.5)
                          : isLowStock
                              ? CelestialTheme.amberBrewing.withValues(alpha: 0.5)
                              : CelestialTheme.emeraldReady.withValues(alpha: 0.5),
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
                          color: isOutOfStock
                              ? CelestialTheme.roseAlert
                              : isLowStock
                                  ? CelestialTheme.amberBrewing
                                  : CelestialTheme.emeraldReady,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOutOfStock
                            ? 'SOLD OUT'
                            : isLowStock
                                ? 'LOW STOCK'
                                : 'IN STOCK',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isOutOfStock
                              ? CelestialTheme.roseAlert
                              : isLowStock
                                  ? CelestialTheme.amberBrewing
                                  : CelestialTheme.emeraldReady,
                        ),
                      ),
                    ],
                  ),
                ),

                // Stepper (Owner) or Static Stock Indicator (Cashier)
                if (isOwner)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Minus Button
                      Material(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: item.stockCount > 0
                              ? () => posProvider.updateStockCount(item.id, item.stockCount - 1)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Icon(
                              Icons.remove_rounded,
                              size: 16,
                              color: item.stockCount > 0 ? CelestialTheme.goldLight : CelestialTheme.textMuted.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),

                      // Count
                      Container(
                        constraints: const BoxConstraints(minWidth: 32),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        child: Text(
                          '${item.stockCount}',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.textLight,
                          ),
                        ),
                      ),

                      // Plus Button
                      Material(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () => posProvider.updateStockCount(item.id, item.stockCount + 1),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: CelestialTheme.goldLight,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      // Quick +20 Button
                      Material(
                        color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () => posProvider.updateStockCount(item.id, item.stockCount + 20),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 9),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '+20',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: CelestialTheme.goldLight,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Qty: ${item.stockCount}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CelestialTheme.textMuted,
                      ),
                    ),
                  ),
              ],
            ),

            if (item.customizationGroups.isNotEmpty || isOwner) ...[
              const SizedBox(height: 10),

              // Row 3: Action Chips (Modifiers, Ingredients, Edit, Delete)
              Row(
                children: [
                  // Scrollable chips on the left for Modifiers & Ingredients
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Modifiers Button
                          if (item.customizationGroups.isNotEmpty) ...[
                            InkWell(
                              onTap: isOwner
                                  ? () => ModifierAvailabilityDialog.show(
                                      context,
                                      posProvider,
                                      item,
                                      onUpdated: () => setState(() {}),
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: item.hasUnavailableOptions
                                      ? CelestialTheme.amberBrewing.withValues(alpha: 0.15)
                                      : Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: item.hasUnavailableOptions
                                        ? CelestialTheme.amberBrewing.withValues(alpha: 0.6)
                                        : Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      item.hasUnavailableOptions ? Icons.warning_amber_rounded : Icons.tune_rounded,
                                      size: 12,
                                      color: item.hasUnavailableOptions ? CelestialTheme.amberBrewing : CelestialTheme.goldLight,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.hasUnavailableOptions ? '${item.unavailableOptionsCount} Off' : 'Modifiers ($optionsCount)',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: item.hasUnavailableOptions ? CelestialTheme.amberBrewing : CelestialTheme.goldLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],

                          // Ingredients Cost Button (Owner only)
                          if (isOwner) ...[
                            InkWell(
                              onTap: () => IngredientsEditorDialog.show(context, posProvider, item),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: item.ingredients.isNotEmpty
                                      ? CelestialTheme.emeraldReady.withValues(alpha: 0.12)
                                      : Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: item.ingredients.isNotEmpty
                                        ? CelestialTheme.emeraldReady.withValues(alpha: 0.5)
                                        : Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calculate_outlined,
                                      size: 12,
                                      color: item.ingredients.isNotEmpty
                                          ? CelestialTheme.emeraldReady
                                          : CelestialTheme.goldLight,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.ingredients.isEmpty
                                          ? 'Ingredients'
                                          : '₱${item.totalIngredientCost.toStringAsFixed(0)} cost',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: item.ingredients.isNotEmpty
                                            ? CelestialTheme.emeraldReady
                                            : CelestialTheme.goldLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  if (isOwner) ...[
                    const SizedBox(width: 8),

                    // Edit Button
                    InkWell(
                      onTap: () => ItemEditorDialog.show(context, posProvider, item),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_note_rounded, size: 14, color: CelestialTheme.goldLight),
                            const SizedBox(width: 3),
                            Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: CelestialTheme.goldLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Delete Button with safe confirmation
                    InkWell(
                      onTap: () => _confirmDeleteItem(context, posProvider, item),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: CelestialTheme.roseAlert.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: CelestialTheme.roseAlert.withValues(alpha: 0.3)),
                        ),
                        child: Icon(Icons.delete_outline_rounded, size: 15, color: CelestialTheme.roseAlert),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PosProvider provider, {required bool isMobile, required bool isOwner}) {
    final activeCategoriesCount = provider.allCategoryTabs.where((t) => t.id != 'all').length;
    final actionButtons = <Widget>[
      if (isOwner) ...[
        OutlinedButton.icon(
          onPressed: () => CategoryManagementDialog.show(
            context,
            provider,
            onUpdated: () => setState(() {
              // Reset local category filter if selected category was deleted (e.g. after reset)
              if (_categoryFilterId != null && _categoryFilterId != 'all') {
                final stillExists = provider.allCategoryTabs.any((t) => t.id == _categoryFilterId);
                if (!stillExists) _categoryFilterId = null;
              }
            }),
          ),
          icon: const Icon(Icons.category_outlined, size: 15),
          label: Text(
            isMobile ? 'Categories' : 'Categories ($activeCategoriesCount)',
            style: const TextStyle(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: CelestialTheme.goldLight,
            side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5)),
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 8 : 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => const SettingsDialog(initialTab: 1),
          ),
          icon: const Icon(Icons.do_not_disturb_on_outlined, size: 15),
          label: Text(
            isMobile
                ? 'Availability'
                : 'Availability (${provider.totalUnavailableItemsCount + provider.totalUnavailableOptionsCount})',
            style: const TextStyle(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: (provider.totalUnavailableItemsCount + provider.totalUnavailableOptionsCount > 0)
                ? CelestialTheme.roseAlert
                : CelestialTheme.goldLight,
            side: BorderSide(
              color: (provider.totalUnavailableItemsCount + provider.totalUnavailableOptionsCount > 0)
                  ? CelestialTheme.roseAlert.withValues(alpha: 0.6)
                  : CelestialTheme.goldPrimary.withValues(alpha: 0.5),
            ),
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 8 : 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => const SettingsDialog(),
          ),
          icon: const Icon(Icons.settings_outlined, size: 15),
          label: Text(isMobile ? 'Settings' : 'Logo & Store', style: const TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: CelestialTheme.goldLight,
            side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5)),
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 8 : 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          onPressed: () => PriceEditorDialog.showPriceSettingsManager(context, provider),
          icon: const Icon(Icons.price_change_outlined, size: 15),
          label: Text(isMobile ? 'Prices' : 'Price Settings', style: const TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: CelestialTheme.goldLight,
            side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5)),
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 8 : 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 6),
        ElevatedButton.icon(
          onPressed: () => ItemEditorDialog.show(context, provider),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text(isMobile ? 'Add' : 'Add Item', style: const TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: CelestialTheme.goldPrimary,
            foregroundColor: CelestialTheme.primaryBtnText,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: isMobile ? 8 : 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ] else ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 13, color: CelestialTheme.goldLight),
              const SizedBox(width: 5),
              Text(
                'Cashier View (Read Only)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: CelestialTheme.goldLight,
                ),
              ),
            ],
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
                if (Navigator.canPop(context)) ...[
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded, color: CelestialTheme.textLight, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Back to Station',
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.inventory_2_rounded, color: CelestialTheme.goldPrimary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Menu & Price Control',
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
              child: Row(children: actionButtons),
            ),
          ] else ...[
            Row(
              children: [
                if (Navigator.canPop(context)) ...[
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded, color: CelestialTheme.textLight),
                    tooltip: 'Back to Station',
                  ),
                  const SizedBox(width: 6),
                ],
                Icon(Icons.inventory_2_rounded, color: CelestialTheme.goldPrimary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Menu & Price Control',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: CelestialTheme.textLight,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actionButtons,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          // Search Box with Category Panel Toggle Button on Desktop
          Row(
            children: [
              if (!isMobile) ...[
                Tooltip(
                  message: provider.isCategoryPanelVisible
                      ? 'Hide Category Panel'
                      : 'Show Category Panel',
                  child: InkWell(
                    onTap: () => provider.toggleCategoryPanel(),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: provider.isCategoryPanelVisible
                            ? CelestialTheme.bgCard
                            : CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: provider.isCategoryPanelVisible
                              ? Colors.white.withValues(alpha: 0.08)
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
                            size: 16,
                            color: provider.isCategoryPanelVisible
                                ? CelestialTheme.textMuted
                                : CelestialTheme.goldLight,
                          ),
                          if (!provider.isCategoryPanelVisible) ...[
                            const SizedBox(width: 6),
                            Text(
                              'Categories',
                              style: TextStyle(
                                fontSize: 11,
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
              Expanded(
                child: Container(
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
                      hintText: 'Filter items to update price or stock...',
                      hintStyle: TextStyle(fontSize: 12, color: CelestialTheme.textSubtle),
                      prefixIcon: Icon(Icons.search_rounded, size: 16, color: CelestialTheme.goldPrimary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Category Filter Chips (Shown on mobile or when category sidebar is hidden)
          if (isMobile || !provider.isCategoryPanelVisible) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: provider.allCategoryTabs.map((cat) {
                  final isSelected = (_categoryFilterId == null && cat.id == 'all') || (_categoryFilterId == cat.id);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cat.icon, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(cat.label, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (cat.id == 'all' || !selected) {
                            _categoryFilterId = null;
                          } else {
                            _categoryFilterId = cat.id;
                          }
                        });
                      },
                      selectedColor: CelestialTheme.goldPrimary.withValues(alpha: 0.25),
                      backgroundColor: CelestialTheme.bgCard,
                      side: BorderSide(
                        color: isSelected
                            ? CelestialTheme.goldPrimary
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? CelestialTheme.goldLight : CelestialTheme.textMuted,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}