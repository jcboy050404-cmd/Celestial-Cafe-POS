import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../theme/celestial_theme.dart';

class CustomizationDialog extends StatefulWidget {
  final MenuItem item;
  final Function(int quantity, List<SelectedCustomization> customizations, String? notes) onAddToCart;

  const CustomizationDialog({
    super.key,
    required this.item,
    required this.onAddToCart,
  });

  @override
  State<CustomizationDialog> createState() => _CustomizationDialogState();
}

class _CustomizationDialogState extends State<CustomizationDialog> {
  int _quantity = 1;
  final Map<String, List<CustomizationOption>> _selectedOptions = {};
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    // Pre-select default options for single-select groups
    for (var group in widget.item.customizationGroups) {
      if (group.options.isNotEmpty) {
        if (!group.isMultiSelect) {
          final defIdx = (group.defaultIndex < group.options.length) ? group.defaultIndex : 0;
          _selectedOptions[group.id] = [group.options[defIdx]];
        } else {
          _selectedOptions[group.id] = [];
        }
      }
    }
  }

  double get _currentUnitPrice {
    double total = widget.item.price;
    _selectedOptions.forEach((groupId, options) {
      for (var opt in options) {
        total += opt.extraPrice;
      }
    });
    return total;
  }

  double get _currentTotalPrice => _currentUnitPrice * _quantity;

  List<SelectedCustomization> _buildCustomizationsList() {
    final list = <SelectedCustomization>[];
    for (var group in widget.item.customizationGroups) {
      final opts = _selectedOptions[group.id] ?? [];
      for (var opt in opts) {
        list.add(
          SelectedCustomization(
            groupTitle: group.title,
            optionName: opt.name,
            extraPrice: opt.extraPrice,
          ),
        );
      }
    }
    return list;
  }

  bool _isTemperatureGroup(CustomizationGroup group) {
    final id = group.id.toLowerCase();
    final title = group.title.toLowerCase();
    return id.contains('temp') || title.contains('temp');
  }

  bool _isSweetnessGroup(CustomizationGroup group) {
    final id = group.id.toLowerCase();
    final title = group.title.toLowerCase();
    return id.contains('sweet') || title.contains('sweet') || id.contains('sugar') || title.contains('sugar');
  }

  IconData _getGroupIcon(CustomizationGroup group) {
    final id = group.id.toLowerCase();
    final title = group.title.toLowerCase();

    if (_isTemperatureGroup(group)) {
      return Icons.thermostat_rounded;
    }
    if (_isSweetnessGroup(group)) {
      return Icons.water_drop_rounded;
    }
    if (id.contains('size') || title.contains('size') || title.contains('cup')) {
      return Icons.local_cafe_rounded;
    }
    if (id.contains('whip') || title.contains('whip') || title.contains('cream')) {
      return Icons.icecream_rounded;
    }
    if (id.contains('prep') || title.contains('prep') || title.contains('cook')) {
      return Icons.restaurant_rounded;
    }
    if (group.isMultiSelect || id.contains('addon') || title.contains('addon') || title.contains('extra') || title.contains('sinker')) {
      return Icons.auto_awesome_rounded;
    }
    return Icons.tune_rounded;
  }

  Widget _buildItemMedia(bool isMobile) {
    final double size = isMobile ? 54 : 64;
    final bool hasBase64 = widget.item.imageBase64 != null && widget.item.imageBase64!.isNotEmpty;
    final bool hasFile = widget.item.imagePath != null && widget.item.imagePath!.isNotEmpty && File(widget.item.imagePath!).existsSync();

    Widget mediaContent;
    if (hasBase64) {
      mediaContent = Image.memory(
        base64Decode(widget.item.imageBase64!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Text(widget.item.icon, style: TextStyle(fontSize: isMobile ? 24 : 28)),
        ),
      );
    } else if (hasFile) {
      mediaContent = Image.file(
        File(widget.item.imagePath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Text(widget.item.icon, style: TextStyle(fontSize: isMobile ? 24 : 28)),
        ),
      );
    } else {
      mediaContent = Container(
        decoration: const BoxDecoration(
          gradient: CelestialTheme.brownGradient,
        ),
        child: Center(
          child: Text(
            widget.item.icon,
            style: TextStyle(fontSize: isMobile ? 24 : 30),
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CelestialTheme.goldPrimary.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.5),
        child: mediaContent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: isMobile ? double.infinity : 550,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * (isMobile ? 0.92 : 0.88),
        ),
        decoration: BoxDecoration(
          color: CelestialTheme.bgSurface,
          borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
          border: Border.all(
            color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: CelestialTheme.goldPrimary.withValues(alpha: 0.1),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Rich Item Info & Close button
            _buildDialogHeader(isMobile),

            // Luminous Accent Divider
            _buildAccentDivider(),

            // Scrollable Customization Options
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.all(isMobile ? 16 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Render Customization Groups
                    ...widget.item.customizationGroups.map((group) {
                      return _buildGroupSection(group, isMobile);
                    }),
                  ],
                ),
              ),
            ),

            // Luminous Accent Divider
            _buildAccentDivider(),

            // Bottom Footer with Tactile Stepper & Add Button
            _buildFooter(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildAccentDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            CelestialTheme.goldPrimary.withValues(alpha: 0.4),
            Colors.white.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(bool isMobile) {
    final tags = widget.item.tags;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF261D2A),
            Color(0xFF1B1420),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(isMobile ? 20 : 24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildItemMedia(isMobile),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        widget.item.name,
                        style: GoogleFonts.outfit(
                          color: CelestialTheme.textLight,
                          fontSize: isMobile ? 17 : 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Base price badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: CelestialTheme.goldPrimary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.45),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '₱${widget.item.price.toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(
                          color: CelestialTheme.goldLight,
                          fontSize: isMobile ? 12 : 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // Category and tags row
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.item.category.icon, style: const TextStyle(fontSize: 10)),
                          const SizedBox(width: 4),
                          Text(
                            widget.item.category.label,
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: CelestialTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (tags.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tags.first,
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: CelestialTheme.goldLight,
                          ),
                        ),
                      ),
                  ],
                ),
                if (widget.item.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.item.description,
                    style: GoogleFonts.outfit(
                      color: CelestialTheme.textMuted,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Circular Frosted Close Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: CelestialTheme.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader({
    required String title,
    required IconData icon,
    required bool isRequired,
    required bool isMultiSelect,
    int selectedCount = 0,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 14,
            color: CelestialTheme.goldPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: CelestialTheme.textLight,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 8),
        if (isRequired)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: CelestialTheme.goldPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'REQUIRED',
                  style: GoogleFonts.outfit(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: CelestialTheme.goldLight,
                  ),
                ),
              ],
            ),
          )
        else if (isMultiSelect)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.8,
              ),
            ),
            child: Text(
              selectedCount > 0 ? '$selectedCount SELECTED' : 'OPTIONAL',
              style: GoogleFonts.outfit(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: selectedCount > 0 ? CelestialTheme.goldLight : CelestialTheme.textSubtle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGroupSection(CustomizationGroup group, bool isMobile) {
    if (_isTemperatureGroup(group) && group.options.length == 2) {
      return _buildTemperatureSection(group, isMobile);
    }
    if (_isSweetnessGroup(group) && group.options.length >= 3 && !group.isMultiSelect) {
      return _buildSweetnessSection(group, isMobile);
    }
    if (group.isMultiSelect) {
      return _buildMultiSelectSection(group, isMobile);
    }
    return _buildStandardSection(group, isMobile);
  }

  // Specialized Temperature Switch (Hot vs Iced)
  Widget _buildTemperatureSection(CustomizationGroup group, bool isMobile) {
    final selectedList = _selectedOptions[group.id] ?? [];
    final hotOption = group.options.firstWhere(
      (o) => o.name.toLowerCase().contains('hot'),
      orElse: () => group.options.first,
    );
    final icedOption = group.options.firstWhere(
      (o) => o.name.toLowerCase().contains('ice'),
      orElse: () => group.options.length > 1 ? group.options[1] : group.options.first,
    );

    final isHotSelected = selectedList.any((o) => o.name == hotOption.name);
    final isIcedSelected = selectedList.any((o) => o.name == icedOption.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroupHeader(
            title: group.title,
            icon: Icons.thermostat_rounded,
            isRequired: group.isRequired,
            isMultiSelect: false,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTempCard(
                  option: hotOption,
                  isSelected: isHotSelected,
                  icon: Icons.local_fire_department_rounded,
                  accentColor: const Color(0xFFFF7A45),
                  label: 'Hot',
                  subLabel: 'Steamed & Fresh',
                  onTap: () {
                    setState(() {
                      _selectedOptions[group.id] = [hotOption];
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTempCard(
                  option: icedOption,
                  isSelected: isIcedSelected,
                  icon: Icons.ac_unit_rounded,
                  accentColor: const Color(0xFF4CC9F0),
                  label: 'Iced',
                  subLabel: 'Chilled with Ice',
                  onTap: () {
                    setState(() {
                      _selectedOptions[group.id] = [icedOption];
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTempCard({
    required CustomizationOption option,
    required bool isSelected,
    required IconData icon,
    required Color accentColor,
    required String label,
    required String subLabel,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.12)
              : CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? CelestialTheme.goldPrimary
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.18),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? accentColor.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.05),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? accentColor : CelestialTheme.textSubtle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    option.name,
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? CelestialTheme.textLight : CelestialTheme.textMuted,
                    ),
                  ),
                  Text(
                    subLabel,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: isSelected ? CelestialTheme.goldLight : CelestialTheme.textSubtle,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 17,
              color: isSelected ? CelestialTheme.goldPrimary : CelestialTheme.textSubtle,
            ),
          ],
        ),
      ),
    );
  }

  // Specialized Sweetness Grid
  Widget _buildSweetnessSection(CustomizationGroup group, bool isMobile) {
    final selectedList = _selectedOptions[group.id] ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroupHeader(
            title: group.title,
            icon: Icons.water_drop_rounded,
            isRequired: group.isRequired,
            isMultiSelect: false,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 8,
                children: group.options.map((option) {
                  final isSelected = selectedList.any((o) => o.name == option.name);

                  return SizedBox(
                    width: cardWidth,
                    child: _buildSweetnessOptionCard(
                      option: option,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedOptions[group.id] = [option];
                        });
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSweetnessOptionCard({
    required CustomizationOption option,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? CelestialTheme.goldPrimary.withValues(alpha: 0.14)
              : CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? CelestialTheme.goldPrimary
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 16,
              color: isSelected ? CelestialTheme.goldPrimary : CelestialTheme.textSubtle,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                option.name,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? CelestialTheme.textLight : CelestialTheme.textMuted,
                ),
                maxLines: 3,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (option.extraPrice != 0) ...[
              const SizedBox(width: 4),
              _buildPriceBadge(option.extraPrice, isSelected),
            ],
          ],
        ),
      ),
    );
  }

  // Multi-Select Section (Add-ons, Sinkers, Extras)
  Widget _buildMultiSelectSection(CustomizationGroup group, bool isMobile) {
    final selectedList = _selectedOptions[group.id] ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroupHeader(
            title: group.title,
            icon: Icons.auto_awesome_rounded,
            isRequired: group.isRequired,
            isMultiSelect: true,
            selectedCount: selectedList.length,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isTwoCol = constraints.maxWidth > 380;
              final cardWidth = isTwoCol ? (constraints.maxWidth - 10) / 2 : constraints.maxWidth;

              return Wrap(
                spacing: 10,
                runSpacing: 8,
                children: group.options.map((option) {
                  final isSelected = selectedList.any((o) => o.name == option.name);

                  return SizedBox(
                    width: cardWidth,
                    child: _buildAddonCard(
                      option: option,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedList.removeWhere((o) => o.name == option.name);
                          } else {
                            selectedList.add(option);
                          }
                          _selectedOptions[group.id] = selectedList;
                        });
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddonCard({
    required CustomizationOption option,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? CelestialTheme.goldPrimary.withValues(alpha: 0.12)
              : CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? CelestialTheme.goldPrimary
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? CelestialTheme.goldPrimary : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? CelestialTheme.goldPrimary
                      : Colors.white.withValues(alpha: 0.2),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Icon(
                  isSelected ? Icons.check_rounded : Icons.add_rounded,
                  size: 14,
                  color: isSelected ? CelestialTheme.bgDark : CelestialTheme.textSubtle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                option.name,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? CelestialTheme.textLight : CelestialTheme.textMuted,
                ),
                maxLines: 3,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            if (option.extraPrice != 0)
              _buildPriceBadge(option.extraPrice, isSelected),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceBadge(double extraPrice, bool isSelected) {
    final isPositive = extraPrice > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? CelestialTheme.goldPrimary.withValues(alpha: 0.22)
            : CelestialTheme.brownWarm.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected
              ? CelestialTheme.goldPrimary.withValues(alpha: 0.5)
              : CelestialTheme.goldPrimary.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Text(
        isPositive
            ? '+₱${extraPrice.toStringAsFixed(0)}'
            : '-₱${(-extraPrice).toStringAsFixed(0)}',
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isSelected ? CelestialTheme.goldLight : CelestialTheme.goldPrimary,
        ),
      ),
    );
  }

  // Standard Single-Select Section (Cup Size, Preparation, etc.)
  Widget _buildStandardSection(CustomizationGroup group, bool isMobile) {
    final selectedList = _selectedOptions[group.id] ?? [];
    final icon = _getGroupIcon(group);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroupHeader(
            title: group.title,
            icon: icon,
            isRequired: group.isRequired,
            isMultiSelect: false,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.options.map((option) {
              final isSelected = selectedList.any((o) => o.name == option.name);
              return _buildStandardChip(
                option: option,
                isSelected: isSelected,
                isMobile: isMobile,
                onTap: () {
                  setState(() {
                    _selectedOptions[group.id] = [option];
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardChip({
    required CustomizationOption option,
    required bool isSelected,
    required bool isMobile,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 14,
          vertical: isMobile ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? CelestialTheme.goldPrimary.withValues(alpha: 0.14)
              : CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? CelestialTheme.goldPrimary
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.14),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 16,
              color: isSelected ? CelestialTheme.goldPrimary : CelestialTheme.textSubtle,
            ),
            const SizedBox(width: 8),
            Text(
              option.name,
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 12.5 : 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? CelestialTheme.textLight : CelestialTheme.textMuted,
              ),
            ),
            if (option.extraPrice != 0) ...[
              const SizedBox(width: 6),
              _buildPriceBadge(option.extraPrice, isSelected),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isMobile) {
    final hasExtras = _currentUnitPrice > widget.item.price;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 22,
        vertical: isMobile ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(isMobile ? 20 : 24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Quantity Stepper
          Container(
            height: isMobile ? 44 : 48,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: CelestialTheme.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CelestialTheme.goldPrimary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  key: const Key('customization_qty_minus'),
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                  icon: const Icon(Icons.remove_rounded, size: 16),
                  color: CelestialTheme.goldPrimary,
                  disabledColor: CelestialTheme.textSubtle.withValues(alpha: 0.4),
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: isMobile ? 32 : 36, minHeight: 32),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '$_quantity',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: CelestialTheme.textLight,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('customization_qty_plus'),
                  onPressed: () => setState(() => _quantity++),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  color: CelestialTheme.goldPrimary,
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: isMobile ? 32 : 36, minHeight: 32),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Total Price & Add to Order CTA
          Expanded(
            child: Container(
              height: isMobile ? 44 : 48,
              decoration: BoxDecoration(
                gradient: CelestialTheme.goldGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('customization_add_to_cart_btn'),
                  onTap: _isAdding
                      ? null
                      : () async {
                          setState(() => _isAdding = true);
                          await Future.delayed(const Duration(milliseconds: 180));
                          final customs = _buildCustomizationsList();
                          widget.onAddToCart(_quantity, customs, null);
                          if (mounted) Navigator.pop(context);
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: Center(
                    child: _isAdding
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: CelestialTheme.bgDark,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_shopping_cart_rounded,
                                size: 19,
                                color: CelestialTheme.bgDark,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _quantity > 1
                                      ? 'Add $_quantity • ₱${_currentTotalPrice.toStringAsFixed(0)}'
                                      : 'Add to Order • ₱${_currentTotalPrice.toStringAsFixed(0)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: isMobile ? 14.5 : 15.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                    color: CelestialTheme.bgDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasExtras) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: CelestialTheme.bgDark.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '(₱${_currentUnitPrice.toStringAsFixed(0)} ea)',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: CelestialTheme.bgDark,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
