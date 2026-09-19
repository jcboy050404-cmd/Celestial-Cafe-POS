import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/app_feature.dart';
import '../providers/pos_provider.dart';
import '../services/auth_service.dart';
import '../theme/celestial_theme.dart';
import 'cart_panel.dart';
import 'settings_dialog.dart';
import 'admin_management_dialog.dart';
import 'cashier_management_dialog.dart';
import 'online_ordering_dialog.dart';

class HeaderBar extends StatefulWidget {
  final bool isScrolled;
  const HeaderBar({super.key, this.isScrolled = false});

  static Widget buildRoleBadge(
    AppUser? user, {
    bool isAdmin = false,
    double fontSize = 8.5,
    double iconSize = 9.0,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
  }) {
    final effectiveAdmin = isAdmin || (user?.isAdmin ?? false);
    final String label;
    final IconData icon;
    final Color bg;
    final Color border;
    final Color textColor;

    if (effectiveAdmin) {
      label = 'ADMIN';
      icon = Icons.admin_panel_settings_rounded;
      bg = CelestialTheme.goldPrimary.withValues(alpha: 0.25);
      border = CelestialTheme.goldPrimary.withValues(alpha: 0.55);
      textColor = CelestialTheme.goldLight;
    } else {
      final roleLabel = user?.roleBadgeLabel ?? 'STAFF';
      final lower = roleLabel.toLowerCase();

      if (lower.contains('barista')) {
        label = roleLabel;
        icon = Icons.coffee_rounded;
        bg = const Color(0xFF5C3317).withValues(alpha: 0.35);
        border = const Color(0xFFD4A373).withValues(alpha: 0.65);
        textColor = const Color(0xFFFFD199);
      } else if (lower.contains('cashier')) {
        label = roleLabel;
        icon = Icons.point_of_sale_rounded;
        bg = const Color(0xFF0F766E).withValues(alpha: 0.30);
        border = const Color(0xFF2DD4BF).withValues(alpha: 0.55);
        textColor = const Color(0xFF5EEAD4);
      } else if (lower.contains('manager')) {
        label = roleLabel;
        icon = Icons.badge_rounded;
        bg = const Color(0xFF5B21B6).withValues(alpha: 0.30);
        border = const Color(0xFFA78BFA).withValues(alpha: 0.55);
        textColor = const Color(0xFFC4B5FD);
      } else if (lower.contains('owner')) {
        label = roleLabel;
        icon = Icons.storefront_rounded;
        bg = CelestialTheme.goldPrimary.withValues(alpha: 0.20);
        border = CelestialTheme.goldPrimary.withValues(alpha: 0.45);
        textColor = CelestialTheme.goldLight;
      } else {
        label = roleLabel;
        icon = Icons.person_rounded;
        bg = const Color(0xFF0369A1).withValues(alpha: 0.30);
        border = const Color(0xFF38BDF8).withValues(alpha: 0.55);
        textColor = const Color(0xFF7DD3FC);
      }
    }

    return Container(
      padding: padding,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize, color: textColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: textColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

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
    final auth = Provider.of<AuthService>(context);
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
                  onTap: (!auth.isCashier && auth.isFeatureEnabled(AppFeature.storeSettings)) ? () => _openSettings(context) : null,
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
                                  key: ValueKey(posProvider.customLogoBase64?.hashCode ?? 1),
                                )
                              : Image.asset(
                                  'assets/images/Logo.png',
                                  fit: BoxFit.cover,
                                  key: const ValueKey('default_mobile_logo'),
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
                              (posProvider.storeName.trim().isEmpty || posProvider.storeName.trim().toUpperCase() == 'CELESTIAL CAFE')
                                  ? 'CELESTIAL'
                                  : posProvider.storeName.trim().toUpperCase(),
                              style: GoogleFonts.cinzel(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                            Text(
                              posProvider.storeTagline.trim().isNotEmpty
                                  ? posProvider.storeTagline.trim()
                                  : 'Cozy&Classic',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
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
                  if (posProvider.pendingSyncCount > 0) ...[
                    _buildMobileOfflineSyncBadge(context, posProvider),
                    const SizedBox(width: 4),
                  ],
                  // Account / Subscription Pill (Mobile)
                  Consumer<AuthService>(
                    builder: (context, auth, _) {
                      final user = auth.currentUser;
                      final isPro = auth.isPro;
                      final isAdmin = auth.isAdmin;
                      final isCashier = auth.isCashier;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isCashier) ...[
                            buildRoleBadge(
                              user,
                              isAdmin: isAdmin,
                              fontSize: 8.0,
                              iconSize: 8.5,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            ),
                          ],
                          InkWell(
                            onTap: () => _openAccountModal(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCashier
                                    ? const Color(0xFF0F766E).withValues(alpha: 0.25)
                                    : (isPro ? CelestialTheme.goldPrimary.withValues(alpha: 0.2) : CelestialTheme.bgCard),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCashier
                                      ? const Color(0xFF2DD4BF)
                                      : (isPro ? CelestialTheme.goldPrimary : CelestialTheme.borderWarm),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isCashier
                                        ? Icons.point_of_sale_rounded
                                        : (isPro ? Icons.workspace_premium_rounded : Icons.flash_on_rounded),
                                    size: 12,
                                    color: isCashier
                                        ? const Color(0xFF5EEAD4)
                                        : (isPro ? CelestialTheme.goldPrimary : CelestialTheme.amberBrewing),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    isCashier
                                        ? (user?.roleBadgeLabel ?? 'CASHIER')
                                        : (isPro ? 'PRO' : '${user?.trialDaysRemaining ?? auth.defaultTrialDays}D TRIAL'),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: isCashier
                                          ? const Color(0xFF5EEAD4)
                                          : (isPro ? CelestialTheme.goldLight : CelestialTheme.amberBrewing),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // Store Settings Button
                  if (!auth.isCashier && auth.isFeatureEnabled(AppFeature.storeSettings)) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => _openSettings(context),
                      icon: Icon(Icons.settings_outlined, color: CelestialTheme.goldLight, size: 20),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                      tooltip: 'Store Settings & Station Configuration',
                    ),
                  ],

                  // Online Ordering Link & QR shortcut for store owners (Mobile)
                  if (!auth.isCashier) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      key: const ValueKey('mobile_online_order_btn'),
                      onPressed: () => OnlineOrderingDialog.show(context),
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(Icons.qr_code_2_rounded, color: CelestialTheme.goldLight, size: 20),
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: posProvider.isOnlineOrderOpen
                                    ? CelestialTheme.emeraldReady
                                    : CelestialTheme.roseAlert,
                                shape: BoxShape.circle,
                                border: Border.all(color: CelestialTheme.bgDark, width: 1.0),
                              ),
                            ),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                      tooltip: posProvider.isOnlineOrderOpen
                          ? 'Customer Online Ordering: Active (Click to manage)'
                          : 'Customer Online Ordering: Paused / Closed (Click to manage)',
                    ),
                  ],

                  const SizedBox(width: 4),

                  // Cart Trigger
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () => _openMobileCartSheet(context),
                        icon: Icon(Icons.shopping_bag_outlined, color: CelestialTheme.goldPrimary, size: 19),
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
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: CelestialTheme.primaryBtnText,
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
                    index: 5,
                    icon: Icons.delivery_dining_rounded,
                    label: 'Online Orders',
                    badgeCount: posProvider.pendingOnlineOrdersCount > 0
                        ? posProvider.pendingOnlineOrdersCount
                        : null,
                  ),
                  if (auth.isFeatureEnabled(AppFeature.orderHistory)) ...[
                    const SizedBox(width: 8),
                    _buildNavTab(
                      context,
                      index: 1,
                      icon: Icons.receipt_long_rounded,
                      label: 'Order History',
                    ),
                  ],
                  if (!auth.isCashier && auth.isFeatureEnabled(AppFeature.inventory)) ...[
                    const SizedBox(width: 8),
                    _buildNavTab(
                      context,
                      index: 2,
                      icon: Icons.inventory_2_rounded,
                      label: 'Menu & Stock',
                    ),
                  ],
                  if (!auth.isCashier && auth.isFeatureEnabled(AppFeature.analytics)) ...[
                    const SizedBox(width: 8),
                    _buildNavTab(
                      context,
                      index: 3,
                      icon: Icons.point_of_sale_rounded,
                      label: 'Sales',
                    ),
                  ],
                  if (!auth.isCashier && auth.isFeatureEnabled(AppFeature.foodCosting)) ...[
                    const SizedBox(width: 8),
                    _buildNavTab(
                      context,
                      index: 4,
                      icon: Icons.calculate_rounded,
                      label: 'Food Costing',
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (posProvider.pendingSyncCount > 0) ...[
            const SizedBox(width: 8),
            _buildOfflineSyncBadge(context, posProvider),
          ],

          if (MediaQuery.of(context).size.width >= 1100) ...[
            const SizedBox(width: 14),
            // Live Clock
            _buildClock(),
          ],
          const SizedBox(width: 10),
          // User Account & Trial/Pro Status Chip (Contains Profile, License, Station Info, and Sign Out)
          _buildAccountChip(context),
          // Online Ordering Link & QR shortcut for store owners (Desktop)
          if (!auth.isCashier) ...[
            const SizedBox(width: 4),
            IconButton(
              key: const ValueKey('desktop_online_order_btn'),
              onPressed: () => OnlineOrderingDialog.show(context),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.qr_code_2_rounded, color: CelestialTheme.goldLight, size: 22),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: posProvider.isOnlineOrderOpen
                            ? CelestialTheme.emeraldReady
                            : CelestialTheme.roseAlert,
                        shape: BoxShape.circle,
                        border: Border.all(color: CelestialTheme.bgDark, width: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
              tooltip: posProvider.isOnlineOrderOpen
                  ? 'Online Ordering: Active (Click to manage)'
                  : 'Online Ordering: Paused / Closed (Click to manage)',
              splashRadius: 20,
            ),
          ],
          // Store Settings (Contains Theme Switcher, Text Scaling, Logo, Store Info, Hardware, & Admin)
          if (!auth.isCashier && auth.isFeatureEnabled(AppFeature.storeSettings)) ...[
            const SizedBox(width: 6),
            IconButton(
              onPressed: () => _openSettings(context),
              icon: Icon(Icons.settings_outlined, color: CelestialTheme.goldLight, size: 22),
              tooltip: 'Store Settings & Station Configuration',
              splashRadius: 20,
            ),
          ],
        ],
      ),
    ),
  ),
);
  }

  void _openSettings(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.isCashier) {
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => const SettingsDialog(),
    );
  }

  void _openAccountModal(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final posProvider = Provider.of<PosProvider>(context, listen: false);
    final user = auth.currentUser;
    final isPro = auth.isPro;
    final isAdmin = auth.isAdmin || auth.checkIfAdmin(user?.email ?? '');
    final email = user?.email ?? 'cashier@celestial.com';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'C';

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
                color: Colors.white.withValues(alpha: 0.12),
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
                          color: CelestialTheme.primaryBtnText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Text(
                                isAdmin
                                    ? 'ADMIN STATION'
                                    : (user?.isOwner == true ? 'OWNER STATION' : 'CASHIER STATION'),
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: isAdmin || user?.isOwner == true
                                      ? CelestialTheme.goldLight
                                      : const Color(0xFF5EEAD4),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: CelestialTheme.emeraldReady,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Online',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: CelestialTheme.emeraldReady,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              buildRoleBadge(user, isAdmin: isAdmin),
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

                // License Info Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CelestialTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAdmin
                            ? Icons.admin_panel_settings_rounded
                            : (isPro ? Icons.verified_rounded : Icons.hourglass_top_rounded),
                        color: isPro || isAdmin ? CelestialTheme.goldPrimary : CelestialTheme.amberBrewing,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAdmin
                                  ? 'Administrator Pro Account'
                                  : (user?.isOwner == true
                                      ? 'Store Owner Pro License'
                                      : '[${user?.roleBadgeLabel ?? "CASHIER"}] Station Terminal'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: CelestialTheme.textLight,
                              ),
                            ),
                            Text(
                              auth.isCashier
                                  ? 'Access: POS Station, Order History & Online Orders Only'
                                  : (isAdmin || isPro
                                      ? 'Full lifetime / enterprise license active'
                                      : 'Active terminal session'),
                              style: TextStyle(
                                fontSize: 10,
                                color: auth.isCashier ? const Color(0xFF5EEAD4) : CelestialTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Action Options
                if (auth.isOwner)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          CashierManagementDialog.show(context);
                        },
                        icon: const Icon(Icons.people_alt_rounded, size: 16),
                        label: const Text('Cashier & Staff Management', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CelestialTheme.goldPrimary,
                          foregroundColor: CelestialTheme.primaryBtnText,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),

                if (!auth.isCashier) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          OnlineOrderingDialog.show(context);
                        },
                        icon: Icon(Icons.qr_code_2_rounded, size: 16, color: CelestialTheme.goldLight),
                        label: Text(
                          'Customer Online Ordering (${posProvider.isOnlineOrderOpen ? "Active" : "Paused"})',
                          style: TextStyle(
                            color: posProvider.isOnlineOrderOpen ? CelestialTheme.goldLight : CelestialTheme.roseAlert,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                ],

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
                        icon: Icon(Icons.admin_panel_settings_rounded, size: 16, color: CelestialTheme.goldLight),
                        label: Text('Developer Admin Portal', style: TextStyle(color: CelestialTheme.goldLight, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),

                if (!auth.isCashier && auth.isFeatureEnabled(AppFeature.storeSettings))
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openSettings(context);
                      },
                      icon: Icon(Icons.settings_outlined, size: 16, color: CelestialTheme.textLight),
                      label: Text('Store & Hardware Settings', style: TextStyle(color: CelestialTheme.textLight, fontSize: 12)),
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

  Widget _buildBrand(BuildContext context, PosProvider posProvider) {
    final auth = Provider.of<AuthService>(context, listen: false);
    return InkWell(
      onTap: (!auth.isCashier && auth.isFeatureEnabled(AppFeature.storeSettings)) ? () => _openSettings(context) : null,
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
                        key: ValueKey(posProvider.customLogoBase64?.hashCode ?? 1),
                      )
                    : Image.asset(
                        'assets/images/Logo.png',
                        fit: BoxFit.cover,
                        key: const ValueKey('default_desktop_logo'),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (posProvider.storeName.trim().isEmpty || posProvider.storeName.trim().toUpperCase() == 'CELESTIAL CAFE')
                        ? 'CELESTIAL'
                        : posProvider.storeName.trim().toUpperCase(),
                    style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    posProvider.storeTagline.trim().isNotEmpty
                        ? posProvider.storeTagline.trim()
                        : 'Cozy&Classic',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
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
                ? CelestialTheme.caramelAccent.withValues(alpha: 0.40)
                : Colors.white.withValues(alpha: 0.04),
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
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
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: CelestialTheme.primaryBtnText,
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

  Widget buildRoleBadge(
    AppUser? user, {
    bool isAdmin = false,
    double fontSize = 8.5,
    double iconSize = 9.0,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
  }) =>
      HeaderBar.buildRoleBadge(
        user,
        isAdmin: isAdmin,
        fontSize: fontSize,
        iconSize: iconSize,
        padding: padding,
      );

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
                      color: CelestialTheme.primaryBtnText,
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
                        buildRoleBadge(user, isAdmin: isAdmin),
                        if (!auth.isCashier) ...[
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
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down_rounded, size: 18, color: CelestialTheme.textMuted),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileOfflineSyncBadge(BuildContext context, PosProvider posProvider) {
    final isSyncing = posProvider.isSyncingPendingSales;
    return Tooltip(
      message: isSyncing
          ? 'Syncing offline sales...'
          : '${posProvider.pendingSyncCount} offline sales pending. Tap to sync.',
      child: InkWell(
        onTap: isSyncing
            ? null
            : () async {
                final synced = await posProvider.syncPendingSales();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: CelestialTheme.bgCard,
                      content: Text(
                        synced > 0
                            ? 'Synced $synced offline sale(s) to cloud!'
                            : (posProvider.pendingSyncCount == 0
                                ? 'All sales are synced.'
                                : 'Still offline. Will sync when reconnected.'),
                      ),
                    ),
                  );
                }
              },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber.shade900.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.amber.shade400.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSyncing ? Icons.sync_rounded : Icons.cloud_upload_outlined,
                size: 11,
                color: Colors.amber.shade300,
              ),
              const SizedBox(width: 3),
              Text(
                '${posProvider.pendingSyncCount}',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade200,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineSyncBadge(BuildContext context, PosProvider posProvider) {
    final isSyncing = posProvider.isSyncingPendingSales;
    return Tooltip(
      message: isSyncing
          ? 'Syncing offline sales to cloud...'
          : '${posProvider.pendingSyncCount} offline sale(s) waiting to sync. Tap to sync now.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isSyncing
              ? null
              : () async {
                  final synced = await posProvider.syncPendingSales();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: CelestialTheme.bgCard,
                        content: Text(
                          synced > 0
                              ? 'Successfully synced $synced offline sale(s) to cloud!'
                              : (posProvider.pendingSyncCount == 0
                                  ? 'All sales are synced with cloud.'
                                  : 'Could not sync yet. Device is still offline.'),
                        ),
                      ),
                    );
                  }
                },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.amber.shade900.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.amber.shade400.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSyncing ? Icons.sync_rounded : Icons.cloud_upload_outlined,
                  size: 14,
                  color: Colors.amber.shade300,
                ),
                const SizedBox(width: 5),
                Text(
                  isSyncing ? 'Syncing...' : '${posProvider.pendingSyncCount} Pending Sync',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade200,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}