import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/menu_item.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';

class ItemEditorDialog {
  static void show(
    BuildContext context,
    PosProvider provider, [
    MenuItem? editItem,
  ]) {
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
            Widget photoPreview;
            if (currentImageBase64 != null && currentImageBase64!.isNotEmpty) {
              try {
                photoPreview = Image.memory(
                  base64Decode(currentImageBase64!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: CelestialTheme.roseAlert),
                );
              } catch (_) {
                photoPreview = const Icon(Icons.broken_image, color: CelestialTheme.roseAlert);
              }
            } else if (currentImagePath != null && currentImagePath!.isNotEmpty) {
              photoPreview = Image.file(
                File(currentImagePath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: CelestialTheme.roseAlert),
              );
            } else {
              photoPreview = const Center(
                child: Icon(Icons.add_a_photo_rounded, color: CelestialTheme.goldPrimary, size: 24),
              );
            }

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
                                child: photoPreview,
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
}
