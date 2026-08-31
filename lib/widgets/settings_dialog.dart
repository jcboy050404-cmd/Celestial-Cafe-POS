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
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<PosProvider>(context, listen: false);
    _nameController = TextEditingController(text: provider.storeName);
    _taglineController = TextEditingController(text: provider.storeTagline);
    _addressController = TextEditingController(text: provider.storeAddress);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _addressController.dispose();
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
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: CelestialTheme.bgCard,
        content: Text('✨ Store branding settings saved!'),
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

                    // Section 2: Store Information
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
                                  content: Text('🔢 Order sequence reset to start at #1'),
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
}
