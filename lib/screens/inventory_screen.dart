import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import '../widgets/category_management_dialog.dart';
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

    return Container(
      color: CelestialTheme.bgDark,
      child: Column(
        children: [
          // Header & Toolbar
          _buildHeader(context, posProvider, isMobile),

          const Divider(height: 1),

          // Inventory Table / List
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 48, color: CelestialTheme.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No Menu Items Found',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Try adjusting your search or category filter.',
                          style: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.all(isMobile ? 12 : 20),
                    itemCount: items.length,
                    separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isLowStock = item.inStock && item.stockCount <= 15;

                      return Container(
                        padding: EdgeInsets.all(isMobile ? 12 : 16),
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
                        child: Column(
                          children: [
                            // Top Row: Icon, Name, Category & Edit/Delete
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => ItemEditorDialog.show(context, posProvider, item),
                                  child: ItemThumbnail(
                                    item: item,
                                    width: isMobile ? 44 : 52,
                                    height: isMobile ? 44 : 52,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              item.name,
                                              style: GoogleFonts.outfit(
                                                fontSize: isMobile ? 14 : 15,
                                                fontWeight: FontWeight.bold,
                                                color: CelestialTheme.textLight,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: CelestialTheme.brownWarm.withValues(alpha: 0.3),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item.categoryLabel,
                                              style: const TextStyle(fontSize: 9, color: CelestialTheme.goldLight),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          // Quick Price Change Chip
                                          InkWell(
                                            onTap: () => PriceEditorDialog.showQuickPrice(context, posProvider, item),
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: CelestialTheme.goldPrimary.withValues(alpha: 0.18),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
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
                                                  const Icon(Icons.edit, size: 10, color: CelestialTheme.goldPrimary),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item.description,
                                              style: const TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => ItemEditorDialog.show(context, posProvider, item),
                                  icon: const Icon(Icons.edit_note_rounded, size: 20, color: CelestialTheme.goldLight),
                                  tooltip: 'Edit Full Details',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                ),
                                IconButton(
                                  onPressed: () => posProvider.deleteMenuItem(item.id),
                                  icon: const Icon(Icons.delete_outline, size: 16, color: CelestialTheme.roseAlert),
                                  tooltip: 'Delete Item',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Bottom Row: Stock Badge, Controls (- / + / +20), and Toggle Switch
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                // Status Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: !item.inStock
                                        ? CelestialTheme.roseAlert.withValues(alpha: 0.15)
                                        : isLowStock
                                            ? CelestialTheme.amberBrewing.withValues(alpha: 0.15)
                                            : CelestialTheme.emeraldReady.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: !item.inStock
                                          ? CelestialTheme.roseAlert
                                          : isLowStock
                                              ? CelestialTheme.amberBrewing
                                              : CelestialTheme.emeraldReady,
                                    ),
                                  ),
                                  child: Text(
                                    !item.inStock
                                        ? 'OUT OF STOCK'
                                        : isLowStock
                                            ? 'LOW (${item.stockCount})'
                                            : 'IN STOCK (${item.stockCount})',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: !item.inStock
                                          ? CelestialTheme.roseAlert
                                          : isLowStock
                                              ? CelestialTheme.amberBrewing
                                              : CelestialTheme.emeraldReady,
                                    ),
                                  ),
                                ),

                                // Adjuster Controls
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
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        '${item.stockCount}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: CelestialTheme.textLight,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => posProvider.updateStockCount(item.id, item.stockCount + 1),
                                      icon: const Icon(Icons.add_circle_outline, size: 18),
                                      color: CelestialTheme.goldPrimary,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    ),
                                    const SizedBox(width: 6),
                                    OutlinedButton(
                                      onPressed: () => posProvider.updateStockCount(item.id, item.stockCount + 20),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: CelestialTheme.goldLight,
                                        side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        minimumSize: Size.zero,
                                      ),
                                      child: const Text('+20', style: TextStyle(fontSize: 11)),
                                    ),
                                    if (item.customizationGroups.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Tooltip(
                                        message: 'Manage modifier availability (${item.customizationGroups.fold(0, (s, g) => s + g.options.length)} options)',
                                        child: OutlinedButton.icon(
                                          onPressed: () => ModifierAvailabilityDialog.show(
                                            context,
                                            posProvider,
                                            item,
                                            onUpdated: () => setState(() {}),
                                          ),
                                          icon: Icon(
                                            item.hasUnavailableOptions ? Icons.warning_amber_rounded : Icons.tune_rounded,
                                            size: 13,
                                            color: item.hasUnavailableOptions ? CelestialTheme.amberBrewing : CelestialTheme.goldLight,
                                          ),
                                          label: Text(
                                            item.hasUnavailableOptions ? '${item.unavailableOptionsCount} 86\'d' : '86 Opts',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: item.hasUnavailableOptions ? CelestialTheme.amberBrewing : CelestialTheme.goldLight,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: item.hasUnavailableOptions ? CelestialTheme.amberBrewing : CelestialTheme.goldLight,
                                            side: BorderSide(
                                              color: item.hasUnavailableOptions
                                                  ? CelestialTheme.amberBrewing
                                                  : CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            minimumSize: Size.zero,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: 8),
                                    // In-Stock Toggle Switch
                                    SizedBox(
                                      height: 24,
                                      width: 36,
                                      child: Switch(
                                        value: item.inStock,
                                        activeThumbColor: CelestialTheme.emeraldReady,
                                        onChanged: (_) => posProvider.toggleItemStock(item.id),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PosProvider provider, bool isMobile) {
    final actionButtons = [
      OutlinedButton.icon(
        onPressed: () => CategoryManagementDialog.show(
          context,
          provider,
          onUpdated: () => setState(() {}),
        ),
        icon: const Icon(Icons.category_outlined, size: 15),
        label: Text(
          isMobile ? 'Categories' : 'Categories (${provider.customCategories.length})',
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
              ? '86 List'
              : '86 List (${provider.totalUnavailableItemsCount + provider.totalUnavailableOptionsCount})',
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
          foregroundColor: CelestialTheme.bgDark,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: isMobile ? 8 : 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
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
                const Icon(Icons.inventory_2_rounded, color: CelestialTheme.goldPrimary, size: 20),
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
                const Icon(Icons.inventory_2_rounded, color: CelestialTheme.goldPrimary, size: 22),
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
                ...actionButtons,
              ],
            ),
          ],
          const SizedBox(height: 8),
          // Search Box
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: CelestialTheme.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              style: const TextStyle(fontSize: 12, color: CelestialTheme.textLight),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Filter items to update price or stock...',
                hintStyle: TextStyle(fontSize: 12, color: CelestialTheme.textSubtle),
                prefixIcon: Icon(Icons.search_rounded, size: 16, color: CelestialTheme.goldPrimary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Category Filter Chips
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
      ),
    );
  }
}
