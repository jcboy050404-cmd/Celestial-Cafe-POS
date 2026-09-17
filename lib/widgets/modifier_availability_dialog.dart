import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/menu_item.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import 'price_editor_dialog.dart';

class ModifierAvailabilityDialog {
  static void show(
    BuildContext context,
    PosProvider posProvider,
    MenuItem item, {
    VoidCallback? onUpdated,
  }) {
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
                width: MediaQuery.of(context).size.width < 540 ? double.infinity : 500,
                constraints: BoxConstraints(
                  maxWidth: 500,
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
                                '${currentItem.name} - Modifier Availability',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.textLight,
                                ),
                              ),
                              Text(
                                'Mark individual sizes, syrups, and add-ons as sold out',
                                style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                              ),
                            ],
                          ),
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
                                          onUpdated?.call();
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
                                              const SizedBox(width: 6),
                                              InkWell(
                                                onTap: () {
                                                  PriceEditorDialog.showOptionPriceEditor(
                                                    context,
                                                    posProvider,
                                                    itemId: currentItem.id,
                                                    groupId: group.id,
                                                    groupTitle: group.title,
                                                    option: opt,
                                                    onSaved: () {
                                                      setDlgState(() {});
                                                      onUpdated?.call();
                                                    },
                                                  );
                                                },
                                                borderRadius: BorderRadius.circular(4),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: opt.extraPrice > 0
                                                        ? CelestialTheme.goldPrimary.withValues(alpha: 0.2)
                                                        : CelestialTheme.bgCard,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(
                                                      color: opt.extraPrice > 0
                                                          ? CelestialTheme.goldPrimary.withValues(alpha: 0.5)
                                                          : CelestialTheme.borderWarm,
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        opt.extraPrice > 0 ? '+₱${opt.extraPrice.toStringAsFixed(0)}' : '₱0',
                                                        style: TextStyle(
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.bold,
                                                          color: opt.extraPrice > 0 ? CelestialTheme.goldLight : CelestialTheme.textMuted,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 2.5),
                                                      Icon(Icons.edit, size: 8.5, color: CelestialTheme.goldPrimary),
                                                    ],
                                                  ),
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
                              onUpdated?.call();
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
                            foregroundColor: CelestialTheme.primaryBtnText,
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
}