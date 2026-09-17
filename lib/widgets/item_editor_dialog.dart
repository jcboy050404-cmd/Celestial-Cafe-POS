import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/menu_item.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import 'customizations_editor_dialog.dart';

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
    String selectedCategoryKey;
    if (editItem != null) {
      selectedCategoryKey = (editItem.customCategory != null && editItem.customCategory!.isNotEmpty)
          ? 'custom:${editItem.customCategory}'
          : editItem.category.name;
    } else {
      final availableTabs = provider.allCategoryTabs.where((t) => t.id != 'all').toList();
      if (availableTabs.isNotEmpty) {
        final firstTab = availableTabs.first;
        selectedCategoryKey = firstTab.isCustom ? 'custom:${firstTab.label}' : firstTab.id;
        selectedCategory = firstTab.isCustom
            ? ItemCategory.custom
            : ItemCategory.values.firstWhere((c) => c.name == firstTab.id, orElse: () => ItemCategory.coffee);
      } else {
        selectedCategoryKey = 'custom:General';
        selectedCategory = ItemCategory.custom;
      }
    }
    String? selectedCustomCategory = editItem?.customCategory ??
        (editItem == null && selectedCategoryKey.startsWith('custom:')
            ? selectedCategoryKey.substring(7)
            : null);

    String? currentImagePath = editItem?.imagePath;
    String? currentImageBase64 = editItem?.imageBase64;
    List<CustomizationGroup>? currentCustomizations = editItem != null
        ? List<CustomizationGroup>.from(
            editItem.customizationGroups.map(
              (g) => g.copyWith(options: g.options.map((o) => o.copyWith()).toList()),
            ),
          )
        : null;
    bool hasManuallyEditedCustomizations = false;
    bool isSaving = false;

    // Helper to get default customizations based on category (deep cloned)
    List<CustomizationGroup> getDefaultCustomizations(ItemCategory cat, String? customCat) {
      final List<CustomizationGroup> list;
      if (cat == ItemCategory.milktea) {
        list = MenuItem.defaultMilkteaCustomizations;
      } else if (cat == ItemCategory.cheesecakeSeries) {
        list = MenuItem.getCheesecakeCustomizations();
      } else if (cat == ItemCategory.frappe) {
        list = MenuItem.defaultFrappeCustomizations;
      } else if (cat == ItemCategory.dinner) {
        list = MenuItem.defaultDinnerCustomizations;
      } else if (cat == ItemCategory.streetBites ||
          cat == ItemCategory.pastaDishes ||
          cat == ItemCategory.sandwich ||
          (customCat != null && provider.customCategories.any((c) => c.name == customCat && c.isKitchenDish))) {
        list = MenuItem.defaultFoodCustomizations;
      } else {
        list = MenuItem.defaultCoffeeCustomizations;
      }
      return list.map((g) => g.copyWith(options: g.options.map((o) => o.copyWith()).toList())).toList();
    }

    if (currentCustomizations == null) {
      if (editItem == null) {
        // New item, set defaults immediately so they can be edited
        currentCustomizations = getDefaultCustomizations(selectedCategory, selectedCustomCategory);
      } else {
        currentCustomizations = [];
      }
    }

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
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, color: CelestialTheme.roseAlert),
                );
              } catch (_) {
                photoPreview = Icon(Icons.broken_image, color: CelestialTheme.roseAlert);
              }
            } else if (currentImagePath != null && currentImagePath!.isNotEmpty && currentImagePath!.startsWith('assets/')) {
              photoPreview = Image.asset(
                currentImagePath!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, color: CelestialTheme.roseAlert),
              );
            } else {
              photoPreview = Center(
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
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 440,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
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
                                  Text(
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
                                    final bytes = await file.readAsBytes();
                                    setDialogState(() {
                                      currentImagePath = file.name;
                                      currentImageBase64 = base64Encode(bytes);
                                    });
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
                                icon: Icon(Icons.close_rounded, color: CelestialTheme.roseAlert, size: 18),
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
                                labelStyle: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
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
                              style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Item Name',
                                labelStyle: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
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
                        style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                          filled: true,
                          fillColor: CelestialTheme.bgCard,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: [
                          ...provider.allCategoryTabs.where((t) => t.id != 'all').map((t) {
                            final val = t.isCustom ? 'custom:${t.label}' : t.id;
                            return DropdownMenuItem(
                              value: val,
                              child: Text('${t.icon} ${t.label}'),
                            );
                          }),
                          if (!provider.allCategoryTabs.where((t) => t.id != 'all').any((t) => (t.isCustom ? 'custom:${t.label}' : t.id) == selectedCategoryKey))
                            DropdownMenuItem(
                              value: selectedCategoryKey,
                              child: Text(selectedCustomCategory != null ? '🏷️ $selectedCustomCategory' : '☕ Other'),
                            ),
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
                              // Only reset to category defaults if the user hasn't customized them yet
                              if (!isEditing && !hasManuallyEditedCustomizations) {
                                currentCustomizations = getDefaultCustomizations(selectedCategory, selectedCustomCategory);
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
                              style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Price (₱)',
                                labelStyle: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
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
                              style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Initial Stock',
                                labelStyle: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
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
                        style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Description',
                          labelStyle: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                          filled: true,
                          fillColor: CelestialTheme.bgCard,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Manage Add-ons Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            CustomizationsEditorDialog.show(
                              context,
                              initialGroups: currentCustomizations ?? getDefaultCustomizations(selectedCategory, selectedCustomCategory),
                              onSave: (updatedGroups) {
                                setDialogState(() {
                                  currentCustomizations = updatedGroups;
                                  hasManuallyEditedCustomizations = true;
                                });
                              },
                            );
                          },
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: Text(
                            'Manage Add-ons & Options (${currentCustomizations?.length ?? 0} groups)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CelestialTheme.goldLight,
                            side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
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
                              SnackBar(
                                content: Text('⚠️ Please enter an item name.'),
                                backgroundColor: CelestialTheme.roseAlert,
                              ),
                            );
                            return;
                          }

                          if (price <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('⚠️ Please enter a valid price greater than ₱0.'),
                                backgroundColor: CelestialTheme.roseAlert,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          await Future.delayed(const Duration(milliseconds: 250));

                          if (selectedCategory == ItemCategory.custom && selectedCustomCategory != null) {
                            final exists = provider.customCategories.any((c) => c.name.toLowerCase() == selectedCustomCategory!.toLowerCase());
                            if (!exists) {
                              provider.addCustomCategory(name: selectedCustomCategory!, icon: '🏷️');
                            }
                          }

                          if (isEditing) {
                            final updated = editItem.copyWith(
                              name: name,
                              price: price,
                              category: selectedCategory,
                              customCategory: selectedCustomCategory,
                              clearCustomCategory: selectedCustomCategory == null,
                              clearImage: currentImagePath == null && (currentImageBase64 == null || currentImageBase64!.isEmpty),
                              description: desc,
                              icon: icon,
                              tags: [
                                if (selectedCustomCategory != null &&
                                    provider.customCategories.any((c) => c.name == selectedCustomCategory && c.isKitchenDish))
                                  'Kitchen Cooked',
                                'House Special'
                              ],
                              stockCount: stock < 0 ? 0 : stock,
                              inStock: stock > 0,
                              imagePath: currentImagePath,
                              imageBase64: currentImageBase64,
                              customizationGroups: currentCustomizations ?? getDefaultCustomizations(selectedCategory, selectedCustomCategory),
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
                              stockCount: stock < 0 ? 0 : stock,
                              inStock: stock > 0,
                              imagePath: currentImagePath,
                              imageBase64: currentImageBase64,
                              customizationGroups: currentCustomizations ?? getDefaultCustomizations(selectedCategory, selectedCustomCategory),
                            );
                            provider.addNewMenuItem(newItem);
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CelestialTheme.goldPrimary,
                    foregroundColor: CelestialTheme.primaryBtnText,
                  ),
                  child: isSaving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: CelestialTheme.primaryBtnText),
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