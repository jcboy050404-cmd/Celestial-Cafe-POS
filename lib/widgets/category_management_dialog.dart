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
            final customCategories = provider.customCategories;

            return Dialog(
              backgroundColor: CelestialTheme.bgSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
              ),
              child: Container(
                width: 580,
                constraints: BoxConstraints(
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
                            border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.category_rounded, color: CelestialTheme.goldLight, size: 22),
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
                              const Text(
                                'Add, edit, or customize menu categories and KDS kitchen routing',
                                style: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          icon: const Icon(Icons.close_rounded, color: CelestialTheme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Add Category Action Button
                    ElevatedButton.icon(
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
                      label: const Text('+ Create Custom Category'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CelestialTheme.goldPrimary,
                        foregroundColor: CelestialTheme.bgDark,
                        minimumSize: const Size(double.infinity, 42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    Text(
                      'All Categories (${provider.allCategoryTabs.length - 1})',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.textLight,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // List of Categories
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          // Section: Custom Categories
                          if (customCategories.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.only(bottom: 6, top: 4),
                              child: Text(
                                'CUSTOM CATEGORIES',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.goldLight,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            ...customCategories.map((cc) {
                              final count = provider.menuItems.where((i) => i.customCategory == cc.name).length;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: CelestialTheme.bgCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  children: [
                                    Text(cc.icon, style: const TextStyle(fontSize: 20)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                cc.name,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: CelestialTheme.textLight,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (cc.isKitchenDish)
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
                                          ),
                                          Text(
                                            '$count item(s) in this category',
                                            style: const TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: CelestialTheme.goldLight),
                                      tooltip: 'Edit Category',
                                      onPressed: () {
                                        showCreateOrEditCategoryModal(
                                          dialogCtx,
                                          provider,
                                          editCategory: cc,
                                          onSaved: () {
                                            setDialogState(() {});
                                            onUpdated?.call();
                                          },
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: CelestialTheme.roseAlert),
                                      tooltip: 'Delete Category',
                                      onPressed: () {
                                        confirmDeleteCategory(
                                          dialogCtx,
                                          provider,
                                          cc,
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
                            }),
                            const SizedBox(height: 8),
                          ],

                          // Section: System Built-in Categories
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6, top: 8),
                            child: Text(
                              'SYSTEM CATEGORIES',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: CelestialTheme.textMuted,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          ...ItemCategory.values.where((c) => c != ItemCategory.all && c != ItemCategory.custom).map((c) {
                            final count = provider.menuItems.where((i) => i.category == c && (i.customCategory == null || i.customCategory!.isEmpty)).length;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: Row(
                                children: [
                                  Text(c.icon, style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      c.label,
                                      style: const TextStyle(fontSize: 13, color: CelestialTheme.textLight),
                                    ),
                                  ),
                                  Text(
                                    '$count items',
                                    style: const TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('SYSTEM', style: TextStyle(fontSize: 9, color: Colors.white54, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          }),
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
    CustomCategory? editCategory,
    required VoidCallback onSaved,
  }) {
    final isEditing = editCategory != null;
    final nameCtrl = TextEditingController(text: editCategory?.name ?? '');
    String selectedIcon = editCategory?.icon ?? '🍰';
    bool isKitchen = editCategory?.isKitchenDish ?? false;

    const emojiPresets = ['🍰', '🍨', '🥞', '🍳', '🥩', '🍱', '🥤', '🧃', '🥐', '🍕', '🥗', '🏷️', '🍪', '🍩', '🍫', '🍿'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return AlertDialog(
              backgroundColor: CelestialTheme.bgSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
              ),
              title: Text(isEditing ? 'Edit Category' : 'New Custom Category'),
              titleTextStyle: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: CelestialTheme.goldLight,
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      style: const TextStyle(fontSize: 13, color: CelestialTheme.textLight),
                      decoration: InputDecoration(
                        labelText: 'Category Name',
                        hintText: 'e.g. Desserts, Breakfast, Specials...',
                        labelStyle: const TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                        filled: true,
                        fillColor: CelestialTheme.bgCard,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Choose Category Icon / Emoji',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: CelestialTheme.textMuted),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: emojiPresets.map((emoji) {
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
                      }).toList(),
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
                          const Expanded(
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(modalCtx),
                  child: const Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final cleanName = nameCtrl.text.trim();
                    if (cleanName.isEmpty) return;

                    if (isEditing) {
                      provider.updateCustomCategory(
                        editCategory.id,
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
                    foregroundColor: CelestialTheme.bgDark,
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
    PosProvider provider,
    CustomCategory category, {
    required VoidCallback onDeleted,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete "${category.name}"?'),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: CelestialTheme.roseAlert,
        ),
        content: Text(
          'Any menu items assigned to "${category.name}" will remain safe and be moved to the Coffee category.',
          style: const TextStyle(fontSize: 12.5, color: CelestialTheme.textLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteCustomCategory(category.id);
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
}
