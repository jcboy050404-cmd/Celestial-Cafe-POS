import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import 'customization_dialog.dart';
import 'customizations_editor_dialog.dart';
import 'item_editor_dialog.dart';
import 'item_thumbnail.dart';
import 'top_notification.dart';

class MenuItemCard extends StatefulWidget {
  final MenuItem item;

  const MenuItemCard({super.key, required this.item});

  @override
  State<MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<MenuItemCard> {
  bool _isHovered = false;

  Widget _buildItemMediaCover(MenuItem item, bool isCompact) {
    return ItemThumbnail(
      item: item,
      width: double.infinity,
      borderRadius: BorderRadius.zero,
      iconSize: isCompact ? 34 : 44,
    );
  }

  Widget _presetButton(String label, StateSetter setDialogState, VoidCallback onSelected) {
    return InkWell(
      onTap: () => setDialogState(onSelected),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: CelestialTheme.borderSubtle),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, color: CelestialTheme.goldLight, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  void _showAddOrEditCategoryDialog(
    BuildContext context,
    PosProvider posProvider,
    MenuItem currentItem, {
    CustomizationGroup? group,
  }) {
    final isEditing = group != null;
    final titleController = TextEditingController(text: group?.title ?? '');
    bool isRequired = group?.isRequired ?? false;
    bool isMultiSelect = group?.isMultiSelect ?? false;
    List<CustomizationOption> presetOptions = group != null ? List.from(group.options) : [];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: CelestialTheme.bgSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: CelestialTheme.borderSubtle),
              ),
              title: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                    color: CelestialTheme.goldPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Edit Option Category' : 'New Option Category',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: CelestialTheme.textLight,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isEditing) ...[
                        Text(
                          'QUICK PRESETS',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: CelestialTheme.goldLight,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _presetButton('Cup Size', setDialogState, () {
                              titleController.text = 'Cup Size';
                              isRequired = true;
                              isMultiSelect = false;
                              presetOptions = [
                                const CustomizationOption(name: '16oz Regular', extraPrice: 0.0),
                                const CustomizationOption(name: '22oz Large', extraPrice: 20.0),
                              ];
                            }),
                            _presetButton('Temperature', setDialogState, () {
                              titleController.text = 'Temperature';
                              isRequired = true;
                              isMultiSelect = false;
                              presetOptions = [
                                const CustomizationOption(name: 'Hot', extraPrice: 0.0),
                                const CustomizationOption(name: 'Iced', extraPrice: 0.0),
                              ];
                            }),
                            _presetButton('Sweetness', setDialogState, () {
                              titleController.text = 'Sweetness Level';
                              isRequired = true;
                              isMultiSelect = false;
                              presetOptions = [
                                const CustomizationOption(name: '100% Regular', extraPrice: 0.0),
                                const CustomizationOption(name: '75% Less Sweet', extraPrice: 0.0),
                                const CustomizationOption(name: '50% Half Sweet', extraPrice: 0.0),
                                const CustomizationOption(name: '25% Mild', extraPrice: 0.0),
                                const CustomizationOption(name: '0% No Sugar', extraPrice: 0.0),
                              ];
                            }),
                            _presetButton('Add-ons & Extras', setDialogState, () {
                              titleController.text = 'Add-ons & Extras';
                              isRequired = false;
                              isMultiSelect = true;
                              presetOptions = [
                                const CustomizationOption(name: 'Extra Shot Espresso', extraPrice: 25.0),
                                const CustomizationOption(name: 'Caramel Drizzle', extraPrice: 15.0),
                                const CustomizationOption(name: 'Vanilla Syrup', extraPrice: 15.0),
                              ];
                            }),
                            _presetButton('Sinkers', setDialogState, () {
                              titleController.text = 'Sinkers & Toppings';
                              isRequired = false;
                              isMultiSelect = true;
                              presetOptions = [
                                const CustomizationOption(name: 'Tapioca Pearls', extraPrice: 15.0),
                                const CustomizationOption(name: 'Cream Cheese Foam', extraPrice: 20.0),
                                const CustomizationOption(name: 'Nata de Coco', extraPrice: 15.0),
                              ];
                            }),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                      Text(
                        'Category Name',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CelestialTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleController,
                        style: TextStyle(color: CelestialTheme.textLight, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'e.g. Milk Type, Size, Sugar Level',
                          hintStyle: TextStyle(color: CelestialTheme.textMuted.withValues(alpha: 0.6)),
                          filled: true,
                          fillColor: CelestialTheme.bgCard,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: CelestialTheme.borderSubtle),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: CelestialTheme.borderSubtle),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: CelestialTheme.goldPrimary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Required Selection',
                          style: GoogleFonts.outfit(fontSize: 13, color: CelestialTheme.textLight, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Customer must choose an option before ordering',
                          style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                        ),
                        value: isRequired,
                        activeThumbColor: CelestialTheme.goldPrimary,
                        onChanged: (val) => setDialogState(() => isRequired = val),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Allow Multiple Selections',
                          style: GoogleFonts.outfit(fontSize: 13, color: CelestialTheme.textLight, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Customer can pick multiple (e.g. add-ons/toppings)',
                          style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                        ),
                        value: isMultiSelect,
                        activeThumbColor: CelestialTheme.goldPrimary,
                        onChanged: (val) => setDialogState(() => isMultiSelect = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (isEditing)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      _confirmDeleteCategory(context, posProvider, currentItem, group);
                    },
                    icon: Icon(Icons.delete_outline_rounded, color: CelestialTheme.roseAlert, size: 16),
                    label: Text('Delete Category', style: TextStyle(color: CelestialTheme.roseAlert, fontSize: 12)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;

                    final groups = List<CustomizationGroup>.from(currentItem.customizationGroups);
                    if (isEditing) {
                      final idx = groups.indexWhere((g) => g.id == group.id);
                      if (idx >= 0) {
                        groups[idx] = group.copyWith(
                          title: title,
                          isRequired: isRequired,
                          isMultiSelect: isMultiSelect,
                        );
                      }
                    } else {
                      final newGroup = CustomizationGroup(
                        id: 'grp_${DateTime.now().millisecondsSinceEpoch}',
                        title: title,
                        isRequired: isRequired,
                        isMultiSelect: isMultiSelect,
                        options: presetOptions,
                      );
                      groups.add(newGroup);
                    }

                    final updatedItem = currentItem.copyWith(customizationGroups: groups);
                    posProvider.updateMenuItem(updatedItem);
                    Navigator.pop(dialogCtx);
                    TopNotification.showSuccess(
                      context,
                      isEditing ? 'Category "$title" updated' : 'Added category "$title"',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CelestialTheme.goldPrimary,
                    foregroundColor: CelestialTheme.primaryBtnText,
                  ),
                  child: Text(isEditing ? 'Save Changes' : 'Add Category'),
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
    PosProvider posProvider,
    MenuItem currentItem,
    CustomizationGroup group,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: CelestialTheme.borderSubtle),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: CelestialTheme.roseAlert),
            const SizedBox(width: 8),
            Text('Delete "${group.title}"?', style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'This will remove "${group.title}" and all its ${group.options.length} options from ${currentItem.name}.',
          style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final groups = List<CustomizationGroup>.from(currentItem.customizationGroups)..removeWhere((g) => g.id == group.id);
              final updatedItem = currentItem.copyWith(customizationGroups: groups);
              posProvider.updateMenuItem(updatedItem);
              Navigator.pop(dialogCtx);
              TopNotification.showSuccess(context, 'Deleted category "${group.title}"');
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

  void _showAddOrEditOptionDialog(
    BuildContext context,
    PosProvider posProvider,
    MenuItem currentItem, {
    required CustomizationGroup group,
    CustomizationOption? option,
  }) {
    final isEditing = option != null;
    final nameController = TextEditingController(text: option?.name ?? '');
    final priceController = TextEditingController(
      text: option != null && option.extraPrice > 0 ? option.extraPrice.toStringAsFixed(0) : '0',
    );
    bool isAvail = option?.isAvailable ?? true;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: CelestialTheme.bgSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: CelestialTheme.borderSubtle),
              ),
              title: Row(
                children: [
                  Icon(
                    isEditing ? Icons.tune_rounded : Icons.add_circle_outline_rounded,
                    color: CelestialTheme.goldPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Option in "${group.title}"' : 'Add Option to "${group.title}"',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.textLight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Option Name',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: CelestialTheme.textMuted),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: CelestialTheme.textLight, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. Oat Milk, Extra Shot, Large 22oz',
                        hintStyle: TextStyle(color: CelestialTheme.textMuted.withValues(alpha: 0.6)),
                        filled: true,
                        fillColor: CelestialTheme.bgCard,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CelestialTheme.borderSubtle)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CelestialTheme.borderSubtle)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CelestialTheme.goldPrimary)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Additional Price (₱)',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: CelestialTheme.textMuted),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: CelestialTheme.textLight, fontSize: 14),
                      decoration: InputDecoration(
                        prefixText: '₱ ',
                        prefixStyle: TextStyle(color: CelestialTheme.goldPrimary, fontWeight: FontWeight.bold),
                        hintText: '0 for free',
                        hintStyle: TextStyle(color: CelestialTheme.textMuted.withValues(alpha: 0.6)),
                        filled: true,
                        fillColor: CelestialTheme.bgCard,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CelestialTheme.borderSubtle)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CelestialTheme.borderSubtle)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CelestialTheme.goldPrimary)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Currently Available',
                        style: GoogleFonts.outfit(fontSize: 13, color: CelestialTheme.textLight, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        isAvail ? 'In stock and orderable' : 'Marked sold out',
                        style: TextStyle(
                          fontSize: 11,
                          color: isAvail ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                        ),
                      ),
                      value: isAvail,
                      activeThumbColor: CelestialTheme.emeraldReady,
                      inactiveThumbColor: CelestialTheme.roseAlert,
                      onChanged: (val) => setDialogState(() => isAvail = val),
                    ),
                  ],
                ),
              ),
              actions: [
                if (isEditing)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      _confirmDeleteOption(context, posProvider, currentItem, group, option);
                    },
                    icon: Icon(Icons.delete_outline_rounded, color: CelestialTheme.roseAlert, size: 16),
                    label: Text('Delete Option', style: TextStyle(color: CelestialTheme.roseAlert, fontSize: 12)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final extraPrice = double.tryParse(priceController.text.trim()) ?? 0.0;

                    final groups = List<CustomizationGroup>.from(currentItem.customizationGroups);
                    final gIdx = groups.indexWhere((g) => g.id == group.id);
                    if (gIdx >= 0) {
                      final targetG = groups[gIdx];
                      final options = List<CustomizationOption>.from(targetG.options);
                      if (isEditing) {
                        final optIdx = options.indexWhere((o) => o.name == option.name);
                        if (optIdx >= 0) {
                          options[optIdx] = CustomizationOption(
                            name: name,
                            extraPrice: extraPrice,
                            isAvailable: isAvail,
                          );
                        }
                      } else {
                        options.add(CustomizationOption(
                          name: name,
                          extraPrice: extraPrice,
                          isAvailable: isAvail,
                        ));
                      }
                      groups[gIdx] = targetG.copyWith(options: options);
                      final updatedItem = currentItem.copyWith(customizationGroups: groups);
                      posProvider.updateMenuItem(updatedItem);
                    }

                    Navigator.pop(dialogCtx);
                    TopNotification.showSuccess(
                      context,
                      isEditing ? 'Updated option "$name"' : 'Added option "$name"',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CelestialTheme.goldPrimary,
                    foregroundColor: CelestialTheme.primaryBtnText,
                  ),
                  child: Text(isEditing ? 'Save Changes' : 'Add Option'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteOption(
    BuildContext context,
    PosProvider posProvider,
    MenuItem currentItem,
    CustomizationGroup group,
    CustomizationOption option,
  ) {
    final groups = List<CustomizationGroup>.from(currentItem.customizationGroups);
    final gIdx = groups.indexWhere((g) => g.id == group.id);
    if (gIdx >= 0) {
      final targetG = groups[gIdx];
      final options = List<CustomizationOption>.from(targetG.options)..removeWhere((o) => o.name == option.name);
      groups[gIdx] = targetG.copyWith(options: options);
      final updatedItem = currentItem.copyWith(customizationGroups: groups);
      posProvider.updateMenuItem(updatedItem);
      TopNotification.showSuccess(context, 'Deleted option "${option.name}"');
    }
  }

  void _confirmDeleteItem(
    BuildContext context,
    PosProvider posProvider,
    MenuItem currentItem,
    BuildContext sheetCtx,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: CelestialTheme.roseAlert, size: 24),
            const SizedBox(width: 8),
            Text(
              'Delete Menu Item?',
              style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${currentItem.name}" from the POS menu?',
          style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              posProvider.deleteMenuItem(currentItem.id);
              Navigator.pop(dialogCtx); // close confirmation dialog
              Navigator.pop(sheetCtx); // close bottom sheet
              TopNotification.showSuccess(context, 'Permanently deleted "${currentItem.name}"');
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.roseAlert,
              foregroundColor: Colors.white,
            ),
            label: const Text('Delete Item'),
          ),
        ],
      ),
    );
  }

  Widget _miniStepperBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: CelestialTheme.borderSubtle),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
        ),
      ),
    );
  }

  Widget _stockQuickSetBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: CelestialTheme.borderSubtle),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CelestialTheme.goldLight),
        ),
      ),
    );
  }

  void _showEditPriceDialog(BuildContext context, PosProvider posProvider, MenuItem currentItem) {
    final controller = TextEditingController(text: currentItem.price.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: CelestialTheme.borderSubtle),
        ),
        title: Row(
          children: [
            Icon(Icons.sell_rounded, color: CelestialTheme.goldPrimary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Edit Price: ${currentItem.name}',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Menu Base Price',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: CelestialTheme.textMuted),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: TextStyle(color: CelestialTheme.textLight, fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixText: '₱ ',
                  prefixStyle: TextStyle(color: CelestialTheme.goldPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                  hintText: '0.00',
                  hintStyle: TextStyle(color: CelestialTheme.textMuted.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: CelestialTheme.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CelestialTheme.borderSubtle)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CelestialTheme.borderSubtle)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CelestialTheme.goldPrimary)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final newP = double.tryParse(controller.text.trim());
              if (newP != null && newP >= 0) {
                posProvider.updateItemPrice(currentItem.id, newP);
                Navigator.pop(dCtx);
                TopNotification.showSuccess(context, 'Price updated to ₱${newP.toStringAsFixed(0)}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.goldPrimary,
              foregroundColor: CelestialTheme.primaryBtnText,
            ),
            child: const Text('Update Price'),
          ),
        ],
      ),
    );
  }

  void _showEditStockDialog(BuildContext context, PosProvider posProvider, MenuItem currentItem) {
    final controller = TextEditingController(text: '${currentItem.stockCount}');
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: CelestialTheme.borderSubtle),
        ),
        title: Row(
          children: [
            Icon(Icons.inventory_2_rounded, color: CelestialTheme.caramelAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Edit Stock: ${currentItem.name}',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Stock Level',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: CelestialTheme.textMuted),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(color: CelestialTheme.textLight, fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  suffixText: 'pcs',
                  suffixStyle: TextStyle(color: CelestialTheme.textMuted, fontSize: 13),
                  hintText: '0',
                  hintStyle: TextStyle(color: CelestialTheme.textMuted.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: CelestialTheme.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CelestialTheme.borderSubtle)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CelestialTheme.borderSubtle)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CelestialTheme.caramelAccent)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'QUICK PRESETS',
                style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: CelestialTheme.textMuted),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  _stockQuickSetBtn('0 (Out)', () => controller.text = '0'),
                  _stockQuickSetBtn('25', () => controller.text = '25'),
                  _stockQuickSetBtn('50', () => controller.text = '50'),
                  _stockQuickSetBtn('100', () => controller.text = '100'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final newS = int.tryParse(controller.text.trim());
              if (newS != null && newS >= 0) {
                posProvider.updateStockCount(currentItem.id, newS);
                Navigator.pop(dCtx);
                TopNotification.showSuccess(context, 'Stock updated to $newS pcs');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.goldPrimary,
              foregroundColor: CelestialTheme.primaryBtnText,
            ),
            child: const Text('Update Stock'),
          ),
        ],
      ),
    );
  }

  void _showQuickAvailabilitySheet(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ChangeNotifierProvider.value(
          value: posProvider,
          child: Consumer<PosProvider>(
            builder: (modalCtx, posProvider, _) {
            final items = posProvider.menuItems.where((m) => m.id == widget.item.id);
            if (items.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ctx.mounted) Navigator.pop(ctx);
              });
              return const SizedBox.shrink();
            }
            final currentItem = items.first;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CelestialTheme.bgSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                border: Border.all(color: CelestialTheme.borderSubtle),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Item Bar with Edit & Delete actions
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(currentItem.icon, style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentItem.name,
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                            ),
                            Text(
                              '${currentItem.category.label} • ₱${currentItem.price.toStringAsFixed(0)} • Stock: ${currentItem.stockCount}',
                              style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      // Edit Item Button
                      OutlinedButton.icon(
                        onPressed: () {
                          ItemEditorDialog.show(context, posProvider, currentItem);
                        },
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: const Text('Edit Item', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CelestialTheme.goldPrimary,
                          side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Delete Item Button
                      IconButton(
                        tooltip: 'Delete Menu Item',
                        onPressed: () => _confirmDeleteItem(context, posProvider, currentItem, ctx),
                        icon: Icon(Icons.delete_outline_rounded, color: CelestialTheme.roseAlert, size: 20),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close_rounded, color: CelestialTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Scrollable Body
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Entire Item Availability Switch
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: CelestialTheme.bgCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: currentItem.inStock
                                    ? CelestialTheme.emeraldReady.withValues(alpha: 0.3)
                                    : CelestialTheme.roseAlert.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      currentItem.inStock ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                      color: currentItem.inStock ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Item Availability',
                                          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                                        ),
                                        Text(
                                          currentItem.inStock ? 'Available on POS & Menu' : 'Sold Out / Unavailable',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: currentItem.inStock ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: currentItem.inStock,
                                  activeThumbColor: CelestialTheme.emeraldReady,
                                  inactiveThumbColor: CelestialTheme.roseAlert,
                                  onChanged: (val) {
                                    posProvider.setItemAvailability(currentItem.id, val);
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Quick Price & Stock Management Cards
                          Row(
                            children: [
                              // PRICE CARD
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: CelestialTheme.bgCard,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: CelestialTheme.borderSubtle),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.sell_outlined, size: 14, color: CelestialTheme.goldPrimary),
                                              const SizedBox(width: 5),
                                              Text(
                                                'PRICE',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.6,
                                                  color: CelestialTheme.goldLight,
                                                ),
                                              ),
                                            ],
                                          ),
                                          InkWell(
                                            onTap: () => _showEditPriceDialog(context, posProvider, currentItem),
                                            borderRadius: BorderRadius.circular(4),
                                            child: Padding(
                                              padding: const EdgeInsets.all(2),
                                              child: Icon(Icons.edit_rounded, size: 14, color: CelestialTheme.goldLight),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      InkWell(
                                        onTap: () => _showEditPriceDialog(context, posProvider, currentItem),
                                        child: Text(
                                          '₱${currentItem.price.toStringAsFixed(0)}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 19,
                                            fontWeight: FontWeight.bold,
                                            color: CelestialTheme.textLight,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _miniStepperBtn('-10', () {
                                            final newP = (currentItem.price - 10).clamp(0.0, 99999.0);
                                            posProvider.updateItemPrice(currentItem.id, newP);
                                          }),
                                          const SizedBox(width: 5),
                                          _miniStepperBtn('+10', () {
                                            final newP = (currentItem.price + 10).clamp(0.0, 99999.0);
                                            posProvider.updateItemPrice(currentItem.id, newP);
                                          }),
                                          const Spacer(),
                                          TextButton(
                                            onPressed: () => _showEditPriceDialog(context, posProvider, currentItem),
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: Text('Edit', style: TextStyle(fontSize: 11, color: CelestialTheme.goldPrimary, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // STOCK CARD
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: CelestialTheme.bgCard,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: currentItem.stockCount == 0
                                          ? CelestialTheme.roseAlert.withValues(alpha: 0.4)
                                          : CelestialTheme.borderSubtle,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.inventory_2_outlined, size: 14, color: CelestialTheme.caramelAccent),
                                              const SizedBox(width: 5),
                                              Text(
                                                'STOCK',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.6,
                                                  color: CelestialTheme.caramelAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                          InkWell(
                                            onTap: () => _showEditStockDialog(context, posProvider, currentItem),
                                            borderRadius: BorderRadius.circular(4),
                                            child: Padding(
                                              padding: const EdgeInsets.all(2),
                                              child: Icon(Icons.edit_rounded, size: 14, color: CelestialTheme.caramelAccent),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      InkWell(
                                        onTap: () => _showEditStockDialog(context, posProvider, currentItem),
                                        child: Row(
                                          children: [
                                            Text(
                                              '${currentItem.stockCount}',
                                              style: GoogleFonts.outfit(
                                                fontSize: 19,
                                                fontWeight: FontWeight.bold,
                                                color: currentItem.stockCount == 0 ? CelestialTheme.roseAlert : CelestialTheme.textLight,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text('pcs', style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted)),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: currentItem.stockCount == 0
                                                    ? CelestialTheme.roseAlert.withValues(alpha: 0.2)
                                                    : currentItem.stockCount <= 10
                                                        ? Colors.amber.withValues(alpha: 0.2)
                                                        : CelestialTheme.emeraldReady.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                currentItem.stockCount == 0
                                                    ? 'Out'
                                                    : currentItem.stockCount <= 10
                                                        ? 'Low'
                                                        : 'OK',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: currentItem.stockCount == 0
                                                      ? CelestialTheme.roseAlert
                                                      : currentItem.stockCount <= 10
                                                          ? Colors.amber
                                                          : CelestialTheme.emeraldReady,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _miniStepperBtn('-1', () {
                                            final newS = (currentItem.stockCount - 1).clamp(0, 9999);
                                            posProvider.updateStockCount(currentItem.id, newS);
                                          }),
                                          const SizedBox(width: 5),
                                          _miniStepperBtn('+5', () {
                                            final newS = (currentItem.stockCount + 5).clamp(0, 9999);
                                            posProvider.updateStockCount(currentItem.id, newS);
                                          }),
                                          const Spacer(),
                                          TextButton(
                                            onPressed: () => _showEditStockDialog(context, posProvider, currentItem),
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: Text('Edit', style: TextStyle(fontSize: 11, color: CelestialTheme.caramelAccent, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Option Categories Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'MODIFIERS & OPTION CATEGORIES',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: CelestialTheme.goldLight,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // + Add Category Button
                                  ElevatedButton.icon(
                                    onPressed: () => _showAddOrEditCategoryDialog(context, posProvider, currentItem),
                                    icon: const Icon(Icons.add_rounded, size: 15),
                                    label: const Text('Add Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                                      foregroundColor: CelestialTheme.goldPrimary,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Studio Button
                                  IconButton(
                                    tooltip: 'Advanced Customization Studio',
                                    icon: Icon(Icons.tune_rounded, size: 18, color: CelestialTheme.caramelAccent),
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      CustomizationsEditorDialog.show(
                                        context,
                                        initialGroups: currentItem.customizationGroups,
                                        onSave: (newGroups) {
                                          final updated = currentItem.copyWith(customizationGroups: newGroups);
                                          posProvider.updateMenuItem(updated);
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Empty state if no groups exist
                          if (currentItem.customizationGroups.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: CelestialTheme.bgCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: CelestialTheme.borderSubtle),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.tune_rounded, size: 28, color: CelestialTheme.goldLight.withValues(alpha: 0.6)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No Option Categories Yet',
                                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Add categories like Size, Temperature, Sweetness, or Add-ons to give customers customization choices.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: () => _showAddOrEditCategoryDialog(context, posProvider, currentItem),
                                    icon: const Icon(Icons.add_rounded, size: 16),
                                    label: const Text('Add First Category'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: CelestialTheme.goldPrimary,
                                      foregroundColor: CelestialTheme.primaryBtnText,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Reorderable Group lists
                          if (currentItem.customizationGroups.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(Icons.swap_vert_rounded, size: 14, color: CelestialTheme.goldLight),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Drag grip to reorder • Section #1 is shown first to customers',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: CelestialTheme.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              itemCount: currentItem.customizationGroups.length,
                              // ignore: deprecated_member_use
                              onReorder: (oldIndex, newIndex) {
                                if (oldIndex < newIndex) newIndex -= 1;
                                if (oldIndex == newIndex) return;
                                final groups = List<CustomizationGroup>.from(currentItem.customizationGroups);
                                final movedGroup = groups.removeAt(oldIndex);
                                groups.insert(newIndex, movedGroup);
                                final updatedItem = currentItem.copyWith(customizationGroups: groups);
                                posProvider.updateMenuItem(updatedItem);
                                TopNotification.showSuccess(
                                  context,
                                  newIndex == 0
                                      ? '"${movedGroup.title}" is now the 1st section'
                                      : 'Moved "${movedGroup.title}" to #${newIndex + 1}',
                                );
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
                                final g = currentItem.customizationGroups[index];
                                final isFirstSection = index == 0;

                                return Container(
                                  key: ValueKey(g.id),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: CelestialTheme.bgCard.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isFirstSection
                                          ? CelestialTheme.goldPrimary.withValues(alpha: 0.4)
                                          : CelestialTheme.borderSubtle.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Category title row with drag handle, badges, and action buttons
                                      Row(
                                        children: [
                                          // Drag Grip Handle & Position Indicator
                                          ReorderableDragStartListener(
                                            index: index,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isFirstSection
                                                    ? CelestialTheme.goldPrimary.withValues(alpha: 0.2)
                                                    : Colors.white.withValues(alpha: 0.05),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isFirstSection
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
                                                    color: isFirstSection
                                                        ? CelestialTheme.goldPrimary
                                                        : CelestialTheme.textMuted,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    isFirstSection ? '1ST' : '#${index + 1}',
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: isFirstSection
                                                          ? CelestialTheme.goldPrimary
                                                          : CelestialTheme.textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Title & Badges
                                          Expanded(
                                            child: Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                Text(
                                                  g.title,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: CelestialTheme.textLight,
                                                  ),
                                                ),
                                                // Required/Optional Badge
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: g.isRequired ? CelestialTheme.goldPrimary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.06),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(
                                                      color: g.isRequired ? CelestialTheme.goldPrimary.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.1),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    g.isRequired ? 'Required' : 'Optional',
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: g.isRequired ? CelestialTheme.goldLight : CelestialTheme.textMuted,
                                                    ),
                                                  ),
                                                ),
                                                // Multi-select Badge
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: g.isMultiSelect ? CelestialTheme.caramelAccent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.06),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(
                                                      color: g.isMultiSelect ? CelestialTheme.caramelAccent.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.1),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    g.isMultiSelect ? 'Multi-select' : 'Single-select',
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: g.isMultiSelect ? CelestialTheme.caramelAccent : CelestialTheme.textMuted,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          // Action Buttons
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Move to 1st Section Button (1-tap shortcut)
                                              if (!isFirstSection)
                                                IconButton(
                                                  tooltip: 'Move to 1st section',
                                                  icon: Icon(Icons.vertical_align_top_rounded, size: 16, color: CelestialTheme.goldLight),
                                                  padding: const EdgeInsets.all(4),
                                                  constraints: const BoxConstraints(),
                                                  onPressed: () {
                                                    final groups = List<CustomizationGroup>.from(currentItem.customizationGroups);
                                                    final moved = groups.removeAt(index);
                                                    groups.insert(0, moved);
                                                    final updatedItem = currentItem.copyWith(customizationGroups: groups);
                                                    posProvider.updateMenuItem(updatedItem);
                                                    TopNotification.showSuccess(context, '"${moved.title}" is now the 1st section');
                                                  },
                                                ),
                                              if (!isFirstSection) const SizedBox(width: 2),
                                              // Edit Category Button
                                              IconButton(
                                                tooltip: 'Edit Category',
                                                icon: Icon(Icons.edit_rounded, size: 15, color: CelestialTheme.goldLight),
                                                padding: const EdgeInsets.all(4),
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _showAddOrEditCategoryDialog(context, posProvider, currentItem, group: g),
                                              ),
                                              const SizedBox(width: 2),
                                              // Delete Category Button
                                              IconButton(
                                                tooltip: 'Delete Category',
                                                icon: Icon(Icons.delete_outline_rounded, size: 16, color: CelestialTheme.roseAlert),
                                                padding: const EdgeInsets.all(4),
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _confirmDeleteCategory(context, posProvider, currentItem, g),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Option chips + Add Option button
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          ...g.options.map((opt) {
                                            final isAvail = opt.isAvailable;
                                            return InkWell(
                                              onTap: () {
                                                posProvider.toggleOptionAvailability(currentItem.id, g.id, opt.name, !isAvail);
                                              },
                                              onLongPress: () {
                                                _showAddOrEditOptionDialog(context, posProvider, currentItem, group: g, option: opt);
                                              },
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: isAvail
                                                      ? CelestialTheme.bgCard
                                                      : CelestialTheme.roseAlert.withValues(alpha: 0.18),
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
                                                    if (opt.extraPrice > 0) ...[
                                                      const SizedBox(width: 4),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          '+₱${opt.extraPrice.toStringAsFixed(0)}',
                                                          style: TextStyle(
                                                            fontSize: 9.5,
                                                            fontWeight: FontWeight.bold,
                                                            color: CelestialTheme.goldLight,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                    const SizedBox(width: 4),
                                                    InkWell(
                                                      onTap: () {
                                                        _showAddOrEditOptionDialog(context, posProvider, currentItem, group: g, option: opt);
                                                      },
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(2),
                                                        child: Icon(
                                                          Icons.edit_rounded,
                                                          size: 12,
                                                          color: isAvail ? CelestialTheme.textMuted : CelestialTheme.roseAlert,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }),

                                          // + Add Option Button Chip
                                          InkWell(
                                            onTap: () {
                                              _showAddOrEditOptionDialog(context, posProvider, currentItem, group: g);
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: CelestialTheme.goldPrimary.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
                                                  style: BorderStyle.solid,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.add_rounded,
                                                    size: 13,
                                                    color: CelestialTheme.goldPrimary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Add Option',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: CelestialTheme.goldPrimary,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  // Footer Bar
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '💡 Tap option to toggle in-stock • Tap pencil to edit or delete',
                          style: TextStyle(fontSize: 10.5, color: CelestialTheme.textMuted, fontStyle: FontStyle.italic),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CelestialTheme.goldPrimary,
                          foregroundColor: CelestialTheme.primaryBtnText,
                        ),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

  void _openCustomization(BuildContext context) {
    if (!widget.item.inStock) {
      _showQuickAvailabilitySheet(context);
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => CustomizationDialog(
        item: widget.item,
        onAddToCart: (quantity, customizations, notes) {
          final posProvider = Provider.of<PosProvider>(context, listen: false);
          posProvider.addToCart(
            widget.item,
            quantity: quantity,
            customizations: customizations,
            notes: notes,
          );

          ScaffoldMessenger.of(context).clearSnackBars();
          TopNotification.showSuccess(
            context,
            'Added ${widget.item.name} to order',
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 180;

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: item.inStock ? SystemMouseCursors.click : SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _openCustomization(context),
            onLongPress: () => _showQuickAvailabilitySheet(context),
            onSecondaryTap: () => _showQuickAvailabilitySheet(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: _isHovered ? CelestialTheme.bgCardHover : CelestialTheme.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isHovered
                      ? CelestialTheme.caramelAccent.withValues(alpha: 0.45)
                      : CelestialTheme.borderSubtle,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _isHovered ? 0.35 : 0.22),
                    blurRadius: _isHovered ? 14 : 8,
                    offset: Offset(0, _isHovered ? 5 : 3),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Inset Rounded Image with subtle tactile frame
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            isCompact ? 8 : 10,
                            isCompact ? 8 : 10,
                            isCompact ? 8 : 10,
                            0,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _buildItemMediaCover(item, isCompact),
                          ),
                        ),
                      ),
                      
                      // Details & Actions
                      Padding(
                        padding: EdgeInsets.all(isCompact ? 8 : 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Item Name in warm cream
                            Text(
                              item.name,
                              style: GoogleFonts.outfit(
                                fontSize: isCompact ? 13.5 : 15.5,
                                fontWeight: FontWeight.bold,
                                color: item.inStock ? CelestialTheme.textLight : CelestialTheme.textSubtle,
                                height: 1.15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            
                            const SizedBox(height: 3),
                            
                            // Category Tag in Warm Toasted Beige
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.category.label.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: isCompact ? 9.5 : 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: CelestialTheme.warmBeige,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                if (item.inStock && item.hasUnavailableOptions) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: CelestialTheme.amberBrewing.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: CelestialTheme.amberBrewing.withValues(alpha: 0.5)),
                                    ),
                                    child: Text(
                                      '⚠️ ${item.unavailableOptionsCount} Sold Out',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: CelestialTheme.amberBrewing,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            
                            if (item.description.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                item.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: isCompact ? 10 : 11,
                                  color: CelestialTheme.textMuted,
                                  height: 1.2,
                                ),
                              ),
                            ],
                            
                            const SizedBox(height: 6),
                            
                            // Bottom Row: Price & Tactile Circular '+' Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    '₱${item.price.toStringAsFixed(0)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: isCompact ? 16 : 18.5,
                                      fontWeight: FontWeight.w800,
                                      color: item.inStock ? Colors.white : CelestialTheme.textSubtle,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (item.inStock) ...[
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => _openCustomization(context),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      width: isCompact ? 32 : 38,
                                      height: isCompact ? 32 : 38,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: CelestialTheme.caramelAccent,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.30),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.add_rounded,
                                        color: CelestialTheme.creamLight,
                                        size: isCompact ? 18 : 22,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Sold Out Overlay
                  if (!item.inStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: CelestialTheme.roseAlert.withValues(alpha: 0.25),
                                  border: Border.all(color: CelestialTheme.roseAlert),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'SOLD OUT',
                                  style: TextStyle(
                                    color: CelestialTheme.roseAlert,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9.5,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Tap to manage',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
  }