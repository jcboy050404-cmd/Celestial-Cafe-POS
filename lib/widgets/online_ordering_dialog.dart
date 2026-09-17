import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/pos_provider.dart';
import '../screens/customer_online_order_screen.dart';
import '../services/online_order_service.dart';
import '../theme/celestial_theme.dart';
import 'top_notification.dart';

/// Modal dialog enabling store owners to generate, customize, and share customer online ordering links & QR codes.
class OnlineOrderingDialog extends StatefulWidget {
  const OnlineOrderingDialog({super.key});

  static Future<void> show(BuildContext context) {
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
  bool _isPublishing = false;
  bool _isSavingSlug = false;
  String? _slugStatusMessage;
  bool _slugStatusIsError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final pos = Provider.of<PosProvider>(context, listen: false);
    final profile = pos.onlineStoreProfile;
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
              tabs: const [
                Tab(icon: Icon(Icons.link_rounded, size: 18), text: 'Ordering Link & QR'),
                Tab(icon: Icon(Icons.store_mall_directory_rounded, size: 18), text: 'Store Controls'),
              ],
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildShareTab(pos, profile, currentUrl, isMobile),
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
              child: Row(
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Status Toggle
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: profile.isOpen
                  ? CelestialTheme.emeraldReady.withValues(alpha: 0.12)
                  : CelestialTheme.roseAlert.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: profile.isOpen
                    ? CelestialTheme.emeraldReady.withValues(alpha: 0.4)
                    : CelestialTheme.roseAlert.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  profile.isOpen ? Icons.check_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                  color: profile.isOpen ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                  size: 26,
                ),
                const SizedBox(width: 12),
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
                        ),
                      ),
                      Text(
                        profile.isOpen
                            ? 'Customers can place orders anytime from anywhere.'
                            : 'Menu is viewable, but checkout is temporarily paused.',
                        style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: profile.isOpen,
                  activeThumbColor: CelestialTheme.emeraldReady,
                  onChanged: (val) {
                    profile.isOpen = val;
                    pos.updateOnlineStoreProfile(profile);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Text(
            'ACCEPTED ORDER TYPES',
            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),

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

          Text(
            'ESTIMATED PREPARATION TIME',
            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight, letterSpacing: 0.5),
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
}
