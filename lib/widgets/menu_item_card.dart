import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import 'customization_dialog.dart';

class MenuItemCard extends StatefulWidget {
  final MenuItem item;

  const MenuItemCard({super.key, required this.item});

  @override
  State<MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<MenuItemCard> {
  bool _isHovered = false;

  Widget _buildItemMedia(MenuItem item, bool isCompact) {
    final bool hasBase64 = item.imageBase64 != null && item.imageBase64!.isNotEmpty;
    final bool hasFile = item.imagePath != null && item.imagePath!.isNotEmpty && File(item.imagePath!).existsSync();

    final size = isCompact ? 36.0 : 42.0;

    if (hasBase64 || hasFile) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: item.inStock
                ? CelestialTheme.goldPrimary.withValues(alpha: 0.45)
                : Colors.white12,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: hasBase64
              ? Image.memory(
                  base64Decode(item.imageBase64!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(child: Text(item.icon, style: TextStyle(fontSize: isCompact ? 16 : 20))),
                )
              : Image.file(
                  File(item.imagePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(child: Text(item.icon, style: TextStyle(fontSize: isCompact ? 16 : 20))),
                ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: item.inStock
            ? CelestialTheme.brownGradient
            : const LinearGradient(
                colors: [Color(0xFF2C2C2C), Color(0xFF1A1A1A)],
              ),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: item.inStock
              ? CelestialTheme.goldPrimary.withValues(alpha: 0.35)
              : Colors.white12,
        ),
      ),
      child: Center(
        child: Text(
          item.icon,
          style: TextStyle(
            fontSize: isCompact ? 18 : 22,
            color: item.inStock ? null : Colors.grey,
          ),
        ),
      ),
    );
  }

  void _openCustomization(BuildContext context) {
    if (!widget.item.inStock) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
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

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: CelestialTheme.bgCard,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
                ),
              ),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: CelestialTheme.goldPrimary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Added ${widget.item.name} to order',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  void _quickAdd(BuildContext context) {
    if (!widget.item.inStock) return;

    final posProvider = Provider.of<PosProvider>(context, listen: false);
    posProvider.addToCart(widget.item);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: CelestialTheme.bgCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
          ),
        ),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: CelestialTheme.goldPrimary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Added ${widget.item.name}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 1),
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
          cursor: item.inStock ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
          child: GestureDetector(
            onTap: () => _openCustomization(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: _isHovered ? CelestialTheme.bgCardHover : CelestialTheme.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isHovered
                      ? CelestialTheme.goldPrimary
                      : CelestialTheme.goldPrimary.withValues(alpha: 0.22),
                  width: _isHovered ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                  if (_isHovered)
                    BoxShadow(
                      color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.all(isCompact ? 9 : 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top Row: Thumbnail & Category Tag
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildItemMedia(item, isCompact),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: CelestialTheme.brownWarm.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: CelestialTheme.goldPrimary.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Text(
                                    item.tags.isNotEmpty ? item.tags.first : item.category.label,
                                    style: const TextStyle(
                                      fontSize: 9.0,
                                      fontWeight: FontWeight.w600,
                                      color: CelestialTheme.goldLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Item Name & Description
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: GoogleFonts.outfit(
                                fontSize: isCompact ? 13 : 14,
                                fontWeight: FontWeight.bold,
                                color: item.inStock
                                    ? CelestialTheme.textLight
                                    : CelestialTheme.textSubtle,
                                height: 1.15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.description,
                              style: GoogleFonts.outfit(
                                fontSize: isCompact ? 9.5 : 10.5,
                                color: CelestialTheme.textMuted,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),

                        // Bottom Row: Price & [+] [Opt] Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '₱${item.price.toStringAsFixed(0)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: isCompact ? 15 : 17,
                                    fontWeight: FontWeight.w800,
                                    color: item.inStock
                                        ? CelestialTheme.goldLight
                                        : CelestialTheme.textSubtle,
                                  ),
                                ),
                                if (item.inStock && item.stockCount <= 15)
                                  Text(
                                    '${item.stockCount} left',
                                    style: const TextStyle(
                                      fontSize: 8.0,
                                      color: CelestialTheme.amberBrewing,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),

                            if (item.inStock)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Quick Add Button (+)
                                  InkWell(
                                    onTap: () => _quickAdd(context),
                                    borderRadius: BorderRadius.circular(7),
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: CelestialTheme.bgSurface,
                                        borderRadius: BorderRadius.circular(7),
                                        border: Border.all(
                                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.add_rounded,
                                        size: 15,
                                        color: CelestialTheme.goldPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  // Customization Option Button (Opt)
                                  InkWell(
                                    onTap: () => _openCustomization(context),
                                    borderRadius: BorderRadius.circular(7),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                                      decoration: BoxDecoration(
                                        gradient: CelestialTheme.goldGradient,
                                        borderRadius: BorderRadius.circular(7),
                                        boxShadow: [
                                          BoxShadow(
                                            color: CelestialTheme.goldPrimary.withValues(alpha: 0.25),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        'Opt',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: CelestialTheme.bgDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Out of Stock Overlay
                  if (!item.inStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: CelestialTheme.roseAlert.withValues(alpha: 0.25),
                              border: Border.all(color: CelestialTheme.roseAlert),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'OUT OF STOCK',
                              style: TextStyle(
                                color: CelestialTheme.roseAlert,
                                fontWeight: FontWeight.bold,
                                fontSize: 9.5,
                                letterSpacing: 0.8,
                              ),
                            ),
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
