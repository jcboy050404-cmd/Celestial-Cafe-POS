import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import 'cart_panel.dart';
import 'settings_dialog.dart';
import 'table_qr_dialog.dart';

class HeaderBar extends StatefulWidget {
  final bool isScrolled;
  const HeaderBar({super.key, this.isScrolled = false});

  @override
  State<HeaderBar> createState() => _HeaderBarState();
}

class _HeaderBarState extends State<HeaderBar> {
  late Timer _timer;
  late DateTime _currentTime;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _openMobileCartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.88,
        child: const CartPanel(isMobileModal: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isCompact = MediaQuery.of(context).size.width < 1000;

    if (isMobile) {
      // Mobile Top App Bar with Liquid Glass Refraction & Scroll Animation
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: widget.isScrolled ? 22 : 16,
            sigmaY: widget.isScrolled ? 22 : 16,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            height: widget.isScrolled ? 54 : 60,
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: widget.isScrolled ? 6 : 8,
            ),
            decoration: CelestialTheme.liquidGlassHeader(
              isMobile: true,
              isScrolled: widget.isScrolled,
            ),
            child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Brand Logo & Compact Title (Tap to open Settings & Logo)
            Expanded(
              child: InkWell(
                onTap: () => _openSettings(context),
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  children: [
                    Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: posProvider.hasCustomLogo
                            ? Image.memory(
                                posProvider.customLogoBytes!,
                                fit: BoxFit.cover,
                              )
                            : Image.asset(
                                'assets/images/Logo.png',
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CELESTIAL',
                            style: GoogleFonts.cinzel(
                              color: CelestialTheme.goldPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                          Text(
                            'Cozy&Classic',
                            style: GoogleFonts.outfit(
                              color: CelestialTheme.goldLight.withValues(alpha: 0.7),
                              fontSize: 8,
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 6),

            // Actions: Pending Approvals, Table QR, Settings & Cart Badge
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pending Customer Orders Alert Pill (Mobile)
                if (posProvider.pendingCustomerOrders.isNotEmpty)
                  InkWell(
                    onTap: () => posProvider.setNavIndex(1),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: CelestialTheme.caramelGradient,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hourglass_top_rounded, size: 14, color: CelestialTheme.bgDark),
                          const SizedBox(width: 4),
                          Text(
                            '${posProvider.pendingCustomerOrders.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.bgDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Table QR Button
                IconButton(
                  onPressed: () => TableQrDialog.show(context),
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: CelestialTheme.goldLight, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  tooltip: 'Table QR Self-Ordering',
                ),

                const SizedBox(width: 2),

                // Text Size / Accessibility Button
                IconButton(
                  onPressed: () => _showQuickTextSizeModal(context),
                  icon: const Icon(Icons.format_size_rounded, color: CelestialTheme.goldLight, size: 19),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  tooltip: 'Adjust Text Size',
                ),

                const SizedBox(width: 2),

                // Settings Button
                IconButton(
                  onPressed: () => _openSettings(context),
                  icon: const Icon(Icons.settings_outlined, color: CelestialTheme.goldLight, size: 19),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  tooltip: 'Store Settings & Logo',
                ),

                const SizedBox(width: 2),

                // Cart Trigger
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: () => _openMobileCartSheet(context),
                      icon: const Icon(Icons.shopping_bag_outlined, color: CelestialTheme.goldPrimary, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      style: IconButton.styleFrom(
                        backgroundColor: CelestialTheme.bgCard,
                      ),
                    ),
                    if (posProvider.cartItemCount > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: CelestialTheme.goldPrimary,
                            shape: BoxShape.circle,
                            border: Border.all(color: CelestialTheme.bgDark, width: 1.2),
                          ),
                          child: Text(
                            '${posProvider.cartItemCount}',
                            style: const TextStyle(
                              fontSize: 9,
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
    ),
  );
}

    // Tablet & Desktop Top Header Bar with Liquid Glass Refraction & Scroll Animation
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: widget.isScrolled ? 24 : 18,
          sigmaY: widget.isScrolled ? 24 : 18,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          height: widget.isScrolled ? 64 : 72,
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: widget.isScrolled ? 6 : 10,
          ),
          decoration: CelestialTheme.liquidGlassHeader(
            isScrolled: widget.isScrolled,
          ),
          child: Row(
        children: [
          // Logo & Brand Name (Tap to open Settings & Logo)
          _buildBrand(context, posProvider),

          const SizedBox(width: 24),

          // Main Navigation Tabs
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildNavTab(
                    context,
                    index: 0,
                    icon: Icons.point_of_sale_rounded,
                    label: 'POS Station',
                    badgeCount: posProvider.cartItemCount > 0 ? posProvider.cartItemCount : null,
                  ),
                  const SizedBox(width: 8),
                  _buildNavTab(
                    context,
                    index: 1,
                    icon: Icons.hourglass_top_rounded,
                    label: 'Pending Orders',
                    badgeCount: posProvider.pendingCustomerOrders.isNotEmpty ? posProvider.pendingCustomerOrders.length : null,
                    badgeColor: CelestialTheme.goldPrimary,
                  ),
                  const SizedBox(width: 8),
                  _buildNavTab(
                    context,
                    index: 2,
                    icon: Icons.coffee_maker_rounded,
                    label: 'Barista / KDS',
                    badgeCount: posProvider.activeKdsOrders.isNotEmpty ? posProvider.activeKdsOrders.length : null,
                    badgeColor: CelestialTheme.amberBrewing,
                  ),
                  const SizedBox(width: 8),
                  _buildNavTab(
                    context,
                    index: 3,
                    icon: Icons.receipt_long_rounded,
                    label: 'Order History',
                  ),
                  const SizedBox(width: 8),
                  _buildNavTab(
                    context,
                    index: 4,
                    icon: Icons.inventory_2_rounded,
                    label: 'Menu & Stock',
                  ),
                  const SizedBox(width: 8),
                  _buildNavTab(
                    context,
                    index: 5,
                    icon: Icons.insights_rounded,
                    label: 'Analytics',
                  ),
                ],
              ),
            ),
          ),

          // Pending Customer Orders Alert Button (Desktop)
          if (posProvider.pendingCustomerOrders.isNotEmpty) ...[
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () => posProvider.setNavIndex(1),
              icon: const Icon(Icons.hourglass_top_rounded, size: 16, color: CelestialTheme.bgDark),
              label: Text(
                '${posProvider.pendingCustomerOrders.length} Pending Approval',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: CelestialTheme.bgDark,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: CelestialTheme.goldPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 4,
              ),
            ),
          ],

          if (!isCompact) ...[
            const SizedBox(width: 14),
            // Live Clock
            _buildClock(),
            const SizedBox(width: 12),
            // Table QR Code Ordering Button
            IconButton(
              onPressed: () => TableQrDialog.show(context),
              icon: const Icon(Icons.qr_code_scanner_rounded, color: CelestialTheme.goldLight, size: 22),
              tooltip: 'Table QR Code Ordering',
              splashRadius: 20,
            ),
            const SizedBox(width: 6),
            // Text Size / Accessibility Quick Button
            IconButton(
              onPressed: () => _showQuickTextSizeModal(context),
              icon: const Icon(Icons.format_size_rounded, color: CelestialTheme.goldLight, size: 22),
              tooltip: 'Adjust Text Size & Vision Scale',
              splashRadius: 20,
            ),
            const SizedBox(width: 6),
            // Store Settings & Logo Button
            IconButton(
              onPressed: () => _openSettings(context),
              icon: const Icon(Icons.settings_outlined, color: CelestialTheme.goldLight, size: 22),
              tooltip: 'Store Settings & Logo',
              splashRadius: 20,
            ),
          ],
        ],
      ),
    ),
  ),
);
  }

  void _showQuickTextSizeModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer<PosProvider>(
          builder: (context, provider, _) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 380,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CelestialTheme.bgSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.format_size_rounded, color: CelestialTheme.goldPrimary, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Text Size & Vision',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: CelestialTheme.textLight,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, color: CelestialTheme.textMuted, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Live text scaling for cashier & staff comfort.',
                      style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: provider.uiScale > 0.86
                                ? () => provider.setUiScale((provider.uiScale - 0.10).clamp(0.85, 1.45))
                                : null,
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: CelestialTheme.goldLight),
                            tooltip: 'Smaller',
                          ),
                          Column(
                            children: [
                              Text(
                                '${(provider.uiScale * 100).round()}%',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.goldLight,
                                ),
                              ),
                              Text(
                                provider.uiScale >= 1.4
                                    ? 'Huge (Vision Aid)'
                                    : provider.uiScale >= 1.25
                                        ? 'Extra Large'
                                        : provider.uiScale >= 1.1
                                            ? 'Large'
                                            : provider.uiScale < 0.95
                                                ? 'Compact'
                                                : 'Standard',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  color: CelestialTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: provider.uiScale < 1.44
                                ? () => provider.setUiScale((provider.uiScale + 0.10).clamp(0.85, 1.45))
                                : null,
                            icon: const Icon(Icons.add_circle_outline_rounded, color: CelestialTheme.goldLight),
                            tooltip: 'Larger',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildQuickPreset(provider, label: '90%', scale: 0.90),
                        _buildQuickPreset(provider, label: '100%', scale: 1.00),
                        _buildQuickPreset(provider, label: '115%', scale: 1.15),
                        _buildQuickPreset(provider, label: '130%', scale: 1.30),
                        _buildQuickPreset(provider, label: '145%', scale: 1.45),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if ((provider.uiScale - 1.0).abs() > 0.01)
                          TextButton.icon(
                            onPressed: () => provider.resetUiScale(),
                            icon: const Icon(Icons.refresh_rounded, size: 14, color: CelestialTheme.textMuted),
                            label: const Text('Reset', style: TextStyle(color: CelestialTheme.textMuted, fontSize: 11)),
                          ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CelestialTheme.goldPrimary,
                            foregroundColor: CelestialTheme.bgDark,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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

  Widget _buildQuickPreset(PosProvider provider, {required String label, required double scale}) {
    final isSelected = (provider.uiScale - scale).abs() < 0.04;
    return InkWell(
      onTap: () => provider.setUiScale(scale),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? CelestialTheme.goldPrimary : CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? CelestialTheme.goldPrimary : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? CelestialTheme.bgDark : CelestialTheme.textLight,
          ),
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const SettingsDialog(),
    );
  }

  Widget _buildBrand(BuildContext context, PosProvider posProvider) {
    return InkWell(
      onTap: () => _openSettings(context),
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: posProvider.hasCustomLogo
                    ? Image.memory(
                        posProvider.customLogoBytes!,
                        fit: BoxFit.cover,
                      )
                    : Image.asset(
                        'assets/images/Logo.png',
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CELESTIAL',
                  style: GoogleFonts.cinzel(
                    color: CelestialTheme.goldPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                  ),
                ),
                Text(
                  'Cozy&Classic',
                  style: GoogleFonts.outfit(
                    color: CelestialTheme.goldLight.withValues(alpha: 0.8),
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTab(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
    int? badgeCount,
    Color? badgeColor,
  }) {
    final posProvider = Provider.of<PosProvider>(context);
    final isSelected = posProvider.currentNavIndex == index;

    return InkWell(
      onTap: () => posProvider.setNavIndex(index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    CelestialTheme.caramelAccent.withValues(alpha: 0.30),
                    CelestialTheme.brownWarm.withValues(alpha: 0.16),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? CelestialTheme.caramelAccent.withValues(alpha: 0.70)
                : Colors.white.withValues(alpha: 0.04),
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: CelestialTheme.caramelAccent.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? CelestialTheme.caramelAccent
                  : CelestialTheme.warmGray,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? CelestialTheme.creamLight
                    : CelestialTheme.warmGray,
              ),
            ),
            if (badgeCount != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor ?? CelestialTheme.goldPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: CelestialTheme.bgDark,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClock() {
    final timeStr = DateFormat('hh:mm:ss a').format(_currentTime);
    final dateStr = DateFormat('EEE, MMM d').format(_currentTime);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            timeStr,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: CelestialTheme.goldLight,
            ),
          ),
          Text(
            dateStr,
            style: GoogleFonts.outfit(
              fontSize: 10,
              color: CelestialTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
