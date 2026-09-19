import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../screens/customer_online_order_screen.dart';
import '../services/auth_service.dart';
import '../services/online_order_service.dart';
import '../theme/celestial_theme.dart';
import 'online_order_confirm_dialog.dart';
import 'top_notification.dart';

/// Modal dialog enabling store owners to generate, customize, and share customer online ordering links & QR codes.
class OnlineOrderingDialog extends StatefulWidget {
  const OnlineOrderingDialog({super.key});

  static Future<void> show(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.isCashier) {
      TopNotification.show(
        context,
        message: 'Cashier accounts do not have permission to access online ordering settings or store controls.',
        type: TopNotificationType.warning,
      );
      return Future.value();
    }
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const OnlineOrderingDialog(),
    );
  }

  @override
  State<OnlineOrderingDialog> createState() => _OnlineOrderingDialogState();
}

class _OnlineOrderingDialogState extends State<OnlineOrderingDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _tableController = TextEditingController();
  final _noticeController = TextEditingController();
  final _customSlugController = TextEditingController();
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  bool _isPublishing = false;
  bool _isSavingSlug = false;
  bool _isSavingNotice = false;
  bool _isSavingBranding = false;
  String? _slugStatusMessage;
  bool _slugStatusIsError = false;

  Future<void> _saveNotice(PosProvider pos, OnlineStoreProfile profile) async {
    setState(() => _isSavingNotice = true);
    final text = _noticeController.text.trim();
    profile.customNotice = text.isNotEmpty ? text : null;
    final success = await pos.updateOnlineStoreProfile(profile);
    if (!mounted) return;
    setState(() => _isSavingNotice = false);
    if (success) {
      TopNotification.show(
        context,
        message: text.isNotEmpty
            ? 'Store notice updated & visible to online customers!'
            : 'Store notice cleared.',
        type: TopNotificationType.success,
      );
    } else {
      TopNotification.show(
        context,
        message: 'Saved locally. Cloud will update when connected.',
        type: TopNotificationType.info,
      );
    }
  }

  Future<void> _clearNotice(PosProvider pos, OnlineStoreProfile profile) async {
    _noticeController.clear();
    await _saveNotice(pos, profile);
  }

  Future<void> _saveBranding(PosProvider pos, OnlineStoreProfile profile) async {
    setState(() => _isSavingBranding = true);
    final newName = _nameController.text.trim();
    final newTagline = _taglineController.text.trim();

    await pos.updateStoreDetails(
      name: newName,
      tagline: newTagline,
      address: pos.storeAddress,
    );
    if (!mounted) return;
    setState(() => _isSavingBranding = false);
    TopNotification.show(
      context,
      message: 'Store name & tagline updated and synced to customer UI!',
      type: TopNotificationType.success,
    );
  }

  Future<void> _toggleStoreStatus(PosProvider pos, OnlineStoreProfile profile, bool isOpen) async {
    profile.isOpen = isOpen;
    setState(() {});
    await pos.updateOnlineStoreProfile(profile);
    if (!mounted) return;
    TopNotification.show(
      context,
      message: isOpen
          ? 'Online Ordering is now OPEN and accepting orders!'
          : 'Online Ordering is PAUSED. Customers cannot place orders right now.',
      type: isOpen ? TopNotificationType.success : TopNotificationType.warning,
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final pos = Provider.of<PosProvider>(context, listen: false);
    final profile = pos.onlineStoreProfile;
    _nameController.text = pos.storeName;
    _taglineController.text = pos.storeTagline.isNotEmpty
        ? pos.storeTagline
        : (profile?.storeTagline != null && profile!.storeTagline != 'Handcrafted Coffee & Treats'
            ? profile.storeTagline
            : '');
    if (profile != null) {
      _noticeController.text = profile.customNotice ?? '';
      _customSlugController.text = profile.customSlug ?? '';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tableController.dispose();
    _noticeController.dispose();
    _customSlugController.dispose();
    _nameController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  String _buildOrderUrl(PosProvider pos) {
    final storeId = pos.effectiveStoreId;
    final table = _tableController.text.trim();
    final slug = _customSlugController.text.trim().isNotEmpty
        ? OnlineOrderService.slugify(_customSlugController.text.trim())
        : pos.onlineStoreProfile?.customSlug;
    return OnlineOrderService.getOrderingUrl(
      storeId: storeId,
      customSlug: slug,
      tableNumber: table.isNotEmpty ? table : null,
    );
  }

  Future<void> _saveCustomSlug(PosProvider pos) async {
    final raw = _customSlugController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _slugStatusMessage = 'Please enter a custom link name.';
        _slugStatusIsError = true;
      });
      return;
    }

    setState(() => _isSavingSlug = true);
    final res = await pos.setCustomSlug(raw);
    if (!mounted) return;
    setState(() {
      _isSavingSlug = false;
      _slugStatusMessage = res.message;
      _slugStatusIsError = !res.success;
      if (res.success) {
        _customSlugController.text = pos.onlineStoreProfile?.customSlug ?? '';
      }
    });

    if (res.success) {
      TopNotification.show(
        context,
        message: 'Custom link activated! Customers can now order with this link.',
        type: TopNotificationType.success,
      );
    }
  }

  Future<void> _resetToDefaultSlug(PosProvider pos) async {
    setState(() => _isSavingSlug = true);
    final res = await pos.setCustomSlug('');
    if (!mounted) return;
    setState(() {
      _isSavingSlug = false;
      _customSlugController.clear();
      _slugStatusMessage = res.message;
      _slugStatusIsError = false;
    });
    TopNotification.show(
      context,
      message: 'Reset back to default Store ID.',
      type: TopNotificationType.info,
    );
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    TopNotification.show(
      context,
      message: 'Ordering link copied to clipboard!',
      type: TopNotificationType.success,
    );
  }

  Future<void> _shareUrl(String url, String storeName) async {
    final text = Uri.encodeComponent('Order now from $storeName: $url');
    final whatsappUri = Uri.parse('https://wa.me/?text=$text');
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        await _copyLink(url);
      }
    } catch (_) {
      await _copyLink(url);
    }
  }

  Future<void> _publishCatalog(PosProvider pos) async {
    setState(() => _isPublishing = true);
    final success = await pos.publishOnlineMenu();
    if (!mounted) return;
    setState(() => _isPublishing = false);
    if (success) {
      TopNotification.show(
        context,
        message: 'Menu & store profile published to online catalog!',
        type: TopNotificationType.success,
      );
    } else {
      TopNotification.show(
        context,
        message: 'Published locally. Cloud sync will update once connected.',
        type: TopNotificationType.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.isCashier) {
      return Dialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 40, color: CelestialTheme.roseAlert),
              const SizedBox(height: 12),
              Text(
                'Access Restricted',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
              ),
              const SizedBox(height: 8),
              Text(
                'Cashier accounts cannot access or modify customer online ordering links, QR codes, or store controls.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: CelestialTheme.textMuted),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(backgroundColor: CelestialTheme.goldPrimary),
                child: Text('Close', style: TextStyle(color: CelestialTheme.primaryBtnText)),
              ),
            ],
          ),
        ),
      );
    }
    final pos = Provider.of<PosProvider>(context);
    final profile = pos.onlineStoreProfile ??
        OnlineStoreProfile(
          storeId: pos.effectiveStoreId,
          ownerEmail: pos.currentUserEmail ?? '',
          storeName: pos.storeName,
          storeAddress: pos.storeAddress,
        );
    final currentUrl = _buildOrderUrl(pos);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 24,
      ),
      child: Material(
        color: CelestialTheme.bgSurface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: CelestialTheme.borderWarm)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.qr_code_2_rounded, color: CelestialTheme.goldPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer Online Ordering',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.textLight,
                          ),
                        ),
                        Text(
                          pos.onlineStoreProfile?.customSlug != null &&
                                  pos.onlineStoreProfile!.customSlug!.isNotEmpty
                              ? 'Custom Link: ${pos.onlineStoreProfile!.customSlug}'
                              : 'Store ID: ${pos.effectiveStoreId}',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            color: CelestialTheme.goldLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: CelestialTheme.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tab Navigation
            TabBar(
              controller: _tabController,
              indicatorColor: CelestialTheme.goldPrimary,
              labelColor: CelestialTheme.goldPrimary,
              unselectedLabelColor: CelestialTheme.textMuted,
              labelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
              tabs: [
                const Tab(icon: Icon(Icons.link_rounded, size: 18), text: 'Ordering Link & QR'),
                Tab(
                  icon: Badge(
                    isLabelVisible: pos.pendingOnlineOrdersCount > 0,
                    label: Text('${pos.pendingOnlineOrdersCount}'),
                    child: const Icon(Icons.receipt_long_rounded, size: 18),
                  ),
                  text: 'Live Orders (${pos.incomingOnlineOrders.length})',
                ),
                const Tab(icon: Icon(Icons.store_mall_directory_rounded, size: 18), text: 'Store Controls'),
              ],
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildShareTab(pos, profile, currentUrl, isMobile),
                  _buildLiveOrdersTab(pos, isMobile),
                  _buildControlsTab(pos, profile),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: CelestialTheme.borderWarm)),
              ),
              child: isMobile
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CustomerOnlineOrderScreen(
                                        storeId: pos.effectiveOrderingSlug,
                                        previewMode: true,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.visibility_outlined, size: 15),
                                label: const Text(
                                  'Preview Menu',
                                  style: TextStyle(fontSize: 11.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  pos.setNavIndex(5);
                                },
                                icon: const Icon(Icons.fullscreen_rounded, size: 15),
                                label: const Text(
                                  'Online Orders',
                                  style: TextStyle(fontSize: 11.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: CelestialTheme.goldLight,
                                  side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isPublishing ? null : () => _publishCatalog(pos),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CelestialTheme.goldPrimary,
                              foregroundColor: CelestialTheme.primaryBtnText,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: _isPublishing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : const Icon(Icons.cloud_upload_rounded, size: 16),
                            label: Text(
                              _isPublishing ? 'Publishing...' : 'Sync & Publish Now',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Flexible(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CustomerOnlineOrderScreen(
                                    storeId: pos.effectiveOrderingSlug,
                                    previewMode: true,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.visibility_outlined, size: 16),
                            label: const Text(
                              'Preview Customer Menu',
                              style: TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            pos.setNavIndex(5);
                          },
                          icon: const Icon(Icons.fullscreen_rounded, size: 16),
                          label: const Text(
                            'All Online Orders',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CelestialTheme.goldLight,
                            side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isPublishing ? null : () => _publishCatalog(pos),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CelestialTheme.goldPrimary,
                            foregroundColor: CelestialTheme.primaryBtnText,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: _isPublishing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Icon(Icons.cloud_upload_rounded, size: 16),
                          label: Text(
                            _isPublishing ? 'Publishing...' : 'Sync & Publish Now',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildShareTab(
    PosProvider pos,
    OnlineStoreProfile profile,
    String currentUrl,
    bool isMobile,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // QR Code Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(
                  data: currentUrl,
                  version: QrVersions.auto,
                  size: isMobile ? 150 : 180,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 6),
                Text(
                  profile.storeName.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  _tableController.text.trim().isNotEmpty
                      ? 'SCAN FOR ${_tableController.text.trim().toUpperCase()}'
                      : 'SCAN TO ORDER FROM ANYWHERE',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Custom Ordering Link Input & Management Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CelestialTheme.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _slugStatusIsError
                    ? CelestialTheme.roseAlert.withValues(alpha: 0.6)
                    : CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.add_link_rounded, color: CelestialTheme.goldPrimary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Custom Ordering Link',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.textLight,
                        ),
                      ),
                    ),
                    if (pos.onlineStoreProfile?.customSlug != null &&
                        pos.onlineStoreProfile!.customSlug!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: CelestialTheme.emeraldReady.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: CelestialTheme.emeraldReady.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          'Custom Active',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.emeraldReady,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Set your own branded link name (e.g. celestial-cafe, neil-coffee):',
                  style: GoogleFonts.outfit(fontSize: 11.5, color: CelestialTheme.textMuted),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customSlugController,
                        onChanged: (val) {
                          setState(() {
                            _slugStatusMessage = null;
                            _slugStatusIsError = false;
                          });
                        },
                        style: GoogleFonts.outfit(
                          color: CelestialTheme.textLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          prefixText: 'order?store=',
                          prefixStyle: TextStyle(
                            color: CelestialTheme.goldLight,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          hintText: 'your-custom-link',
                          hintStyle: TextStyle(color: CelestialTheme.textSubtle, fontSize: 12),
                          filled: true,
                          fillColor: CelestialTheme.bgSurface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: CelestialTheme.borderWarm),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: CelestialTheme.borderWarm),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: CelestialTheme.goldPrimary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSavingSlug ? null : () => _saveCustomSlug(pos),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CelestialTheme.goldPrimary,
                        foregroundColor: CelestialTheme.primaryBtnText,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSavingSlug
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text('Save Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                if (_slugStatusMessage != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        _slugStatusIsError ? Icons.error_outline : Icons.check_circle_outline,
                        size: 14,
                        color: _slugStatusIsError ? CelestialTheme.roseAlert : CelestialTheme.emeraldReady,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _slugStatusMessage!,
                          style: TextStyle(
                            fontSize: 11,
                            color: _slugStatusIsError ? CelestialTheme.roseAlert : CelestialTheme.emeraldReady,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (pos.onlineStoreProfile?.customSlug != null &&
                    pos.onlineStoreProfile!.customSlug!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () => _resetToDefaultSlug(pos),
                      child: Text(
                        'Reset to default Store ID (${pos.effectiveStoreId})',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: CelestialTheme.textMuted,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Optional Table Number
          TextField(
            controller: _tableController,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Optional: Table Number (e.g. Table 04)',
              hintStyle: TextStyle(color: CelestialTheme.textSubtle, fontSize: 12),
              prefixIcon: Icon(Icons.table_restaurant_outlined, color: CelestialTheme.goldLight, size: 18),
              suffixIcon: _tableController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _tableController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: CelestialTheme.bgCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.goldPrimary)),
            ),
          ),
          const SizedBox(height: 14),

          // URL Display & Copy Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: CelestialTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CelestialTheme.borderWarm),
            ),
            child: Row(
              children: [
                Icon(Icons.link_rounded, size: 18, color: CelestialTheme.goldLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentUrl,
                    style: GoogleFonts.outfit(fontSize: 12, color: CelestialTheme.textLight),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.copy_rounded, size: 18, color: CelestialTheme.goldPrimary),
                  tooltip: 'Copy Link',
                  onPressed: () => _copyLink(currentUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons: Copy & Share
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyLink(currentUrl),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: CelestialTheme.goldPrimary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(Icons.copy_all_rounded, size: 16, color: CelestialTheme.goldPrimary),
                  label: Text('Copy Link', style: TextStyle(color: CelestialTheme.goldPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _shareUrl(currentUrl, profile.storeName),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CelestialTheme.goldPrimary,
                    foregroundColor: CelestialTheme.primaryBtnText,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Share Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlsTab(PosProvider pos, OnlineStoreProfile profile) {
    final noticeText = _noticeController.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Store Status Card (Active vs Paused) ─────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: profile.isOpen
                  ? CelestialTheme.emeraldReady.withValues(alpha: 0.12)
                  : CelestialTheme.roseAlert.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: profile.isOpen
                    ? CelestialTheme.emeraldReady.withValues(alpha: 0.45)
                    : CelestialTheme.roseAlert.withValues(alpha: 0.45),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (profile.isOpen ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert)
                            .withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        profile.isOpen ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                        color: profile.isOpen ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.isOpen ? 'ONLINE ORDERING IS ACTIVE' : 'ONLINE ORDERING IS PAUSED',
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: profile.isOpen ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            profile.isOpen
                                ? 'Customers can browse and place orders online.'
                                : 'Store is closed for orders. Customers can browse, but cannot checkout.',
                            style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: profile.isOpen,
                      activeThumbColor: CelestialTheme.emeraldReady,
                      inactiveThumbColor: CelestialTheme.roseAlert,
                      onChanged: (val) => _toggleStoreStatus(pos, profile, val),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: profile.isOpen ? null : () => _toggleStoreStatus(pos, profile, true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CelestialTheme.emeraldReady,
                          side: BorderSide(
                            color: profile.isOpen ? CelestialTheme.emeraldReady : CelestialTheme.borderWarm,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.storefront_rounded, size: 16),
                        label: const Text('Open Store', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: !profile.isOpen ? null : () => _toggleStoreStatus(pos, profile, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CelestialTheme.roseAlert,
                          side: BorderSide(
                            color: !profile.isOpen ? CelestialTheme.roseAlert : CelestialTheme.borderWarm,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.pause_circle_outline_rounded, size: 16),
                        label: const Text('Pause Orders', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Store Branding (Name & Tagline) ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CelestialTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.branding_watermark_rounded, color: CelestialTheme.goldLight, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STORE NAME & TAGLINE',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.goldLight,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Visible on the Customer Ordering website header and receipts.',
                            style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Store / Café Name',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                ),
                const SizedBox(height: 4),
                TextField(
                  key: const ValueKey('dialog_store_name_field'),
                  controller: _nameController,
                  style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. Celestial Cafe',
                    hintStyle: TextStyle(color: CelestialTheme.textSubtle, fontSize: 12),
                    filled: true,
                    fillColor: CelestialTheme.bgSurface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CelestialTheme.goldPrimary)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tagline / Subtitle',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
                ),
                const SizedBox(height: 4),
                TextField(
                  key: const ValueKey('dialog_tagline_field'),
                  controller: _taglineController,
                  style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. Handcrafted Coffee & Fresh Pastries',
                    hintStyle: TextStyle(color: CelestialTheme.textSubtle, fontSize: 12),
                    filled: true,
                    fillColor: CelestialTheme.bgSurface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CelestialTheme.goldPrimary)),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  key: const ValueKey('dialog_save_branding_btn'),
                  onPressed: _isSavingBranding ? null : () => _saveBranding(pos, profile),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CelestialTheme.goldPrimary,
                    foregroundColor: CelestialTheme.primaryBtnText,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isSavingBranding
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.check_rounded, size: 16),
                  label: Text(
                    _isSavingBranding ? 'Saving...' : 'Save Name & Tagline',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 2. Store Announcement & Closed Notice ───────────────────────────
          Row(
            children: [
              Icon(Icons.campaign_outlined, size: 16, color: CelestialTheme.goldLight),
              const SizedBox(width: 6),
              Text(
                'STORE ANNOUNCEMENT & CLOSED MESSAGE',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: CelestialTheme.goldLight,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Displays prominently at the top of the ordering website. Informs customers if you are closed, resting, or when orders will resume.',
            style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted),
          ),
          const SizedBox(height: 8),

          // Text Field for Notice
          TextField(
            controller: _noticeController,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'e.g. We are closed right now. Reopening at 8:00 AM! / Orders paused for 30 mins due to rush.',
              hintStyle: TextStyle(color: CelestialTheme.textSubtle, fontSize: 12),
              filled: true,
              fillColor: CelestialTheme.bgCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.goldPrimary)),
            ),
          ),
          const SizedBox(height: 8),

          // Quick Presets Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildNoticePresetChip('Closed for the day'),
              _buildNoticePresetChip('Back in 30 minutes'),
              _buildNoticePresetChip('Kitchen at capacity - orders paused'),
              _buildNoticePresetChip('Closed for private event'),
              _buildNoticePresetChip('Sold out for today - see you tomorrow!'),
            ],
          ),
          const SizedBox(height: 10),

          // Save & Clear Message Actions
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isSavingNotice ? null : () => _saveNotice(pos, profile),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CelestialTheme.goldPrimary,
                  foregroundColor: CelestialTheme.primaryBtnText,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isSavingNotice
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.check_rounded, size: 16),
                label: Text(
                  _isSavingNotice ? 'Saving...' : 'Save Message',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              if (_noticeController.text.isNotEmpty) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _isSavingNotice ? null : () => _clearNotice(pos, profile),
                  style: TextButton.styleFrom(
                    foregroundColor: CelestialTheme.roseAlert,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.clear_rounded, size: 14),
                  label: const Text('Clear Message', style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Live Customer Preview Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CelestialTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: !profile.isOpen
                    ? CelestialTheme.roseAlert.withValues(alpha: 0.5)
                    : CelestialTheme.goldPrimary.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      !profile.isOpen ? Icons.lock_clock_rounded : Icons.campaign_rounded,
                      size: 14,
                      color: !profile.isOpen ? CelestialTheme.roseAlert : CelestialTheme.goldLight,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'PREVIEW: WHAT CUSTOMERS SEE ON THE WEBSITE',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: !profile.isOpen ? CelestialTheme.roseAlert : CelestialTheme.goldLight,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  !profile.isOpen
                      ? (noticeText.isNotEmpty
                          ? '⚠️ STORE CLOSED: $noticeText'
                          : '⚠️ ONLINE ORDERING IS PAUSED: The store is currently not accepting online orders right now.')
                      : (noticeText.isNotEmpty
                          ? '📢 ANNOUNCEMENT: $noticeText'
                          : '✨ Store is open and accepting all online orders!'),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: !profile.isOpen ? CelestialTheme.creamLight : CelestialTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 3. Accepted Order Types ─────────────────────────────────────────
          Text(
            'ACCEPTED ORDER TYPES',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: CelestialTheme.goldLight,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),

          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              value: profile.allowDineIn,
              activeColor: CelestialTheme.goldPrimary,
              checkColor: CelestialTheme.primaryBtnText,
              contentPadding: EdgeInsets.zero,
              title: Text('Dine-In (Table QR Ordering)', style: GoogleFonts.outfit(fontSize: 13, color: CelestialTheme.textLight)),
              subtitle: Text('Customers enter their table number at checkout', style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted)),
              onChanged: (val) {
                profile.allowDineIn = val ?? true;
                pos.updateOnlineStoreProfile(profile);
                setState(() {});
              },
            ),
          ),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              value: profile.allowTakeaway,
              activeColor: CelestialTheme.goldPrimary,
              checkColor: CelestialTheme.primaryBtnText,
              contentPadding: EdgeInsets.zero,
              title: Text('Takeaway / Pickup', style: GoogleFonts.outfit(fontSize: 13, color: CelestialTheme.textLight)),
              subtitle: Text('Customers order from home/office and pick up in store', style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted)),
              onChanged: (val) {
                profile.allowTakeaway = val ?? true;
                pos.updateOnlineStoreProfile(profile);
                setState(() {});
              },
            ),
          ),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              value: profile.allowDelivery,
              activeColor: CelestialTheme.goldPrimary,
              checkColor: CelestialTheme.primaryBtnText,
              contentPadding: EdgeInsets.zero,
              title: Text('Delivery', style: GoogleFonts.outfit(fontSize: 13, color: CelestialTheme.textLight)),
              subtitle: Text('Customers enter delivery address and mobile number', style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted)),
              onChanged: (val) {
                profile.allowDelivery = val ?? true;
                pos.updateOnlineStoreProfile(profile);
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 14),

          // ── 4. Estimated Preparation Time ──────────────────────────────────
          Text(
            'ESTIMATED PREPARATION TIME',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: CelestialTheme.goldLight,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            initialValue: profile.estimatedPrepMinutes,
            dropdownColor: CelestialTheme.bgCard,
            style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: CelestialTheme.bgCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: CelestialTheme.borderWarm)),
            ),
            items: const [
              DropdownMenuItem(value: 10, child: Text('10 Minutes')),
              DropdownMenuItem(value: 15, child: Text('15 Minutes (Standard)')),
              DropdownMenuItem(value: 20, child: Text('20 Minutes')),
              DropdownMenuItem(value: 30, child: Text('30 Minutes')),
              DropdownMenuItem(value: 45, child: Text('45 Minutes')),
            ],
            onChanged: (val) {
              if (val != null) {
                profile.estimatedPrepMinutes = val;
                pos.updateOnlineStoreProfile(profile);
                setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoticePresetChip(String text) {
    return InkWell(
      onTap: () {
        _noticeController.text = text;
        setState(() {});
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: CelestialTheme.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CelestialTheme.borderWarm),
        ),
        child: Text(
          text,
          style: GoogleFonts.outfit(fontSize: 10.5, color: CelestialTheme.goldLight),
        ),
      ),
    );
  }

  Widget _buildLiveOrdersTab(PosProvider pos, bool isMobile) {
    final incoming = pos.incomingOnlineOrders;

    if (incoming.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CelestialTheme.bgCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: CelestialTheme.borderWarm),
                ),
                child: Icon(Icons.inbox_rounded, size: 42, color: CelestialTheme.goldLight.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 16),
              Text(
                'No Incoming Online Orders',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: CelestialTheme.textLight,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Customer orders placed through your web menu will appear here and in the header badge instantly.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  color: CelestialTheme.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  pos.setNavIndex(5);
                },
                icon: const Icon(Icons.delivery_dining_rounded, size: 16),
                label: const Text('Open Online Orders Screen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CelestialTheme.goldPrimary,
                  foregroundColor: CelestialTheme.primaryBtnText,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: incoming.length + 1,
      itemBuilder: (context, index) {
        if (index == incoming.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  pos.setNavIndex(5);
                },
                icon: const Icon(Icons.fullscreen_rounded, size: 16),
                label: const Text('View All in Online Orders Screen'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CelestialTheme.goldLight,
                  side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          );
        }

        final order = incoming[index];
        final isPending = order.status == OrderStatus.pending;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: CelestialTheme.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isPending
                  ? CelestialTheme.goldPrimary.withValues(alpha: 0.5)
                  : CelestialTheme.borderWarm,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPending
                            ? CelestialTheme.goldPrimary.withValues(alpha: 0.2)
                            : CelestialTheme.emeraldReady.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order.status.name.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isPending ? CelestialTheme.goldLight : CelestialTheme.emeraldReady,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.orderNumber,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.textLight,
                        ),
                      ),
                    ),
                    Text(
                      NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(order.totalAmount),
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.goldLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${order.customerName.isNotEmpty ? order.customerName : "Customer"} • ${order.orderType.name.toUpperCase()} (${order.items.length} items)',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: CelestialTheme.warmGray,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        pos.setNavIndex(5);
                      },
                      child: const Text('Details', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    if (isPending)
                      ElevatedButton.icon(
                        onPressed: () => OnlineOrderConfirmDialog.show(context, order),
                        icon: const Icon(Icons.check_circle_rounded, size: 14),
                        label: const Text('Review & Confirm', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CelestialTheme.goldPrimary,
                          foregroundColor: CelestialTheme.primaryBtnText,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
