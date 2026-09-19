import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/menu_item.dart';
import '../theme/celestial_theme.dart';
import 'item_thumbnail.dart';
import 'top_notification.dart';

/// Customer-facing menu item card matching the cashier POS item card layout,
/// typography, tactile border effects, and responsive visual hierarchy.
class ClientMenuItemCard extends StatefulWidget {
  final MenuItem item;
  final int inCartCount;
  final bool isStoreOpen;
  final String? customNotice;
  final VoidCallback onTap;

  const ClientMenuItemCard({
    super.key,
    required this.item,
    required this.inCartCount,
    required this.isStoreOpen,
    this.customNotice,
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
            onTap: isAvailable
                ? widget.onTap
                : () {
                    if (!widget.isStoreOpen) {
                      final closedMsg = widget.customNotice?.trim().isNotEmpty == true
                          ? widget.customNotice!.trim()
                          : 'The café is currently closed. Online orders cannot be placed right now.';
                      TopNotification.show(
                        context,
                        message: closedMsg,
                        type: TopNotificationType.warning,
                      );
                      widget.onTap();
                    } else {
                      TopNotification.show(
                        context,
                        message: '${item.name} is currently sold out.',
                        type: TopNotificationType.info,
                      );
                    }
                  },
            child: AnimatedScale(
              scale: _isHovered ? 1.025 : 1.0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  color: _isHovered ? CelestialTheme.bgCardHover : CelestialTheme.bgCard,
                  borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                  border: Border.all(
                    color: widget.inCartCount > 0
                        ? CelestialTheme.goldPrimary.withValues(alpha: _isHovered ? 0.8 : 0.5)
                        : (_isHovered
                            ? Colors.white.withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.06)),
                    width: widget.inCartCount > 0 ? 1.4 : 1.0,
                  ),
                  boxShadow: [
                    if (widget.inCartCount > 0)
                      BoxShadow(
                        color: CelestialTheme.goldPrimary.withValues(alpha: _isHovered ? 0.25 : 0.12),
                        blurRadius: _isHovered ? 16 : 10,
                        offset: const Offset(0, 2),
                      ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: _isHovered ? 0.35 : 0.18),
                      blurRadius: _isHovered ? 14 : 6,
                      offset: Offset(0, _isHovered ? 5 : 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Inset Rounded Image with tactile frame & subtle zoom
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
                                  AnimatedScale(
                                    scale: _isHovered ? 1.05 : 1.0,
                                    duration: const Duration(milliseconds: 240),
                                    curve: Curves.easeOutQuad,
                                    child: _buildItemMediaCover(item, isCompact),
                                  ),
                                if (!isAvailable)
                                  Positioned(
                                    bottom: 4,
                                    left: 2,
                                    right: 2,
                                    child: Center(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isMobile ? 4 : 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xE8141113),
                                          borderRadius: BorderRadius.circular(5),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.12),
                                            width: 0.8,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.35),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 4,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: CelestialTheme.roseAlert.withValues(alpha: 0.85),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                !widget.isStoreOpen ? 'STORE CLOSED' : 'SOLD OUT',
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white,
                                                  fontSize: isMobile ? 7.5 : 8.5,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ],
                                          ),
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
                                      horizontal: isMobile ? 4 : 6,
                                      vertical: isMobile ? 1 : 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                                    ),
                                    child: Text(
                                      'Options',
                                      style: TextStyle(
                                        fontSize: isMobile ? 7.5 : 8.5,
                                        fontWeight: FontWeight.w600,
                                        color: CelestialTheme.creamSoft,
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
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    height: isMobile ? 24 : (isCompact ? 28 : 32),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 6 : (isCompact ? 8 : 10),
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: _isHovered ? CelestialTheme.goldGradient : null,
                                      color: _isHovered ? null : CelestialTheme.caramelAccent,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _isHovered
                                              ? CelestialTheme.goldPrimary.withValues(alpha: 0.35)
                                              : Colors.black.withValues(alpha: 0.30),
                                          blurRadius: _isHovered ? 8 : 6,
                                          offset: Offset(0, _isHovered ? 3 : 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add_rounded,
                                          color: _isHovered ? CelestialTheme.bgDark : CelestialTheme.creamLight,
                                          size: isMobile ? 13 : (isCompact ? 16 : 18),
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Add',
                                          style: GoogleFonts.outfit(
                                            color: _isHovered ? CelestialTheme.bgDark : CelestialTheme.creamLight,
                                            fontWeight: FontWeight.bold,
                                            fontSize: isMobile ? 10 : (isCompact ? 11 : 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    height: isMobile ? 22 : (isCompact ? 25 : 28),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 6 : (isCompact ? 8 : 10),
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.09),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        !widget.isStoreOpen ? 'Closed' : 'Sold Out',
                                        style: GoogleFonts.outfit(
                                          color: CelestialTheme.textMuted,
                                          fontWeight: FontWeight.w600,
                                          fontSize: isMobile ? 9 : (isCompact ? 10 : 11),
                                        ),
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

                  // In-cart Badge with springy scale bounce animation
                  Positioned(
                    top: isMobile ? 6 : 10,
                    right: isMobile ? 6 : 10,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.elasticOut,
                      switchOutCurve: Curves.easeInBack,
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: child,
                        );
                      },
                      child: widget.inCartCount > 0
                          ? Container(
                              key: ValueKey('cart_badge_${widget.item.id}_${widget.inCartCount}'),
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 6 : 8,
                                vertical: isMobile ? 2.5 : 3.5,
                              ),
                              decoration: BoxDecoration(
                                gradient: CelestialTheme.goldGradient,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: [
                                  BoxShadow(
                                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.45),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
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
                                  Icon(
                                    Icons.shopping_bag_rounded,
                                    size: isMobile ? 9 : 11,
                                    color: CelestialTheme.bgDark,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${widget.inCartCount}',
                                    style: TextStyle(
                                      fontSize: isMobile ? 10 : 11.5,
                                      fontWeight: FontWeight.w900,
                                      color: CelestialTheme.bgDark,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('empty_badge')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  }
}
