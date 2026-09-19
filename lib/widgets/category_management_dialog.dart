import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/menu_item.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';

class CategoryManagementDialog {
  static void show(
    BuildContext context,
    PosProvider provider, {
    VoidCallback? onUpdated,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final categories = provider.allCategoryTabs.where((t) => t.id != 'all').toList();

            return Dialog(
              backgroundColor: CelestialTheme.bgSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width < 620 ? double.infinity : 580,
                constraints: BoxConstraints(
                  maxWidth: 580,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Icon(Icons.category_rounded, color: CelestialTheme.goldLight, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manage Menu Categories',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.goldLight,
                                ),
                              ),
                              Text(
                                'Add, edit, or customize menu categories and KDS kitchen routing',
                                style: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          icon: Icon(Icons.close_rounded, color: CelestialTheme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Category Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              showCreateOrEditCategoryModal(
                                dialogCtx,
                                provider,
                                onSaved: () {
                                  setDialogState(() {});
                                  onUpdated?.call();
                                },
                              );
                            },
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Create Category'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CelestialTheme.goldPrimary,
                              foregroundColor: CelestialTheme.primaryBtnText,
                              minimumSize: const Size(0, 42),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            confirmResetCategories(
                              dialogCtx,
                              provider,
                              onReset: () {
                                setDialogState(() {});
                                onUpdated?.call();
                              },
                            );
                          },
                          icon: const Icon(Icons.restart_alt_rounded, size: 16),
                          label: const Text('Reset Categories', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CelestialTheme.goldLight,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                            minimumSize: const Size(0, 42),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Text(
                          'All Categories (${categories.length})',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.textLight,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(Icons.swap_vert_rounded, size: 14, color: CelestialTheme.goldLight),
                            const SizedBox(width: 4),
                            Text(
                              'Drag to choose 1st section',
                              style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Reorderable List of Categories
                    Flexible(
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        buildDefaultDragHandles: false,
                        itemCount: categories.length,
                        // ignore: deprecated_member_use
                        onReorder: (oldIndex, newIndex) {
                          provider.reorderCategoryTabs(oldIndex, newIndex);
                          setDialogState(() {});
                          onUpdated?.call();
                        },
                        proxyDecorator: (child, index, animation) {
                          return Material(
                            color: Colors.transparent,
                            elevation: 6,
                            shadowColor: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: CelestialTheme.bgSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: CelestialTheme.goldPrimary, width: 1.5),
                              ),
                              child: child,
                            ),
                          );
                        },
                        itemBuilder: (ctx, index) {
                          final cat = categories[index];
                          final isFirst = index == 0;
                          final count = provider.menuItems.where((i) {
                            if (cat.isCustom) {
                              return i.customCategory == cat.label || i.customCategory == cat.id;
                            } else {
                              final enumMatch = ItemCategory.values.firstWhere(
                                (c) => c.name == cat.id,
                                orElse: () => ItemCategory.custom,
                              );
                              return i.category == enumMatch && (i.customCategory == null || i.customCategory!.isEmpty);
                            }
                          }).length;

                          return Container(
                            key: ValueKey(cat.id),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: CelestialTheme.bgCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isFirst
                                    ? CelestialTheme.goldPrimary.withValues(alpha: 0.4)
                                    : Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Drag Handle & Position Indicator
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isFirst
                                          ? CelestialTheme.goldPrimary.withValues(alpha: 0.2)
                                          : Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isFirst
                                            ? CelestialTheme.goldPrimary.withValues(alpha: 0.5)
                                            : Colors.white.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.drag_indicator_rounded,
                                          size: 15,
                                          color: isFirst ? CelestialTheme.goldPrimary : CelestialTheme.textMuted,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          isFirst ? '1ST' : '#${index + 1}',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: isFirst ? CelestialTheme.goldPrimary : CelestialTheme.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (cat.icon.trim().isNotEmpty) ...[
                                  Text(cat.icon, style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              cat.label,
                                              style: GoogleFonts.outfit(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.bold,
                                                color: CelestialTheme.textLight,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isFirst) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: CelestialTheme.goldPrimary.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                                              ),
                                              child: Text(
                                                '1ST SECTION',
                                                style: TextStyle(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: CelestialTheme.goldLight,
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (cat.isKitchenDish) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFF7043).withValues(alpha: 0.18),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFFF7043).withValues(alpha: 0.5)),
                                              ),
                                              child: const Text(
                                                'KDS KITCHEN',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFFF7043),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$count item(s) in this category',
                                        style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isFirst)
                                  IconButton(
                                    icon: Icon(Icons.vertical_align_top_rounded, size: 17, color: CelestialTheme.goldLight),
                                    tooltip: 'Move to 1st Section',
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      provider.moveCategoryToFirst(cat.id);
                                      setDialogState(() {});
                                      onUpdated?.call();
                                    },
                                  ),
                                IconButton(
                                  icon: Icon(Icons.edit_outlined, size: 17, color: CelestialTheme.goldLight),
                                  tooltip: 'Edit Category',
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    showCreateOrEditCategoryModal(
                                      dialogCtx,
                                      provider,
                                      editTab: cat,
                                      onSaved: () {
                                        setDialogState(() {});
                                        onUpdated?.call();
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(width: 2),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 17, color: CelestialTheme.roseAlert),
                                  tooltip: 'Delete Category',
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    confirmDeleteCategory(
                                      dialogCtx,
                                      provider,
                                      tab: cat,
                                      onDeleted: () {
                                        setDialogState(() {});
                                        onUpdated?.call();
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Empty State when no categories exist
                    if (categories.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.category_outlined, size: 44, color: CelestialTheme.textMuted.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text(
                              'No Categories in Catalog',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: CelestialTheme.textLight,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'All categories have been removed.\nClick "Create Category" above to add your own, or restore the default cafe categories below.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: CelestialTheme.textMuted, height: 1.4),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await provider.restoreSystemCategories();
                                setDialogState(() {});
                                onUpdated?.call();
                              },
                              icon: const Icon(Icons.restore_rounded, size: 16),
                              label: const Text('Restore Default Categories', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: CelestialTheme.goldLight,
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static void showCreateOrEditCategoryModal(
    BuildContext context,
    PosProvider provider, {
    CategoryTabItem? editTab,
    CustomCategory? editCategory,
    required VoidCallback onSaved,
  }) {
    final isEditing = editTab != null || editCategory != null;
    final catId = editTab?.id ?? editCategory?.id ?? '';
    final initialName = editTab?.label ?? editCategory?.name ?? '';
    final initialIcon = editTab?.icon ?? editCategory?.icon ?? '🍰';
    final initialKitchen = editTab?.isKitchenDish ?? editCategory?.isKitchenDish ?? false;

    final nameCtrl = TextEditingController(text: initialName);
    String selectedIcon = initialIcon;
    bool isKitchen = initialKitchen;

    const emojiPresets = ['🍰', '☕', '🍵', '🧋', '🥤', '🍟', '🍝', '🥪', '🍛', '🍨', '🥞', '🍳', '🥩', '🍱', '🧃', '🥐', '🍕', '🥗', '🏷️', '🍪', '🍩', '🍫', '🍿'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return AlertDialog(
              backgroundColor: CelestialTheme.bgSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              title: Text(isEditing ? 'Edit Category' : 'New Category'),
              titleTextStyle: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: CelestialTheme.goldLight,
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        autofocus: true,
                        style: TextStyle(fontSize: 13, color: CelestialTheme.textLight),
                        decoration: InputDecoration(
                          labelText: 'Category Name',
                          hintText: 'e.g. Desserts, Breakfast, Specials...',
                          labelStyle: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                          filled: true,
                          fillColor: CelestialTheme.bgCard,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Choose Category Icon / Emoji',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: CelestialTheme.textMuted),
                          ),
                          if (selectedIcon.trim().isNotEmpty)
                            InkWell(
                              onTap: () => setModalState(() => selectedIcon = ''),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.block_rounded, size: 12, color: CelestialTheme.roseAlert),
                                    const SizedBox(width: 4),
                                    Text(
                                      'No Emoji',
                                      style: TextStyle(fontSize: 11, color: CelestialTheme.roseAlert, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Option for No Emoji (Text Only)
                          InkWell(
                            onTap: () => setModalState(() => selectedIcon = ''),
                            borderRadius: BorderRadius.circular(8),
                            child: Tooltip(
                              message: 'No Emoji (Text only)',
                              child: Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selectedIcon.trim().isEmpty
                                      ? CelestialTheme.goldPrimary.withValues(alpha: 0.3)
                                      : CelestialTheme.bgCard,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selectedIcon.trim().isEmpty ? CelestialTheme.goldPrimary : Colors.white12,
                                    width: selectedIcon.trim().isEmpty ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Icon(
                                  Icons.block_rounded,
                                  size: 18,
                                  color: selectedIcon.trim().isEmpty
                                      ? CelestialTheme.goldLight
                                      : CelestialTheme.textMuted,
                                ),
                              ),
                            ),
                          ),
                          ...emojiPresets.map((emoji) {
                            final isSel = selectedIcon == emoji;
                            return InkWell(
                              onTap: () => setModalState(() => selectedIcon = emoji),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSel ? CelestialTheme.goldPrimary.withValues(alpha: 0.3) : CelestialTheme.bgCard,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSel ? CelestialTheme.goldPrimary : Colors.white12,
                                    width: isSel ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Text(emoji, style: const TextStyle(fontSize: 18)),
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // KDS Kitchen Routing Switch
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: CelestialTheme.bgCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.soup_kitchen_rounded, color: Color(0xFFFF7043), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Route to Kitchen (KDS)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: CelestialTheme.textLight)),
                                  Text('Kitchen display screens will receive orders for this category', style: TextStyle(fontSize: 10, color: CelestialTheme.textMuted)),
                                ],
                              ),
                            ),
                            Switch(
                              value: isKitchen,
                              activeThumbColor: const Color(0xFFFF7043),
                              onChanged: (val) => setModalState(() => isKitchen = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(modalCtx),
                  child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final cleanName = nameCtrl.text.trim();
                    if (cleanName.isEmpty) return;

                    if (isEditing) {
                      provider.updateCategory(
                        catId,
                        name: cleanName,
                        icon: selectedIcon,
                        isKitchenDish: isKitchen,
                      );
                    } else {
                      provider.addCustomCategory(
                        name: cleanName,
                        icon: selectedIcon,
                        isKitchenDish: isKitchen,
                      );
                    }
                    Navigator.pop(modalCtx);
                    onSaved();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CelestialTheme.goldPrimary,
                    foregroundColor: CelestialTheme.primaryBtnText,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(isEditing ? 'Save Changes' : 'Create Category'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static void confirmDeleteCategory(
    BuildContext context,
    PosProvider provider, {
    CategoryTabItem? tab,
    CustomCategory? category,
    required VoidCallback onDeleted,
  }) {
    final catId = tab?.id ?? category?.id ?? '';
    final catName = tab?.label ?? category?.name ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete "$catName"?'),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: CelestialTheme.roseAlert,
        ),
        content: Text(
          'Any menu items in "$catName" will remain safe and be accessible under "All Items".',
          style: TextStyle(fontSize: 12.5, color: CelestialTheme.textLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteCategory(catId, name: catName);
              Navigator.pop(ctx);
              onDeleted();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.roseAlert,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Category'),
          ),
        ],
      ),
    );
  }

  static void confirmResetCategories(
    BuildContext context,
    PosProvider provider, {
    required VoidCallback onReset,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: CelestialTheme.goldLight, size: 22),
            const SizedBox(width: 8),
            Text(
              'Reset Categories to Default?',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: CelestialTheme.textLight,
              ),
            ),
          ],
        ),
        content: Text(
          'This will restore all default cafe categories (Coffee, Non Espresso, Milktea, Frappe, Cheesecake Series, Street Bites, Pasta Dishes, Sandwich, Dinner).\n\nExisting menu items will remain intact and will be re-aligned with the default categories.',
          style: TextStyle(fontSize: 12.5, color: CelestialTheme.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await provider.restoreSystemCategories();
              if (ctx.mounted) Navigator.pop(ctx);
              onReset();
            },
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: const Text('Reset Categories'),
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.goldPrimary,
              foregroundColor: CelestialTheme.primaryBtnText,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}