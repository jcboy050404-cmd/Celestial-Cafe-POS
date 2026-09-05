import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../theme/celestial_theme.dart';
import 'item_thumbnail.dart';

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

  void _notifyOptionUnavailable(String name) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: CelestialTheme.bgSurfaceLight,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: CelestialTheme.borderSubtle),
        ),
        content: Row(
          children: [
            const Icon(Icons.do_not_disturb_on_outlined, color: CelestialTheme.roseAlert, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '⚠️ "$name" is currently 86\'d / not available.',
                style: const TextStyle(color: CelestialTheme.textLight, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Pre-select default options for single-select groups (skipping unavailable options)
    for (var group in widget.item.customizationGroups) {
      if (group.options.isNotEmpty) {
        if (!group.isMultiSelect) {
          CustomizationOption? chosen;
          if (group.defaultIndex < group.options.length && group.options[group.defaultIndex].isAvailable) {
            chosen = group.options[group.defaultIndex];
          } else {
            chosen = group.options.firstWhere(
              (o) => o.isAvailable,
              orElse: () => group.options.first,
            );
          }
          _selectedOptions[group.id] = [chosen];
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
        width: isMobile ? double.infinity : 480,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * (isMobile ? 0.94 : 0.90),
        ),
        decoration: BoxDecoration(
          color: CelestialTheme.bgSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: CelestialTheme.borderSubtle,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogHeader(isMobile),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...widget.item.customizationGroups.map((group) {
                            return _buildGroupSection(group, isMobile);
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Footer
            _buildFooter(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildShowcaseMedia(bool isMobile) {
    return ItemThumbnail(
      item: widget.item,
      width: double.infinity,
      borderRadius: BorderRadius.zero,
      iconSize: isMobile ? 44 : 54,
    );
  }

  Widget _buildDialogHeader(bool isMobile) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        isMobile ? 14 : 18,
        isMobile ? 14 : 18,
        isMobile ? 14 : 18,
        14,
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CelestialTheme.borderSubtle,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Inset Media Container with subtle bevel
              Container(
                width: double.infinity,
                height: isMobile ? 140 : 165,
                decoration: BoxDecoration(
                  color: CelestialTheme.bgSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _buildShowcaseMedia(isMobile),
                ),
              ),
              const SizedBox(height: 12),
              // Item Name in steamed milk cream
              Text(
                widget.item.name,
                style: GoogleFonts.outfit(
                  color: CelestialTheme.creamLight,
                  fontSize: isMobile ? 19 : 21,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              // Price in white
              Text(
                '₱${widget.item.price.toStringAsFixed(0)}',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: isMobile ? 16 : 17.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (widget.item.description.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.item.description.trim(),
                  style: GoogleFonts.outfit(
                    color: CelestialTheme.creamLight.withValues(alpha: 0.75),
                    fontSize: isMobile ? 11.5 : 12.5,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          // Floating Close Button
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.5),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.20),
                    ),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
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
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: CelestialTheme.caramelAccent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 14,
            color: CelestialTheme.caramelAccent,
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
              color: CelestialTheme.caramelAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: CelestialTheme.caramelAccent.withValues(alpha: 0.4),
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
                    color: CelestialTheme.caramelAccent,
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
                color: CelestialTheme.borderSubtle,
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
    if (group.isMultiSelect) {
      return _buildMultiSelectSection(group, isMobile);
    }
    return _buildStandardSection(group, isMobile);
  }

  // Multi-Select Section (Add-ons & Extras Rows)
  Widget _buildMultiSelectSection(CustomizationGroup group, bool isMobile) {
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
            isMultiSelect: true,
            selectedCount: selectedList.length,
          ),
          const SizedBox(height: 10),
          Column(
            children: group.options.map((option) {
              final isSelected = selectedList.any((o) => o.name == option.name);
              final isAvailable = option.isAvailable;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: isAvailable
                      ? () {
                          setState(() {
                            final current = _selectedOptions[group.id] ?? [];
                            if (isSelected) {
                              _selectedOptions[group.id] = current.where((o) => o.name != option.name).toList();
                            } else {
                              _selectedOptions[group.id] = [...current, option];
                            }
                          });
                        }
                      : () => _notifyOptionUnavailable(option.name),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? CelestialTheme.caramelAccent.withValues(alpha: 0.15) : CelestialTheme.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? CelestialTheme.caramelAccent
                            : CelestialTheme.borderSubtle,
                        width: isSelected ? 1.2 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? CelestialTheme.caramelAccent : CelestialTheme.bgSurfaceLight,
                                  border: Border.all(
                                    color: isSelected ? CelestialTheme.caramelAccent : CelestialTheme.borderSubtle,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    isSelected ? Icons.check_rounded : Icons.add_rounded,
                                    size: 14,
                                    color: isSelected ? CelestialTheme.bgDark : CelestialTheme.textMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  option.name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: !isAvailable
                                        ? CelestialTheme.roseAlert
                                        : (isSelected ? CelestialTheme.creamLight : CelestialTheme.textLight),
                                    decoration: !isAvailable ? TextDecoration.lineThrough : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!isAvailable) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: CelestialTheme.roseAlert.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '86\'d',
                                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: CelestialTheme.roseAlert),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (option.extraPrice > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '+₱${option.extraPrice.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : CelestialTheme.warmGray,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBadge(double extraPrice, bool isSelected) {
    final isPositive = extraPrice > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? CelestialTheme.caramelAccent.withValues(alpha: 0.22)
            : CelestialTheme.bgSurfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected
              ? CelestialTheme.caramelAccent
              : CelestialTheme.borderSubtle,
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
          color: isSelected ? Colors.white : CelestialTheme.warmGray,
        ),
      ),
    );
  }

  // Standard Single-Select Section (Temperature, Sweetness, Size, Rice, etc.)
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
    final isAvailable = option.isAvailable;

    return InkWell(
      onTap: isAvailable ? onTap : () => _notifyOptionUnavailable(option.name),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 14,
          vertical: isMobile ? 9 : 10,
        ),
        constraints: BoxConstraints(maxWidth: isMobile ? 320 : 380),
        decoration: BoxDecoration(
          color: !isAvailable
              ? Colors.white.withValues(alpha: 0.02)
              : isSelected
                  ? CelestialTheme.caramelAccent.withValues(alpha: 0.18)
                  : CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: !isAvailable
                ? CelestialTheme.roseAlert.withValues(alpha: 0.3)
                : isSelected
                    ? CelestialTheme.caramelAccent
                    : CelestialTheme.borderSubtle,
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.25 : 0.12),
              blurRadius: isSelected ? 6 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              !isAvailable
                  ? Icons.block_rounded
                  : isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
              size: 16,
              color: !isAvailable
                  ? CelestialTheme.roseAlert.withValues(alpha: 0.6)
                  : isSelected
                      ? CelestialTheme.caramelAccent
                      : CelestialTheme.textSubtle,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                option.name,
                style: GoogleFonts.outfit(
                  fontSize: isMobile ? 12.5 : 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: !isAvailable
                      ? CelestialTheme.roseAlert
                      : isSelected
                          ? CelestialTheme.creamLight
                          : CelestialTheme.textMuted,
                  decoration: !isAvailable ? TextDecoration.lineThrough : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isAvailable) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: CelestialTheme.roseAlert.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '86\'d',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: CelestialTheme.roseAlert),
                ),
              ),
            ],
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
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 20,
        vertical: isMobile ? 12 : 16,
      ),
      decoration: const BoxDecoration(
        color: CelestialTheme.bgSurface,
        border: Border(
          top: BorderSide(color: CelestialTheme.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Quantity Stepper Pill
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: CelestialTheme.bgSurfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: CelestialTheme.borderSubtle,
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('customization_qty_minus'),
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                  icon: const Icon(Icons.remove_rounded, size: 18),
                  color: CelestialTheme.caramelAccent,
                  disabledColor: CelestialTheme.caramelAccent.withValues(alpha: 0.3),
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '$_quantity',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: CelestialTheme.textLight,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('customization_qty_plus'),
                  onPressed: () => setState(() => _quantity++),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  color: CelestialTheme.caramelAccent,
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Tactile Warm Caramel Add to Order Button
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('customization_add_to_cart_btn'),
                onTap: _isAdding
                    ? null
                    : () async {
                        setState(() => _isAdding = true);
                        await Future.delayed(const Duration(milliseconds: 160));
                        final customs = _buildCustomizationsList();
                        widget.onAddToCart(_quantity, customs, null);
                        if (mounted) Navigator.pop(context);
                      },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: CelestialTheme.caramelAccent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
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
                                Icons.shopping_cart_rounded,
                                size: 19,
                                color: CelestialTheme.bgDark,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _quantity > 1
                                      ? 'Add $_quantity to Order • ₱${_currentTotalPrice.toStringAsFixed(0)}'
                                      : 'Add to Order • ₱${_currentTotalPrice.toStringAsFixed(0)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: isMobile ? 14.5 : 15.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                    color: CelestialTheme.bgDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
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
