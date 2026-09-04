import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';

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
  late TextEditingController _pinController;
  late TextEditingController _availabilitySearchController;
  bool _isPickingImage = false;
  bool _isSavingSettings = false;
  int _activeTab = 0; // 0 = Store & Branding, 1 = Item & Modifier Availability (86 List)
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
    _pinController = TextEditingController(text: provider.baristaPin);
    _availabilitySearchController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _addressController.dispose();
    _pinController.dispose();
    _availabilitySearchController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadLogo(PosProvider provider) async {
    setState(() => _isPickingImage = true);
    try {
      final files = await FilePickerPlatform.instance.pickFiles(
        type: FileType.image,
      );

      if (files.isNotEmpty) {
        final file = files.first;
        Uint8List? bytes;

        if (file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }

        if (bytes != null && mounted) {
          await provider.setCustomLogo(bytes);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: CelestialTheme.bgCard,
                content: Text('✨ Cafe logo updated and saved successfully!'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
    setState(() => _isSavingSettings = true);
    await Future.delayed(const Duration(milliseconds: 250));
    provider.updateStoreDetails(
      name: _nameController.text,
      tagline: _taglineController.text,
      address: _addressController.text,
    );
    if (_pinController.text.trim().length >= 4) {
      provider.updateBaristaPin(_pinController.text.trim());
    }
    if (mounted) setState(() => _isSavingSettings = false);
    if (mounted) Navigator.pop(context);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: CelestialTheme.bgCard,
          content: Text('Store branding and security settings saved!'),
        ),
      );
    }
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
            color: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
            width: 1.2,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: CelestialTheme.bgCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _activeTab == 0 ? Icons.storefront_rounded : Icons.do_not_disturb_on_outlined,
                        color: CelestialTheme.goldPrimary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _activeTab == 0 ? 'Store Settings & Logo' : 'Item & Modifier Availability (86 List)',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: CelestialTheme.textMuted),
                    splashRadius: 18,
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
                      title: 'Store & Branding',
                      icon: Icons.storefront_rounded,
                      isSelected: _activeTab == 0,
                      onTap: () => setState(() => _activeTab = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTabButton(
                      title: 'Item Availability (86)',
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
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: CelestialTheme.bgSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
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
                                          ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(strokeWidth: 1.5, color: CelestialTheme.bgDark),
                                            )
                                          : const Icon(Icons.upload_file_rounded, size: 14),
                                      label: const Text('Upload Logo', style: TextStyle(fontSize: 11)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: CelestialTheme.goldPrimary,
                                        foregroundColor: CelestialTheme.bgDark,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                    if (provider.hasCustomLogo)
                                      OutlinedButton.icon(
                                        onPressed: () => provider.resetToDefaultLogo(),
                                        icon: const Icon(Icons.restart_alt_rounded, size: 14),
                                        label: const Text('Reset', style: TextStyle(fontSize: 11)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: CelestialTheme.roseAlert,
                                          side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.5)),
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
                        Text(
                          'DISPLAY & ACCESSIBILITY (TEXT SIZE)',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: CelestialTheme.goldLight,
                          ),
                        ),
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
                              const Icon(Icons.remove_red_eye_outlined, color: CelestialTheme.goldPrimary, size: 18),
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
                              const Icon(Icons.text_fields_rounded, size: 14, color: CelestialTheme.textMuted),
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
                                  child: const Icon(Icons.coffee_rounded, size: 18, color: CelestialTheme.goldLight),
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order Number Sequence',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.textLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Next Order: #${provider.currentOrderSequence}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: CelestialTheme.goldLight,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              provider.resetOrderSequence(startNumber: 1);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
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

                    // Barista KDS Security PIN Manager
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.security_rounded, color: CelestialTheme.goldLight, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Barista KDS Security PIN',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: CelestialTheme.textLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Prevents table customers from viewing kitchen tickets',
                                  style: TextStyle(fontSize: 10, color: CelestialTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 90,
                            height: 38,
                            child: TextField(
                              controller: _pinController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: CelestialTheme.goldLight,
                                letterSpacing: 2,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: CelestialTheme.bgCard,
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: CelestialTheme.goldPrimary),
                                ),
                              ),
                            ),
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
          _buildFooterActions(provider),
        ],
      ),
    ),
  );
}

  Widget _buildFooterActions(PosProvider provider) {
    if (_activeTab == 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          color: CelestialTheme.bgCard,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        child: Row(
          children: [
            const Icon(Icons.flash_on_rounded, size: 16, color: CelestialTheme.goldLight),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Changes apply live to POS workstations & self-order web menus.',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  color: CelestialTheme.textMuted,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Done'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CelestialTheme.goldPrimary,
                foregroundColor: CelestialTheme.bgDark,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _isSavingSettings ? null : () => _saveSettings(provider),
            icon: _isSavingSettings
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: CelestialTheme.bgDark),
                  )
                : const Icon(Icons.check_rounded, size: 16),
            label: Text(_isSavingSettings ? 'Saving...' : 'Save Changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.goldPrimary,
              foregroundColor: CelestialTheme.bgDark,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
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
                        style: const TextStyle(fontSize: 13, color: CelestialTheme.textLight),
                        decoration: InputDecoration(
                          hintText: 'Search items or modifiers (e.g. Oat Milk, Pearls, Latte)...',
                          hintStyle: const TextStyle(color: CelestialTheme.textSubtle, fontSize: 12),
                          prefixIcon: const Icon(Icons.search_rounded, color: CelestialTheme.goldPrimary, size: 18),
                          suffixIcon: _availabilitySearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16, color: CelestialTheme.textMuted),
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
                            borderSide: const BorderSide(color: CelestialTheme.goldPrimary),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Global Modifier 86 Button
                  Tooltip(
                    message: '86 common ingredients across all drinks at once',
                    child: OutlinedButton.icon(
                      onPressed: () => _showGlobalModifiersDialog(context, provider),
                      icon: const Icon(Icons.tune_rounded, size: 15),
                      label: Text(isMobile ? 'Global' : 'Global 86', style: const TextStyle(fontSize: 11)),
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
                      onPressed: (unavailableItems > 0 || unavailableOpts > 0)
                          ? () => _confirmResetAllAvailability(context, provider)
                          : null,
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      color: CelestialTheme.goldLight,
                      disabledColor: Colors.white24,
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

              // Categories Row + 86'd Filter Pill
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
                          Text('86\'d Only (${unavailableItems + unavailableOpts})'),
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
                          label: Text('${tab.icon} ${tab.label}'),
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
                          style: const TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
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
                            : item.imagePath != null && item.imagePath!.isNotEmpty && File(item.imagePath!).existsSync()
                                ? Image.file(
                                    File(item.imagePath!),
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
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
                          ),
                          const SizedBox(width: 8),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                  ? '86\'D / OUT OF STOCK'
                                  : item.hasUnavailableOptions
                                      ? '⚠️ $unavailCount MODIFIER 86\'D'
                                      : 'IN STOCK',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: !item.inStock
                                    ? CelestialTheme.roseAlert
                                    : item.hasUnavailableOptions
                                        ? CelestialTheme.amberBrewing
                                        : CelestialTheme.emeraldReady,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            '${item.category.icon} ${item.category.label} • ₱${item.price.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                          ),
                          if (hasGroups) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• ${item.customizationGroups.fold(0, (s, g) => s + g.options.length)} modifiers',
                              style: TextStyle(fontSize: 11, color: CelestialTheme.goldLight.withValues(alpha: 0.8)),
                            ),
                          ],
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
                  const SizedBox(width: 6),
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
                    splashRadius: 18,
                    tooltip: isExpanded ? 'Hide Modifiers' : 'Manage Modifiers (86)',
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
                      Text(
                        'MODIFIER AVAILABILITY FOR ${item.name.toUpperCase()}',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: CelestialTheme.goldLight,
                        ),
                      ),
                      if (item.hasUnavailableOptions)
                        InkWell(
                          onTap: () => provider.resetAllItemOptionsAvailability(item.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.restart_alt_rounded, size: 13, color: CelestialTheme.emeraldReady),
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
                  style: const TextStyle(fontSize: 8.5, color: CelestialTheme.textMuted, fontWeight: FontWeight.bold),
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
                      if (option.extraPrice > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '+₱${option.extraPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isAvailable ? CelestialTheme.goldLight : CelestialTheme.roseAlert.withValues(alpha: 0.7),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
                          isAvailable ? 'AVAILABLE' : '86\'D OUT',
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
            const Icon(Icons.restart_alt_rounded, color: CelestialTheme.goldPrimary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Reset All Availability?',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
            ),
          ],
        ),
        content: const Text(
          'This will mark all out-of-stock items and unavailable modifiers back to AVAILABLE across the entire store menu.',
          style: TextStyle(fontSize: 12.5, color: CelestialTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              provider.resetAllAvailability();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: CelestialTheme.bgCard,
                  content: Text('✨ All items and modifiers have been reset to Available!'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.goldPrimary,
              foregroundColor: CelestialTheme.bgDark,
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
                        const Icon(Icons.tune_rounded, color: CelestialTheme.goldPrimary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Global Modifier / Ingredient 86',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.textLight,
                                ),
                              ),
                              const Text(
                                'Toggle an ingredient or modifier across all drinks at once',
                                style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
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
                                        style: const TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
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
                                    isAvailable ? 'AVAILABLE' : '86\'D OUT',
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
                          foregroundColor: CelestialTheme.bgDark,
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
          style: const TextStyle(fontSize: 13, color: CelestialTheme.textLight),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: CelestialTheme.textSubtle, fontSize: 12),
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
              borderSide: const BorderSide(color: CelestialTheme.goldPrimary),
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
                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.3),
                    blurRadius: 8,
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
}
