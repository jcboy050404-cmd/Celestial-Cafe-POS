import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';
import '../services/auth_service.dart';
import '../theme/celestial_theme.dart';
import 'cart_panel.dart';
import 'settings_dialog.dart';
import 'admin_management_dialog.dart';

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
              Flexible(
                child: InkWell(
                  onTap: () => _openSettings(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 34,
                        width: 34,
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
                      const SizedBox(width: 6),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'CELESTIAL',
                              style: GoogleFonts.cinzel(
                                color: CelestialTheme.goldPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                            Text(
                              'Cozy&Classic',
                              style: GoogleFonts.outfit(
                                color: CelestialTheme.goldLight.withValues(alpha: 0.7),
                                fontSize: 7.5,
                                letterSpacing: 0.5,
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

              const SizedBox(width: 4),

              // Actions: User Account (Trial/Pro), Accessibility, Settings & Cart Badge
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Account / Subscription Pill (Mobile)
                  Consumer<AuthService>(
                    builder: (context, auth, _) {
                      final user = auth.currentUser;
                      final isPro = auth.isPro;
                      final isAdmin = auth.isAdmin;
                      return InkWell(
                        onTap: () => _openAccountModal(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAdmin
                                ? CelestialTheme.goldPrimary.withValues(alpha: 0.25)
                                : (isPro ? CelestialTheme.goldPrimary.withValues(alpha: 0.2) : CelestialTheme.bgCard),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isAdmin || isPro ? CelestialTheme.goldPrimary : CelestialTheme.borderWarm,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isAdmin
                                    ? Icons.admin_panel_settings_rounded
                                    : (isPro ? Icons.workspace_premium_rounded : Icons.flash_on_rounded),
                                size: 12,
                                color: isAdmin || isPro ? CelestialTheme.goldPrimary : CelestialTheme.amberBrewing,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isAdmin ? 'ADMIN' : (isPro ? 'PRO' : '${user?.trialDaysRemaining ?? auth.defaultTrialDays}D TRIAL'),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: isAdmin || isPro ? CelestialTheme.goldLight : CelestialTheme.amberBrewing,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Text Size / Accessibility Button (shown on wider screens)
                  if (MediaQuery.of(context).size.width >= 430) ...[
                    IconButton(
                      onPressed: () => _showQuickTextSizeModal(context),
                      icon: const Icon(Icons.format_size_rounded, color: CelestialTheme.goldLight, size: 18),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                      tooltip: 'Adjust Text Size',
                    ),
                    const SizedBox(width: 2),
                  ],

                  // Settings Button
                  IconButton(
                    onPressed: () => _openSettings(context),
                    icon: const Icon(Icons.settings_outlined, color: CelestialTheme.goldLight, size: 18),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    ),
                    tooltip: 'Store Settings & Logo',
                  ),

                  const SizedBox(width: 2),

                  // Sign Out Quick Button (Mobile)
                  IconButton(
                    onPressed: () => _confirmSignOut(context),
                    icon: const Icon(Icons.logout_rounded, color: CelestialTheme.roseAlert, size: 18),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    ),
                    tooltip: 'Sign Out Station',
                  ),

                  const SizedBox(width: 2),

                  // Cart Trigger
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () => _openMobileCartSheet(context),
                        icon: const Icon(Icons.shopping_bag_outlined, color: CelestialTheme.goldPrimary, size: 19),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: CelestialTheme.bgCard,
                          padding: EdgeInsets.zero,
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

          // Main Navigation Tabs (POS, History, Stock, Analytics)
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
                    icon: Icons.receipt_long_rounded,
                    label: 'Order History',
                  ),
                  const SizedBox(width: 8),
                  _buildNavTab(
                    context,
                    index: 2,
                    icon: Icons.inventory_2_rounded,
                    label: 'Menu & Stock',
                  ),
                  const SizedBox(width: 8),
                  _buildNavTab(
                    context,
                    index: 3,
                    icon: Icons.insights_rounded,
                    label: 'Analytics',
                  ),
                  const SizedBox(width: 8),
                  _buildNavTab(
                    context,
                    index: 4,
                    icon: Icons.calculate_rounded,
                    label: 'Food Costing',
                  ),
                ],
              ),
            ),
          ),

          if (MediaQuery.of(context).size.width >= 1100) ...[
            const SizedBox(width: 14),
            // Live Clock
            _buildClock(),
          ],
          const SizedBox(width: 10),
          // User Account & Trial/Pro Status Chip
          _buildAccountChip(context),
          Consumer<AuthService>(
            builder: (context, auth, _) {
              if (!auth.isAdmin) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: 4),
                child: IconButton(
                  onPressed: () => AdminManagementDialog.show(context),
                  icon: const Icon(Icons.admin_panel_settings_rounded, color: CelestialTheme.goldLight, size: 22),
                  tooltip: 'Admin License & Account Manager',
                  splashRadius: 20,
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          // Text Size / Accessibility Quick Button
          IconButton(
            onPressed: () => _showQuickTextSizeModal(context),
            icon: const Icon(Icons.format_size_rounded, color: CelestialTheme.goldLight, size: 22),
            tooltip: 'Adjust Text Size & Vision Scale',
            splashRadius: 20,
          ),
          const SizedBox(width: 4),
          // Store Settings & Logo Button
          IconButton(
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings_outlined, color: CelestialTheme.goldLight, size: 22),
            tooltip: 'Store Settings & Logo',
            splashRadius: 20,
          ),
          const SizedBox(width: 8),
          // Prominent Sign Out Button (Desktop)
          Tooltip(
            message: 'Sign Out / Switch Station',
            child: InkWell(
              onTap: () => _confirmSignOut(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: CelestialTheme.roseAlert.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: CelestialTheme.roseAlert.withValues(alpha: 0.45),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.logout_rounded, color: CelestialTheme.roseAlert, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      'Sign Out',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CelestialTheme.roseAlert,
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

  void _openAccountModal(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    final isPro = auth.isPro;
    final isAdmin = auth.isAdmin || auth.checkIfAdmin(user?.email ?? '');
    final email = user?.email ?? 'cashier@celestial.com';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'C';
    final trialDays = (user?.hasCustomTrial == true ? user!.customTrialDays : null) ?? auth.defaultTrialDays;

    showDialog(
      context: context,
      builder: (ctx) {
        final isMobile = (MediaQuery.maybeOf(ctx)?.size.width ?? 800) < 600;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: 24,
          ),
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: EdgeInsets.all(isMobile ? 18 : 22),
            decoration: BoxDecoration(
              color: CelestialTheme.bgSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Avatar & Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: isAdmin
                          ? CelestialTheme.goldLight
                          : (isPro ? CelestialTheme.goldPrimary : CelestialTheme.brownWarm),
                      child: Text(
                        initial,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.bgDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isAdmin ? 'ADMIN STATION' : 'CASHIER STATION',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: isAdmin ? CelestialTheme.goldLight : CelestialTheme.textMuted,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: CelestialTheme.emeraldReady,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Online',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: CelestialTheme.emeraldReady,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.textLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: CelestialTheme.borderWarm, height: 1),
                const SizedBox(height: 14),

                // License & Cloud Status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CelestialTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPro ? Icons.verified_rounded : Icons.timer_outlined,
                              size: 18,
                              color: isPro ? CelestialTheme.goldLight : CelestialTheme.amberBrewing,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                isPro ? 'Pro Active' : '$trialDays-Day Trial License',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: CelestialTheme.textLight,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isPro
                              ? CelestialTheme.goldPrimary.withValues(alpha: 0.2)
                              : CelestialTheme.amberBrewing.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isPro ? 'UNLIMITED' : '${user?.trialDaysRemaining ?? trialDays}D LEFT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isPro ? CelestialTheme.goldLight : CelestialTheme.amberBrewing,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Action Options
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          AdminManagementDialog.show(context);
                        },
                        icon: const Icon(Icons.admin_panel_settings_rounded, size: 16, color: CelestialTheme.goldLight),
                        label: const Text('Admin Management Console', style: TextStyle(color: CelestialTheme.goldLight, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openSettings(context);
                    },
                    icon: const Icon(Icons.settings_outlined, size: 16, color: CelestialTheme.textLight),
                    label: const Text('Store & Hardware Settings', style: TextStyle(color: CelestialTheme.textLight, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Sign Out Button (Prominent Red)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const Key('modal_sign_out_button'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await auth.signOut();
                    },
                    icon: const Icon(Icons.logout_rounded, size: 17, color: Colors.white),
                    label: const Text(
                      'Sign Out Terminal',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CelestialTheme.roseAlert,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Future<void> _confirmSignOut(BuildContext context) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final userEmail = auth.currentUser?.email ?? 'current session';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.45), width: 1.2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CelestialTheme.roseAlert.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, color: CelestialTheme.roseAlert, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Sign Out Station',
              style: TextStyle(color: CelestialTheme.textLight, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to sign out?',
              style: TextStyle(color: CelestialTheme.textLight, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Logged in as: $userEmail',
              style: const TextStyle(color: CelestialTheme.goldLight, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CelestialTheme.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_clock_rounded, color: CelestialTheme.textMuted, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Signing out returns to the terminal PIN / Google login screen.',
                      style: TextStyle(color: CelestialTheme.textMuted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton.icon(
            key: const Key('confirm_sign_out_button'),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.white),
            label: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.roseAlert,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await auth.signOut();
    }
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

  Widget _buildAccountChip(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        final user = auth.currentUser;
        final isPro = auth.isPro;
        final isAdmin = auth.isAdmin;
        final email = user?.email ?? 'cashier@celestial.com';
        final initial = email.isNotEmpty ? email[0].toUpperCase() : 'C';

        return InkWell(
          onTap: () => _openAccountModal(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: CelestialTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isAdmin
                    ? CelestialTheme.goldLight
                    : (isPro ? CelestialTheme.goldPrimary.withValues(alpha: 0.5) : CelestialTheme.borderWarm),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: isAdmin
                      ? CelestialTheme.goldLight
                      : (isPro ? CelestialTheme.goldPrimary : CelestialTheme.brownWarm),
                  child: Text(
                    initial,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: CelestialTheme.bgDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Text(
                        email,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: CelestialTheme.textLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        if (isAdmin) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: CelestialTheme.goldPrimary.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: CelestialTheme.goldLight,
                              ),
                            ),
                          ),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isPro
                                ? CelestialTheme.goldPrimary.withValues(alpha: 0.2)
                                : CelestialTheme.amberBrewing.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isPro ? 'PRO LICENSE' : '${user?.trialDaysRemaining ?? auth.defaultTrialDays}D TRIAL',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: isPro ? CelestialTheme.goldLight : CelestialTheme.amberBrewing,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down_rounded, size: 18, color: CelestialTheme.textMuted),
              ],
            ),
          ),
        );
      },
    );
  }
}
