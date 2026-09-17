import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../providers/pos_provider.dart';
import '../services/auth_service.dart';
import '../services/cloud_backup_service.dart';
import '../theme/celestial_theme.dart';
import 'price_editor_dialog.dart';
import 'top_notification.dart';
import 'admin_management_dialog.dart';
import 'cashier_management_dialog.dart';
import 'create_pin_dialog.dart';
import 'signature_banner_dialog.dart';
import 'upgrade_pro_dialog.dart';

class SettingsDialog extends StatefulWidget {
  final int initialTab;
  const SettingsDialog({super.key, this.initialTab = 0});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _nameController;
  late TextEditingController _taglineController;
  late TextEditingController _addressController;
  late TextEditingController _availabilitySearchController;
  bool _isPickingImage = false;
  bool _isSavingSettings = false;
  bool _isCloudRestoring = false;
  int _activeTab = 0; // 0 = Store & Branding, 1 = Item & Modifier Availability
  String _availabilitySearchQuery = '';
  ItemCategory _selectedAvailabilityCategory = ItemCategory.all;
  String _selectedAvailabilityCategoryId = 'all';
  bool _showOnlyUnavailable = false;
  final Set<String> _expandedItemIds = {};

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    final provider = Provider.of<PosProvider>(context, listen: false);
    _nameController = TextEditingController(text: provider.storeName);
    _taglineController = TextEditingController(text: provider.storeTagline);
    _addressController = TextEditingController(text: provider.storeAddress);
    _availabilitySearchController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _addressController.dispose();
    _availabilitySearchController.dispose();
    super.dispose();
  }

  String _formatSyncTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 10) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return 'at $h:$m';
  }

  Future<void> _pickAndUploadLogo(PosProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isPickingImage = true);
    try {
      final files = await FilePickerPlatform.instance.pickFiles(
        type: FileType.image,
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final Uint8List bytes = await file.readAsBytes();

        if (mounted) {
          await provider.setCustomLogo(bytes);
          // Auto-sync handled automatically by PosProvider._scheduleProCloudSync()
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                backgroundColor: CelestialTheme.bgCard,
                content: const Text('✨ Cafe logo updated and saved successfully!'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: CelestialTheme.roseAlert,
            content: Text('⚠️ Failed to pick image: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _saveSettings(PosProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _isSavingSettings = true);
    await Future.delayed(const Duration(milliseconds: 250));
    provider.updateStoreDetails(
      name: _nameController.text,
      tagline: _taglineController.text,
      address: _addressController.text,
    );
    // Auto-sync handled automatically by PosProvider._scheduleProCloudSync()
    if (mounted) setState(() => _isSavingSettings = false);
    nav.pop();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: CelestialTheme.bgCard,
        content: Text('Store branding settings saved!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PosProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: isMobile ? double.infinity : (_activeTab == 1 ? 760.0 : 560.0),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: CelestialTheme.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 14),
              decoration: BoxDecoration(
                color: CelestialTheme.bgCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(
                    _activeTab == 0 ? Icons.storefront_rounded : Icons.do_not_disturb_on_outlined,
                    color: CelestialTheme.goldPrimary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _activeTab == 0
                          ? (isMobile ? 'Store & Theme Settings' : 'Store Settings, Theme & Logo')
                          : (isMobile ? 'Item & Modifier Availability' : 'Item & Modifier Availability'),
                      style: GoogleFonts.outfit(
                        fontSize: isMobile ? 15 : 17,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.textLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: CelestialTheme.textMuted),
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),

            // Tab Navigation Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: CelestialTheme.bgCard.withValues(alpha: 0.6),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      title: isMobile ? 'Store & Theme' : 'Store, Theme & Branding',
                      icon: Icons.storefront_rounded,
                      isSelected: _activeTab == 0,
                      onTap: () => setState(() => _activeTab = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTabButton(
                      title: isMobile ? 'Availability' : 'Item Availability',
                      icon: Icons.do_not_disturb_on_outlined,
                      badgeCount: provider.totalUnavailableItemsCount + provider.totalUnavailableOptionsCount,
                      isSelected: _activeTab == 1,
                      onTap: () => setState(() => _activeTab = 1),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Tab Content
            Expanded(
              child: _activeTab == 0
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 0: POS Theme & Atmosphere
                    Text(
                      'POS THEME & ATMOSPHERE',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: CelestialTheme.goldLight,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (isMobile) ...[
                      _buildThemeCard(
                        context: context,
                        mode: PosThemeMode.classicEspresso,
                        isSelected: provider.themeMode == PosThemeMode.classicEspresso,
                        onTap: () {
                          provider.setThemeMode(PosThemeMode.classicEspresso);
                          setState(() {});
                        },
                        title: 'Classic Warm Espresso',
                        subtitle: 'Roasted espresso, honey gold & toasted caramel',
                        primaryColor: const Color(0xFFD4A359),
                        accentColor: const Color(0xFFC48248),
                        bgColor: const Color(0xFF000000),
                        icon: Icons.coffee_rounded,
                      ),
                      const SizedBox(height: 10),
                      _buildThemeCard(
                        context: context,
                        mode: PosThemeMode.londonBistro,
                        isSelected: provider.themeMode == PosThemeMode.londonBistro,
                        onTap: () {
                          provider.setThemeMode(PosThemeMode.londonBistro);
                          setState(() {});
                        },
                        title: 'London Bistro Resto',
                        subtitle: 'Obsidian matte black & British royal red (Pure Black & Red)',
                        primaryColor: const Color(0xFFE52538),
                        accentColor: const Color(0xFFC8102E),
                        bgColor: const Color(0xFF060608),
                        icon: Icons.local_bar_rounded,
                      ),
                    ] else
                      Row(
                        children: [
                          // Option A: Classic Warm Espresso
                          Expanded(
                            child: _buildThemeCard(
                              context: context,
                              mode: PosThemeMode.classicEspresso,
                              isSelected: provider.themeMode == PosThemeMode.classicEspresso,
                              onTap: () {
                                provider.setThemeMode(PosThemeMode.classicEspresso);
                                setState(() {});
                              },
                              title: 'Classic Warm Espresso',
                              subtitle: 'Roasted espresso, honey gold & toasted caramel',
                              primaryColor: const Color(0xFFD4A359),
                              accentColor: const Color(0xFFC48248),
                              bgColor: const Color(0xFF000000),
                              icon: Icons.coffee_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Option B: London Bistro Black & Red
                          Expanded(
                            child: _buildThemeCard(
                              context: context,
                              mode: PosThemeMode.londonBistro,
                              isSelected: provider.themeMode == PosThemeMode.londonBistro,
                              onTap: () {
                                provider.setThemeMode(PosThemeMode.londonBistro);
                                setState(() {});
                              },
                              title: 'London Bistro Resto',
                              subtitle: 'Obsidian matte black & British royal red (Pure Black & Red)',
                              primaryColor: const Color(0xFFE52538),
                              accentColor: const Color(0xFFC8102E),
                              bgColor: const Color(0xFF060608),
                              icon: Icons.local_bar_rounded,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),

                    // Section 1: Logo Upload & Preview
                    Text(
                      'CAFE LOGO',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: CelestialTheme.goldLight,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          // Logo Preview Box
                          GestureDetector(
                            onTap: _isPickingImage ? null : () => _pickAndUploadLogo(provider),
                            child: Tooltip(
                              message: 'Click to upload or edit cafe logo',
                              child: Stack(
                                children: [
                                  Container(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      color: CelestialTheme.bgSurface,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.18),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.35),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: provider.hasCustomLogo
                                          ? Image.memory(
                                              provider.customLogoBytes!,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.asset(
                                              'assets/images/Logo.png',
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: CelestialTheme.goldPrimary,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: CelestialTheme.bgDark, width: 1.5),
                                      ),
                                      child: Icon(
                                        Icons.camera_alt_rounded,
                                        size: 13,
                                        color: CelestialTheme.primaryBtnText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Actions
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.hasCustomLogo ? 'Custom Logo Active' : 'Default Celestial Logo',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: CelestialTheme.textLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Used on App Header, Receipts, & Reports.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: CelestialTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _isPickingImage ? null : () => _pickAndUploadLogo(provider),
                                      icon: _isPickingImage
                                          ? SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: CelestialTheme.primaryBtnText),
                                            )
                                          : const Icon(Icons.upload_file_rounded, size: 14),
                                      label: Text(
                                        provider.hasCustomLogo ? 'Change Logo' : 'Upload Logo',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: CelestialTheme.goldPrimary,
                                        foregroundColor: CelestialTheme.primaryBtnText,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                    if (provider.hasCustomLogo)
                                      OutlinedButton.icon(
                                        onPressed: () => provider.resetToDefaultLogo(),
                                        icon: const Icon(Icons.restore_rounded, size: 14),
                                        label: const Text('Reset', style: TextStyle(fontSize: 11)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: CelestialTheme.textMuted,
                                          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Section 1.5: Menu Catalog Template & Management
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'MENU CATALOG TEMPLATE',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: CelestialTheme.goldLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            '${provider.menuItems.length} items in catalog',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.restaurant_menu_rounded, size: 20, color: CelestialTheme.goldLight),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.menuItems.isEmpty ? 'Clean Slate (0 Items)' : '${provider.menuItems.length} Items in Catalog',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: CelestialTheme.textLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  provider.menuItems.isEmpty
                                      ? 'Your catalog is clean and empty. You can add custom items in Menu & Stock, or load the sample template.'
                                      : 'You can clear all default items to start fresh, or re-load the sample cafe catalog.',
                                  style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (provider.menuItems.isNotEmpty)
                                      OutlinedButton.icon(
                                        onPressed: () => _confirmClearMenu(context, provider),
                                        icon: const Icon(Icons.delete_sweep_rounded, size: 14),
                                        label: const Text('Clear All Default Items', style: TextStyle(fontSize: 11)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: CelestialTheme.roseAlert,
                                          side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.5)),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        await provider.loadSampleMenu();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              backgroundColor: CelestialTheme.bgSurfaceLight,
                                              content: Text('Sample cafe menu items loaded!', style: TextStyle(color: CelestialTheme.goldLight)),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.download_rounded, size: 14),
                                      label: const Text('Load Sample Cafe Menu', style: TextStyle(fontSize: 11)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: CelestialTheme.goldLight,
                                        side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 2: Display & Accessibility (Text Scaling)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'DISPLAY & ACCESSIBILITY (TEXT SIZE)',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: CelestialTheme.goldLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${(provider.uiScale * 100).round()}% ${provider.uiScale >= 1.4 ? 'Huge' : provider.uiScale >= 1.25 ? 'Extra Large' : provider.uiScale >= 1.1 ? 'Large' : provider.uiScale < 0.95 ? 'Compact' : 'Standard'}',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.goldLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.remove_red_eye_outlined, color: CelestialTheme.goldPrimary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Adjust text size live for cashiers with eye strain or vision needs.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    color: CelestialTheme.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Preset Scale Pills
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildScalePresetButton(provider, label: '90% Small', scale: 0.90),
                              _buildScalePresetButton(provider, label: '100% Standard', scale: 1.00),
                              _buildScalePresetButton(provider, label: '115% Large', scale: 1.15),
                              _buildScalePresetButton(provider, label: '130% Extra Large', scale: 1.30),
                              _buildScalePresetButton(provider, label: '145% Huge', scale: 1.45),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Live Slider Control
                          Row(
                            children: [
                              Icon(Icons.text_fields_rounded, size: 14, color: CelestialTheme.textMuted),
                              const SizedBox(width: 6),
                              Text('A', style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted)),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: CelestialTheme.goldPrimary,
                                    inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                                    thumbColor: CelestialTheme.goldLight,
                                    overlayColor: CelestialTheme.goldPrimary.withValues(alpha: 0.2),
                                    trackHeight: 3.5,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                  ),
                                  child: Slider(
                                    value: provider.uiScale,
                                    min: 0.85,
                                    max: 1.45,
                                    divisions: 12,
                                    onChanged: (newScale) {
                                      provider.setUiScale(newScale);
                                    },
                                  ),
                                ),
                              ),
                              Text('A', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight)),
                              const SizedBox(width: 8),
                              if ((provider.uiScale - 1.0).abs() > 0.01)
                                Tooltip(
                                  message: 'Reset to 100% Default',
                                  child: InkWell(
                                    onTap: () => provider.resetUiScale(),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(Icons.refresh_rounded, size: 16, color: CelestialTheme.goldLight.withValues(alpha: 0.8)),
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          // Live Preview Box
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: CelestialTheme.bgSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.coffee_rounded, size: 18, color: CelestialTheme.goldLight),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Iced Spanish Latte (Large)',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: CelestialTheme.textLight,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Oat Milk • Less Sweet 50% • Dine-In',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10.5,
                                          color: CelestialTheme.textMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₱160.00',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: CelestialTheme.goldLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),



                    const SizedBox(height: 20),

                    // Section 3: Store Information
                    Text(
                      'RECEIPT & STORE DETAILS',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: CelestialTheme.goldLight,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Store Name
                    _buildTextField(
                      controller: _nameController,
                      label: 'Store / Cafe Name',
                      hint: 'e.g. Celestial Cafe',
                      icon: Icons.title_rounded,
                    ),

                    const SizedBox(height: 12),

                    // Tagline
                    _buildTextField(
                      controller: _taglineController,
                      label: 'Tagline / Category Header',
                      hint: 'e.g. COFFEE • MILKTEA • CHEESECAKE • BITES',
                      icon: Icons.subtitles_rounded,
                    ),

                    const SizedBox(height: 12),

                    // Address / Contact / TIN
                    _buildTextField(
                      controller: _addressController,
                      label: 'Branch Address, Phone & TIN',
                      hint: 'e.g. Main Branch\nTel: (02) 8721-4900 • TIN #482-901-382-000',
                      icon: Icons.location_on_outlined,
                      maxLines: 2,
                    ),

                    const SizedBox(height: 16),

                    // Order Number Sequence Manager
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order Number Sequence',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: CelestialTheme.textLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Next Order: #${provider.currentOrderSequence}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: CelestialTheme.goldLight,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              provider.resetOrderSequence(startNumber: 1);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: CelestialTheme.bgCard,
                                  content: Text('Order sequence reset to start at #1'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.restart_alt_rounded, size: 14),
                            label: const Text('Reset to #1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: CelestialTheme.goldLight,
                              side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Section: Signature Spotlight Banner Customizer
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: provider.signatureBannerEnabled
                              ? CelestialTheme.caramelAccent.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: CelestialTheme.caramelAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.stars_rounded, color: CelestialTheme.goldLight, size: 18),
                          ),
                          const SizedBox(width: 10),
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
                                      'Signature Craft Banner',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: CelestialTheme.textLight,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: provider.signatureBannerEnabled
                                            ? CelestialTheme.caramelAccent.withValues(alpha: 0.2)
                                            : CelestialTheme.roseAlert.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        provider.signatureBannerEnabled ? 'ACTIVE' : 'HIDDEN',
                                        style: GoogleFonts.outfit(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: provider.signatureBannerEnabled
                                              ? CelestialTheme.goldLight
                                              : CelestialTheme.roseAlert,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Hero spotlight on POS: "${provider.signatureBannerTitle}"',
                                  style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierColor: Colors.black.withValues(alpha: 0.85),
                                builder: (ctx) => const SignatureBannerDialog(),
                              );
                            },
                            icon: const Icon(Icons.tune_rounded, size: 14),
                            label: const Text('Customize', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CelestialTheme.caramelAccent,
                              foregroundColor: CelestialTheme.primaryBtnText,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Section 3: User Account & Subscription Tier (Firebase)
                    Consumer<AuthService>(
                      builder: (context, auth, _) {
                        final user = auth.currentUser;
                        final isPro = auth.isPro;
                        final isAdmin = auth.isAdmin || auth.checkIfAdmin(user?.email ?? '');
                        final trialDays = (user?.hasCustomTrial == true ? user!.customTrialDays : null) ?? auth.defaultTrialDays;
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: CelestialTheme.bgSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isAdmin
                                        ? Icons.admin_panel_settings_rounded
                                        : (isPro ? Icons.workspace_premium_rounded : Icons.account_circle_outlined),
                                    color: isPro || isAdmin ? CelestialTheme.goldPrimary : CelestialTheme.goldLight,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'ACCOUNT & LICENSE',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.8,
                                            color: CelestialTheme.goldLight,
                                          ),
                                        ),
                                        Text(
                                          user?.email ?? 'cashier@celestialcafe.com',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: CelestialTheme.textLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isAdmin) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        color: CelestialTheme.goldPrimary.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5)),
                                      ),
                                      child: Text(
                                        'ADMIN',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: CelestialTheme.goldLight,
                                        ),
                                      ),
                                    ),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isPro
                                          ? CelestialTheme.goldPrimary.withValues(alpha: 0.2)
                                          : CelestialTheme.amberBrewing.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isPro ? CelestialTheme.goldPrimary : CelestialTheme.amberBrewing,
                                      ),
                                    ),
                                    child: Text(
                                      isPro ? 'PRO ACTIVE' : '${user?.trialDaysRemaining ?? trialDays}D TRIAL',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isPro ? CelestialTheme.goldLight : CelestialTheme.amberBrewing,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        CreatePinDialog.show(
                                          context,
                                          email: user?.email ?? '',
                                          displayName: user?.displayName,
                                          isUpdate: auth.hasPin(user?.email),
                                        );
                                      },
                                      icon: Icon(Icons.pin_outlined, size: 14, color: CelestialTheme.goldLight),
                                      label: Text(
                                        auth.hasPin(user?.email) ? 'Update Station PIN' : 'Create Station PIN',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CelestialTheme.goldLight),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: CelestialTheme.bgSurface,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            side: BorderSide(color: CelestialTheme.borderWarm),
                                          ),
                                          title: Text('Sign Out Station', style: TextStyle(color: CelestialTheme.textLight, fontWeight: FontWeight.bold)),
                                          content: Text(
                                            'Are you sure you want to sign out of this terminal session?',
                                            style: TextStyle(color: CelestialTheme.textMuted),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
                                            ),
                                            ElevatedButton.icon(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              icon: const Icon(Icons.logout_rounded, size: 15, color: Colors.white),
                                              style: ElevatedButton.styleFrom(backgroundColor: CelestialTheme.roseAlert),
                                              label: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true && context.mounted) {
                                        Navigator.pop(context);
                                        TopNotification.showSuccess(context, 'Signed out of terminal.');
                                        await auth.signOut();
                                      }
                                    },
                                    icon: const Icon(Icons.logout_rounded, size: 14, color: Colors.white),
                                    label: const Text(
                                      'Sign Out',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: CelestialTheme.roseAlert,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                              if (auth.isOwner) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      CashierManagementDialog.show(context);
                                    },
                                    icon: const Icon(Icons.people_alt_rounded, size: 16),
                                    label: const Text(
                                      'Cashier & Staff Management',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: CelestialTheme.goldPrimary,
                                      foregroundColor: CelestialTheme.primaryBtnText,
                                      padding: const EdgeInsets.symmetric(vertical: 9),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                              if (isAdmin) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      AdminManagementDialog.show(context);
                                    },
                                    icon: Icon(Icons.admin_panel_settings_rounded, size: 16, color: CelestialTheme.goldLight),
                                    label: Text(
                                      'Developer Admin Portal',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                                      padding: const EdgeInsets.symmetric(vertical: 9),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Section: Cloud Email Backup & Restore (Pro Exclusive)
                    Consumer<AuthService>(
                      builder: (context, auth, _) {
                        final user = auth.currentUser;
                        final isPro = auth.isPro || auth.isAdmin;
                        final email = user?.email ?? '';

                        if (isPro) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: CelestialTheme.bgSurface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: CelestialTheme.goldPrimary.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.cloud_done_rounded,
                                      color: CelestialTheme.goldPrimary,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'CLOUD EMAIL BACKUP',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.8,
                                              color: CelestialTheme.goldLight,
                                            ),
                                          ),
                                          Text(
                                            'Automatic cloud protection active',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              color: CelestialTheme.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: CelestialTheme.goldPrimary.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: CelestialTheme.goldPrimary),
                                      ),
                                      child: Text(
                                        'PRO SYNCED',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: CelestialTheme.goldLight,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Your store branding, settings, and cafe logo are automatically backed up to Firebase under $email. Changes sync to the cloud within seconds — no manual backup needed.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    color: CelestialTheme.textLight.withValues(alpha: 0.85),
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Auto-save status row
                                Consumer<PosProvider>(
                                  builder: (context, pos, _) {
                                    final lastSync = pos.autoSyncLastTime;
                                    final syncLabel = lastSync == null
                                        ? 'Not yet synced this session'
                                        : 'Auto-saved ${_formatSyncTime(lastSync)}';
                                    return Row(
                                      children: [
                                        Icon(
                                          lastSync == null
                                              ? Icons.cloud_queue_rounded
                                              : Icons.cloud_done_rounded,
                                          size: 14,
                                          color: lastSync == null
                                              ? CelestialTheme.textMuted
                                              : CelestialTheme.goldPrimary,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            syncLabel,
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              color: lastSync == null
                                                  ? CelestialTheme.textMuted
                                                  : CelestialTheme.goldLight,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: _isCloudRestoring
                                                ? null
                                                : () async {
                                                    final messenger = ScaffoldMessenger.of(context);
                                                    setState(() => _isCloudRestoring = true);
                                                    final backup = await CloudBackupService().fetchProBackup(email);
                                                    if (backup != null) {
                                                      await provider.restoreFromProCloudBackup(backup);
                                                      _nameController.text = provider.storeName;
                                                      _taglineController.text = provider.storeTagline;
                                                      _addressController.text = provider.storeAddress;
                                                    }
                                                    final menuRestored = await provider.syncMenuFromCloud();
                                                    if (mounted) setState(() => _isCloudRestoring = false);
                                                    if (mounted) {
                                                      final hasSuccess = backup != null || menuRestored;
                                                      messenger.showSnackBar(
                                                        SnackBar(
                                                          backgroundColor: hasSuccess
                                                              ? CelestialTheme.bgCard
                                                              : CelestialTheme.roseAlert,
                                                          content: Text(
                                                            hasSuccess
                                                                ? '✨ Pro settings, logo & menu restored from Cloud!'
                                                                : 'No cloud backup found or device is offline.',
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                            icon: _isCloudRestoring
                                                ? SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child: CircularProgressIndicator(strokeWidth: 2, color: CelestialTheme.goldLight),
                                                  )
                                                : Icon(Icons.cloud_download_rounded, size: 16, color: CelestialTheme.goldLight),
                                            label: Text(
                                              _isCloudRestoring ? 'Restoring...' : 'Restore from Cloud',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        } else {
                          // Free Trial account - Pro Only feature banner
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: CelestialTheme.bgSurface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.cloud_off_rounded,
                                      color: CelestialTheme.amberBrewing,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'CLOUD EMAIL BACKUP',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.8,
                                              color: CelestialTheme.textLight,
                                            ),
                                          ),
                                          Text(
                                            'Stored on local device only',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              color: CelestialTheme.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: CelestialTheme.amberBrewing.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: CelestialTheme.amberBrewing),
                                      ),
                                      child: Text(
                                        'PRO ONLY',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: CelestialTheme.amberBrewing,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Cloud backup and automatic data recovery after clearing app data is an exclusive Pro feature. Upgrade to protect your business settings, custom logo, and menu.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    color: CelestialTheme.textMuted,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => UpgradeProDialog.show(context),
                                    icon: const Icon(Icons.workspace_premium_rounded, size: 15),
                                    label: const Text(
                                      'Upgrade to Pro to Unlock Cloud Backup',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: CelestialTheme.goldPrimary,
                                      foregroundColor: CelestialTheme.primaryBtnText,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    // Data & Shift Reset Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CelestialTheme.roseAlert.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CelestialTheme.roseAlert.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.delete_sweep_rounded, color: CelestialTheme.roseAlert, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Clear Data & Shift Reset',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: CelestialTheme.textLight,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Clear orders for a fresh shift or completely wipe application data',
                                      style: TextStyle(fontSize: 10.5, color: CelestialTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _confirmClearOrders(context, provider),
                                icon: Icon(Icons.cleaning_services_rounded, size: 14, color: CelestialTheme.amberBrewing),
                                label: Text(
                                  'Clear All Orders (Start Shift #1)',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CelestialTheme.amberBrewing),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: CelestialTheme.amberBrewing.withValues(alpha: 0.5)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _confirmResetAllData(context, provider),
                                icon: const Icon(Icons.delete_forever_rounded, size: 14, color: Colors.white),
                                label: const Text(
                                  'Factory Reset All Data',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: CelestialTheme.roseAlert,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : _buildAvailabilityTab(context, provider, isMobile),
          ),

          const Divider(height: 1),

          // Footer Actions
          _buildFooterActions(provider, isMobile),
        ],
      ),
    ),
  );
}

  Widget _buildFooterActions(PosProvider provider, bool isMobile) {
    if (_activeTab == 1) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
        decoration: BoxDecoration(
          color: CelestialTheme.bgCard,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        child: Row(
          children: [
            Icon(Icons.flash_on_rounded, size: 16, color: CelestialTheme.goldLight),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isMobile ? 'Live sync with POS & KDS' : 'Changes apply live to POS workstations & self-order web menus.',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  color: CelestialTheme.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Done'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CelestialTheme.goldPrimary,
                foregroundColor: CelestialTheme.primaryBtnText,
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isMobile) ...[
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isSavingSettings ? null : () => _saveSettings(provider),
                icon: _isSavingSettings
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: CelestialTheme.primaryBtnText),
                      )
                    : const Icon(Icons.check_rounded, size: 16),
                label: Text(_isSavingSettings ? 'Saving...' : 'Save Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CelestialTheme.goldPrimary,
                  foregroundColor: CelestialTheme.primaryBtnText,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ] else ...[
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _isSavingSettings ? null : () => _saveSettings(provider),
              icon: _isSavingSettings
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: CelestialTheme.primaryBtnText),
                    )
                  : const Icon(Icons.check_rounded, size: 16),
              label: Text(_isSavingSettings ? 'Saving...' : 'Save Changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CelestialTheme.goldPrimary,
                foregroundColor: CelestialTheme.primaryBtnText,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? CelestialTheme.goldPrimary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? CelestialTheme.goldPrimary.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? CelestialTheme.goldPrimary : CelestialTheme.textMuted,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? CelestialTheme.textLight : CelestialTheme.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: CelestialTheme.roseAlert,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityTab(BuildContext context, PosProvider provider, bool isMobile) {
    final allItems = provider.menuItems;
    final unavailableItems = allItems.where((i) => !i.inStock).length;
    final unavailableOpts = allItems.fold(0, (sum, i) => sum + i.unavailableOptionsCount);

    final filtered = allItems.where((item) {
      if (_selectedAvailabilityCategoryId != 'all') {
        final matchesCat = item.customCategory != null && item.customCategory!.isNotEmpty
            ? item.customCategory == _selectedAvailabilityCategoryId || item.category.name == _selectedAvailabilityCategoryId
            : item.category.name == _selectedAvailabilityCategoryId || item.category == _selectedAvailabilityCategory;
        if (!matchesCat) return false;
      }
      if (_showOnlyUnavailable && item.inStock && !item.hasUnavailableOptions) {
        return false;
      }
      if (_availabilitySearchQuery.isNotEmpty) {
        final q = _availabilitySearchQuery.toLowerCase();
        final matchName = item.name.toLowerCase().contains(q);
        final matchCategory = item.category.label.toLowerCase().contains(q);
        final matchOptions = item.customizationGroups.any(
          (g) => g.options.any((o) => o.name.toLowerCase().contains(q)),
        );
        if (!matchName && !matchCategory && !matchOptions) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Top Toolbar: Search Bar + Filter Options
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          decoration: BoxDecoration(
            color: CelestialTheme.bgCard.withValues(alpha: 0.5),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Field & Quick Action Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _availabilitySearchController,
                        onChanged: (val) {
                          setState(() {
                            _availabilitySearchQuery = val.trim();
                          });
                        },
                        style: TextStyle(fontSize: 13, color: CelestialTheme.textLight),
                        decoration: InputDecoration(
                          hintText: 'Search items or modifiers (e.g. Oat Milk, Pearls, Latte)...',
                          hintStyle: TextStyle(color: CelestialTheme.textSubtle, fontSize: 12),
                          prefixIcon: Icon(Icons.search_rounded, color: CelestialTheme.goldPrimary, size: 18),
                          suffixIcon: _availabilitySearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear_rounded, size: 16, color: CelestialTheme.textMuted),
                                  onPressed: () {
                                    _availabilitySearchController.clear();
                                    setState(() => _availabilitySearchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: CelestialTheme.bgSurface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: CelestialTheme.goldPrimary),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Global Modifier Bulk Button
                  Tooltip(
                    message: 'Manage common ingredients / modifiers across all drinks at once',
                    child: OutlinedButton.icon(
                      onPressed: () => _showGlobalModifiersDialog(context, provider),
                      icon: const Icon(Icons.tune_rounded, size: 15),
                      label: Text(isMobile ? 'Global' : 'Global Modifiers', style: const TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CelestialTheme.goldLight,
                        side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Reset All Available Button
                  Tooltip(
                    message: 'Reset all items & modifiers to available',
                    child: IconButton(
                      onPressed: () {
                        if (unavailableItems > 0 || unavailableOpts > 0) {
                          _confirmResetAllAvailability(context, provider);
                        } else {
                          TopNotification.showInfo(
                            context,
                            'All items and modifiers are already available (0 sold out).',
                          );
                        }
                      },
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      color: (unavailableItems > 0 || unavailableOpts > 0) ? CelestialTheme.goldLight : Colors.white54,
                      style: IconButton.styleFrom(
                        backgroundColor: CelestialTheme.bgSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Categories Row + Unavailable Filter Pill
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Only Unavailable Filter Pill
                    FilterChip(
                      selected: _showOnlyUnavailable,
                      onSelected: (val) => setState(() => _showOnlyUnavailable = val),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 13,
                            color: _showOnlyUnavailable ? CelestialTheme.bgDark : CelestialTheme.roseAlert,
                          ),
                          const SizedBox(width: 5),
                          Text('Unavailable Only (${unavailableItems + unavailableOpts})'),
                        ],
                      ),
                      labelStyle: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _showOnlyUnavailable ? CelestialTheme.bgDark : CelestialTheme.roseAlert,
                      ),
                      backgroundColor: CelestialTheme.roseAlert.withValues(alpha: 0.12),
                      selectedColor: CelestialTheme.roseAlert,
                      side: BorderSide(
                        color: _showOnlyUnavailable ? CelestialTheme.roseAlert : CelestialTheme.roseAlert.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    ),
                    const SizedBox(width: 8),

                    // Categories
                    ...provider.allCategoryTabs.map((tab) {
                      final isSelected = _selectedAvailabilityCategoryId == tab.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(tab.icon.trim().isNotEmpty ? '${tab.icon} ${tab.label}' : tab.label),
                          selected: isSelected,
                          onSelected: (_) => setState(() {
                            _selectedAvailabilityCategoryId = tab.id;
                            final matchedEnum = ItemCategory.values.firstWhere(
                              (c) => c.name == tab.id,
                              orElse: () => ItemCategory.custom,
                            );
                            _selectedAvailabilityCategory = matchedEnum;
                          }),
                          labelStyle: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? CelestialTheme.bgDark : CelestialTheme.textLight,
                          ),
                          selectedColor: CelestialTheme.goldPrimary,
                          backgroundColor: CelestialTheme.bgSurface,
                          side: BorderSide(
                            color: isSelected
                                ? CelestialTheme.goldPrimary
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Content Area: List of items
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showOnlyUnavailable ? Icons.check_circle_outline_rounded : Icons.search_off_rounded,
                          size: 44,
                          color: _showOnlyUnavailable ? CelestialTheme.emeraldReady : CelestialTheme.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _showOnlyUnavailable
                              ? 'All Items & Modifiers Are In Stock!'
                              : 'No matching items or modifiers found',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.textLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _showOnlyUnavailable
                              ? 'No items are currently marked as not available.'
                              : 'Try adjusting your search or category filter.',
                          style: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildItemAvailabilityCard(context, provider, item, isMobile);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildItemAvailabilityCard(BuildContext context, PosProvider provider, MenuItem item, bool isMobile) {
    final isExpanded = _expandedItemIds.contains(item.id);
    final hasGroups = item.customizationGroups.isNotEmpty;
    final unavailCount = item.unavailableOptionsCount;

    return Container(
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: !item.inStock
              ? CelestialTheme.roseAlert.withValues(alpha: 0.5)
              : item.hasUnavailableOptions
                  ? CelestialTheme.amberBrewing.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08),
          width: (!item.inStock || item.hasUnavailableOptions) ? 1.3 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Item Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Item Icon or Image Thumbnail
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.inStock
                        ? CelestialTheme.brownWarm.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: item.inStock
                          ? CelestialTheme.goldPrimary.withValues(alpha: 0.3)
                          : Colors.white12,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: item.imageBase64 != null && item.imageBase64!.isNotEmpty
                        ? Image.memory(
                            base64Decode(item.imageBase64!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(child: Text(item.icon, style: const TextStyle(fontSize: 20))),
                          )
                        : (item.imagePath != null && item.imagePath!.isNotEmpty && item.imagePath!.startsWith('assets/'))
                            ? Image.asset(
                                item.imagePath!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Center(child: Text(item.icon, style: const TextStyle(fontSize: 20))),
                              )
                            : Center(child: Text(item.icon, style: const TextStyle(fontSize: 20))),
                  ),
                ),
                const SizedBox(width: 12),

                // Name, Category & Price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: item.inStock ? CelestialTheme.textLight : CelestialTheme.textSubtle,
                          decoration: item.inStock ? null : TextDecoration.lineThrough,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: !item.inStock
                                  ? CelestialTheme.roseAlert.withValues(alpha: 0.18)
                                  : item.hasUnavailableOptions
                                      ? CelestialTheme.amberBrewing.withValues(alpha: 0.18)
                                      : CelestialTheme.emeraldReady.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: !item.inStock
                                    ? CelestialTheme.roseAlert
                                    : item.hasUnavailableOptions
                                        ? CelestialTheme.amberBrewing
                                        : CelestialTheme.emeraldReady.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              !item.inStock
                                  ? 'SOLD OUT'
                                  : item.hasUnavailableOptions
                                      ? (isMobile ? '⚠️ $unavailCount OFF' : '⚠️ $unavailCount MODIFIERS SOLD OUT')
                                      : 'IN STOCK',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: !item.inStock
                                    ? CelestialTheme.roseAlert
                                    : item.hasUnavailableOptions
                                        ? CelestialTheme.amberBrewing
                                        : CelestialTheme.emeraldReady,
                              ),
                            ),
                          ),
                          Text(
                            '${item.category.icon} ${item.category.label} • ₱${item.price.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                          ),
                          if (hasGroups)
                            Text(
                              '• ${item.customizationGroups.fold(0, (s, g) => s + g.options.length)} mod',
                              style: TextStyle(fontSize: 10.5, color: CelestialTheme.goldLight.withValues(alpha: 0.8)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Entire Item In-Stock Switch
                Column(
                  children: [
                    SizedBox(
                      height: 28,
                      child: Switch(
                        value: item.inStock,
                        activeThumbColor: CelestialTheme.emeraldReady,
                        inactiveThumbColor: CelestialTheme.roseAlert,
                        inactiveTrackColor: CelestialTheme.roseAlert.withValues(alpha: 0.3),
                        onChanged: (val) {
                          provider.setItemAvailability(item.id, val);
                        },
                      ),
                    ),
                    Text(
                      item.inStock ? 'Available' : 'Unavailable',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: item.inStock ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                      ),
                    ),
                  ],
                ),

                // Expand/Collapse Modifier Group Button
                if (hasGroups) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedItemIds.remove(item.id);
                        } else {
                          _expandedItemIds.add(item.id);
                        }
                      });
                    },
                    icon: Icon(
                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: CelestialTheme.goldLight,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    splashRadius: 18,
                    tooltip: isExpanded ? 'Hide Modifiers' : 'Manage Modifier Availability',
                  ),
                ],
              ],
            ),
          ),

          // Expanded Customization Groups & Modifiers
          if (isExpanded && hasGroups) ...[
            const Divider(height: 1, color: Colors.white10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CelestialTheme.bgSurface.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'MODIFIER AVAILABILITY FOR ${item.name.toUpperCase()}',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: CelestialTheme.goldLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.hasUnavailableOptions) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => provider.resetAllItemOptionsAvailability(item.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.restart_alt_rounded, size: 13, color: CelestialTheme.emeraldReady),
                                const SizedBox(width: 4),
                                Text(
                                  'Make All Available',
                                  style: GoogleFonts.outfit(fontSize: 10.5, color: CelestialTheme.emeraldReady, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),

                  ...item.customizationGroups.map((group) {
                    return _buildGroupAvailabilitySection(context, provider, item, group);
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupAvailabilitySection(
    BuildContext context,
    PosProvider provider,
    MenuItem item,
    CustomizationGroup group,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                group.title,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CelestialTheme.textLight,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  group.isRequired ? 'REQUIRED' : 'OPTIONAL',
                  style: TextStyle(fontSize: 8.5, color: CelestialTheme.textMuted, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.options.map((option) {
              final isAvailable = option.isAvailable;
              return InkWell(
                onTap: () {
                  provider.toggleOptionAvailability(
                    item.id,
                    group.id,
                    option.name,
                    !isAvailable,
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? CelestialTheme.bgCard
                        : CelestialTheme.roseAlert.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isAvailable
                          ? Colors.white.withValues(alpha: 0.12)
                          : CelestialTheme.roseAlert,
                      width: isAvailable ? 1.0 : 1.3,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAvailable ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        size: 14,
                        color: isAvailable ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        option.name,
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: isAvailable ? FontWeight.w500 : FontWeight.bold,
                          color: isAvailable ? CelestialTheme.textLight : CelestialTheme.roseAlert,
                          decoration: isAvailable ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 5),
                      InkWell(
                        onTap: () {
                          PriceEditorDialog.showOptionPriceEditor(
                            context,
                            provider,
                            itemId: item.id,
                            groupId: group.id,
                            groupTitle: group.title,
                            option: option,
                            defaultApplyGlobally: true,
                            onSaved: () => setState(() {}),
                          );
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: option.extraPrice > 0
                                ? CelestialTheme.goldPrimary.withValues(alpha: 0.18)
                                : CelestialTheme.bgCard,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: option.extraPrice > 0
                                  ? CelestialTheme.goldPrimary.withValues(alpha: 0.4)
                                  : CelestialTheme.borderWarm,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                option.extraPrice > 0
                                    ? '+₱${option.extraPrice.toStringAsFixed(0)}'
                                    : '₱0',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: option.extraPrice > 0
                                      ? CelestialTheme.goldLight
                                      : CelestialTheme.textMuted,
                                ),
                              ),
                              const SizedBox(width: 2.5),
                              Icon(Icons.edit, size: 8.5, color: CelestialTheme.goldPrimary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? CelestialTheme.emeraldReady.withValues(alpha: 0.15)
                              : CelestialTheme.roseAlert.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isAvailable ? 'AVAILABLE' : 'SOLD OUT',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: isAvailable ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
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
  }

  void _confirmResetAllAvailability(BuildContext context, PosProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: CelestialTheme.goldPrimary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Reset All Availability?',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
            ),
          ],
        ),
        content: Text(
          'This will mark all sold-out items and unavailable modifiers back to AVAILABLE across the entire store menu.',
          style: TextStyle(fontSize: 12.5, color: CelestialTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              provider.resetAllAvailability();
              Navigator.pop(ctx);
              TopNotification.showSuccess(
                context,
                '✨ All items and modifiers have been reset to Available!',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.goldPrimary,
              foregroundColor: CelestialTheme.primaryBtnText,
            ),
            child: const Text('Reset All'),
          ),
        ],
      ),
    );
  }

  void _showGlobalModifiersDialog(BuildContext context, PosProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            // Find unique option names across all menu items
            final Map<String, List<MenuItem>> optionToItems = {};

            for (final item in provider.menuItems) {
              for (final group in item.customizationGroups) {
                for (final opt in group.options) {
                  final key = opt.name.trim();
                  optionToItems.putIfAbsent(key, () => []).add(item);
                }
              }
            }

            final sortedKeys = optionToItems.keys.toList()..sort();

            return Dialog(
              backgroundColor: CelestialTheme.bgSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
              ),
              child: Container(
                width: 520,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune_rounded, color: CelestialTheme.goldPrimary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Global Modifier & Ingredient Availability',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.textLight,
                                ),
                              ),
                              Text(
                                'Toggle an ingredient or modifier across all drinks at once',
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
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: sortedKeys.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, color: Colors.white10),
                        itemBuilder: (context, idx) {
                          final optName = sortedKeys[idx];
                          final itemsWithOpt = optionToItems[optName]!;
                          final anyUnavailable = itemsWithOpt.any((item) {
                            return item.customizationGroups.any((g) => g.options.any((o) => o.name.trim() == optName && !o.isAvailable));
                          });
                          final isAvailable = !anyUnavailable;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        optName,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: isAvailable ? CelestialTheme.textLight : CelestialTheme.roseAlert,
                                        ),
                                      ),
                                      Text(
                                        'Used in ${itemsWithOpt.length} item(s)',
                                        style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: isAvailable
                                        ? CelestialTheme.emeraldReady.withValues(alpha: 0.15)
                                        : CelestialTheme.roseAlert.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isAvailable ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                                    ),
                                  ),
                                  child: Text(
                                    isAvailable ? 'AVAILABLE' : 'SOLD OUT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isAvailable ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: isAvailable,
                                  activeThumbColor: CelestialTheme.emeraldReady,
                                  inactiveThumbColor: CelestialTheme.roseAlert,
                                  inactiveTrackColor: CelestialTheme.roseAlert.withValues(alpha: 0.3),
                                  onChanged: (newVal) {
                                    provider.toggleOptionAvailabilityGlobally(optName, newVal);
                                    setDlgState(() {});
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CelestialTheme.goldPrimary,
                          foregroundColor: CelestialTheme.primaryBtnText,
                        ),
                        child: const Text('Close'),
                      ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: CelestialTheme.textLight,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(fontSize: 13, color: CelestialTheme.textLight),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: CelestialTheme.textSubtle, fontSize: 12),
            prefixIcon: Icon(icon, color: CelestialTheme.goldPrimary, size: 18),
            filled: true,
            fillColor: CelestialTheme.bgCard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: CelestialTheme.goldPrimary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScalePresetButton(PosProvider provider, {required String label, required double scale}) {
    final isSelected = (provider.uiScale - scale).abs() < 0.04;
    return InkWell(
      onTap: () => provider.setUiScale(scale),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? CelestialTheme.goldPrimary : CelestialTheme.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? CelestialTheme.goldPrimary
                : Colors.white.withValues(alpha: 0.12),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
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

  void _confirmClearOrders(BuildContext context, PosProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: CelestialTheme.amberBrewing.withValues(alpha: 0.4)),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: CelestialTheme.amberBrewing),
            const SizedBox(width: 8),
            Text(
              'Clear All Orders?',
              style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'This will clear all active and historical orders, restock sold items, and reset the order counter to #1 for a fresh shift.\n\nMenu items, prices, and custom photos will be kept.',
          style: TextStyle(fontSize: 13, color: CelestialTheme.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await provider.clearAllOrdersAndResetCounter(startNumber: 1);
              if (context.mounted) {
                final messenger = ScaffoldMessenger.of(context);
                messenger.clearSnackBars();
                messenger.showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1E293B),
                    behavior: SnackBarBehavior.floating,
                    width: 380,
                    showCloseIcon: true,
                    closeIconColor: Colors.white70,
                    duration: const Duration(milliseconds: 2000),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF334155), width: 1),
                    ),
                    content: const Text('All orders cleared! Next order is #1.'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.cleaning_services_rounded, size: 16),
            label: const Text('Clear Orders'),
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.amberBrewing,
              foregroundColor: CelestialTheme.primaryBtnText,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearMenu(BuildContext context, PosProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.4)),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: CelestialTheme.roseAlert),
            const SizedBox(width: 8),
            Text(
              'Clear All Menu Items?',
              style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'This will remove all menu items and custom categories from your catalog so you can start with a completely fresh, empty menu.\n\nYou can re-load the sample cafe menu at any time.',
          style: TextStyle(fontSize: 13, color: CelestialTheme.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await provider.clearAllMenuItems();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: CelestialTheme.bgSurfaceLight,
                    content: Text('Menu catalog cleared! You have a fresh slate.', style: TextStyle(color: CelestialTheme.goldLight)),
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete_sweep_rounded, size: 16),
            label: const Text('Clear All Items'),
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.roseAlert,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmResetAllData(BuildContext context, PosProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CelestialTheme.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.4)),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: CelestialTheme.roseAlert),
            const SizedBox(width: 8),
            Text(
              'Factory Reset All Data?',
              style: GoogleFonts.outfit(color: CelestialTheme.textLight, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'WARNING: This will completely wipe all orders, reset custom menu item prices and stock, delete uploaded photos, and restore the cafe catalog to default.\n\nThis action cannot be undone!',
          style: TextStyle(fontSize: 13, color: CelestialTheme.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await provider.resetAllData();
              if (context.mounted) {
                final messenger = ScaffoldMessenger.of(context);
                messenger.clearSnackBars();
                messenger.showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1E293B),
                    behavior: SnackBarBehavior.floating,
                    width: 380,
                    showCloseIcon: true,
                    closeIconColor: Colors.white70,
                    duration: const Duration(milliseconds: 2000),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF334155), width: 1),
                    ),
                    content: const Text('All application data has been reset to defaults!'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text('Wipe & Reset Everything'),
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.roseAlert,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard({
    required BuildContext context,
    required PosThemeMode mode,
    required bool isSelected,
    required VoidCallback onTap,
    required String title,
    required String subtitle,
    required Color primaryColor,
    required Color accentColor,
    required Color bgColor,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withValues(alpha: 0.12) : CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.40),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: primaryColor),
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      'SELECT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? primaryColor : CelestialTheme.textLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: CelestialTheme.textMuted,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _colorSwatch(bgColor),
                const SizedBox(width: 6),
                _colorSwatch(primaryColor),
                const SizedBox(width: 6),
                _colorSwatch(accentColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorSwatch(Color color) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
      ),
    );
  }
}