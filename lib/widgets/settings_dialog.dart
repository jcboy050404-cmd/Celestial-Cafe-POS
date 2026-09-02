import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _nameController;
  late TextEditingController _taglineController;
  late TextEditingController _addressController;
  late TextEditingController _pinController;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<PosProvider>(context, listen: false);
    _nameController = TextEditingController(text: provider.storeName);
    _taglineController = TextEditingController(text: provider.storeTagline);
    _addressController = TextEditingController(text: provider.storeAddress);
    _pinController = TextEditingController(text: provider.baristaPin);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _addressController.dispose();
    _pinController.dispose();
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

  void _saveSettings(PosProvider provider) {
    provider.updateStoreDetails(
      name: _nameController.text,
      tagline: _taglineController.text,
      address: _addressController.text,
    );
    if (_pinController.text.trim().length >= 4) {
      provider.updateBaristaPin(_pinController.text.trim());
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: CelestialTheme.bgCard,
        content: Text('Store branding and security settings saved!'),
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
      child: Container(
        width: isMobile ? double.infinity : 560,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: CelestialTheme.bgCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded, color: CelestialTheme.goldPrimary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Store Settings & Logo',
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

            const Divider(height: 1),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
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
              ),
            ),

            const Divider(height: 1),

            // Footer Actions
            Container(
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
                    onPressed: () => _saveSettings(provider),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CelestialTheme.goldPrimary,
                      foregroundColor: CelestialTheme.bgDark,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
