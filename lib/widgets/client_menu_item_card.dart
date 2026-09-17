import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/menu_item.dart';
import '../theme/celestial_theme.dart';
import 'item_thumbnail.dart';

/// Customer-facing menu item card matching the cashier POS item card layout,
/// typography, tactile border effects, and responsive visual hierarchy.
class ClientMenuItemCard extends StatefulWidget {
  final MenuItem item;
  final int inCartCount;
  final bool isStoreOpen;
  final VoidCallback onTap;

  const ClientMenuItemCard({
    super.key,
    required this.item,
    required this.inCartCount,
    required this.isStoreOpen,
    required this.onTap,
  });

  @override
  State<ClientMenuItemCard> createState() => _ClientMenuItemCardState();
}

class _ClientMenuItemCardState extends State<ClientMenuItemCard> {
  bool _isHovered = false;

  Widget _buildItemMediaCover(MenuItem item, bool isCompact) {
    return ItemThumbnail(
      item: item,
      width: double.infinity,
      borderRadius: BorderRadius.zero,
      iconSize: isCompact ? 36 : 46,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isAvailable = item.inStock && widget.isStoreOpen;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 145;
        final isCompact = constraints.maxWidth < 180;

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: isAvailable ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            onTap: isAvailable ? widget.onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: _isHovered ? CelestialTheme.bgCardHover : CelestialTheme.bgCard,
                borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                border: Border.all(
                  color: widget.inCartCount > 0
                      ? CelestialTheme.goldPrimary.withValues(alpha: 0.65)
                      : (_isHovered
                          ? CelestialTheme.caramelAccent.withValues(alpha: 0.45)
                          : CelestialTheme.borderSubtle),
                  width: widget.inCartCount > 0 ? 1.5 : 1.0,
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
                      // Inset Rounded Image with tactile frame
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            isMobile ? 6 : (isCompact ? 8 : 10),
                            isMobile ? 6 : (isCompact ? 8 : 10),
                            isMobile ? 6 : (isCompact ? 8 : 10),
                            0,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(isMobile ? 11 : 14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildItemMediaCover(item, isCompact),
                                if (!isAvailable)
                                  Container(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    alignment: Alignment.center,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 5 : 8,
                                        vertical: isMobile ? 2 : 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: CelestialTheme.roseAlert.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        !widget.isStoreOpen ? 'PAUSED' : 'SOLD OUT',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: isMobile ? 8.5 : 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Details & Price Actions
                      Padding(
                        padding: EdgeInsets.all(isMobile ? 6 : (isCompact ? 8 : 10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Item Name
                            Text(
                              item.name,
                              style: GoogleFonts.outfit(
                                fontSize: isMobile ? 12 : (isCompact ? 13.5 : 15.5),
                                fontWeight: FontWeight.bold,
                                color: isAvailable ? CelestialTheme.textLight : CelestialTheme.textSubtle,
                                height: 1.15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),

                            // Category Tag in Warm Toasted Beige
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (item.customCategory ?? item.category.label).toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: isMobile ? 8 : (isCompact ? 9.5 : 10.5),
                                      fontWeight: FontWeight.w700,
                                      color: CelestialTheme.warmBeige,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                if (item.customizationGroups.isNotEmpty) ...[
                                  const SizedBox(width: 3),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 3 : 5,
                                      vertical: isMobile ? 1 : 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      'Options',
                                      style: TextStyle(
                                        fontSize: isMobile ? 7.5 : 8.5,
                                        fontWeight: FontWeight.bold,
                                        color: CelestialTheme.goldLight,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            if (item.description.isNotEmpty && !isMobile) ...[
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

                            SizedBox(height: isMobile ? 4 : 6),

                            // Bottom Row: Price & Tactile Button (matches cashier card '+' and provides 'Add' action)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                 Expanded(
                                   child: Text(
                                     '₱${item.price % 1 == 0 ? item.price.toInt() : item.price.toStringAsFixed(2)}',
                                     style: GoogleFonts.outfit(
                                       fontSize: isMobile ? 12.5 : (isCompact ? 15 : 17.5),
                                       fontWeight: FontWeight.w800,
                                       color: isAvailable ? Colors.white : CelestialTheme.textSubtle,
                                     ),
                                     maxLines: 1,
                                     overflow: TextOverflow.ellipsis,
                                   ),
                                 ),
                                if (isAvailable) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    height: isMobile ? 24 : (isCompact ? 28 : 32),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 6 : (isCompact ? 8 : 10),
                                    ),
                                    decoration: BoxDecoration(
                                      color: CelestialTheme.caramelAccent,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.30),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add_rounded,
                                          color: CelestialTheme.creamLight,
                                          size: isMobile ? 13 : (isCompact ? 16 : 18),
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Add',
                                          style: GoogleFonts.outfit(
                                            color: CelestialTheme.creamLight,
                                            fontWeight: FontWeight.bold,
                                            fontSize: isMobile ? 10 : (isCompact ? 11 : 12),
                                          ),
                                        ),
                                      ],
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

                  // In-cart Badge
                  if (widget.inCartCount > 0)
                    Positioned(
                      top: isMobile ? 6 : 10,
                      right: isMobile ? 6 : 10,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 5 : 7,
                          vertical: isMobile ? 2 : 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: CelestialTheme.goldGradient,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shopping_bag_rounded, size: isMobile ? 8 : 10, color: CelestialTheme.bgDark),
                            const SizedBox(width: 2),
                            Text(
                              '${widget.inCartCount}',
                              style: TextStyle(
                                fontSize: isMobile ? 9.5 : 11,
                                fontWeight: FontWeight.w900,
                                color: CelestialTheme.bgDark,
                              ),
                            ),
                          ],
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
