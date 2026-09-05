import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/menu_item.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import 'item_thumbnail.dart';

class PriceEditorDialog {
  static void showQuickPrice(BuildContext context, PosProvider provider, MenuItem item) {
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

  static void showPriceSettingsManager(BuildContext context, PosProvider provider) {
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
                        leading: ItemThumbnail(
                          item: m,
                          width: 34,
                          height: 34,
                          borderRadius: BorderRadius.circular(8),
                          iconSize: 16,
                        ),
                        title: Text(
                          m.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                        ),
                        subtitle: Text(
                          m.categoryLabel,
                          style: const TextStyle(fontSize: 10, color: CelestialTheme.textMuted),
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
}
