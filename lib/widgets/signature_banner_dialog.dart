import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';

class SignatureBannerDialog extends StatefulWidget {
  const SignatureBannerDialog({super.key});

  @override
  State<SignatureBannerDialog> createState() => _SignatureBannerDialogState();
}

class _SignatureBannerDialogState extends State<SignatureBannerDialog> {
  late bool _enabled;
  late TextEditingController _badgeController;
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _buttonTextController;
  String _selectedItemId = 'nesp_1';
  Uint8List? _customImageBytes;
  bool _removeCustomImage = false;
  bool _isPickingImage = false;
  bool _isSaving = false;

  final List<String> _badgePresets = const [
    'CELESTIAL SIGNATURE CRAFT',
    'TODAY\'S SPECIAL',
    'CHEF\'S RECOMMENDATION',
    'BARISTA SPOTLIGHT',
    'LIMITED TIME CRAFT',
  ];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<PosProvider>(context, listen: false);
    _enabled = provider.signatureBannerEnabled;
    _badgeController = TextEditingController(text: provider.signatureBannerBadge);
    _titleController = TextEditingController(text: provider.signatureBannerTitle);
    _subtitleController = TextEditingController(text: provider.signatureBannerSubtitle);
    _buttonTextController = TextEditingController(text: provider.signatureBannerButtonText);
    _selectedItemId = provider.signatureBannerItemId;
    _customImageBytes = provider.signatureBannerImageBytes;

    _badgeController.addListener(() => setState(() {}));
    _titleController.addListener(() => setState(() {}));
    _subtitleController.addListener(() => setState(() {}));
    _buttonTextController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _badgeController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _buttonTextController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _isPickingImage = true);
    try {
      final files = await FilePickerPlatform.instance.pickFiles(type: FileType.image);
      if (files.isNotEmpty) {
        final file = files.first;
        Uint8List? bytes;
        if (file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }

        if (bytes != null && mounted) {
          setState(() {
            _customImageBytes = bytes;
            _removeCustomImage = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: CelestialTheme.roseAlert,
            content: Text('Failed to pick image: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _autoFillFromItem(MenuItem item) {
    setState(() {
      _selectedItemId = item.id;
      _titleController.text = item.name;
      _subtitleController.text = item.description.isNotEmpty
          ? item.description
          : 'Handcrafted premium ${item.name} prepared with artisanal mastery';
    });
  }

  void _save(PosProvider provider) async {
    setState(() => _isSaving = true);
    await provider.updateSignatureBanner(
      enabled: _enabled,
      badge: _badgeController.text,
      title: _titleController.text,
      subtitle: _subtitleController.text,
      buttonText: _buttonTextController.text,
      itemId: _selectedItemId,
      imageBytes: _removeCustomImage ? null : _customImageBytes,
      removeCustomImage: _removeCustomImage,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: CelestialTheme.bgSurfaceLight,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: CelestialTheme.borderSubtle),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: CelestialTheme.caramelAccent, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Signature craft banner customized and saved!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _resetDefaults(PosProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CelestialTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: CelestialTheme.borderSubtle),
        ),
        title: Text(
          'Reset Signature Banner?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: const Text(
          'This will restore the original Celestial Signature Latte banner settings.',
          style: TextStyle(color: CelestialTheme.creamSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: CelestialTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestialTheme.caramelAccent,
              foregroundColor: CelestialTheme.bgDark,
            ),
            child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await provider.resetSignatureBanner();
      if (mounted) {
        setState(() {
          _enabled = provider.signatureBannerEnabled;
          _badgeController.text = provider.signatureBannerBadge;
          _titleController.text = provider.signatureBannerTitle;
          _subtitleController.text = provider.signatureBannerSubtitle;
          _buttonTextController.text = provider.signatureBannerButtonText;
          _selectedItemId = provider.signatureBannerItemId;
          _customImageBytes = null;
          _removeCustomImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PosProvider>();
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    // Resolve featured menu item
    final featuredItem = provider.menuItems.firstWhere(
      (i) => i.id == _selectedItemId,
      orElse: () => provider.menuItems.first,
    );

    return Dialog(
      backgroundColor: CelestialTheme.bgDark,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 40 : 16,
        vertical: isDesktop ? 30 : 16,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.25), width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: CelestialTheme.bgSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CelestialTheme.caramelAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CelestialTheme.caramelAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.stars_rounded, color: CelestialTheme.goldLight, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customize Signature Banner',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.creamLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Personalize the spotlight hero banner featured on the POS workspace',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            color: CelestialTheme.creamSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: CelestialTheme.creamSoft, size: 20),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Live Real-Time Preview
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'LIVE BANNER PREVIEW',
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
                            color: _enabled
                                ? CelestialTheme.caramelAccent.withValues(alpha: 0.2)
                                : CelestialTheme.roseAlert.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _enabled ? CelestialTheme.caramelAccent : CelestialTheme.roseAlert,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            _enabled ? '● ACTIVE ON POS' : '○ HIDDEN',
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: _enabled ? CelestialTheme.goldLight : CelestialTheme.roseAlert,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Preview Card
                    _buildPreviewBanner(context, isDesktop, featuredItem),

                    const SizedBox(height: 20),

                    // Section 2: Visibility Toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _enabled ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                            color: _enabled ? CelestialTheme.caramelAccent : CelestialTheme.textMuted,
                            size: 22,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Display Hero Banner on POS',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: CelestialTheme.textLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Showcase your signature specialty or daily special above the catalog',
                                  style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _enabled,
                            onChanged: (val) => setState(() => _enabled = val),
                            activeThumbColor: CelestialTheme.caramelAccent,
                            activeTrackColor: CelestialTheme.caramelAccent.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Section 3: Target Featured Menu Item
                    Text(
                      'LINKED MENU ITEM',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: CelestialTheme.goldLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tapping the banner or its button will instantly open the customization dialog for this item.',
                      style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.creamSoft),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: provider.menuItems.any((i) => i.id == _selectedItemId)
                              ? _selectedItemId
                              : provider.menuItems.first.id,
                          isExpanded: true,
                          dropdownColor: CelestialTheme.bgCard,
                          icon: const Icon(Icons.arrow_drop_down_rounded, color: CelestialTheme.goldLight),
                          items: provider.menuItems.map((item) {
                            return DropdownMenuItem<String>(
                              value: item.id,
                              child: Row(
                                children: [
                                  Text(item.icon, style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: CelestialTheme.creamLight,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '₱${item.price.toStringAsFixed(2)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: CelestialTheme.goldLight,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newId) {
                            if (newId != null) {
                              final item = provider.menuItems.firstWhere((i) => i.id == newId);
                              setState(() => _selectedItemId = newId);
                              // Auto-fill prompt or direct auto-fill
                              _autoFillFromItem(item);
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _autoFillFromItem(featuredItem),
                        icon: const Icon(Icons.sync_rounded, size: 14, color: CelestialTheme.caramelAccent),
                        label: Text(
                          'Re-sync Title & Subtitle from "${featuredItem.name}"',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.caramelAccent,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Section 4: Badge & Copy Details
                    Text(
                      'BANNER TEXT & COPY',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: CelestialTheme.goldLight,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Badge Text
                    _buildTextField(
                      controller: _badgeController,
                      label: 'Badge Header Text',
                      hint: 'e.g. CELESTIAL SIGNATURE CRAFT',
                      icon: Icons.label_important_outline_rounded,
                    ),

                    const SizedBox(height: 8),

                    // Quick Preset Chips for Badge
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _badgePresets.map((preset) {
                        final isSelected = _badgeController.text == preset;
                        return InkWell(
                          onTap: () => setState(() => _badgeController.text = preset),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? CelestialTheme.caramelAccent.withValues(alpha: 0.25)
                                  : CelestialTheme.bgSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? CelestialTheme.caramelAccent
                                    : Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Text(
                              preset,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? CelestialTheme.goldLight : CelestialTheme.creamSoft,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 14),

                    // Banner Title
                    _buildTextField(
                      controller: _titleController,
                      label: 'Banner Title (Item / Promo Headline)',
                      hint: 'e.g. Celestial Signature Latte',
                      icon: Icons.title_rounded,
                    ),

                    const SizedBox(height: 12),

                    // Subtitle / Tagline
                    _buildTextField(
                      controller: _subtitleController,
                      label: 'Description / Tagline',
                      hint: 'e.g. Handcrafted specialty latte blend with silky sweet foam',
                      icon: Icons.subtitles_rounded,
                      maxLines: 2,
                    ),

                    const SizedBox(height: 12),

                    // Action Button Text
                    _buildTextField(
                      controller: _buttonTextController,
                      label: 'Order Button Text',
                      hint: 'e.g. Order or Order Signature',
                      icon: Icons.smart_button_rounded,
                    ),

                    const SizedBox(height: 20),

                    // Section 5: Banner Image Customization
                    Text(
                      'BANNER BACKGROUND PHOTOGRAPHY',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: CelestialTheme.goldLight,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _removeCustomImage || _customImageBytes == null
                                ? Image.asset(
                                    'assets/images/hero_coffee_splash.jpg',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(color: CelestialTheme.bgCardHover),
                                  )
                                : Image.memory(_customImageBytes!, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (!_removeCustomImage && _customImageBytes != null)
                                      ? 'Custom Image Active'
                                      : 'Default Coffee Photography',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: CelestialTheme.creamLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Upload a high-res photo or restore the default artisan coffee background.',
                                  style: GoogleFonts.outfit(fontSize: 11, color: CelestialTheme.creamSoft),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _isPickingImage ? null : _pickImage,
                                      icon: _isPickingImage
                                          ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.black),
                                            )
                                          : const Icon(Icons.upload_file_rounded, size: 14),
                                      label: const Text('Upload Photo', style: TextStyle(fontSize: 11)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: CelestialTheme.caramelAccent,
                                        foregroundColor: CelestialTheme.bgDark,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                    if (!_removeCustomImage && _customImageBytes != null)
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _customImageBytes = null;
                                            _removeCustomImage = true;
                                          });
                                        },
                                        icon: const Icon(Icons.restart_alt_rounded, size: 14),
                                        label: const Text('Use Default Image', style: TextStyle(fontSize: 11)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: CelestialTheme.roseAlert,
                                          side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.5)),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  ],
                ),
              ),
            ),

            // Footer Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: CelestialTheme.bgSurface,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _resetDefaults(provider),
                    icon: const Icon(Icons.settings_backup_restore_rounded, size: 14),
                    label: const Text('Reset Defaults', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CelestialTheme.creamSoft,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: CelestialTheme.creamSoft)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _save(provider),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 16),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save Banner Settings',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CelestialTheme.caramelAccent,
                      foregroundColor: CelestialTheme.bgDark,
                      elevation: 3,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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

  Widget _buildPreviewBanner(BuildContext context, bool isDesktop, MenuItem featuredItem) {
    final badgeText = _badgeController.text.trim().isEmpty
        ? (isDesktop ? 'CELESTIAL SIGNATURE CRAFT' : 'SIGNATURE CRAFT')
        : _badgeController.text.trim();
    final titleText = _titleController.text.trim().isEmpty
        ? featuredItem.name
        : _titleController.text.trim();
    final subtitleText = _subtitleController.text.trim().isEmpty
        ? featuredItem.description
        : _subtitleController.text.trim();
    final buttonText = _buttonTextController.text.trim().isEmpty
        ? 'Order'
        : _buttonTextController.text.trim();

    return Container(
      decoration: CelestialTheme.tactileHero(),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background photography
          Positioned.fill(
            child: Row(
              children: [
                const Spacer(flex: 2),
                Expanded(
                  flex: 3,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        colors: [Colors.transparent, Colors.black54, Colors.black],
                        stops: [0.0, 0.4, 1.0],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: (!_removeCustomImage && _customImageBytes != null)
                        ? Image.memory(
                            _customImageBytes!,
                            fit: BoxFit.cover,
                            alignment: Alignment.centerRight,
                            errorBuilder: (context, error, stackTrace) => Container(color: CelestialTheme.bgCardHover),
                          )
                        : Image.asset(
                            'assets/images/hero_coffee_splash.jpg',
                            fit: BoxFit.cover,
                            alignment: Alignment.centerRight,
                            errorBuilder: (context, error, stackTrace) => Container(color: CelestialTheme.bgCardHover),
                          ),
                  ),
                ),
              ],
            ),
          ),

          // Content Layer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: CelestialTheme.caramelAccent.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: CelestialTheme.caramelAccent.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('✨', style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                badgeText,
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.goldLight,
                                  letterSpacing: 0.6,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        titleText,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.creamLight,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          color: CelestialTheme.creamSoft,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.auto_awesome_rounded, size: 13),
                  label: Text(
                    buttonText,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CelestialTheme.caramelAccent,
                    foregroundColor: CelestialTheme.bgDark,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          // Dimmed overlay if hidden
          if (!_enabled)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.70),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility_off_rounded, color: CelestialTheme.roseAlert, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Banner Hidden (Enable to show on POS screen)',
                      style: GoogleFonts.outfit(
                        color: CelestialTheme.creamLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: CelestialTheme.creamLight,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.outfit(fontSize: 12.5, color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 12),
            prefixIcon: Icon(icon, color: CelestialTheme.goldLight.withValues(alpha: 0.7), size: 18),
            filled: true,
            fillColor: CelestialTheme.bgCard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: CelestialTheme.caramelAccent, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}
