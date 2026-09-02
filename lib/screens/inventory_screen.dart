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
  ItemCategory? _categoryFilter;

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
    final bool hasFile = _safeFileExists(item.imagePath);

    if (hasBase64 || hasFile) {
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
                      DropdownButtonFormField<ItemCategory>(
                        initialValue: selectedCategory,
                        dropdownColor: CelestialTheme.bgCard,
                        style: const TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: const TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                          filled: true,
                          fillColor: CelestialTheme.bgCard,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: ItemCategory.values.where((c) => c != ItemCategory.all).map((c) {
                          return DropdownMenuItem(value: c, child: Text('${c.icon} ${c.label}'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedCategory = val);
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
                              price: price,
                              description: desc.isNotEmpty ? desc : 'Artisanal recipe crafted by Celestial Cafe.',
                              icon: icon,
                              tags: ['House Special'],
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
                                          : (selectedCategory == ItemCategory.streetBites ||
                                                  selectedCategory == ItemCategory.pastaDishes ||
                                                  selectedCategory == ItemCategory.sandwich)
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
      final matchesCat = _categoryFilter == null || item.category == _categoryFilter;
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
        ],
      ),
    );
  }
}
