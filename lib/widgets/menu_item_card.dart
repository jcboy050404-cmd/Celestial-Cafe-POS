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

  Widget _buildItemMediaCover(MenuItem item, bool isCompact) {
    final bool hasBase64 = item.imageBase64 != null && item.imageBase64!.isNotEmpty;
    final bool hasAsset = item.imagePath != null && item.imagePath!.isNotEmpty && item.imagePath!.startsWith('assets/');
    final bool hasFile = item.imagePath != null && item.imagePath!.isNotEmpty && !hasAsset && File(item.imagePath!).existsSync();

    if (hasBase64 || hasAsset || hasFile) {
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF140E18),
        ),
        child: hasBase64
            ? Image.memory(
                base64Decode(item.imageBase64!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(child: Text(item.icon, style: TextStyle(fontSize: isCompact ? 34 : 44))),
              )
            : hasAsset
                ? Image.asset(
                    item.imagePath!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(child: Text(item.icon, style: TextStyle(fontSize: isCompact ? 34 : 44))),
                  )
                : Image.file(
                    File(item.imagePath!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(child: Text(item.icon, style: TextStyle(fontSize: isCompact ? 34 : 44))),
                  ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: item.inStock
            ? CelestialTheme.brownGradient
            : const LinearGradient(
                colors: [Color(0xFF2C2C2C), Color(0xFF1A1A1A)],
              ),
      ),
      child: Center(
        child: Text(
          item.icon,
          style: TextStyle(
            fontSize: isCompact ? 34 : 44,
            color: item.inStock ? null : Colors.grey,
          ),
        ),
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
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final currentItem = posProvider.menuItems.firstWhere(
              (m) => m.id == widget.item.id,
              orElse: () => widget.item,
            );

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
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
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(currentItem.icon, style: const TextStyle(fontSize: 20)),
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
                              '${currentItem.category.label} • ₱${currentItem.price.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
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
                                  currentItem.inStock ? 'Available on POS & Menu' : '86\'d / Out of Stock',
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
                            setModalState(() {});
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),

                  // Customization Groups & Modifiers
                  if (currentItem.customizationGroups.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'MODIFIERS & OPTIONS (86 LIST)',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: CelestialTheme.goldLight),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: currentItem.customizationGroups.map((g) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    g.title,
                                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: CelestialTheme.textLight),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: g.options.map((opt) {
                                      final isAvail = opt.isAvailable;
                                      return InkWell(
                                        onTap: () {
                                          posProvider.toggleOptionAvailability(currentItem.id, g.id, opt.name, !isAvail);
                                          setModalState(() {});
                                          setState(() {});
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
                  ],

                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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
            );
          },
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
              backgroundColor: CelestialTheme.bgSurfaceLight,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(
                  color: CelestialTheme.borderSubtle,
                ),
              ),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: CelestialTheme.caramelAccent, size: 20),
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
                                Flexible(
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
                                      '⚠️ ${item.unavailableOptionsCount} 86\'d',
                                      style: const TextStyle(
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
                                Text(
                                  '₱${item.price.toStringAsFixed(0)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: isCompact ? 16 : 18.5,
                                    fontWeight: FontWeight.w800,
                                    color: item.inStock ? Colors.white : CelestialTheme.textSubtle,
                                  ),
                                ),
                                if (item.inStock)
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
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Out of Stock Overlay
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
