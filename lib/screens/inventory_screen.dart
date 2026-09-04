import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import '../widgets/settings_dialog.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _searchQuery = '';
  String? _categoryFilterId;

  static bool _safeFileExists(String? path) {
    if (path == null || path.trim().isEmpty) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  Widget _buildItemThumbnail(MenuItem item, bool isMobile) {
    final bool hasBase64 = item.imageBase64 != null && item.imageBase64!.isNotEmpty;
    final bool hasAsset = item.imagePath != null && item.imagePath!.isNotEmpty && item.imagePath!.startsWith('assets/');
    final bool hasFile = _safeFileExists(item.imagePath) && !hasAsset;

    if (hasBase64 || hasAsset || hasFile) {
      return Container(
        width: isMobile ? 44 : 52,
        height: isMobile ? 44 : 52,
        decoration: BoxDecoration(
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: hasBase64
              ? Image.memory(
                  base64Decode(item.imageBase64!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(child: Text(item.icon, style: TextStyle(fontSize: isMobile ? 20 : 24))),
                )
              : hasAsset
                  ? Image.asset(
                      item.imagePath!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(child: Text(item.icon, style: TextStyle(fontSize: isMobile ? 20 : 24))),
                    )
                  : Image.file(
                      File(item.imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(child: Text(item.icon, style: TextStyle(fontSize: isMobile ? 20 : 24))),
                    ),
        ),
      );
    }

    return Container(
      width: isMobile ? 42 : 50,
      height: isMobile ? 42 : 50,
      decoration: BoxDecoration(
        gradient: CelestialTheme.brownGradient,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(item.icon, style: TextStyle(fontSize: isMobile ? 20 : 24)),
      ),
    );
  }

  void _showQuickPriceDialog(BuildContext context, PosProvider provider, MenuItem item) {
    final priceController = TextEditingController(text: item.price.toStringAsFixed(0));
    double tempPrice = item.price;
    bool isSavingPrice = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: CelestialTheme.bgSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
              ),
              title: Row(
                children: [
                  Text(item.icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Item Price',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.goldLight,
                          ),
                        ),
                        Text(
                          item.name,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: CelestialTheme.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: CelestialTheme.brownGradient,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'NEW PRICE (₱)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: CelestialTheme.goldLight,
                            ),
                          ),
                          Text(
                            '₱${tempPrice.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.goldLight,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Manual Price Input
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.textLight,
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val);
                        if (parsed != null && parsed >= 0) {
                          setDialogState(() => tempPrice = parsed);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Enter Custom Price (₱)',
                        labelStyle: const TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          child: Text(
                            '₱',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.goldPrimary,
                            ),
                          ),
                        ),
                        filled: true,
                        fillColor: CelestialTheme.bgCard,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Quick Step Buttons
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Quick Adjustments:',
                        style: TextStyle(fontSize: 11, color: CelestialTheme.textSubtle),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [-10.0, -5.0, 5.0, 10.0, 20.0].map((delta) {
                        return ActionChip(
                          label: Text(
                            delta > 0 ? '+₱${delta.toStringAsFixed(0)}' : '-₱${(-delta).toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: delta > 0 ? CelestialTheme.goldLight : CelestialTheme.roseAlert,
                            ),
                          ),
                          backgroundColor: CelestialTheme.bgCard,
                          side: BorderSide(
                            color: delta > 0
                                ? CelestialTheme.goldPrimary.withValues(alpha: 0.3)
                                : CelestialTheme.roseAlert.withValues(alpha: 0.3),
                          ),
                          onPressed: () {
                            final newP = (tempPrice + delta).clamp(0.0, 99999.0);
                            setDialogState(() {
                              tempPrice = newP;
                              priceController.text = newP.toStringAsFixed(0);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: isSavingPrice
                      ? null
                      : () async {
                          final finalPrice = double.tryParse(priceController.text.trim()) ?? tempPrice;
                          if (finalPrice >= 0) {
                            setDialogState(() => isSavingPrice = true);
                            await Future.delayed(const Duration(milliseconds: 200));
                            provider.updateItemPrice(item.id, finalPrice);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: CelestialTheme.bgCard,
                                  content: Text('✨ Updated price for ${item.name} to ₱${finalPrice.toStringAsFixed(0)}'),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CelestialTheme.goldPrimary,
                    foregroundColor: CelestialTheme.bgDark,
                  ),
                  child: isSavingPrice
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: CelestialTheme.bgDark),
                        )
                      : const Text('Save Price', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPriceSettingsManager(BuildContext context, PosProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: CelestialTheme.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
          ),
          title: Row(
            children: [
              const Icon(Icons.price_change_rounded, color: CelestialTheme.goldPrimary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Menu Price Settings',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: CelestialTheme.goldLight,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tap any item to quickly update its selling price. Changes save to local storage immediately.',
                  style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: provider.menuItems.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final m = provider.menuItems[index];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: CelestialTheme.brownGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(child: Text(m.icon, style: const TextStyle(fontSize: 16))),
                        ),
                        title: Text(
                          m.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                        ),
                        subtitle: Text(
                          m.category.label,
                          style: const TextStyle(fontSize: 10, color: CelestialTheme.textMuted),
                        ),
                        trailing: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _showQuickPriceDialog(context, provider, m);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: CelestialTheme.goldPrimary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '₱${m.price.toStringAsFixed(0)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: CelestialTheme.goldLight,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit, size: 12, color: CelestialTheme.goldPrimary),
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
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: CelestialTheme.goldPrimary,
                foregroundColor: CelestialTheme.bgDark,
              ),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _showAddItemDialog(BuildContext context, PosProvider provider, [MenuItem? editItem]) {
    final isEditing = editItem != null;
    final nameController = TextEditingController(text: editItem?.name ?? '');
    final priceController = TextEditingController(text: editItem != null ? editItem.price.toStringAsFixed(0) : '');
    final descController = TextEditingController(text: editItem?.description ?? '');
    final iconController = TextEditingController(text: editItem?.icon ?? '☕');
    final stockController = TextEditingController(text: editItem != null ? '${editItem.stockCount}' : '50');
    ItemCategory selectedCategory = editItem?.category ?? ItemCategory.coffee;
    String selectedCategoryKey = editItem != null
        ? (editItem.customCategory != null && editItem.customCategory!.isNotEmpty
            ? 'custom:${editItem.customCategory}'
            : editItem.category.name)
        : ItemCategory.coffee.name;
    String? selectedCustomCategory = editItem?.customCategory;

    String? currentImagePath = editItem?.imagePath;
    String? currentImageBase64 = editItem?.imageBase64;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: CelestialTheme.bgSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
              ),
              title: Text(isEditing ? '✏️ Edit Menu Item & Photo' : '✨ Add New Celestial Item'),
              titleTextStyle: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: CelestialTheme.goldLight,
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Photo Upload Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: CelestialTheme.bgCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: CelestialTheme.bgSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: (currentImageBase64 != null && currentImageBase64!.isNotEmpty)
                                    ? Image.memory(
                                        base64Decode(currentImageBase64!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: CelestialTheme.roseAlert),
                                    )
                                    : _safeFileExists(currentImagePath)
                                        ? Image.file(
                                            File(currentImagePath!),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: CelestialTheme.roseAlert),
                                          )
                                        : const Center(
                                            child: Icon(Icons.add_a_photo_rounded, color: CelestialTheme.goldPrimary, size: 24),
                                          ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentImageBase64 != null || currentImagePath != null ? 'Item Photo Attached' : 'Upload Item Photo',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: CelestialTheme.goldLight,
                                    ),
                                  ),
                                  const Text(
                                    'Shows on POS & Customer Table QR Menu',
                                    style: TextStyle(fontSize: 10, color: CelestialTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  final files = await FilePickerPlatform.instance.pickFiles(type: FileType.image);
                                  if (files.isNotEmpty) {
                                    final file = files.first;
                                    if (file.path != null) {
                                      final bytes = await File(file.path!).readAsBytes();
                                      setDialogState(() {
                                        currentImagePath = file.path;
                                        currentImageBase64 = base64Encode(bytes);
                                      });
                                    }
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error picking photo: $e')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.photo_library_rounded, size: 14),
                              label: Text(currentImageBase64 != null || currentImagePath != null ? 'Change' : 'Upload'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: CelestialTheme.goldPrimary,
                                side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (currentImageBase64 != null || currentImagePath != null) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: CelestialTheme.roseAlert, size: 18),
                                onPressed: () {
                                  setDialogState(() {
                                    currentImagePath = null;
                                    currentImageBase64 = null;
                                  });
                                },
                                tooltip: 'Remove Photo',
                                splashRadius: 16,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Item Name & Icon
                      Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: TextField(
                              controller: iconController,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 22),
                              decoration: InputDecoration(
                                labelText: 'Emoji',
                                labelStyle: const TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                                filled: true,
                                fillColor: CelestialTheme.bgCard,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: nameController,
                              style: const TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Item Name',
                                labelStyle: const TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                                filled: true,
                                fillColor: CelestialTheme.bgCard,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategoryKey,
                        dropdownColor: CelestialTheme.bgCard,
                        style: const TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: const TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                          filled: true,
                          fillColor: CelestialTheme.bgCard,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: [
                          ...ItemCategory.values
                              .where((c) => c != ItemCategory.all && c != ItemCategory.custom)
                              .map((c) {
                            return DropdownMenuItem(
                              value: c.name,
                              child: Text('${c.icon} ${c.label}'),
                            );
                          }),
                          ...provider.customCategories.map((cc) {
                            return DropdownMenuItem(
                              value: 'custom:${cc.name}',
                              child: Text('${cc.icon} ${cc.name} (Custom)'),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedCategoryKey = val;
                              if (val.startsWith('custom:')) {
                                selectedCustomCategory = val.substring(7);
                                selectedCategory = ItemCategory.custom;
                              } else {
                                selectedCustomCategory = null;
                                selectedCategory = ItemCategory.values.firstWhere(
                                  (c) => c.name == val,
                                  orElse: () => ItemCategory.coffee,
                                );
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Price & Stock
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Price (₱)',
                                labelStyle: const TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                                filled: true,
                                fillColor: CelestialTheme.bgCard,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: stockController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Initial Stock',
                                labelStyle: const TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                                filled: true,
                                fillColor: CelestialTheme.bgCard,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Description
                      TextField(
                        controller: descController,
                        maxLines: 2,
                        style: const TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Description',
                          labelStyle: const TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                          filled: true,
                          fillColor: CelestialTheme.bgCard,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final rawPrice = priceController.text.trim().replaceAll(',', '.');
                          final price = double.tryParse(rawPrice) ?? 0.0;
                          final stock = int.tryParse(stockController.text.trim()) ?? 0;
                          final desc = descController.text.trim();
                          final icon = iconController.text.trim().isNotEmpty ? iconController.text.trim() : '✨';

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('⚠️ Please enter an item name.'),
                                backgroundColor: CelestialTheme.roseAlert,
                              ),
                            );
                            return;
                          }

                          if (price <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('⚠️ Please enter a valid price greater than ₱0.'),
                                backgroundColor: CelestialTheme.roseAlert,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          await Future.delayed(const Duration(milliseconds: 250));

                          if (isEditing) {
                            final updated = editItem.copyWith(
                              name: name,
                              price: price,
                              category: selectedCategory,
                              customCategory: selectedCustomCategory,
                              description: desc,
                              icon: icon,
                              stockCount: stock,
                              inStock: stock > 0,
                              imagePath: currentImagePath,
                              imageBase64: currentImageBase64,
                            );
                            provider.updateMenuItem(updated);
                          } else {
                            final newItem = MenuItem(
                              id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                              name: name,
                              category: selectedCategory,
                              customCategory: selectedCustomCategory,
                              price: price,
                              description: desc.isNotEmpty ? desc : 'Artisanal recipe crafted by Celestial Cafe.',
                              icon: icon,
                              tags: [
                                if (selectedCustomCategory != null &&
                                    provider.customCategories.any((c) => c.name == selectedCustomCategory && c.isKitchenDish))
                                  'Kitchen Cooked',
                                'House Special'
                              ],
                              stockCount: stock,
                              inStock: stock > 0,
                              imagePath: currentImagePath,
                              imageBase64: currentImageBase64,
                              customizationGroups: selectedCategory == ItemCategory.milktea
                                  ? MenuItem.defaultMilkteaCustomizations
                                  : selectedCategory == ItemCategory.cheesecakeSeries
                                      ? MenuItem.getCheesecakeCustomizations()
                                      : selectedCategory == ItemCategory.frappe
                                          ? MenuItem.defaultFrappeCustomizations
                                          : selectedCategory == ItemCategory.dinner
                                              ? MenuItem.defaultDinnerCustomizations
                                              : (selectedCategory == ItemCategory.streetBites ||
                                                      selectedCategory == ItemCategory.pastaDishes ||
                                                      selectedCategory == ItemCategory.sandwich ||
                                                      (selectedCustomCategory != null &&
                                                          provider.customCategories.any((c) => c.name == selectedCustomCategory && c.isKitchenDish)))
                                                  ? MenuItem.defaultFoodCustomizations
                                                  : MenuItem.defaultCoffeeCustomizations,
                            );
                            provider.addNewMenuItem(newItem);
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CelestialTheme.goldPrimary,
                    foregroundColor: CelestialTheme.bgDark,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: CelestialTheme.bgDark),
                        )
                      : Text(isEditing ? 'Save Changes' : 'Create Item'),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
            child: ListView.separated(
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
                            onTap: () => _showAddItemDialog(context, posProvider, item),
                            child: _buildItemThumbnail(item, isMobile),
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
                                        item.category.label,
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
                                      onTap: () => _showQuickPriceDialog(context, posProvider, item),
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
                            onPressed: () => _showAddItemDialog(context, posProvider, item),
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
                                    onPressed: () => _showItemModifierAvailabilityDialog(context, posProvider, item),
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
        onPressed: () => _showCategoryManagementDialog(context, provider),
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
        onPressed: () => _showPriceSettingsManager(context, provider),
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
        onPressed: () => _showAddItemDialog(context, provider),
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

  void _showItemModifierAvailabilityDialog(BuildContext context, PosProvider posProvider, MenuItem item) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDlgState) {
            final currentItem = posProvider.menuItems.firstWhere(
              (m) => m.id == item.id,
              orElse: () => item,
            );

            return Dialog(
              backgroundColor: CelestialTheme.bgSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
              ),
              child: Container(
                width: 500,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(currentItem.icon, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${currentItem.name} - 86 & Modifiers',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.textLight,
                                ),
                              ),
                              const Text(
                                'Mark individual sizes, syrups, and add-ons as sold out',
                                style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, color: CelestialTheme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: currentItem.customizationGroups.map((group) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.title,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: CelestialTheme.textLight,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: group.options.map((opt) {
                                      final isAvail = opt.isAvailable;
                                      return InkWell(
                                        onTap: () {
                                          posProvider.toggleOptionAvailability(
                                            currentItem.id,
                                            group.id,
                                            opt.name,
                                            !isAvail,
                                          );
                                          setDlgState(() {});
                                          setState(() {});
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: isAvail
                                                ? CelestialTheme.bgCard
                                                : CelestialTheme.roseAlert.withValues(alpha: 0.16),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isAvail
                                                  ? Colors.white.withValues(alpha: 0.1)
                                                  : CelestialTheme.roseAlert,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isAvail ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                                size: 13,
                                                color: isAvail ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                opt.name,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isAvail ? CelestialTheme.textLight : CelestialTheme.roseAlert,
                                                  fontWeight: isAvail ? FontWeight.w500 : FontWeight.bold,
                                                  decoration: isAvail ? null : TextDecoration.lineThrough,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (currentItem.hasUnavailableOptions)
                          TextButton.icon(
                            onPressed: () {
                              posProvider.resetAllItemOptionsAvailability(currentItem.id);
                              setDlgState(() {});
                              setState(() {});
                            },
                            icon: const Icon(Icons.restart_alt_rounded, size: 14),
                            label: const Text('Make All Available', style: TextStyle(fontSize: 11)),
                            style: TextButton.styleFrom(foregroundColor: CelestialTheme.emeraldReady),
                          )
                        else
                          const SizedBox.shrink(),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CelestialTheme.goldPrimary,
                            foregroundColor: CelestialTheme.bgDark,
                          ),
                          child: const Text('Done'),
                        ),
                      ],
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

  void _showCategoryManagementDialog(BuildContext context, PosProvider provider) {
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
                        _showCreateOrEditCategoryModal(dialogCtx, provider, onSaved: () {
                          setDialogState(() {});
                          setState(() {});
                        });
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
                                        _showCreateOrEditCategoryModal(dialogCtx, provider, editCategory: cc, onSaved: () {
                                          setDialogState(() {});
                                          setState(() {});
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: CelestialTheme.roseAlert),
                                      tooltip: 'Delete Category',
                                      onPressed: () {
                                        _confirmDeleteCategory(dialogCtx, provider, cc, onDeleted: () {
                                          setDialogState(() {});
                                          setState(() {});
                                        });
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

  void _showCreateOrEditCategoryModal(
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

  void _confirmDeleteCategory(
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
