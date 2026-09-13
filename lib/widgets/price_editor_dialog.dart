import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/menu_item.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import 'item_thumbnail.dart';
import 'top_notification.dart';

class PriceEditorDialog {
  /// Quick Price Editor for a Menu Item, including its Base Price
  /// AND all Customization / Add-on / Flavor & Spice Option Prices.
  static void showQuickPrice(BuildContext context, PosProvider provider, MenuItem item) {
    // Current fresh copy of the item from provider
    final currentItem = provider.menuItems.firstWhere(
      (m) => m.id == item.id,
      orElse: () => item,
    );

    final priceController = TextEditingController(text: currentItem.price.toStringAsFixed(0));
    double tempPrice = currentItem.price;
    bool isSavingPrice = false;
    bool applyModifiersGlobally = true;

    // Track edited extra prices for all customization options in this item:
    // key: "${group.id}:::${opt.name}" -> new extraPrice
    final Map<String, double> tempOptionPrices = {};
    for (final group in currentItem.customizationGroups) {
      for (final opt in group.options) {
        tempOptionPrices['${group.id}:::${opt.name}'] = opt.extraPrice;
      }
    }

    final isMobile = MediaQuery.of(context).size.width < 600;

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
                  Text(currentItem.icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price Control & Modifiers',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.goldLight,
                          ),
                        ),
                        Text(
                          currentItem.name,
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
                width: isMobile ? double.infinity : 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Base Item Price Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: CelestialTheme.brownGradient,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'BASE ITEM PRICE (₱)',
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

                      const SizedBox(height: 12),

                      // Manual Base Price Input
                      TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
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
                          labelText: 'Edit Base Selling Price (₱)',
                          labelStyle: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                          prefixIcon: Padding(
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

                      const SizedBox(height: 10),

                      // Quick Step Buttons for Base Price
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

                      // Section 2: Customization & Add-on Prices (Flavor & Spice, Add-ons, Rice Choice, etc.)
                      if (currentItem.customizationGroups.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Divider(color: CelestialTheme.borderWarm, height: 1),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 16, color: CelestialTheme.goldPrimary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ADD-ONS, FLAVORS & OPTIONS PRICING',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                      color: CelestialTheme.goldLight,
                                    ),
                                  ),
                                  Text(
                                    'Tap any option badge to edit its additional price',
                                    style: TextStyle(fontSize: 10, color: CelestialTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Global propagation toggle
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: CelestialTheme.bgSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: CelestialTheme.borderWarm),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.public_rounded, size: 14, color: CelestialTheme.goldPrimary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Apply modifier prices across all menu items',
                                  style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textLight),
                                ),
                              ),
                              Switch.adaptive(
                                value: applyModifiersGlobally,
                                activeThumbColor: CelestialTheme.goldPrimary,
                                activeTrackColor: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                                onChanged: (val) => setDialogState(() => applyModifiersGlobally = val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // List of groups and options
                        ...currentItem.customizationGroups.map((group) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: CelestialTheme.bgCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.title,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: CelestialTheme.goldPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...group.options.map((opt) {
                                  final key = '${group.id}:::${opt.name}';
                                  final currentExtra = tempOptionPrices[key] ?? opt.extraPrice;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            opt.name,
                                            style: GoogleFonts.outfit(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w500,
                                              color: CelestialTheme.textLight,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () {
                                            _showSingleOptionPriceEditorInline(
                                              context: context,
                                              groupTitle: group.title,
                                              optionName: opt.name,
                                              initialPrice: currentExtra,
                                              onSaved: (newVal) {
                                                setDialogState(() {
                                                  tempOptionPrices[key] = newVal;
                                                });
                                              },
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                            decoration: BoxDecoration(
                                              color: currentExtra > 0
                                                  ? CelestialTheme.goldPrimary.withValues(alpha: 0.2)
                                                  : CelestialTheme.bgCard,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: currentExtra > 0
                                                    ? CelestialTheme.goldPrimary.withValues(alpha: 0.6)
                                                    : CelestialTheme.borderWarm,
                                                width: 0.9,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  currentExtra > 0
                                                      ? '+₱${currentExtra.toStringAsFixed(0)}'
                                                      : '₱0 (Free)',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: currentExtra > 0
                                                        ? CelestialTheme.goldPrimary
                                                        : CelestialTheme.textMuted,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(Icons.edit, size: 10.5, color: CelestialTheme.goldPrimary),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        }),
                      ],
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
                  onPressed: isSavingPrice
                      ? null
                      : () async {
                          final finalPrice = double.tryParse(priceController.text.trim()) ?? tempPrice;
                          if (finalPrice >= 0) {
                            setDialogState(() => isSavingPrice = true);

                            // 1. Update base item price
                            provider.updateItemPrice(currentItem.id, finalPrice);

                            // 2. Update all modified customization option prices
                            for (final entry in tempOptionPrices.entries) {
                              final parts = entry.key.split(':::');
                              if (parts.length == 2) {
                                final gId = parts[0];
                                final optName = parts[1];
                                final newExtra = entry.value;

                                provider.updateCustomizationOptionPrice(
                                  itemId: currentItem.id,
                                  groupId: gId,
                                  optionName: optName,
                                  newExtraPrice: newExtra,
                                  applyGlobally: applyModifiersGlobally,
                                );
                              }
                            }

                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              TopNotification.showSuccess(
                                context,
                                '✨ Updated prices for ${currentItem.name} successfully!',
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CelestialTheme.goldPrimary,
                    foregroundColor: CelestialTheme.primaryBtnText,
                  ),
                  child: isSavingPrice
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: CelestialTheme.primaryBtnText),
                        )
                      : const Text('Save All Prices', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Dedicated modal for editing the price of any single customization option
  /// (e.g. from CustomizationDialog, Settings, or Modifier Availability sheets).
  static void showOptionPriceEditor(
    BuildContext context,
    PosProvider provider, {
    required String itemId,
    required String groupId,
    required String groupTitle,
    required CustomizationOption option,
    bool defaultApplyGlobally = true,
    VoidCallback? onSaved,
  }) {
    double tempExtraPrice = option.extraPrice;
    final controller = TextEditingController(text: option.extraPrice.toStringAsFixed(0));
    bool applyGlobally = defaultApplyGlobally;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: CelestialTheme.bgSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
              ),
              title: Row(
                children: [
                  Icon(Icons.price_change_rounded, color: CelestialTheme.goldPrimary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Option Price',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.goldLight,
                          ),
                        ),
                        Text(
                          '$groupTitle • ${option.name}',
                          style: GoogleFonts.outfit(fontSize: 12, color: CelestialTheme.textMuted),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: CelestialTheme.brownGradient,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'EXTRA PRICE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: CelestialTheme.goldLight,
                            ),
                          ),
                          Text(
                            tempExtraPrice > 0 ? '+₱${tempExtraPrice.toStringAsFixed(0)}' : '₱0 (Free)',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.goldLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.textLight,
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val);
                        if (parsed != null && parsed >= 0) {
                          setDlgState(() => tempExtraPrice = parsed);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Additional Price (₱)',
                        labelStyle: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                        prefixIcon: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          child: Text(
                            '+₱',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.goldPrimary,
                            ),
                          ),
                        ),
                        filled: true,
                        fillColor: CelestialTheme.bgCard,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Quick buttons: 0, 5, 10, 15, 20, 25, 30, 35
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 35.0].map((val) {
                        final isSelected = tempExtraPrice == val;
                        return ActionChip(
                          label: Text(
                            val == 0 ? 'Free' : '+₱${val.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? CelestialTheme.bgDark : CelestialTheme.goldLight,
                            ),
                          ),
                          backgroundColor: isSelected ? CelestialTheme.goldPrimary : CelestialTheme.bgCard,
                          side: BorderSide(
                            color: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
                          ),
                          onPressed: () {
                            setDlgState(() {
                              tempExtraPrice = val;
                              controller.text = val.toStringAsFixed(0);
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),

                    // Global Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: CelestialTheme.borderWarm),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.public_rounded, size: 14, color: CelestialTheme.goldPrimary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Apply to all menu items',
                              style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textLight),
                            ),
                          ),
                          Switch.adaptive(
                            value: applyGlobally,
                            activeThumbColor: CelestialTheme.goldPrimary,
                            activeTrackColor: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                            onChanged: (val) => setDlgState(() => applyGlobally = val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final finalPrice = double.tryParse(controller.text.trim()) ?? tempExtraPrice;
                    provider.updateCustomizationOptionPrice(
                      itemId: itemId,
                      groupId: groupId,
                      optionName: option.name,
                      newExtraPrice: finalPrice,
                      applyGlobally: applyGlobally,
                    );
                    Navigator.pop(ctx);
                    onSaved?.call();
                    TopNotification.showSuccess(
                      context,
                      '✨ ${option.name} price updated to +₱${finalPrice.toStringAsFixed(0)}',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CelestialTheme.goldPrimary,
                    foregroundColor: CelestialTheme.primaryBtnText,
                  ),
                  child: const Text('Save Price', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static void _showSingleOptionPriceEditorInline({
    required BuildContext context,
    required String groupTitle,
    required String optionName,
    required double initialPrice,
    required ValueChanged<double> onSaved,
  }) {
    double temp = initialPrice;
    final ctrl = TextEditingController(text: initialPrice.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: CelestialTheme.bgSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Edit Extra Price',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: CelestialTheme.goldLight,
                    ),
                  ),
                  Text(
                    '$groupTitle • $optionName',
                    style: GoogleFonts.outfit(fontSize: 12, color: CelestialTheme.textMuted),
                  ),
                ],
              ),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: ctrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.textLight,
                      ),
                      onChanged: (v) {
                        final p = double.tryParse(v);
                        if (p != null && p >= 0) setDlgState(() => temp = p);
                      },
                      decoration: InputDecoration(
                        labelText: 'Extra Price (₱)',
                        prefixIcon: Padding(
                          padding: EdgeInsets.all(10),
                          child: Text('+₱', style: TextStyle(color: CelestialTheme.goldPrimary, fontWeight: FontWeight.bold)),
                        ),
                        filled: true,
                        fillColor: CelestialTheme.bgCard,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 35.0].map((v) {
                        return ActionChip(
                          label: Text(
                            v == 0 ? 'Free' : '+₱${v.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            setDlgState(() {
                              temp = v;
                              ctrl.text = v.toStringAsFixed(0);
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final p = double.tryParse(ctrl.text.trim()) ?? temp;
                    onSaved(p);
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CelestialTheme.goldPrimary,
                    foregroundColor: CelestialTheme.primaryBtnText,
                  ),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Full Price Settings Manager (supports both Base Item Prices
  /// AND Add-ons / Flavors / Modifiers pricing with search).
  static void showPriceSettingsManager(BuildContext context, PosProvider provider) {
    int activeTab = 0; // 0: Base Items, 1: Add-ons & Modifiers
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            // Collect all unique modifiers across the entire menu
            final Map<String, _ModifierSummary> allModifiers = {};
            for (final item in provider.menuItems) {
              for (final group in item.customizationGroups) {
                for (final opt in group.options) {
                  final key = '${group.title}:::${opt.name.trim()}';
                  if (!allModifiers.containsKey(key)) {
                    allModifiers[key] = _ModifierSummary(
                      groupTitle: group.title,
                      groupId: group.id,
                      optionName: opt.name,
                      extraPrice: opt.extraPrice,
                      itemCount: 1,
                    );
                  } else {
                    allModifiers[key]!.itemCount++;
                  }
                }
              }
            }

            final modifierList = allModifiers.values.where((m) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              return m.optionName.toLowerCase().contains(q) || m.groupTitle.toLowerCase().contains(q);
            }).toList();

            final filteredItems = provider.menuItems.where((m) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              return m.name.toLowerCase().contains(q) || m.categoryLabel.toLowerCase().contains(q);
            }).toList();

            return AlertDialog(
              backgroundColor: CelestialTheme.bgSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
              ),
              title: Row(
                children: [
                  Icon(Icons.price_change_rounded, color: CelestialTheme.goldPrimary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Store Price Control',
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
                width: 520,
                height: 500,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    TextField(
                      onChanged: (val) => setDlgState(() => searchQuery = val.trim()),
                      style: TextStyle(fontSize: 13, color: CelestialTheme.textLight),
                      decoration: InputDecoration(
                        hintText: activeTab == 0 ? 'Search menu items...' : 'Search add-ons, flavors, spices, rice...',
                        hintStyle: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                        prefixIcon: Icon(Icons.search, size: 18, color: CelestialTheme.goldPrimary),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: CelestialTheme.bgCard,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Tab Selector
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setDlgState(() => activeTab = 0),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: activeTab == 0 ? CelestialTheme.goldPrimary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    'Base Items (${filteredItems.length})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: activeTab == 0 ? CelestialTheme.bgDark : CelestialTheme.textLight,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setDlgState(() => activeTab = 1),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: activeTab == 1 ? CelestialTheme.goldPrimary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    'Add-ons & Flavors (${modifierList.length})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: activeTab == 1 ? CelestialTheme.bgDark : CelestialTheme.textLight,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Tab 0: Base Item Prices
                    if (activeTab == 0)
                      Expanded(
                        child: filteredItems.isEmpty
                            ? Center(child: Text('No items match search', style: TextStyle(color: CelestialTheme.textMuted)))
                            : ListView.separated(
                                itemCount: filteredItems.length,
                                separatorBuilder: (c, i) => Divider(height: 1, color: CelestialTheme.borderWarm),
                                itemBuilder: (context, index) {
                                  final m = filteredItems[index];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                    leading: ItemThumbnail(
                                      item: m,
                                      width: 36,
                                      height: 36,
                                      borderRadius: BorderRadius.circular(8),
                                      iconSize: 16,
                                    ),
                                    title: Text(
                                      m.name,
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                                    ),
                                    subtitle: Text(
                                      '${m.categoryLabel} • ${m.customizationGroups.length} modifier groups',
                                      style: TextStyle(fontSize: 10, color: CelestialTheme.textMuted),
                                    ),
                                    trailing: InkWell(
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        showQuickPrice(context, provider, m);
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
                                            Icon(Icons.edit, size: 12, color: CelestialTheme.goldPrimary),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),

                    // Tab 1: Add-ons & Modifiers Pricing
                    if (activeTab == 1)
                      Expanded(
                        child: modifierList.isEmpty
                            ? Center(child: Text('No modifiers match search', style: TextStyle(color: CelestialTheme.textMuted)))
                            : ListView.separated(
                                itemCount: modifierList.length,
                                separatorBuilder: (c, i) => Divider(height: 1, color: CelestialTheme.borderWarm),
                                itemBuilder: (context, index) {
                                  final mod = modifierList[index];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                    title: Text(
                                      mod.optionName,
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                                    ),
                                    subtitle: Text(
                                      '${mod.groupTitle} • in ${mod.itemCount} items',
                                      style: TextStyle(fontSize: 10, color: CelestialTheme.textMuted),
                                    ),
                                    trailing: InkWell(
                                      onTap: () {
                                        showOptionPriceEditor(
                                          context,
                                          provider,
                                          itemId: '',
                                          groupId: mod.groupId,
                                          groupTitle: mod.groupTitle,
                                          option: CustomizationOption(name: mod.optionName, extraPrice: mod.extraPrice),
                                          defaultApplyGlobally: true,
                                          onSaved: () => setDlgState(() {}),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: mod.extraPrice > 0
                                              ? CelestialTheme.goldPrimary.withValues(alpha: 0.2)
                                              : CelestialTheme.bgCard,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: mod.extraPrice > 0
                                                ? CelestialTheme.goldPrimary.withValues(alpha: 0.5)
                                                : CelestialTheme.borderWarm,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              mod.extraPrice > 0 ? '+₱${mod.extraPrice.toStringAsFixed(0)}' : '₱0 (Free)',
                                              style: GoogleFonts.outfit(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: mod.extraPrice > 0 ? CelestialTheme.goldPrimary : CelestialTheme.textMuted,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(Icons.edit, size: 11, color: CelestialTheme.goldPrimary),
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
                    foregroundColor: CelestialTheme.isLondon ? Colors.white : CelestialTheme.bgDark,
                  ),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ModifierSummary {
  final String groupTitle;
  final String groupId;
  final String optionName;
  final double extraPrice;
  int itemCount;

  _ModifierSummary({
    required this.groupTitle,
    required this.groupId,
    required this.optionName,
    required this.extraPrice,
    required this.itemCount,
  });
}